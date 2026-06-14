# ARM64 Krita Build — Live State
Last updated: 2026-06-14

## Where things are

| Path | What |
|------|------|
| `C:\kritadeps\krita-deps-management\` | KDE dep recipes (`ext_*` cmake projects) |
| `C:\kritadeps\b\` | Build dirs (one per dep) |
| `C:\kritadeps\i\` | Install prefix (all built headers/libs/dlls go here) |
| `C:\kritadeps\d\` | Download cache (tarballs/zips) |
| `C:\kritadeps\LLVM\` | LLVM 19.1.7 ARM64 (clang-cl for x265 NEON) |
| `C:\kritadeps\python313-dev\` | Python 3.13.5 ARM64 full install (dev headers + pip) |
| `C:\KritaARM\scripts\` | Build scripts (`build-deps.cmd`, `dep-env.cmd`) |
| `C:\Users\Queuereel\Documents\Krita ARM\` | This repo's working copy |
| GitHub | `https://github.com/Queuereel/krita-for-windows-on-arm` |

## How to build a dep

```cmd
C:\KritaARM\scripts\build-deps.cmd <depname> [depname2 ...]
```

Cleans nothing. To force-rebuild: `rmdir /S /Q C:\kritadeps\b\ext_<name>` first.

## Build environment (dep-env.cmd key entries)

- VS 2022 ARM64 MSVC via `vcvarsall arm64`
- Strawberry Perl on PATH before Git perl (OpenSSL/Qt)
- ARM64 Python 3.13.5 at `C:\kritadeps\python313-dev` on PATH — must precede system Python 3.14
- LLVM 19 at `C:\kritadeps\LLVM\bin` (clang-cl for x265)
- `C:\kritadeps\i\bin` on PATH for prefix tools (qmake, pkgconf, jom, nasm, gas-preprocessor.pl)

## cmake configure flags (build-deps.cmd)

```
-G Ninja
-DCMAKE_BUILD_TYPE=RelWithDebInfo
-DCMAKE_PREFIX_PATH=C:\kritadeps\i
-DPython_ROOT_DIR=C:\kritadeps\python313-dev
-DPython_EXECUTABLE=C:\kritadeps\python313-dev\python.exe
```

The Python pins prevent cmake finding system Python 3.14 (no dev headers in prefix).

---

## Dependency status

### DONE — native ARM64

- zlib, png, jpeg, tiff, webp, openjpeg, jpegxl, lcms2, expat, exiv2
- giflib, gsl, eigen3, xsimd, immer, iconv, json_c, highway, brotli
- unibreak, nasm, fribidi, extra_cmake_modules, pkgconfig
- freetype (+ harfbuzz via meson)
- openssl (built from source, `VC-WIN64-ARM`)
- boost 1.81 (header-only; b2 has no ARM64 msvc.jam support — Krita only needs headers)
- openexr 2.5.9 (patched ImfSimd.h to gate SSE2 on `_M_X64||_M_IX86`)
- seexpr, libraw, ocio (OpenColorIO), fontconfig, mypaint, quazip
- fftw3, ogg, vorbis, flac, opus, lame, vpx, libde265, libaom, sdl2, libheif
- gettext + KDE Frameworks 5: karchive, kconfig, kcoreaddons, ki18n, kwidgetsaddons,
  kcompletion, kguiaddons, kitemmodels, kitemviews, kwindowsystem, kcrash
