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

