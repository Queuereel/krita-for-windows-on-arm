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

