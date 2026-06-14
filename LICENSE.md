# Licensing

This repository is an **independent, unofficial community project** that builds
Krita natively for Windows on ARM64. It is **not** affiliated with, endorsed by,
or supported by the Krita Foundation or KDE e.V.

It is made up of several kinds of files, each under its own license. Nothing
here relicenses anyone else's work — every file keeps the license of the project
it came from.

## 1. Original work in this repository

The build tooling written for this project — the scripts under `scripts/`, the
`build-krita-arm64.bat` launcher, and the installer under
`packaging/arm64-installer/` (except `license_gpl-3.0.rtf`, which is the GPL
text itself) — is licensed under the **GNU General Public License, version 3 or
later (GPL-3.0-or-later)**, to match the program it builds.

SPDX-License-Identifier: GPL-3.0-or-later

## 2. Patches to Krita's source (`arm64-patches/krita-source/`)

These are modified copies of files from Krita
(<https://invent.kde.org/graphics/krita>). They remain under **Krita's own
license (GPL-2.0-or-later / GPL-3.0-or-later)** and retain their original
`SPDX-FileCopyrightText` headers. Copyright belongs to the Krita / KDE
community; the ARM64 changes are contributed back under the same terms.

## 3. Patches to dependency recipes and headers

- `arm64-patches/deps-recipes/` and `arm64-patches/blueprints/`,
  `arm64-patches/craft-core/` — modifications to KDE's
  `krita-deps-management` / Craft build recipes, under their original licenses
  (BSD-2-Clause).
- `arm64-patches/deps-prefix-headers/` — modified copies of third-party library
  headers, each kept under **its own upstream license**, preserved in the file
  header. As included here:
  - Eigen — MPL-2.0
  - lager — MIT
  - xsimd — BSD-3-Clause

## 4. Icons

`packaging/arm64-installer/krita.ico` and `kritafile.ico` are generated from
Krita's own branding artwork (`krita-src/pics/`), which is part of the Krita
project and under its license. The "Krita" name and logo are trademarks of the
Krita Foundation; they are used here only to identify a faithful native build,
not to imply endorsement.

## 5. The built program and release binaries

Binaries on the Releases page bundle Krita and its dependencies. Krita is
distributed under the GPL. The bundled FFmpeg links GPL components (x265) and is
therefore covered by the GPL as a whole; its notice ships as
`ffmpeg_LICENSE.txt` alongside the binary. The complete corresponding source is
obtainable by following this repository (which fetches Krita's source and every
dependency's source) — i.e. these build scripts ARE the offer of source.

## Summary

| Part | License |
|------|---------|
| This project's build tooling | GPL-3.0-or-later |
| Krita source patches | GPL-2.0-or-later / GPL-3.0-or-later (Krita) |
| Dep recipe/blueprint patches | BSD-2-Clause (KDE) |
| Vendored dep headers | MPL-2.0 / MIT / BSD-3-Clause (per file) |
| Released binaries | GPL (Krita + bundled deps) |

Full GPL-3.0 text: <https://www.gnu.org/licenses/gpl-3.0.html>
(also bundled as `packaging/arm64-installer/license_gpl-3.0.rtf`).
