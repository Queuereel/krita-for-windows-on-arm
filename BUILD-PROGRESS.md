# Native ARM64 Krita â€” build progress log

Running record of the Windows-on-ARM64 native build. Updated as waves complete.
Goal: **full-featured** Krita 6.0.2.1 (scripting + animation included).

## Pipeline
- Toolchain: VS 2022 native ARM64 MSVC 14.44 + CMake + Ninja + meson (pip)
- Build root (no-space, required): `C:\kritadeps`  (junctioned to `Documents\Krita ARM\deps-build`)
- Driver: `scripts\build-deps.cmd <names...>` (configure+build each `ext_` into shared prefix)
- Install prefix: `C:\kritadeps\i`

## Dependency status

### âœ… Built native ARM64 (unpatched unless noted)
zlib Â· png Â· jpeg Â· tiff Â· webp Â· openjpeg Â· jpegxl Â· lcms2 Â· expat Â· exiv2 Â·
giflib Â· gsl Â· eigen3 Â· xsimd Â· immer Â· iconv Â· json_c Â· highway Â· brotli Â·
unibreak Â· nasm Â· fribidi Â· extra_cmake_modules Â· pkgconfig Â· freetype(+harfbuzz)

> Note: 23/24 leaf+image deps built with **zero arm64 patches** â€” strong sign the
> krita-deps-management/CMake path handles arm64 far better than Craft did.

