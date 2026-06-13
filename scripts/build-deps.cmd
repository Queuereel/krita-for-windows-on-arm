@echo off
:: Build a list of krita-deps-management ext_ packages for native arm64 into a
:: shared prefix. Continues on failure and prints clear OK/FAILED markers.
:: Usage:  build-deps.cmd zlib eigen3 expat lcms2 ...
setlocal
call "%~dp0dep-env.cmd" >nul 2>&1

set "DEPS=C:\KritaARM\krita-deps-management"
set "DL=C:\KritaARM\deps-build\d"
set "PREFIX=C:\KritaARM\deps-build\i"
set "BLD=C:\KritaARM\deps-build\b"

for %%P in (%*) do call :one %%P
echo.
echo ===== ALL DONE =====
goto :eof

:one
echo.
echo ===== ext_%1 =====
if not exist "%DEPS%\ext_%1\CMakeLists.txt" ( echo SKIP_NOEXIST: %1 & exit /b 0 )
cmake -S "%DEPS%\ext_%1" -B "%BLD%\ext_%1" -G Ninja -DEXTERNALS_DOWNLOAD_DIR="%DL%" -DCMAKE_INSTALL_PREFIX="%PREFIX%" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH="%PREFIX%"
if errorlevel 1 ( echo CONFIGURE_FAILED: %1 & exit /b 0 )
cmake --build "%BLD%\ext_%1"
if errorlevel 1 ( echo BUILD_FAILED: %1 & exit /b 0 )
echo OK_BUILT: %1
exit /b 0
