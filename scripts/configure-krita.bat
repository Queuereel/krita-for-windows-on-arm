@echo off
call "C:\KritaARM\scripts\dep-env.cmd" > nul 2>&1
if not exist C:\kritadeps\b\krita mkdir C:\kritadeps\b\krita
cmake -S C:\KritaARM\krita-src -B C:\kritadeps\b\krita ^
  -G Ninja ^
  -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
  -DCMAKE_PREFIX_PATH=C:\kritadeps\i ^
  -DCMAKE_INSTALL_PREFIX=C:\kritadeps\krita-install ^
  -DPython_ROOT_DIR=C:\kritadeps\python313-dev ^
  -DPython_EXECUTABLE=C:\kritadeps\python313-dev\python.exe ^
  -DBUILD_TESTING=OFF ^
  -DHIDE_SAFE_ASSERTS=ON ^
  -DKRITA_ENABLE_PCH=OFF ^
  -DCMAKE_CXX_STANDARD=20
echo.
echo CONFIGURE EXIT: %ERRORLEVEL%
