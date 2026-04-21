@echo off
REM ============================================================
REM  Register NSSM services for Postgres + FastAPI backend.
REM  Runs after first_run_setup has initialized the cluster.
REM  %1 = install dir, %2 = data dir
REM ============================================================
setlocal EnableExtensions
set "INSTALL_DIR=%~1"
set "DATA_DIR=%~2"

set "NSSM=%INSTALL_DIR%\tools\nssm.exe"
set "PG_BIN=%INSTALL_DIR%\pgsql\bin"
set "PY=%INSTALL_DIR%\python\python.exe"
set "BACKEND=%INSTALL_DIR%\backend"

set "PGDATA=%DATA_DIR%\pgdata"
set "LOGS=%DATA_DIR%\logs"

if not exist "%LOGS%" mkdir "%LOGS%"

REM ----- Remove any stale registrations (silent if absent) -----
"%NSSM%" stop   SPBillingBackend  >nul 2>&1
"%NSSM%" remove SPBillingBackend  confirm >nul 2>&1
"%NSSM%" stop   SPBillingPostgres >nul 2>&1
"%NSSM%" remove SPBillingPostgres confirm >nul 2>&1

REM ----- Postgres service -----
"%NSSM%" install SPBillingPostgres "%PG_BIN%\pg_ctl.exe" runservice -D "%PGDATA%"
REM Use pg_ctl 'register' semantics via NSSM wrapping the `postgres.exe` directly is more reliable:
"%NSSM%" remove SPBillingPostgres confirm >nul 2>&1
"%NSSM%" install SPBillingPostgres "%PG_BIN%\postgres.exe" -D "%PGDATA%"
"%NSSM%" set SPBillingPostgres DisplayName "SP Gas Billing - Postgres"
"%NSSM%" set SPBillingPostgres Description "PostgreSQL database for SP Gas Billing"
"%NSSM%" set SPBillingPostgres Start SERVICE_AUTO_START
"%NSSM%" set SPBillingPostgres AppStdout "%LOGS%\postgres-stdout.log"
"%NSSM%" set SPBillingPostgres AppStderr "%LOGS%\postgres-stderr.log"
"%NSSM%" set SPBillingPostgres AppStopMethodSkip 0
"%NSSM%" set SPBillingPostgres AppStopMethodConsole 30000
"%NSSM%" set SPBillingPostgres AppRotateFiles 1
"%NSSM%" set SPBillingPostgres AppRotateBytes 10485760

REM ----- Backend service (uvicorn) -----
"%NSSM%" install SPBillingBackend "%PY%" -m uvicorn app.main:app --host 127.0.0.1 --port 8001
"%NSSM%" set SPBillingBackend DisplayName "SP Gas Billing - API"
"%NSSM%" set SPBillingBackend Description "FastAPI backend for SP Gas Billing"
"%NSSM%" set SPBillingBackend AppDirectory "%BACKEND%"
"%NSSM%" set SPBillingBackend AppEnvironmentExtra "PYTHONPATH=%BACKEND%"
"%NSSM%" set SPBillingBackend Start SERVICE_AUTO_START
"%NSSM%" set SPBillingBackend DependOnService SPBillingPostgres
"%NSSM%" set SPBillingBackend AppStdout "%LOGS%\backend-stdout.log"
"%NSSM%" set SPBillingBackend AppStderr "%LOGS%\backend-stderr.log"
"%NSSM%" set SPBillingBackend AppRotateFiles 1
"%NSSM%" set SPBillingBackend AppRotateBytes 10485760
REM Restart on crash with 5 sec delay, up to 3 attempts
"%NSSM%" set SPBillingBackend AppRestartDelay 5000
"%NSSM%" set SPBillingBackend AppExit Default Restart

REM ----- Start both -----
net start SPBillingPostgres >> "%LOGS%\install.log" 2>&1
REM Give Postgres a moment to open the socket before API starts hitting it
ping -n 4 127.0.0.1 >nul
net start SPBillingBackend >> "%LOGS%\install.log" 2>&1

echo [install_services] services registered and started >> "%LOGS%\install.log"
endlocal
exit /b 0