- kimageformats, kdcraw
- **ANGLE** (libEGL.dll + libGLESv2.dll, ARM64)
- **Qt 5.15.7** — full: ICU + ANGLE + EGL + dynamic GL (no shortcuts)
- **Python 3.13.5 ARM64 embeddable** (in prefix) + full dev install at python313-dev
- **libx265** 4.1 — 8bit + 10bit + 12bit, clang-cl 19.1.7, NEON + DotProd (ARM64 PE ✓)
- **openh264** 2.3.1 — ARM64 NEON via gas-preprocessor.pl + armasm64 (ARM64 PE ✓)
- **sip** 6.10.0 — installed to `C:\kritadeps\i\lib\site-packages\sipbuild\`

- **PyQt5** 5.15.11 — sip-build → jom → install to site-packages (QtCore/QtGui/QtWidgets .pyd present)
- **ffmpeg** (meson port) — avcodec-61.dll etc. in prefix
- **mlt** 7 — mlt-7.dll + mlt++-7.dll (animation/video export)

### DONE — Krita itself

- **Krita 6.0.2.1** — compiled native ARM64 with pure MSVC cl.exe, 241/241
  plugins linked. Installed to `C:\kritadeps\krita-install`. `krita.exe` PE
  machine 0xAA64; launches natively (no emulation), main window initializes
  clean. See `arm64-patches/KRITA-SOURCE-PATCHES.md` for the source patches.
  Launch via `krita-install/bin/krita-launch.bat`.

### PENDING / TODO

- Verify Python scripting (PyQt5 import inside Krita) + animation export end-to-end in-app

---

## ARM64 patches applied to recipes

### ext_libx265 / ext_libx265_10bit / ext_libx265_12bit

**Problem 1**: x265 aarch64 NEON intrinsics (`arm_neon.h`) use GCC/Clang syntax; MSVC cl.exe can't compile them (C2065).
**Fix**: Switch inner cmake to `clang-cl.exe` (LLVM 19, `aarch64-pc-windows-msvc`, MSVC-ABI compatible).
```cmake
-DCMAKE_C_COMPILER=C:/kritadeps/LLVM/bin/clang-cl.exe
-DCMAKE_CXX_COMPILER=C:/kritadeps/LLVM/bin/clang-cl.exe
```

**Problem 2**: `winbase.h` (SDK 26100) C++ Interlocked overloads call `_InterlockedIncrement(volatile long*)` — clang-cl ARM64 doesn't provide this as a builtin. Error: "no matching function for call to '_InterlockedIncrement'".
**Fix**: Suppress the overload block entirely (x265 doesn't call it):
```cmake
"-DCMAKE_C_FLAGS=-DMICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS=0"
"-DCMAKE_CXX_FLAGS=-DMICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS=0"
```

**Problem 3**: With clang-cl + Ninja (single-config), built lib is at `x265-static.lib` (build root), NOT `RelWithDebInfo/x265-static.lib`. The INSTALL_COMMAND uses `${x265_LIBDIR}${x265_LIBRARY}` and `x265_LIBDIR = "$<CONFIG>/"` which is wrong for Ninja.
**Fix**: For ARM64, set `x265_LIBDIR = ""` (empty) in 10bit and 12bit recipes.

### ext_openexr

**Problem**: `ImfSimd.h` enables SSE2 for any MSVC (`#if _MSC_VER >= 1300 && !_M_CEE_PURE`), causes C1189 on ARM64.
**Fix** (via PATCH_COMMAND sed):
```
s/!_M_CEE_PURE)/!_M_CEE_PURE \&\& (defined(_M_X64) || defined(_M_IX86)))/
```

### ext_boost

