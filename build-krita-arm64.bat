@echo off
:: ===========================================================================
::  Krita for Windows on ARM64 - ONE-CLICK NATIVE BUILDER
::  Double-click this file. It self-elevates, installs everything it needs,
::  and builds Krita from source for native arm64 (no x64 emulation).
:: ===========================================================================
setlocal EnableDelayedExpansion

:: --- require admin (VS Build Tools install needs it); self-elevate if not ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

set "PS=%~dp0scripts\build-krita-arm64.ps1"
if not exist "%PS%" (
    echo [FATAL] Cannot find %PS%
    pause
    exit /b 1
)

:: Log everything so errors are never lost if the window closes.
set "LOG=%~dp0build-log.txt"
echo Logging to %LOG%
echo Starting native ARM64 Krita build...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" %* 2>&1 | powershell -NoProfile -Command "$input | Tee-Object -FilePath '%LOG%'"
set "RC=%errorlevel%"

echo.
if "%RC%"=="0" (
    echo ============================================================
    echo  BUILD COMPLETE.
    echo  Krita installed at:  C:\kritadeps\krita-install\bin\krita.exe
    echo  Installer + zip:     packaging\arm64-installer\
    echo ============================================================
) else (
    echo ============================================================
    echo  Build stopped with exit code %RC%.
    echo  The full log is saved at: %LOG%
    echo  Scroll up, or open that file, to see what failed.
    echo ============================================================
)
echo.
echo Press any key to close this window...
pause >nul
endlocal
