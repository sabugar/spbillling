@echo off
REM User-facing "Start SP Gas Billing Services" shortcut.
net start SPBillingPostgres
ping -n 3 127.0.0.1 >nul
net start SPBillingBackend
pause
