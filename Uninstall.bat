@echo off
setlocal EnableExtensions

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\NetTimeStartup.ps1" -Action Restore
if errorlevel 1 echo Canh bao: khong the khoi phuc startup cua NetTime. Trang thai da luu duoc giu lai de phuc hoi thu cong.

set "SERVICE_NAME=winfakerct"
set "NSSM_EXE="

for %%I in (
    "%ProgramFiles%\NSSM\win64\nssm.exe"
    "%ProgramFiles(x86)%\NSSM\win64\nssm.exe"
    "%ProgramFiles%\NSSM\win32\nssm.exe"
    "%ProgramFiles(x86)%\NSSM\win32\nssm.exe"
    "%ProgramData%\chocolatey\bin\nssm.exe"
    "C:\Tools\nssm\win64\nssm.exe"
    "C:\Tools\nssm\win32\nssm.exe"
) do (
    if exist "%%~I" set "NSSM_EXE=%%~I"
)

sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Service %SERVICE_NAME% khong ton tai.
    pause
    exit /b 0
)

if defined NSSM_EXE (
    echo Dang xoa service %SERVICE_NAME% bang NSSM...
    "%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
) else (
    echo NSSM khong tim thay. Dang xoa service bang sc.exe...
    sc.exe delete "%SERVICE_NAME%" >nul 2>&1
)

echo Da xoa service %SERVICE_NAME%.
echo Project va log khong bi xoa.
pause
exit /b 0