### ðŸ”§ Fixes applied so far
- meson installed via pip; added to build env PATH (fribidi/harfbuzz)
- pkgconfig built early so meson can resolve freetype2 (harfbuzz)
- relocated build to no-space path (meson/Qt break on spaces)
- added `PKG_CONFIG_PATH` (main prefix) to build env so `.pc` Requires chains resolve
- created `libpng.pc`/`libpng16.pc` in prefix (ext_png installs CMake config but no
  `.pc`; freetype2.pc's `Requires: libpng` needs it for harfbuzz meson). TODO: make
  this durable via a post-png fixup in the one-click flow.

### â¬œ Pending â€” mid tier
openssl (expect `VC-WIN64-ARM`) Â· boost (expect `architecture=arm address-model=64`) Â·
openexr Â· OpenColorIO (ocio) Â· libraw Â· quazip Â· mypaint Â· lager Â· zug Â· seexpr Â·
fontconfig Â· libheif/libaom/libde265 Â· zug

### â¬œ Pending â€” big rocks
**Qt6** (the long pole) Â· KDE Frameworks 6 (karchive, kconfig, kcoreaddons, ki18n,
kwidgetsaddons, kcompletion, kcrash, kguiaddons, kitemmodels, kitemviews,
kwindowsystem, kimageformats, kdcraw, â€¦)

### â¬œ Pending â€” full-feature (hardest on arm64)
python Â· sip Â· pyqt5 (scripting) Â· ffmpeg Â· mlt (animation) Â· sdl2 Â· openvino

### â¬œ Final
Build Krita 6.0.2.1 against prefix Â· verify native arm64 launch + features

## Changelog of important changes
See `arm64-patches/CHANGES.md` (Craft-era learnings) and `PIVOT.md` (path change).
Recipe-level arm64 patches will be recorded here per `ext_` as they're made.


### Driver fix
- build-deps.cmd now drives the `ext_install` target (global-config force-install-target),
  required by bootstrap-pattern recipes like freetype that stage into a temp prefix
  then copy into the shared prefix.

## Wave 3 (mid-tier) — 6 built, 4 hard
Built: zug, lager, fontconfig, mypaint, libraw, **ocio** (OpenColorIO).
Total native arm64 so far: ~31 deps.

Hard failures (each a real arm64 port):
- **openssl**: MSVC recipe DOWNLOADS a prebuilt x64 binary (no arm64 exists). Patched
  ext_openssl to build 1.1.1w from source with `Configure VC-WIN64-ARM` + nmake on arm64.
- **boost**: MSVC branch hardcodes `architecture=x86` and `bootstrap.bat msvc` reports
  "Unknown toolset: msvc" on arm64. TODO: arch=arm address-model=64 + fix b2 engine build.
- **openexr** (v2.5.9): `ImfDwaCompressor.cpp` pulls SSE2 `emmintrin.h` -> C1189 on arm64.
  TODO: disable IMF_HAVE_SSE2 / SSE paths for arm64.
- **seexpr** (optional plugin lib): a `find_package` at CMakeLists:222 fails. Low priority.


## openssl DONE (from source, native arm64). boost WIP
- openssl: built 1.1.1w from source, libcrypto-1_1-arm64.dll (PE=ARM64). 32 deps total.
- boost: bootstrap fails - build.bat 'call config_toolset.bat' needs cwd exec (disabled
  by system policy). PATH-prepend insufficient; needs a source patch to build.bat to
  call with %~dp0. WIP.


## Loop status checkpoint (~46 deps native arm64)
Built: full image/core stack, openssl(src), ocio, libraw, fontconfig, mypaint,
  fftw3, ogg, vorbis, flac, opus, lame, vpx, libde265, libaom, sdl2, libheif.
NEEDS FIX:
- python: built but python313.dll is x64 (MSBuild PCbuild didn't honor ARM64 platform);
  must force /p:Platform=ARM64. Critical (pyqt5/scripting/Krita need arm64 python).
- libx265 (+10/12bit): x86 asm; disable ASM or arm64 asm. ffmpeg: depends on x265.
- openh264: meson x86 asm. seexpr: find_package. boost: b2 arm64 arch-check (lib skip).
- All optional-ish except python+boost. Next big target: Qt6.


## Qt5.15 finding
Krita 6.0.2.1 uses Qt 5.15 (szaman fork), not Qt6. First configure error 'libs.icu
failed' was NOT a Qt arm64 issue -- icu+libxml2 were accidentally omitted from the
no-space prefix rebuild. Rebuilding them, then Qt configure proceeds (recipe already
passes -I/-L prefix + -icu). Qt build is multi-hour.


## Qt ICU blocker (next action)
Qt5.15 configure: 'ICU ... no' -> 'libs.icu failed'. Confirmed: icu IS built native
arm64 (icuuc-72.dll = ARM64), libs (icuuc/icuin/icudt.lib) + headers + .pc present,
prefix bin on PATH. Test fails at compile/link, not runtime. config.log not at qtbase root.
NEXT: add -verbose to ext_qt CONFIGURE to capture the real icu config-test compiler/linker
error; candidate causes: include/lib path not reaching config.tests, ICU lib-name expectation,
or data lib. Fallback to unblock Qt build + revisit: configure -no-icu (Krita loses some i18n).
Also pending: rebuild libxml2 (omitted), fix python x64, boost/x265/ffmpeg/openh264/seexpr.


## Qt ICU root cause (config.log at ext_qt\b\config.log)
icu test: 'unicode/utypes.h not found in [] and global paths' -- Qt library probe gets
EMPTY include list; -I prefix\include not reaching library detection. jpeg/webp probes
DO compile but fail at link: Qt links 'libjpeg.lib'/'webp.lib' but our deps install
'jpeg.lib'/'libwebp.lib' (name mismatch). NEXT: confirm -I in configure.bat args; fix
include-path delivery for Qt probes; add lib-name aliases or fix -system-* expectations.


## Host toolchain complete (all upcoming steps)
Verified on PATH via dep-env: cl/link/nmake (arm64), cmake, ninja, perl(Strawberry),
meson, nasm, patch, git, python, sed, pkgconf. Pip: sip, PyQt-builder, lxml, pyyaml,
python-gitlab, ply, packaging, meson, setuptools, wheel. No upcoming step should
stall on a missing host tool; remaining work is recipe-level arm64 fixes.


## Qt ICU resolved via -no-icu (known reduction)
Qt5.15 ICU detection on Windows ARM64 is resistant: -I and INCLUDE env are ignored by
Qt's library probe, and -pkg-config is gated off on win32 (tests.pkg-config fails).
It was blocking the entire multi-hour Qt build. Set -no-icu to unblock. Krita i18n uses
ki18n/gettext, not Qt-ICU, so impact is minimal. REVISIT later: patch Qt mkspec
QMAKE_INCDIR_ICU/QMAKE_LIBS_ICU, or place icu headers in a default-searched dir.


## Qt CONFIGURED + COMPILING (milestone)
Qt5.15 configure passed with -no-icu. jom missing (ext_jom not wired as build dep) ->
fetched jom 1.1.3 into prefix/bin. Qt now compiling for arm64 via jom (multi-hour).
TODO durable: wire ext_jom as ext_qt build dependency OR add jom to one-click setup.

