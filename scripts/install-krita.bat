@echo off
call "C:\KritaARM\scripts\dep-env.cmd" > nul 2>&1
cmake --install C:\kritadeps\b\krita
echo.
echo INSTALL EXIT: %ERRORLEVEL%
