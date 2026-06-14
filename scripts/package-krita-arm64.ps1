<#
.SYNOPSIS
    Assemble the self-contained Krita package and build the ARM64 setup .exe.

.DESCRIPTION
    Runs Krita's official packaging script (package-complete-msvc.py) against the
    installed tree to produce a redistributable folder + .zip where krita.exe
    launches directly (no .bat), then feeds that tree to the NSIS installer.
#>
[CmdletBinding()]
param(
    [string]$DepsRoot = "C:\kritadeps",
    [string]$Version  = "5.3.2.1"
)

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$KritaSrc   = Join-Path $RepoRoot "krita-src"
$InstallerDir = Join-Path $RepoRoot "packaging\arm64-installer"

$Prefix      = Join-Path $DepsRoot "i"
$KritaInstall = Join-Path $DepsRoot "krita-install"
$PkgDir      = Join-Path $DepsRoot "pkg"
$PkgName     = "krita-$Version-windows-arm64"
$PkgTree     = Join-Path $PkgDir $PkgName

$SevenZip = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $SevenZip) { throw "7-Zip not found. Install it (winget install 7zip.7zip)." }

$Python = Join-Path $DepsRoot "python313-dev\python.exe"
if (-not (Test-Path $Python)) { throw "ARM64 Python not found at $Python" }

New-Item -ItemType Directory -Force $PkgDir | Out-Null
if (Test-Path $PkgTree) { Remove-Item -Recurse -Force $PkgTree }

Write-Host "==> Packaging self-contained tree" -ForegroundColor Cyan
$env:PATH       = "$Prefix\bin;$env:PATH"
$env:PYTHONPATH = "$Prefix\lib\site-packages"
$env:SEVENZIP_EXE = $SevenZip
Push-Location $PkgDir
try {
    & $Python (Join-Path $KritaSrc "packaging\windows\package-complete-msvc.py") `
        --no-interactive `
        --package-name $PkgName `
        --src-dir $KritaSrc `
        --deps-install-dir $Prefix `
        --krita-install-dir $KritaInstall
    if ($LASTEXITCODE -ne 0) { throw "packaging script failed ($LASTEXITCODE)" }
} finally { Pop-Location }

if (-not (Test-Path (Join-Path $PkgTree "bin\krita.exe"))) {
    throw "Packaging did not produce $PkgTree\bin\krita.exe"
}

Write-Host "==> Building installer" -ForegroundColor Cyan
& (Join-Path $InstallerDir "build-installer.ps1") `
    -PackageRoot $PkgTree `
    -Version $Version `
    -VersionDisplay $Version `
    -OutFile (Join-Path $InstallerDir "$PkgName-setup.exe")

Write-Host "`n[ok] Package zip : $PkgTree.zip" -ForegroundColor Green
Write-Host "[ok] Installer   : $InstallerDir\$PkgName-setup.exe" -ForegroundColor Green
