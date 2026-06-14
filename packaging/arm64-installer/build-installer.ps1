# Build the Krita-for-Windows-on-ARM setup .exe with NSIS.
#
# Usage:
#   build-installer.ps1 -PackageRoot <extracted package tree> `
#                       -Version 5.3.2.1 -VersionDisplay "5.3.2.1 (git ...)" `
#                       [-OutFile <path to setup .exe>] [-MakeNsis <makensis.exe>]
#
# PackageRoot must be the extracted self-contained tree (bin/lib/share/python),
# NOT the .zip and NOT the live packaging dir.

param(
    [Parameter(Mandatory = $true)] [string]$PackageRoot,
    [Parameter(Mandatory = $true)] [string]$Version,
    [string]$VersionDisplay = $Version,
    [string]$OutFile,
    [string]$MakeNsis
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $PackageRoot 'bin\krita.exe'))) {
    throw "PackageRoot '$PackageRoot' does not contain bin\krita.exe -- point it at the extracted package tree."
}

if (-not $OutFile) {
    $OutFile = Join-Path $scriptDir "krita-$Version-windows-arm64-setup.exe"
}

if (-not $MakeNsis) {
    $candidates = @(
        'C:\kritadeps\nsis\nsis-3.10\makensis.exe',
        "$env:ProgramFiles\NSIS\makensis.exe",
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
    )
    $MakeNsis = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $MakeNsis) { throw "makensis.exe not found. Pass -MakeNsis <path>." }
}

Write-Host "makensis     : $MakeNsis"
Write-Host "package root : $PackageRoot"
Write-Host "version      : $Version ($VersionDisplay)"
Write-Host "output       : $OutFile"

& $MakeNsis `
    "/DKRITA_PACKAGE_ROOT=$PackageRoot" `
    "/DKRITA_VERSION=$Version" `
    "/DKRITA_VERSION_DISPLAY=$VersionDisplay" `
    "/DKRITA_OUTFILE=$OutFile" `
    "/INPUTCHARSET" "UTF8" `
    (Join-Path $scriptDir 'installer_krita_arm64.nsi')

if ($LASTEXITCODE -ne 0) { throw "makensis failed with exit code $LASTEXITCODE" }
Write-Host "`nInstaller built: $OutFile"
