@echo off
REM Thin wrapper — delegates to first_run_setup.py using the bundled embedded Python.
REM %1 = install dir, %2 = data dir
setlocal
set "INSTALL_DIR=%~1"
set "DATA_DIR=%~2"
"%INSTALL_DIR%\python\python.exe" "%INSTALL_DIR%\scripts\first_run_setup.py" "%INSTALL_DIR%" "%DATA_DIR%"
exit /b %ERRORLEVEL%
