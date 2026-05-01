@echo off
setlocal enabledelayedexpansion
set ROOT=%~dp0
set ROOT=%ROOT:~0,-1%
set APP_URL=http://127.0.0.1:5173
set API_URL=http://127.0.0.1:8001/docs
set WEB_DIR=%ROOT%\app\build\web

title S. P. Gas Billing Launcher

echo =========================================
echo   S. P. Gas Billing - Starting
echo =========================================
echo.

REM --- Sanity: web build mojud hai? ---
if not exist "%WEB_DIR%\main.dart.js" (
    echo ERROR: Web build nahi mila ^(%WEB_DIR%^).
    echo Ek baar build karna padega:
    echo   cd "%ROOT%\app" ^&^& C:\flutter\bin\flutter.bat build web --release
    pause
    exit /b 1
)

REM --- Backend check ---
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%API_URL%' -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [1/3] Backend start ho raha hai...
    start "SPGas Backend" /min cmd /k "cd /d "%ROOT%\backend" && set PYTHONIOENCODING=utf-8&& set PYTHONUTF8=1&& venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8001"
) else (
    echo [1/3] Backend already chal raha hai.
)

REM --- Static web server check ---
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri '%APP_URL%' -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [2/3] App web server start ho raha hai...
    start "SPGas Web" /min cmd /k "cd /d "%WEB_DIR%" && python -m http.server 5173 --bind 127.0.0.1"
) else (
    echo [2/3] App web server already chal raha hai.
)

echo.
echo [3/3] App ready hone ka wait kar rahe hain...

REM --- Wait up to 30 seconds for app + backend to be reachable ---
set /a TRIES=0
:waitloop
powershell -NoProfile -Command "try { $a = Invoke-WebRequest -UseBasicParsing -Uri '%APP_URL%' -TimeoutSec 2; $b = Invoke-WebRequest -UseBasicParsing -Uri '%API_URL%' -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto ready
set /a TRIES+=1
if %TRIES% GEQ 15 goto timeout
timeout /t 2 >nul
goto waitloop

:ready
echo Ready! Browser khol rahe hain...
start "" "%APP_URL%"
timeout /t 2 >nul
exit /b 0

:timeout
echo.
echo Time out ho gaya. "SPGas Backend" / "SPGas Web" terminals check karen.
echo Manually: %APP_URL%
start "" "%APP_URL%"
pause
exit /b 1
