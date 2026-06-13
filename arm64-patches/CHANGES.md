# Native Windows-on-ARM64 Krita build — source changes

Goal: build Krita **6.0.2.1** natively for **Windows 11 ARM64** (no x64 emulation).

- Source: `..\krita-src` (KDE Krita 6.0.2.1, commit 462e15e)
- Build system: KDE Craft, ABI `windows-cl-msvc2022-arm64`
- Toolchain: VS 2022 Build Tools, native ARM64 MSVC 14.44 (`Hostarm64\arm64\cl.exe`)
- Craft root: `C:\CraftRoot` (short-path `C:\_`)

Every fix below addresses the same root cause: Craft/blueprints assume
`if x86_64 ... else <x86/x64 fallback>`, so arm64 silently got wrong settings.
These are the patched files (mirrored here from `C:\CraftRoot\craft-tmp\...`).

## Environment fixes (not files)
- Added `C:\Program Files (x86)\Microsoft Visual Studio\Installer` to PATH so
  `vcvarsall.bat` finds `vswhere.exe` (its stderr error otherwise corrupted
  Craft's JSON env-dump). NOTE: must be injected inline per-process.

## File patches
1. **CraftBootstrap.py** — Windows arch default x86_64 -> arm64 (the Windows
   bootstrap path never prompts for architecture), yielding the arm64 ABI.
2. **craft-core/bin/CraftSetupHelper.py** — `getMSVCEnv` architectures map had
   no arm64 entry; added `arm64 -> "arm64"` vcvarsall arg (native host).
3. **blueprints/dev-utils/perl/perl.py** —
   (a) `CRAFT_WIN64` was empty only for x86_64 -> arm64 got 32-bit pointer
       model -> miniperl.exe segfaulted. Now arm64 treated as 64-bit.
   (b) perl's win32 Makefile calls bare `miniperl` relying on cwd execution,
       which hardened Windows disables; added perl source root to PATH.
4. **blueprints/libs/openssl/openssl.py** — Configure target was `VC-WIN32`
   for non-x86_64 -> arm64 built as x86 (LNK1112). Now arm64 -> `VC-WIN64-ARM`.
5. **blueprints/libs/liblzma/liblzma.py** — the bundled xz 5.2.3 MSBuild
   solution/projects only define Win32/x64. Added a post-unpack hook that
   injects ARM64 platform configs (cloned from x64) into the .sln + .vcxproj.
6. **blueprints/libs/libunistring/libunistring.py** — DLL version resource
   (.res) can only be produced as x64 by mingw windres (conflicts with ARM64
   link); MSVC rc.exe rejects windres flags. Strip the optional .res object
   from the generated Makefiles. (Same fix will be needed for gettext.)

## Status checkpoint
Core deps built (native arm64): perl, nasm, openssl, iconv, liblzma, icu,
libxml2. In progress: libunistring. Remaining core: gettext, sqlite, libffi,
python, msys, craft-core. Then Phase 2 = Krita's full dep tree (Qt6, KF6,
Boost, image libs), then Phase 3 = compile `..\krita-src`.
