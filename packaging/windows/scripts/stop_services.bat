@echo off
REM User-facing "Stop SP Gas Billing Services" shortcut.
net stop SPBillingBackend
net stop SPBillingPostgres
pause
