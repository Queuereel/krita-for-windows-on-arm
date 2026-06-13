@echo off
:: Sets up the native ARM64 build environment for krita-deps-management:
::  - VS 2022 MSVC targeting arm64 (via vcvarsall arm64)
::  - VS-bundled CMake + Ninja on PATH
::  - vswhere dir on PATH (so vcvarsall does not error)
:: Usage:  call dep-env.cmd      (then run cmake/ninja in the same shell)

set "VSROOT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
:: Git's usr/bin provides patch.exe and other unix tools some ext_ recipes need
:: meson (for ext_fribidi etc.) lives in the Python Scripts dir after pip install
set "PYSCRIPTS=%LOCALAPPDATA%\Programs\Python\Python311\Scripts"
:: Strawberry (Windows-native) perl MUST precede Git's msys perl: openssl/Qt Configure
:: break with msys perl (it emits unix-style paths). Built by ext_strawberryperl.
set "SBPERL=C:\kritadeps\i\Strawberry\perl\bin;C:\kritadeps\i\Strawberry\c\bin"
set "PATH=%SBPERL%;%VSROOT%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%VSROOT%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%ProgramFiles(x86)%\Microsoft Visual Studio\Installer;%PYSCRIPTS%;C:\Program Files\Git\usr\bin;%PATH%"
call "%VSROOT%\VC\Auxiliary\Build\vcvarsall.bat" arm64

:: Put the install prefix bin on PATH so config-test probe exes (e.g. Qt's ICU
:: test) can load the dependency DLLs at runtime.
set "PATH=C:\kritadeps\i\bin;%PATH%"

:: Let pkg-config (and meson) find .pc files from the shared install prefix
:: (e.g. freetype2.pc -> Requires: libpng -> libpng.pc lives in the main prefix)
set "PKG_CONFIG_PATH=C:\kritadeps\i\lib\pkgconfig;C:\kritadeps\i\share\pkgconfig;%PKG_CONFIG_PATH%"
