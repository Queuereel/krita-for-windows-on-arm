@echo off
rem Native ARM64 Krita launcher — sets up runtime environment (Qt plugins, deps DLLs, fontconfig)
set "KRITA_ROOT=%~dp0"
set "DEPS=C:\kritadeps\i"
set "PATH=%KRITA_ROOT%;%DEPS%\bin;%PATH%"
set "QT_PLUGIN_PATH=%DEPS%\plugins"
set "FONTCONFIG_PATH=%DEPS%\etc\fonts"
start "" "%KRITA_ROOT%krita.exe" %*
