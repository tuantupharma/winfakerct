@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "SERVICE_NAME=winfakerct"
set "NSSM_DIR=%ProgramData%\winfakerct\nssm"
set "NSSM_EXE="

net session >nul 2>&1
if errorlevel 1 (
    echo Yêu cầu quyền Administrator...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b %errorlevel%
)

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

if not defined NSSM_EXE (
    echo NSSM chua duoc tim thay.
    echo.
    echo Vui long cai NSSM truoc, sau do chay lai Install.bat.
    echo Trang chinh thuc: https://nssm.cc/download
    echo.
    echo Huong dan nhanh:
    echo  1. Tai NSSM tu https://nssm.cc/download
    echo  2. Giai nen vao thu muc, vi du: C:\Tools\nssm\win64
    echo  3. Dat duong dan den nssm.exe o PATH hoac de o C:\Tools\nssm\win64\nssm.exe
    echo  4. Chay lai Install.bat
    echo.
    pause
    exit /b 1
)

if not exist "%PROJECT_ROOT%\src\WinFakeRctService.ps1" (
    echo Loi: khong tim thay service runner tai "%PROJECT_ROOT%\src\WinFakeRctService.ps1"
    exit /b 1
)

if not exist "%PROJECT_ROOT%\logs" mkdir "%PROJECT_ROOT%\logs" >nul 2>&1

sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo Dang xoa service cu: %SERVICE_NAME%
    "%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
)

echo Dang cai dat service: %SERVICE_NAME%
"%NSSM_EXE%" install "%SERVICE_NAME%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\src\WinFakeRctService.ps1"
"%NSSM_EXE%" set "%SERVICE_NAME%" AppDirectory "%PROJECT_ROOT%"
"%NSSM_EXE%" set "%SERVICE_NAME%" ObjectName LocalSystem
"%NSSM_EXE%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
"%NSSM_EXE%" start "%SERVICE_NAME%"

if errorlevel 1 (
    echo Loi khi tao hoac khoi dong service.
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\NetTimeStartup.ps1" -Action Delay
if errorlevel 1 echo Canh bao: khong the dat NetTime sang Delayed Start. Hay chinh bang services.msc.

echo.
echo Cai dat winfakerct thanh cong.
echo - Service: %SERVICE_NAME%
echo - Service runner: %PROJECT_ROOT%\src\WinFakeRctService.ps1
echo - Log: %PROJECT_ROOT%\logs\winfakerct.log
echo.
echo Luu y: NetTime phai duoc cai san va tu dong dong bo thoi gian theo cach cua no.
echo.
pause
exit /b 0
