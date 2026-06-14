@echo off
call "C:\KritaARM\scripts\dep-env.cmd" > nul 2>&1
cmake --build C:\kritadeps\b\krita --parallel
echo.
echo BUILD EXIT: %ERRORLEVEL%
