<#
.SYNOPSIS
    One-click native Windows-on-ARM64 Krita builder (from source, no emulation).

.DESCRIPTION
    Builds Krita and its full dependency tree natively for Windows on ARM64
    using KDE's krita-deps-management recipes plus the ARM64 fixes tracked in
    this repository. This is the *actual* flow used to produce the published
    release -- not a wrapper around KDE Craft.

    Stages (each is idempotent; re-run safely):

      1. Prerequisites  - Git, ARM64 Python 3.13, VS 2022 Build Tools (ARM64 C++),
                          LLVM/clang-cl (for x265 NEON)
      2. Sources        - clone krita-deps-management; apply this repo's ARM64
                          recipe + header patches over it
      3. Dependencies   - build every ext_* dep into the shared prefix, in order
      4. Python binding - build the ARM64 PyQt5.sip runtime module
      5. Krita          - configure (scripting on) -> ninja -> install
      6. Package        - assemble the self-contained tree + build the setup .exe

    Expect the first full run to take *hours*: it compiles Qt, the KDE
    Frameworks, image/codec libraries and Krita itself from source.

.NOTES
    Requires a Windows 11 ARM64 machine. See arm64-patches/CHANGES.md and
    arm64-patches/KRITA-SOURCE-PATCHES.md for what each patch fixes.
#>
[CmdletBinding()]
param(
    [string]$DepsRoot   = "C:\kritadeps",       # build root (no spaces!)
    [switch]$SkipPrereqs,                        # toolchain already installed
    [switch]$DepsOnly,                           # stop after the dependency tree
    [switch]$SkipDeps,                           # jump straight to building Krita
    [switch]$NoPackage                           # skip packaging + installer
)

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ScriptsDir = Join-Path $RepoRoot "scripts"
$PatchDir   = Join-Path $RepoRoot "arm64-patches"
$KritaSrc   = Join-Path $RepoRoot "krita-src"

$Prefix     = Join-Path $DepsRoot "i"
$DepsMgmt   = Join-Path $DepsRoot "krita-deps-management"

function Info($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!] $m"  -ForegroundColor Yellow }
function Die($m)  { Write-Host "`n[FATAL] $m" -ForegroundColor Red; exit 1 }
function Have($e) { [bool](Get-Command $e -ErrorAction SilentlyContinue) }

if ($env:PROCESSOR_ARCHITECTURE -ne "ARM64") {
    Warn "This machine reports $env:PROCESSOR_ARCHITECTURE, not ARM64."
    Warn "A native arm64 build only makes sense on Windows-on-ARM. Continuing anyway."
}

