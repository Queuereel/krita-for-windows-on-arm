@echo off
:: Sets up the native ARM64 build environment for krita-deps-management:
::  - VS 2022 MSVC targeting arm64 (via vcvarsall arm64)
::  - VS-bundled CMake + Ninja on PATH
::  - vswhere dir on PATH (so vcvarsall does not error)
:: Usage:  call dep-env.cmd      (then run cmake/ninja in the same shell)

set "VSROOT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
:: Git's usr/bin provides patch.exe and other unix tools some ext_ recipes need
set "PATH=%VSROOT%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%VSROOT%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%ProgramFiles(x86)%\Microsoft Visual Studio\Installer;C:\Program Files\Git\usr\bin;%PATH%"
call "%VSROOT%\VC\Auxiliary\Build\vcvarsall.bat" arm64
