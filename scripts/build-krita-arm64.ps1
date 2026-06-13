<#
.SYNOPSIS
    One-click native Windows-on-ARM64 Krita builder (from source, no emulation).

.DESCRIPTION
    Designed to run on a CLEAN ARM64 Windows 11 machine. Every step is idempotent:
    it detects what is already present and only does what is missing. Stages:

      1. Prerequisites  - Git, Python, VS 2022 Build Tools (+ native ARM64 C++)
      2. Craft bootstrap - KDE Craft set up with ABI windows-cl-msvc2022-arm64
      3. ARM64 patches   - apply the fixes that make the toolchain build on arm64
      4. Build           - compile Krita's dependency tree, then Krita itself

    Re-run safely at any time; completed work is cached by Craft.

.NOTES
    STATUS: work in progress. The dependency tree (Qt6/KF6/...) is large and some
    blueprints still need arm64 fixes; see arm64-patches\CHANGES.md.
#>
[CmdletBinding()]
param(
    [string]$CraftRoot = "C:\CraftRoot",
    [switch]$SkipPrereqs,   # skip winget installs (use if toolchain already present)
    [switch]$DepsOnly,      # build only Krita's dependencies, not Krita
    [switch]$Resume         # skip bootstrap/patch, jump straight to building
)

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$PatchDir   = Join-Path $RepoRoot "arm64-patches"
$KritaSrc   = Join-Path $RepoRoot "krita-src"
$VsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"