# Canonical build order: foundational libs first, then codecs, KDE Frameworks,
# Qt, Python bindings, and finally the media stack. Mirrors the verified order
# in BUILD-STATE.md. Names map to ext_<name> recipe dirs.
$DepOrder = @(
    # toolchain helpers + foundational
    'nasm','pkgconfig','extra_cmake_modules','strawberryperl','patch',
    'zlib','iconv','gettext','expat','png','jpeg','tiff','webp','openjpeg',
    'lcms2','giflib','gsl','eigen3','xsimd','immer','zug','lager','highway',
    'brotli','unibreak','fribidi','json_c',
    # text/render
    'freetype','fontconfig','openssl','boost',
    'openexr','exiv2','seexpr','libraw','ocio','mypaint','quazip',
    # audio/video codecs
    'fftw3','libogg','libvorbis','flac','opus','lame','vpx','libde265',
    'libaom','sdl2','jpegxl','openh264','libx265','libx265_10bit','libx265_12bit',
    'libheif',
    # KDE Frameworks 5
    'karchive','kconfig','kcoreaddons','ki18n','kwidgetsaddons','kcompletion',
    'kguiaddons','kitemmodels','kitemviews','kwindowsystem','kcrash',
    'kimageformats','kdcraw',
    # graphics stack + Qt
    'googleangle','icu','qt',
    # python + media
    'python','sip','pyqt5','ffmpeg','mlt'
)

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
function Install-Prereqs {
    if ($SkipPrereqs) { Info "Skipping prerequisite install (-SkipPrereqs)"; return }
    Info "Checking prerequisites"
    if (-not (Have winget)) { Die "winget not found. Install 'App Installer' from the Microsoft Store, then re-run." }

    if (-not (Have git)) {
        Info "Installing Git"
        winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    } else { Ok "Git present" }

    $haveArmCl = Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostarm64\arm64\cl.exe"
    if (-not $haveArmCl) {
        Info "Installing VS 2022 Build Tools + ARM64 C++ (large; approve the prompts)"
        $comps = @(
            "Microsoft.VisualStudio.Workload.VCTools",
            "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
            "Microsoft.VisualStudio.Component.VC.ATL.ARM64",
            "Microsoft.VisualStudio.Component.Windows11SDK.22621"
        )
        $override = "--quiet --wait --norestart " + (($comps | ForEach-Object { "--add $_" }) -join " ") + " --includeRecommended"
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
            --accept-source-agreements --accept-package-agreements --override $override
    } else { Ok "ARM64 MSVC toolchain present" }

    if (-not (Test-Path "$DepsRoot\python313-dev\python.exe")) {
        Warn "ARM64 Python 3.13 dev install not found at $DepsRoot\python313-dev."
        Warn "Download the Windows ARM64 installer from python.org (3.13.x) and install"
        Warn "it there (with headers/pip), or adjust dep-env.cmd. Continuing."
    } else { Ok "ARM64 Python 3.13 present" }

    if (-not (Test-Path "$DepsRoot\LLVM\bin\clang-cl.exe")) {
        Warn "LLVM (clang-cl) not found at $DepsRoot\LLVM. Needed only for x265 NEON."
        Warn "Install the Windows ARM64 LLVM release there if you build x265. Continuing."
    } else { Ok "LLVM/clang-cl present" }
}

