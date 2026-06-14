@echo off
:: Build a list of krita-deps-management ext_ packages for native arm64 into a
:: shared prefix. Continues on failure and prints clear OK/FAILED markers.
:: Usage:  build-deps.cmd zlib eigen3 expat lcms2 ...
setlocal
call "%~dp0dep-env.cmd" >nul 2>&1

:: No-space real paths: spaces break meson/pkg-config/Qt. Surfaced under
:: Documents\Krita ARM\deps-build via a junction for visibility.
set "DEPS=C:\kritadeps\krita-deps-management"
set "DL=C:\kritadeps\d"
set "PREFIX=C:\kritadeps\i"
set "BLD=C:\kritadeps\b"

for %%P in (%*) do call :one %%P
echo.
echo ===== ALL DONE =====
goto :eof

:one
echo.
echo ===== ext_%1 =====
if not exist "%DEPS%\ext_%1\CMakeLists.txt" ( echo SKIP_NOEXIST: %1 & exit /b 0 )
cmake -S "%DEPS%\ext_%1" -B "%BLD%\ext_%1" -G Ninja -DEXTERNALS_DOWNLOAD_DIR="%DL%" -DCMAKE_INSTALL_PREFIX="%PREFIX%" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH="%PREFIX%" -DPython_ROOT_DIR=C:\kritadeps\python313-dev -DPython_EXECUTABLE=C:\kritadeps\python313-dev\python.exe
if errorlevel 1 ( echo CONFIGURE_FAILED: %1 & exit /b 0 )
:: ext_install is the canonical install target (global-config.yml force-install-target).
:: Some recipes (e.g. freetype) stage into a bootstrap prefix and only copy into the
:: shared prefix via ext_install, so always drive that target.
cmake --build "%BLD%\ext_%1" --target ext_install
if errorlevel 1 ( echo BUILD_FAILED: %1 & exit /b 0 )
echo OK_BUILT: %1
exit /b 0
