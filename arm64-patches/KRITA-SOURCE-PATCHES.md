# Krita 6.0.2.1 — native Windows ARM64 source patches

These are the source-level changes needed to compile **Krita 6.0.2.1** with
**pure MSVC cl.exe** (native ARM64, `Hostarm64\arm64\cl.exe` v14.44) against the
deps prefix at `C:\kritadeps\i`. The upstream Windows build uses **clang-cl**, so
none of these surface there — every one is a pure-MSVC or ARM64-NEON issue.

Patched copies live under:
- `krita-source/` — files in `..\..\krita-src` (gitignored)
- `deps-prefix-headers/` — third-party headers installed into `C:\kritadeps\i\include` (gitignored)

## Root-cause themes

1. **MSVC ARM64 NEON type aliasing.** Every NEON vector type (`uint8x16_t`,
   `int8x16_t`, …) aliases to a single `__n128`, so libraries that template-
   specialize on distinct NEON types break. Fix: disable NEON vectorization on
   `_MSC_VER` (the scalar C path is fully functional).
2. **MSVC eager template instantiation.** MSVC instantiates members GCC/Clang
   skip lazily (e.g. `std::unique_lock::try_lock`, implicit inline destructors of
   `QScopedPointer<Private>` with incomplete `Private`).
3. **MSVC injected-class-name resolution (C3200).** When a class transitively
   derives from `reader_node<T>`/`cursor_node<T>`, MSVC resolves the bare template
   name to the concrete injected type instead of the template — breaks lager's
   template-template parameters. Fix: fully-qualify `::lager::detail::reader_node`.
4. **`/permissive` parity.** Stock Krita adds `/permissive` only for clang-cl;
   pure cl.exe needs it too (KoColorSpaceMaths operators, lager).

## deps-prefix-headers (third-party, installed into the prefix)

| File | Change |
|------|--------|
| `xsimd/config/xsimd_config.hpp` | `#ifdef __ARM_NEON` → `#if defined(__ARM_NEON) && !defined(_MSC_VER)` — disable xsimd NEON backend on MSVC (theme 1). |
| `eigen3/Eigen/src/Core/util/ConfigureVectorization.h` | NEON gating `elif` gets `&& !(defined _MSC_VER)` — disable Eigen NEON on MSVC (theme 1; GCC inline-asm + initializer-list errors). |
| `lager/constant.hpp` | `root_node<T, ::lager::detail::reader_node>` (theme 3). |
| `lager/sensor.hpp` | `root_node<T, ::lager::detail::reader_node>` (theme 3). |
| `lager/store.hpp` | `root_node<Model, ::lager::detail::reader_node>` (theme 3). |
| `lager/state.hpp` | `root_node<T, ::lager::detail::cursor_node>` (theme 3). |
| `lager/detail/nodes.hpp` | `root_node` Base param made variadic-tolerant (kept; the real fix is qualification). |
| `lager/detail/xform_nodes.hpp` | `xform_reader_node<…, ::lager::detail::cursor_node>` (lines 123/125). |
| `lager/detail/merge_nodes.hpp` | `merge_reader_node<…, ::lager::detail::cursor_node>` (line 56). |
| `lager/detail/lens_nodes.hpp` | `lens_reader_node<…, ::lager::detail::cursor_node>` (line 74). |

## krita-source

| File | Change |
|------|--------|
| `CMakeLists.txt` | Add `/permissive` for pure MSVC (`if (MSVC AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")`) — parity with the existing clang-cl block (theme 4). |
| `libs/global/KisAdaptedLock.h` | Add `kis_adapted_lock_detail::has_try_lock` SFINAE trait + `AdapterShim<Adapter>` supplying a blocking `try_lock` fallback; `KisAdaptedLock` inherits the shim. Fixes C2039 `try_lock` not a member for all lock adapters in one place (theme 2). |
| `libs/widgets/KoZoomActionState.cpp` | `qMin<int>(...)` with explicit int casts — resolves qsizetype/ptrdiff_t overload ambiguity (C2672). |
| `libs/image/commands_new/KisChangeCloneLayersCommand.{h,cpp}` | Out-of-line `~…() = default;` so `QScopedPointer<Private>` destructor sees a complete `Private` (theme 2, C2027). |
| `libs/ui/widgets/KisGrabKeyboardFocusRecoveryWorkaround.{h,cpp}` | Same out-of-line destructor pattern (theme 2). |
| `libs/flake/commands/KoShapeMergeTextPropertiesCommand.{h,cpp}` | Same out-of-line destructor pattern (theme 2). |
| `libs/ui/KisViewManager.cpp` | `#include <kis_filter_configuration.h>` — `KisSharedPtr::deref`'s `delete` needs the complete type (C2027). |
| `libs/ui/KisMultiSurfaceStateManager.cpp` | Guard `#include <KisRootSurfaceInfoProxy.h>` in `#if KRITA_USE_SURFACE_COLOR_MANAGEMENT_API` (flag OFF here) — fixes LNK2001 on `staticMetaObject`. |

## Install-step fixes (not source files)

- **`ecm_add_app_icon` produced no `.ico`** (no icotool/png2ico in the ARM64
  deps), so `cmake --install` failed on missing `krita.ico`/`kritafile.ico`.
  Generated real multi-resolution ICO containers (16/32/48/64/128/256, PNG-
  embedded) directly from `krita/pics/branding/default/*-apps-krita.png` and
  `krita/pics/mimetypes/*-application-x-krita.png` into the build dir.

## Runtime launcher

`krita-install/bin/krita-launch.bat` sets `PATH` (install bin + `C:\kritadeps\i\bin`),
`QT_PLUGIN_PATH` (`…\i\plugins`), and `FONTCONFIG_PATH` (`…\i\etc\fonts`) so Krita
starts with a clean environment (no Fontconfig warning; Qt platform plugin found).

## Result

`krita.exe` — PE machine **0xAA64 (ARM64)**, launches natively (no x64 emulation),
main window initializes cleanly. Build: 241/241 plugins linked, install exit 0.
