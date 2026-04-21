<#
.SYNOPSIS
  Build the SP Gas Billing Windows installer locally.

.DESCRIPTION
  Replicates the GitHub Actions workflow on a local Windows machine.
  Run from the repository root:

      .\packaging\windows\build-installer.ps1

  Requirements (install once, ~30 min):
    - Flutter SDK (on PATH)          https://docs.flutter.dev/get-started/install/windows
    - Visual Studio 2022 Community with "Desktop development with C++" workload
    - Inno Setup 6                   https://jrsoftware.org/isdl.php
    - Git (PowerShell 5.1+ is built in on Windows 10/11)

  First run downloads Python embedded (~15 MB), Postgres binaries (~200 MB),
  and NSSM (~2 MB) into .build-cache\ — subsequent runs reuse the cache.

.PARAMETER Clean
  Wipe intermediate build output (payload/, output/) before building. Does not
  clear .build-cache\ — downloaded archives are always reused.

.PARAMETER SkipFlutter
  Skip `flutter pub get` + `flutter build`. Useful when iterating on
  backend/packaging/installer changes without retouching the app.
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipFlutter
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest runs ~50x faster without it

# --- Pin versions (must match .github/workflows/windows-installer.yml) --------
$PY_VERSION   = "3.11.9"
$PG_VERSION   = "16.4-1"
$NSSM_VERSION = "2.24"

# --- Resolve repo root (two levels up from this script) ----------------------
$RepoRoot    = Resolve-Path (Join-Path $PSScriptRoot "..\..") | Select-Object -ExpandProperty Path
$CacheDir    = Join-Path $RepoRoot ".build-cache"
$WorkDir     = Join-Path $RepoRoot ".build-work"
$PayloadDir  = Join-Path $RepoRoot "packaging\payload"
$OutputDir   = Join-Path $RepoRoot "packaging\output"
$AppDir      = Join-Path $RepoRoot "app"
$BackendDir  = Join-Path $RepoRoot "backend"
$ScriptsSrc  = Join-Path $RepoRoot "packaging\windows\scripts"
$IssPath     = Join-Path $RepoRoot "packaging\windows\installer.iss"

Set-Location $RepoRoot

function Section($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Fetch($url, $dest) {
    if (Test-Path $dest) {
        Write-Host "  cached: $(Split-Path $dest -Leaf)"
        return
    }
    Write-Host "  downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $dest
}

function Require($exe, $help) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        throw "'$exe' not found on PATH. $help"
    }
}

# ================================================================= preflight
Section "Preflight checks"

if (-not $SkipFlutter) {
    Require "flutter" "Install Flutter SDK: https://docs.flutter.dev/get-started/install/windows"
}

$ISCC = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $ISCC)) {
    $ISCC = "C:\Program Files\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $ISCC)) {
    throw "Inno Setup 6 not found. Install from https://jrsoftware.org/isdl.php"
}
Write-Host "  flutter:     $(if ($SkipFlutter) { 'SKIPPED' } else { (Get-Command flutter).Source })"
Write-Host "  Inno Setup:  $ISCC"

New-Item -ItemType Directory -Force -Path $CacheDir, $WorkDir, $OutputDir | Out-Null

if ($Clean) {
    Section "Cleaning previous build output"
    Remove-Item $PayloadDir, $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $WorkDir, $OutputDir | Out-Null
}

# ============================================================ 1. Flutter build
if (-not $SkipFlutter) {
    Section "1/7  Flutter — Windows release build"
    Push-Location $AppDir
    try {
        flutter pub get
        flutter build windows --release
    } finally {
        Pop-Location
    }
} else {
    Section "1/7  Flutter — SKIPPED (-SkipFlutter)"
}

$flutterRelease = Join-Path $AppDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $flutterRelease "sp_billing.exe"))) {
    throw "Flutter release not found at $flutterRelease. Rerun without -SkipFlutter."
}

# ============================================================= 2. Python embedded
Section "2/7  Python $PY_VERSION embedded + pip"
$pyZip    = Join-Path $CacheDir "python-$PY_VERSION-embed-amd64.zip"
$getPip   = Join-Path $CacheDir "get-pip.py"
$pyDir    = Join-Path $WorkDir "python"

Fetch "https://www.python.org/ftp/python/$PY_VERSION/python-$PY_VERSION-embed-amd64.zip" $pyZip
Fetch "https://bootstrap.pypa.io/get-pip.py" $getPip

if (Test-Path $pyDir) { Remove-Item $pyDir -Recurse -Force }
Expand-Archive $pyZip -DestinationPath $pyDir

# Enable `import site` so pip-installed packages are discoverable
$pth = Get-ChildItem $pyDir -Filter "python*._pth" | Select-Object -First 1
(Get-Content $pth.FullName) -replace '^#import site','import site' | Set-Content $pth.FullName

