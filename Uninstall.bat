@echo off
setlocal EnableExtensions

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\NetTimeStartup.ps1" -Action Restore
if errorlevel 1 echo Canh bao: khong the khoi phuc startup cua NetTime. Trang thai da luu duoc giu lai de phuc hoi thu cong.

set "SERVICE_NAME=winfakerct"
set "RC_SERVICE_NAME=repairclock"
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

echo.
echo Chon service can gỡ:
echo  1. WinFakeRct
echo  2. RepairClock
echo  3. Ca hai
set /p CHON="Nhap lua chon (1-3): "

if "%CHON%"=="1" (
    set "REMOVE_WINFAKERCT=1"
) else if "%CHON%"=="2" (
    set "REMOVE_REPAIRCLOCK=1"
) else if "%CHON%"=="3" (
    set "REMOVE_WINFAKERCT=1"
    set "REMOVE_REPAIRCLOCK=1"
) else (
    echo Lua chon khong hop le. Thoat.
    pause
    exit /b 1
)

:RemoveService
if defined REMOVE_WINFAKERCT (
    sc query "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 (
        echo Service %SERVICE_NAME% khong ton tai.
    ) else (
        if defined NSSM_EXE (
            echo Dang xoa service %SERVICE_NAME% bang NSSM...
            "%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
        ) else (
            echo NSSM khong tim thay. Dang xoa service %SERVICE_NAME% bang sc.exe...
            sc.exe delete "%SERVICE_NAME%" >nul 2>&1
        )
        echo Da xoa service %SERVICE_NAME%.
    )
    set "REMOVE_WINFAKERCT="
)

if defined REMOVE_REPAIRCLOCK (
    sc query "%RC_SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 (
        echo Service %RC_SERVICE_NAME% khong ton tai.
    ) else (
        if defined NSSM_EXE (
            echo Dang xoa service %RC_SERVICE_NAME% bang NSSM...
            "%NSSM_EXE%" remove "%RC_SERVICE_NAME%" confirm >nul 2>&1
        ) else (
            echo NSSM khong tim thay. Dang xoa service %RC_SERVICE_NAME% bang sc.exe...
            sc.exe delete "%RC_SERVICE_NAME%" >nul 2>&1
        )
        echo Da xoa service %RC_SERVICE_NAME%.
    )
    set "REMOVE_REPAIRCLOCK="
)

echo.
echo Project va log khong bi xoa.
pause
exit /b 0
