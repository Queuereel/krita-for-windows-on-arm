# Krita for Windows on ARM64 (native build)

Build **Krita** natively for **Windows 11 on ARM64** — no x64 emulation — from
source, with a single click.

Upstream Krita ships only x64 Windows builds, which run under emulation on ARM
devices (Snapdragon X, etc.): slower and heavier on battery. This fork adds the
tooling and patches needed to produce a **native arm64** Krita.

> ⚠️ **Status: work in progress.** Windows-on-ARM is not an officially supported
> Krita/KDE-Craft target, so the dependency tree needs hand fixes as we go. The
> core toolchain builds; the full dependency tree (Qt6, KF6, image libs) is being
> brought up. See [`arm64-patches/CHANGES.md`](arm64-patches/CHANGES.md) for the
> running list of fixes and current progress.

## One-click build

1. Use an **ARM64 Windows 11** machine.
2. Double-click **`build-krita-arm64.bat`**.
3. Approve the UAC prompt and the Visual Studio installer prompt.
4. Wait. (First run compiles a large dependency tree from source — hours.)

When it finishes: `C:\CraftRoot\bin\krita.exe`.

The script is **idempotent** — if it stops, just run it again; completed work is
cached and it resumes.

### What it does (on even a clean PC)

| Stage | Action |
|------|--------|
| Prerequisites | Installs Git, Python, and VS 2022 Build Tools with the native **ARM64** C++ toolchain (via `winget`) |
| Bootstrap | Sets up **KDE Craft** with ABI `windows-cl-msvc2022-arm64` |
| Patches | Applies the arm64 fixes (see `arm64-patches/`) to Craft + blueprints |
| Build | Compiles Krita's dependency tree, then Krita |

### Options

```powershell
# advanced: call the engine directly
scripts\build-krita-arm64.ps1 [-SkipPrereqs] [-DepsOnly] [-Resume] [-CraftRoot C:\CraftRoot]
```

- `-SkipPrereqs` — toolchain already installed; skip winget
- `-DepsOnly` — build only the dependencies, not Krita
- `-Resume` — skip bootstrap/patching, go straight to building

## Why each patch exists

Every fix addresses the same root cause: Craft and its blueprints branch on
`if x86_64 … else <x86/x64 fallback>`, so arm64 silently inherited 32-bit or x86
settings. Full detail in [`arm64-patches/CHANGES.md`](arm64-patches/CHANGES.md).

## Layout

```
build-krita-arm64.bat     one-click launcher (self-elevating)
scripts/                  PowerShell build engine
arm64-patches/            patched Craft/blueprint files + CHANGES.md
krita-src/                Krita source (not committed; see .gitignore)
```

## Credits / license

Krita is © the Krita/KDE community (GPL). KDE Craft is © KDE (BSD-2-Clause).
The arm64 build tooling and patches in this repo are provided under the same
licenses as the files they modify. This is an unofficial community port.