$pyExe = Join-Path $pyDir "python.exe"
& $pyExe $getPip --no-warn-script-location
if ($LASTEXITCODE -ne 0) { throw "get-pip failed" }

# Install backend requirements into embedded python
& $pyExe -m pip install --no-warn-script-location --upgrade pip
& $pyExe -m pip install --no-warn-script-location -r (Join-Path $BackendDir "requirements.txt")
if ($LASTEXITCODE -ne 0) { throw "pip install -r requirements.txt failed" }

# Sanity check
& $pyExe -c "import fastapi, sqlalchemy, psycopg, alembic, bcrypt, reportlab; print('embedded python OK')"
if ($LASTEXITCODE -ne 0) { throw "embedded python import check failed" }

# ============================================================ 3. Postgres
Section "3/7  Postgres $PG_VERSION binaries"
$pgZip     = Join-Path $CacheDir "postgresql-$PG_VERSION-windows-x64-binaries.zip"
$pgExtract = Join-Path $WorkDir "pgsql-extract"

Fetch "https://get.enterprisedb.com/postgresql/postgresql-$PG_VERSION-windows-x64-binaries.zip" $pgZip

if (Test-Path $pgExtract) { Remove-Item $pgExtract -Recurse -Force }
Expand-Archive $pgZip -DestinationPath $pgExtract
if (-not (Test-Path (Join-Path $pgExtract "pgsql\bin\postgres.exe"))) {
    throw "Unexpected Postgres zip layout — no pgsql\bin\postgres.exe"
}

# ============================================================ 4. NSSM
Section "4/7  NSSM $NSSM_VERSION"
$nssmZip     = Join-Path $CacheDir "nssm-$NSSM_VERSION.zip"
$nssmExtract = Join-Path $WorkDir "nssm-extract"

Fetch "https://nssm.cc/release/nssm-$NSSM_VERSION.zip" $nssmZip

if (Test-Path $nssmExtract) { Remove-Item $nssmExtract -Recurse -Force }
Expand-Archive $nssmZip -DestinationPath $nssmExtract
$nssmExe = Join-Path $nssmExtract "nssm-$NSSM_VERSION\win64\nssm.exe"
if (-not (Test-Path $nssmExe)) { throw "nssm.exe not found in archive" }

# ============================================================ 5. Assemble payload
Section "5/7  Assembling payload"
if (Test-Path $PayloadDir) { Remove-Item $PayloadDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null

# app
Copy-Item (Join-Path $flutterRelease "*") -Destination (Join-Path $PayloadDir "app") -Recurse -Force

# backend source (exclude __pycache__, venv, .env)
$null = robocopy $BackendDir (Join-Path $PayloadDir "backend") /E /XD __pycache__ venv .venv /XF .env
if ($LASTEXITCODE -ge 8) { throw "robocopy backend failed: $LASTEXITCODE" }
$LASTEXITCODE = 0   # robocopy 1-7 are "success-with-info", reset for downstream checks

# embedded python
Copy-Item (Join-Path $pyDir "*") -Destination (Join-Path $PayloadDir "python") -Recurse -Force

# postgres
Copy-Item (Join-Path $pgExtract "pgsql\*") -Destination (Join-Path $PayloadDir "pgsql") -Recurse -Force

# nssm
New-Item -ItemType Directory -Force -Path (Join-Path $PayloadDir "tools") | Out-Null
Copy-Item $nssmExe -Destination (Join-Path $PayloadDir "tools\nssm.exe") -Force

# scripts
Copy-Item (Join-Path $ScriptsSrc "*") -Destination (Join-Path $PayloadDir "scripts") -Recurse -Force

Write-Host "  payload layout:"
Get-ChildItem $PayloadDir | ForEach-Object {
    $size = [math]::Round((Get-ChildItem $_.FullName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host ("    {0,-12} {1,8} MB" -f $_.Name, $size)
}

# ============================================================ 6. Inno Setup
Section "6/7  Compiling installer (Inno Setup)"
& $ISCC $IssPath
if ($LASTEXITCODE -ne 0) { throw "ISCC failed: $LASTEXITCODE" }

# ============================================================ 7. Report
Section "7/7  Done"
$exe = Get-ChildItem $OutputDir -Filter "SPBilling-Setup-*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw "No installer produced in $OutputDir" }

$sizeMB = [math]::Round($exe.Length / 1MB, 1)
Write-Host ""
Write-Host "  Built: $($exe.FullName)" -ForegroundColor Green
Write-Host "  Size:  $sizeMB MB"
Write-Host ""
Write-Host "  Double-click to install, or from an elevated prompt:"
Write-Host "    `"$($exe.FullName)`" /SILENT"