**Problem 1**: `b2` (boost build engine) has no `architecture=arm` support in msvc.jam — can't build compiled libs. But boost::system is header-only since 1.69; Krita only needs headers + CMake config.
**Fix**: Skip the DLL-copy `pre_install` step on ARM64 (it copies x32/x64 DLLs that don't exist), and tolerate b2 exit code if headers are installed.

### ext_python

**Problem**: WIN32 recipe downloads `embed-amd64.zip` (x64). ARM64 embeddable exists at `embed-arm64.zip`.
**Fix**: Detect `CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64|arm64"` and use `embed-arm64.zip` (MD5: `0d2b5391a1df1319242f17a8339b8bc6`).

### ext_qt (Qt 5.15.7)

**Key fixes**:
- ICU detection: stale `config.cache` masked 12 fix iterations. Always `rmdir` the qt build dir before reconfiguring. Use `QMAKE_INCDIR_ICU=${EXTPREFIX}/include`.
- EGL/ANGLE: built `ext_googleangle` first (provides `EGL/egl.h`, `libEGL.dll`, `libGLESv2.dll`), then Qt with `-opengl dynamic`.
- `-no-libproxy -no-system-proxies -icu -no-mtdev`

### ext_ffmpeg

**Problem**: KDE patch sets `enable-ssp=enabled` by default; MSVC doesn't support `-fstack-protector-strong`.
**Fix**: Add explicit `else()` branch for MSVC:
```cmake
else()
    set(_stack_guard_flag "-Denable-ssp=disabled")
```
**Also**: `libtheora=enabled` → `libtheora=auto` (no ext_theora recipe in krita-deps-management).

### openh264

**Problem**: ARM64 Windows with MSVC syntax needs `gas-preprocessor.pl` + `armasm64` to assemble GAS-syntax ARM64 asm.
**Fix**: Downloaded `gas-preprocessor.pl` from FFmpeg project to `C:\kritadeps\i\bin\`, created `gas-preprocessor.pl.cmd` wrapper (`perl %~dp0gas-preprocessor.pl %*`). `armasm64.exe` is already in VS ARM64 tools.

---

## Python/sip/PyQt5 setup notes

The embeddable Python zip (ext_python) lacks `python.exe`, `Python.h`, and `python313.lib`. Required for sip/PyQt5:

1. Download & install `python-3.13.5-arm64.exe` to `C:\kritadeps\python313-dev` (silent: `/quiet InstallAllUsers=0 TargetDir=...`)
2. Bootstrap pip: `python.exe C:\kritadeps\d\get-pip.py`
3. Install setuptools: `python.exe -m pip install setuptools wheel`
4. Copy `Python.h` + all includes to `C:\kritadeps\i\include\`
5. Copy `python313.lib`, `python3.lib` to `C:\kritadeps\i\lib\`
6. Copy `python313.dll` to `C:\kritadeps\i\bin\`
7. Pin cmake via `-DPython_ROOT_DIR` + `-DPython_EXECUTABLE` in build-deps.cmd
8. Install `pyqtbuild` + `setuptools` into `C:\kritadeps\i\lib\site-packages\` (pure Python, can use x64 pip to install)
9. Copy `sip-build.exe` from `C:\kritadeps\i\bin\Scripts\` to `C:\kritadeps\i\bin\` (pip puts scripts there on Windows)

---

## LLVM 19.1.7 ARM64 setup

Downloaded `LLVM-19.1.7-woa64.exe` (NSIS), extracted via 7-Zip (no elevation) to `C:\kritadeps\LLVM\`.

Verification:
```
clang-cl --version  → clang version 19.1.7; Target: aarch64-pc-windows-msvc
C:\kritadeps\LLVM\lib\clang\19\include\arm_neon.h  → exists
```

---

## Verified ARM64 binaries

| File | PE machine |
|------|-----------|
| `C:\kritadeps\i\bin\Qt5Core.dll` | 0xAA64 ✓ |
| `C:\kritadeps\i\bin\libEGL.dll` | 0xAA64 ✓ |
| `C:\kritadeps\i\bin\libx265.dll` | 0xAA64 ✓ |
| `C:\kritadeps\i\bin\openh264-7.dll` | 0xAA64 ✓ |
| `C:\kritadeps\python313-dev\python313.dll` | 0xAA64 ✓ |
| `C:\kritadeps\krita-install\bin\krita.exe` | 0xAA64 ✓ |

x265 runtime confirms: `NEON + Neon_DotProd` detected at startup.
Krita confirms: native ARM64 launch, main window "Krita" up, clean stderr.
