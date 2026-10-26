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

if not exist "%PROJECT_ROOT%\src\RepairClockService.ps1" (
    echo Loi: khong tim thay service runner tai "%PROJECT_ROOT%\src\RepairClockService.ps1"
    exit /b 1
)

if not exist "%PROJECT_ROOT%\logs" mkdir "%PROJECT_ROOT%\logs" >nul 2>&1

echo.
echo Chon loai service can cai dat:
echo  1. WinFakeRct (can NetTime, khuyen khich)
echo  2. RepairClock (khong can NetTime, chay tu dong tu Internet)
echo  3. Ca hai
set /p CHON="Nhap lua chon (1-3): "

if "%CHON%"=="1" (
    set "INSTALL_WINFAKERCT=1"
) else if "%CHON%"=="2" (
    set "INSTALL_REPAIRCLOCK=1"
) else if "%CHON%"=="3" (
    set "INSTALL_WINFAKERCT=1"
    set "INSTALL_REPAIRCLOCK=1"
) else (
    echo Lua chon khong hop le. Thoat.
    exit /b 1
)

echo.
set /p NAM="Nhap nam hien tai (vi du 2026) de cai dat ResetYearThreshold: "
if "%NAM%"=="" (
    echo Chua nhap nam. Thoat.
    exit /b 1
)
set /a NAM_TEST=%NAM% 2>nul
if errorlevel 1 (
    echo Nam khong hop le. Thoat.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%PROJECT_ROOT%\config.json'; $c=Get-Content $p -Raw | ConvertFrom-Json; $c.ResetYearThreshold=%NAM%; $c | ConvertTo-Json -Depth 5 | Set-Content $p -Encoding UTF8"
if errorlevel 1 (
    echo Loi khi cap nhat config.json. Thoat.
    exit /b 1
)

if defined INSTALL_WINFAKERCT (
    sc query "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto SkipWinFakeRctRemove
    echo Dang xoa service cu: %SERVICE_NAME%
    "%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
    echo Dang cho service bi xoa hoan toan...
    set /a COUNT=0
    :WaitWinFakeRct
    sc query "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto WinFakeRctRemoved
    set /a COUNT+=1
    if !COUNT! GTR 30 (
        echo Khong the xoa service %SERVICE_NAME% sau 30 lan thu. Vui long khoi dong may tinh va chay lai Install.bat.
        exit /b 1
    )
    timeout /t 1 >nul
    goto WaitWinFakeRct
    :WinFakeRctRemoved
    :SkipWinFakeRctRemove

    echo Dang cai dat service: %SERVICE_NAME%
    "%NSSM_EXE%" install "%SERVICE_NAME%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\src\WinFakeRctService.ps1"
    "%NSSM_EXE%" set "%SERVICE_NAME%" AppDirectory "%PROJECT_ROOT%"
    "%NSSM_EXE%" set "%SERVICE_NAME%" ObjectName LocalSystem
    "%NSSM_EXE%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
    "%NSSM_EXE%" start "%SERVICE_NAME%"

    if errorlevel 1 (
        echo Loi khi tao hoac khoi dong service %SERVICE_NAME%.
        exit /b 1
    )

    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\NetTimeStartup.ps1" -Action Delay
    if errorlevel 1 echo Canh bao: khong the dat NetTime sang Delayed Start. Hay chinh bang services.msc.
)

set "RC_SERVICE_NAME=repairclock"
if defined INSTALL_REPAIRCLOCK (
    sc query "%RC_SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto SkipRepairClockRemove
    echo Dang xoa service cu: %RC_SERVICE_NAME%
    "%NSSM_EXE%" remove "%RC_SERVICE_NAME%" confirm >nul 2>&1
    echo Dang cho service bi xoa hoan toan...
    set /a COUNT=0
    :WaitRepairClock
    sc query "%RC_SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto RepairClockRemoved
    set /a COUNT+=1
    if !COUNT! GTR 30 (
        echo Khong the xoa service %RC_SERVICE_NAME% sau 30 lan thu. Vui long khoi dong may tinh va chay lai Install.bat.
        exit /b 1
    )
    timeout /t 1 >nul
    goto WaitRepairClock
    :RepairClockRemoved
    :SkipRepairClockRemove

    echo Dang cai dat service: %RC_SERVICE_NAME%
    "%NSSM_EXE%" install "%RC_SERVICE_NAME%" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\src\RepairClockService.ps1"
    "%NSSM_EXE%" set "%RC_SERVICE_NAME%" AppDirectory "%PROJECT_ROOT%"
    "%NSSM_EXE%" set "%RC_SERVICE_NAME%" ObjectName LocalSystem
    "%NSSM_EXE%" set "%RC_SERVICE_NAME%" Start SERVICE_AUTO_START
    "%NSSM_EXE%" start "%RC_SERVICE_NAME%"

    if errorlevel 1 (
        echo Loi khi tao hoac khoi dong service %RC_SERVICE_NAME%.
        exit /b 1
    )
)

echo.
echo Cai dat thanh cong.
if defined INSTALL_WINFAKERCT (
    echo - Service: %SERVICE_NAME% (WinFakeRct, can NetTime)
    echo - Kiem tra: sc query "%SERVICE_NAME%"
)
if defined INSTALL_REPAIRCLOCK (
    echo - Service: %RC_SERVICE_NAME% (RepairClock, khong can NetTime)
    echo - Kiem tra: sc query "%RC_SERVICE_NAME%"
)
echo - Thu muc log: %PROJECT_ROOT%\logs\
echo.
echo Luu y: Neu chon RepairClock, service se chay tu dong lay gio tu Internet (NTP/HTTPS) va cap nhat dong ho.
echo.
pause
exit /b 0
