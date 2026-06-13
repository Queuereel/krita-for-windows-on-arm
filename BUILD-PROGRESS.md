# Native ARM64 Krita — build progress log

Running record of the Windows-on-ARM64 native build. Updated as waves complete.
Goal: **full-featured** Krita 6.0.2.1 (scripting + animation included).

## Pipeline
- Toolchain: VS 2022 native ARM64 MSVC 14.44 + CMake + Ninja + meson (pip)
- Build root (no-space, required): `C:\kritadeps`  (junctioned to `Documents\Krita ARM\deps-build`)
- Driver: `scripts\build-deps.cmd <names...>` (configure+build each `ext_` into shared prefix)
- Install prefix: `C:\kritadeps\i`

## Dependency status

### ✅ Built native ARM64 (unpatched unless noted)
zlib · png · jpeg · tiff · webp · openjpeg · jpegxl · lcms2 · expat · exiv2 ·
giflib · gsl · eigen3 · xsimd · immer · iconv · json_c · highway · brotli ·
unibreak · nasm · fribidi · extra_cmake_modules · pkgconfig · freetype(+harfbuzz)

> Note: 23/24 leaf+image deps built with **zero arm64 patches** — strong sign the
> krita-deps-management/CMake path handles arm64 far better than Craft did.

### 🔧 Fixes applied so far
- meson installed via pip; added to build env PATH (fribidi/harfbuzz)
- pkgconfig built early so meson can resolve freetype2 (harfbuzz)
- relocated build to no-space path (meson/Qt break on spaces)
- added `PKG_CONFIG_PATH` (main prefix) to build env so `.pc` Requires chains resolve
- created `libpng.pc`/`libpng16.pc` in prefix (ext_png installs CMake config but no
  `.pc`; freetype2.pc's `Requires: libpng` needs it for harfbuzz meson). TODO: make
  this durable via a post-png fixup in the one-click flow.

### ⬜ Pending — mid tier
openssl (expect `VC-WIN64-ARM`) · boost (expect `architecture=arm address-model=64`) ·
openexr · OpenColorIO (ocio) · libraw · quazip · mypaint · lager · zug · seexpr ·
fontconfig · libheif/libaom/libde265 · zug

### ⬜ Pending — big rocks
**Qt6** (the long pole) · KDE Frameworks 6 (karchive, kconfig, kcoreaddons, ki18n,
kwidgetsaddons, kcompletion, kcrash, kguiaddons, kitemmodels, kitemviews,
kwindowsystem, kimageformats, kdcraw, …)

### ⬜ Pending — full-feature (hardest on arm64)
python · sip · pyqt5 (scripting) · ffmpeg · mlt (animation) · sdl2 · openvino

### ⬜ Final
Build Krita 6.0.2.1 against prefix · verify native arm64 launch + features

## Changelog of important changes
See `arm64-patches/CHANGES.md` (Craft-era learnings) and `PIVOT.md` (path change).
Recipe-level arm64 patches will be recorded here per `ext_` as they're made.
