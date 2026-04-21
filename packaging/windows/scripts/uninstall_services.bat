@echo off
REM Stop + remove NSSM services. Called from installer.iss [UninstallRun].
REM %1 = install dir, %2 = data dir
setlocal EnableExtensions
set "INSTALL_DIR=%~1"
set "DATA_DIR=%~2"
set "NSSM=%INSTALL_DIR%\tools\nssm.exe"

if exist "%NSSM%" (
  "%NSSM%" stop   SPBillingBackend  >nul 2>&1
  "%NSSM%" remove SPBillingBackend  confirm >nul 2>&1
  "%NSSM%" stop   SPBillingPostgres >nul 2>&1
  "%NSSM%" remove SPBillingPostgres confirm >nul 2>&1
) else (
  REM NSSM already removed — fall back to sc
  sc stop   SPBillingBackend  >nul 2>&1
  sc delete SPBillingBackend  >nul 2>&1
  sc stop   SPBillingPostgres >nul 2>&1
  sc delete SPBillingPostgres >nul 2>&1
)

endlocal
exit /b 0