function Info($m)  { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "    [ok] $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "    [!] $m"  -ForegroundColor Yellow }
function Die($m)   { Write-Host "`n[FATAL] $m" -ForegroundColor Red; exit 1 }

# --- sanity ----------------------------------------------------------------
if ($env:PROCESSOR_ARCHITECTURE -ne "ARM64") {
    Warn "This machine reports $env:PROCESSOR_ARCHITECTURE, not ARM64."
    Warn "A native arm64 build only makes sense on Windows-on-ARM. Continuing anyway."
}

function Have($exe) { [bool](Get-Command $exe -ErrorAction SilentlyContinue) }

# --- 1. prerequisites ------------------------------------------------------
function Install-Prereqs {
    if ($SkipPrereqs) { Info "Skipping prerequisite install (-SkipPrereqs)"; return }
    Info "Checking prerequisites"
    if (-not (Have winget)) { Die "winget not found. Install 'App Installer' from the Microsoft Store, then re-run." }

    if (-not (Have git)) {
        Info "Installing Git"
        winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    } else { Ok "Git present" }

    if (-not (Have python)) {
        Info "Installing Python 3.11"
        winget install --id Python.Python.3.11 -e --accept-source-agreements --accept-package-agreements
    } else { Ok "Python present" }

    # VS 2022 Build Tools with the native ARM64 C++ toolchain
    $haveArmCl = Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostarm64\arm64\cl.exe"
    if (-not $haveArmCl) {
        Info "Installing VS 2022 Build Tools + ARM64 C++ (large download; approve the UAC/installer prompts)"
        $comps = @(
            "Microsoft.VisualStudio.Workload.VCTools",
            "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
            "Microsoft.VisualStudio.Component.VC.ATL.ARM64",
            "Microsoft.VisualStudio.Component.Windows11SDK.22621",
            "Microsoft.VisualStudio.Component.VC.CMake.Project"
        )
        $override = "--quiet --wait --norestart " + (($comps | ForEach-Object { "--add $_" }) -join " ") + " --includeRecommended"
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
            --accept-source-agreements --accept-package-agreements --override $override
    } else { Ok "ARM64 MSVC toolchain present" }

    # vcvarsall.bat needs vswhere.exe on PATH or it pollutes Craft's env-dump.
    if ((Test-Path "$VsInstaller\vswhere.exe") -and ($env:Path -notlike "*$VsInstaller*")) {
        $env:Path = "$VsInstaller;$env:Path"
        Ok "Added VS Installer dir to PATH (for this session)"
    }
}

# --- 2. Craft bootstrap ----------------------------------------------------
function Bootstrap-Craft {
    if (Test-Path "$CraftRoot\craft-tmp\bin\craft.py") { Ok "Craft already bootstrapped at $CraftRoot"; return }
    Info "Bootstrapping KDE Craft (arm64 ABI) into $CraftRoot"
    $bs = Join-Path $env:TEMP "CraftBootstrap.py"
    Invoke-WebRequest "https://raw.githubusercontent.com/KDE/craft/master/setup/CraftBootstrap.py" -OutFile $bs -UseBasicParsing
    # The Windows bootstrap path never prompts for architecture and hardcodes
    # x86_64; flip the default to arm64 so we get windows-cl-msvc2022-arm64.
    (Get-Content $bs -Raw) -replace 'arch = "x86_64"', 'arch = "arm64"' | Set-Content $bs -Encoding UTF8
    & python $bs --prefix $CraftRoot --use-defaults
}

# --- 3. apply ARM64 patches ------------------------------------------------
function Apply-Patches {
    Info "Applying ARM64 patches"

    # 3a. Craft core: add the arm64 vcvars arg to getMSVCEnv's architectures map.
    Get-ChildItem $CraftRoot -Recurse -Filter CraftSetupHelper.py -ErrorAction SilentlyContinue | ForEach-Object {
        $t = Get-Content $_.FullName -Raw
        if ($t -notmatch 'Architecture\.arm64: "arm64"') {
            $t = $t -replace '(Architecture\.x86_64: "amd64",)', "`$1`n                CraftCore.compiler.Architecture.arm64: `"arm64`","
            $t = $t -replace '(Architecture\.x86_64: "x86_amd64",)', "`$1`n                CraftCore.compiler.Architecture.arm64: `"arm64`","
            Set-Content $_.FullName $t -Encoding UTF8
            Ok "patched $($_.Name)"
        }
    }

    # 3b. Blueprint fixes: drop our patched .py files over every matching blueprint
    # location Craft knows about (craft-tmp during bootstrap, and the installed
    # craft-blueprints-kde checkout once present).
    $bpRoot = Join-Path $PatchDir "blueprints"
    if (Test-Path $bpRoot) {
        Get-ChildItem $bpRoot -Recurse -File -Filter *.py | ForEach-Object {
            $rel = $_.FullName.Substring($bpRoot.Length).TrimStart('\')
            $copied = 0
            Get-ChildItem $CraftRoot -Recurse -Directory -Filter blueprints -ErrorAction SilentlyContinue | ForEach-Object {
                $dest = Join-Path $_.FullName $rel
                if (Test-Path (Split-Path $dest)) { Copy-Item $_.FullName $dest -Force -ErrorAction SilentlyContinue }
                if (Test-Path $dest) { Copy-Item $_.FullName $dest -Force; $copied++ }
            }
            Ok "blueprint $rel -> $copied location(s)"
        }
    }
}

# --- 4. build --------------------------------------------------------------
function Invoke-Craft([string[]]$craftArgs) {
    if ((Test-Path "$VsInstaller\vswhere.exe") -and ($env:Path -notlike "*$VsInstaller*")) {
        $env:Path = "$VsInstaller;$env:Path"
    }
    & python "$CraftRoot\craft-tmp\bin\craft.py" @craftArgs
    if ($LASTEXITCODE -ne 0) { throw "craft $($craftArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

function Build {
    Info "Finalizing Craft (builds its core toolchain on first run)"
    Invoke-Craft @("craft")

    Info "Building Krita's dependency tree for arm64 (this is the long one)"
    Invoke-Craft @("--install-deps", "krita")

    if ($DepsOnly) { Ok "Dependencies built (-DepsOnly). Stopping before Krita."; return }

    Info "Building Krita"
    # Prefer building the bundled source tree if present; else let Craft fetch it.
    if (Test-Path (Join-Path $KritaSrc "CMakeLists.txt")) {
        Warn "Local krita-src build wiring is handled in a later step; using Craft's krita blueprint for now."
    }
    Invoke-Craft @("krita")
    Ok "Build finished. Launch with:  $CraftRoot\bin\krita.exe"
}

# --- run -------------------------------------------------------------------
Info "Native ARM64 Krita builder  |  CraftRoot=$CraftRoot"
if (-not $Resume) {
    Install-Prereqs
    Bootstrap-Craft
    Apply-Patches
}
Build
Ok "DONE."
