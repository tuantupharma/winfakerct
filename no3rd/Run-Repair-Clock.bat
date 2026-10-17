@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-Clock.ps1" %*
set "RC=%errorlevel%"
rem Keep the window open for a double-click; schedule Repair-Clock.ps1 directly for unattended runs.
echo %cmdcmdline% | find /i "%~nx0" >nul && pause
exit /b %RC%