# Build-path pivot: Craft → krita-deps-management

## Why
Krita **does not build via KDE Craft** — there is no `krita` package in
craft-blueprints-kde. Krita 6.x moved all dependency management to a dedicated
repo: **https://invent.kde.org/packaging/krita-deps-management** (its
`3rdparty/README.md` points there). That is the official, supported build
system: ~90 `ext_*` CMake `ExternalProject` recipes for Qt6, KF6, OpenEXR,
OpenColorIO, libraw, boost, image libs, etc., orchestrated by
**krita-ci-utilities** (`run-ci-build.py`).

Note: krita-deps-management's own CI builds Windows / Linux / macOS /
Android-arm64 — **no Windows-arm64**. Still uncharted, but this is the correct
framework and patches here are upstreamable.

## What carries over from the Craft attempt
- The **VS 2022 native ARM64 MSVC toolchain** (reused as-is).
- The environment lessons (vswhere/PATH, cwd-execution hardening).
- The pattern recognition: every recipe assumes `x86_64 … else x86/x64`.

The Craft blueprint patches under `arm64-patches/` are kept for reference/learning
but are NOT used by the new path (krita-deps-management builds its own perl,
python, nasm, openssl, etc.).

## New layout
```
krita-deps-management/   official dep recipes (ext_qt, ext_boost, ext_kconfig, …)
krita-ci-utilities/      orchestration (run-ci-build.py, PlatformFlavor, …)
krita-src/               Krita 6.0.2.1 source
deps-build/              working dir: downloads + install prefix (gitignored)
```

## Build invocation (per dependency)
```
python krita-ci-utilities/run-ci-build.py --project ext_<name> \
    --platform Windows --branch master [--skip-dependencies-fetch] [...]
```
- `PlatformFlavor` is just a `/`-separated label and does NOT encode arch; the
  arm64 target comes from running inside the MSVC arm64 environment + CMake.
- No arm64 package registry exists, so deps must be built locally in order
  (`--skip-dependencies-fetch`) rather than downloaded.

## Open arm64 work (expected)
Patch x86/x64 assumptions in the `ext_*` recipes as we hit them, e.g.:
- `ext_qt` — Qt `-platform`/configure args, jom build
- `ext_boost` — `address-model=64 architecture=arm` (b2)
- `ext_openssl` — `VC-WIN64-ARM` target (same fix as the Craft attempt)
- `ext_python` / sip / pyqt5 — arch-specific output dirs
- general: any `ml64`/SSE/x64 asm paths

## Build location constraint (important)
meson, pkg-config and Qt break on paths containing spaces, and CMake/meson
canonicalize junctions back to the real path -- so a junction with a spaced
target does NOT help. The heavy build therefore lives at a real no-space path:

    C:\kritadeps\{krita-deps-management, krita-ci-utilities, d, i, b}

and is surfaced under the fork via a junction:

    Documents\Krita ARM\deps-build  ->  C:\kritadeps

So your files are still visible where you asked, but tools only ever see the
no-space path. The git fork (tooling, patches, source) stays in Documents\Krita ARM.
