; SP Gas Billing — Windows Installer
; Built by Inno Setup 6. Bundles Flutter app + FastAPI backend + embedded Python + portable Postgres + NSSM.
;
; Staged layout (assembled by the GitHub Actions workflow before compile):
;   payload/
;     app/          Flutter Windows Release folder (sp_billing.exe + DLLs + data/)
;     backend/      FastAPI source (app/, alembic/, scripts/, alembic.ini, requirements.txt)
;     python/       Embedded Python 3.11 with pip + all requirements preinstalled
;     pgsql/        Postgres 16 Windows binaries (bin/, lib/, share/)
;     tools/        nssm.exe
;     scripts/      first_run_setup.bat, install_services.bat, uninstall_services.bat, start/stop helpers
;
; Install destination : C:\Program Files\SP Gas Billing\
; Mutable data        : C:\ProgramData\SP Gas Billing\
;   pgdata/   Postgres cluster data (survives uninstall unless user opts to wipe)
;   logs/     Service stdout/stderr captured by NSSM
;   backend.env  Generated on first install with random SECRET_KEY

#define AppName       "SP Gas Billing"
#define AppVersion    "1.0.0"
#define AppPublisher  "SP Gas Agency"
#define AppExeName    "sp_billing.exe"
#define ServicePg     "SPBillingPostgres"
#define ServiceApi    "SPBillingBackend"

[Setup]
AppId={{8E7C2F8A-3B42-4A9D-9F1C-SPBILLING00001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\output
OutputBaseFilename=SPBilling-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\app\{#AppExeName}
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; Flutter app
Source: "..\payload\app\*"; DestDir: "{app}\app"; Flags: ignoreversion recursesubdirs createallsubdirs
; Backend source
Source: "..\payload\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs
; Embedded Python + site-packages
Source: "..\payload\python\*"; DestDir: "{app}\python"; Flags: ignoreversion recursesubdirs createallsubdirs
; Postgres binaries
Source: "..\payload\pgsql\*"; DestDir: "{app}\pgsql"; Flags: ignoreversion recursesubdirs createallsubdirs
; NSSM
Source: "..\payload\tools\nssm.exe"; DestDir: "{app}\tools"; Flags: ignoreversion
; Helper scripts
Source: "..\payload\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\{#AppName}"; Permissions: users-modify
Name: "{commonappdata}\{#AppName}\pgdata"; Permissions: users-modify
Name: "{commonappdata}\{#AppName}\logs"; Permissions: users-modify

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\app\{#AppExeName}"; WorkingDir: "{app}\app"
Name: "{group}\Start {#AppName} Services"; Filename: "{app}\scripts\start_services.bat"; IconFilename: "{app}\app\{#AppExeName}"
Name: "{group}\Stop {#AppName} Services"; Filename: "{app}\scripts\stop_services.bat"; IconFilename: "{app}\app\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\app\{#AppExeName}"; WorkingDir: "{app}\app"; Tasks: desktopicon

[Run]
; 1. Initialize Postgres cluster (idempotent — script skips if pgdata already populated)
Filename: "{app}\scripts\first_run_setup.bat"; \
  Parameters: """{app}"" ""{commonappdata}\{#AppName}"""; \
  StatusMsg: "Initializing database (this may take 30-60 seconds)..."; \
  Flags: runhidden waituntilterminated
; 2. Register + start Windows services via NSSM
Filename: "{app}\scripts\install_services.bat"; \
  Parameters: """{app}"" ""{commonappdata}\{#AppName}"""; \
  StatusMsg: "Registering background services..."; \
  Flags: runhidden waituntilterminated
; 3. Offer to launch the app
Filename: "{app}\app\{#AppExeName}"; \
  Description: "Launch {#AppName} now"; \
  Flags: postinstall nowait skipifsilent

[UninstallRun]
; Stop + remove services BEFORE files are deleted
Filename: "{app}\scripts\uninstall_services.bat"; \
  Parameters: """{app}"" ""{commonappdata}\{#AppName}"""; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "RemoveServices"

[UninstallDelete]
; Clean generated artifacts. Postgres data is kept by default —
; user can manually delete C:\ProgramData\SP Gas Billing\ if desired.
Type: files; Name: "{commonappdata}\{#AppName}\backend.env"

[Code]
// Prevent installing over a running app
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Best-effort: stop services if they exist from a previous install
  Exec(ExpandConstant('{cmd}'), '/C net stop SPBillingBackend >nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{cmd}'), '/C net stop SPBillingPostgres >nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