# ---------------------------------------------------------------------------
# 2. Sources + patches
# ---------------------------------------------------------------------------
function Sync-Sources {
    Info "Preparing krita-deps-management"
    if (-not (Test-Path (Join-Path $DepsMgmt ".git"))) {
        if (-not (Test-Path $DepsRoot)) { New-Item -ItemType Directory -Force $DepsRoot | Out-Null }
        git clone https://invent.kde.org/dmitryk/krita-deps-management.git $DepsMgmt
    } else { Ok "krita-deps-management present" }

    # Apply our ARM64 recipe + prefix-header patches (full-file overlays).
    $recipeSrc = Join-Path $PatchDir "deps-recipes"
    if (Test-Path $recipeSrc) {
        Info "Applying ARM64 recipe patches"
        Get-ChildItem $recipeSrc -Recurse -File | ForEach-Object {
            $rel  = $_.FullName.Substring($recipeSrc.Length).TrimStart('\')
            $dest = Join-Path $DepsMgmt $rel
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            Copy-Item $_.FullName $dest -Force
            Ok "recipe $rel"
        }
    }
}

# ---------------------------------------------------------------------------
# 3. Dependencies
# ---------------------------------------------------------------------------
function Build-Deps {
    if ($SkipDeps) { Info "Skipping dependency build (-SkipDeps)"; return }
    Info "Building dependency tree (this is the long stage)"
    $buildDeps = Join-Path $ScriptsDir "build-deps.cmd"
    foreach ($dep in $DepOrder) {
        if (-not (Test-Path (Join-Path $DepsMgmt "ext_$dep\CMakeLists.txt"))) {
            Warn "ext_$dep not present in recipes; skipping"
            continue
        }
        Info "dep: $dep"
        & cmd /c "`"$buildDeps`" $dep"
        if ($LASTEXITCODE -ne 0) { Die "Dependency '$dep' failed. See logs; fix the recipe and re-run." }
    }
    Ok "All dependencies built into $Prefix"

    Info "Building ARM64 PyQt5.sip runtime module"
    & cmd /c "`"$(Join-Path $ScriptsDir 'build-pyqt5sip.bat')`""
}

# ---------------------------------------------------------------------------
# 4. Krita source: fetch + apply ARM64 overlays
# ---------------------------------------------------------------------------
# Krita's own source is NOT vendored in this repo (it is large and lives
# upstream, exactly like KDE keeps deps out of the Krita repo). We clone the
# official repo and drop our patched files over it. The patches are stored as
# full-file overlays (arm64-patches/krita-source/<same relative path>), so they
# replace whole files and do not depend on a fragile line-level diff.
$KritaGitUrl = "https://invent.kde.org/graphics/krita.git"
$KritaGitRef = "master"   # 5.3.2.1 (Qt5) line; override if upstream drifts

function Sync-KritaSource {
    if (Test-Path (Join-Path $KritaSrc "CMakeLists.txt")) {
        Ok "krita-src already present at $KritaSrc"
    } else {
        Info "Cloning Krita source ($KritaGitRef) into $KritaSrc"
        git clone --depth 1 --branch $KritaGitRef $KritaGitUrl $KritaSrc
        if ($LASTEXITCODE -ne 0) { Die "Failed to clone Krita source." }
    }

    $srcPatches = Join-Path $PatchDir "krita-source"
    if (Test-Path $srcPatches) {
        Info "Applying ARM64 source overlays"
        Get-ChildItem $srcPatches -Recurse -File | ForEach-Object {
            $rel  = $_.FullName.Substring($srcPatches.Length).TrimStart('\')
            $dest = Join-Path $KritaSrc $rel
            if (-not (Test-Path (Split-Path $dest))) {
                Warn "overlay target dir missing for $rel (upstream may have moved it); skipping"
                return
            }
            Copy-Item $_.FullName $dest -Force
            Ok "overlay $rel"
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Krita build
# ---------------------------------------------------------------------------
function Build-Krita {
    if (-not (Test-Path (Join-Path $KritaSrc "CMakeLists.txt"))) {
        Die "krita-src not found at $KritaSrc after sync; cannot continue."
    }
    Info "Configuring Krita (Python scripting enabled)"
    & cmd /c "`"$(Join-Path $ScriptsDir 'configure-krita.bat')`""
    if ($LASTEXITCODE -ne 0) { Die "Krita configure failed." }

    Info "Compiling Krita"
    & cmd /c "`"$(Join-Path $ScriptsDir 'build-krita.bat')`""
    if ($LASTEXITCODE -ne 0) { Die "Krita build failed." }

    Info "Installing Krita"
    & cmd /c "`"$(Join-Path $ScriptsDir 'install-krita.bat')`""
    if ($LASTEXITCODE -ne 0) { Die "Krita install failed." }
    Ok "Krita installed to $DepsRoot\krita-install"
}

# ---------------------------------------------------------------------------
# 6. Package + installer
# ---------------------------------------------------------------------------
function Package-Krita {
    if ($NoPackage) { Info "Skipping packaging (-NoPackage)"; return }
    Info "Packaging self-contained tree + installer"
    & (Join-Path $ScriptsDir "package-krita-arm64.ps1") -DepsRoot $DepsRoot
}

# ---------------------------------------------------------------------------
Info "Native ARM64 Krita builder  |  DepsRoot=$DepsRoot"
Install-Prereqs
Sync-Sources
Build-Deps
if ($DepsOnly) { Ok "Dependencies built (-DepsOnly). Stopping before Krita."; exit 0 }
Sync-KritaSource
Build-Krita
Package-Krita
Ok "DONE.  Installer + zip are under $RepoRoot\packaging\arm64-installer\ (and $DepsRoot\pkg)."
