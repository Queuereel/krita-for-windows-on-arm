# Generate krita.ico + kritafile.ico for the ARM64 build.
#
# The ARM64 deps prefix has no icotool/png2ico, so ECM's ecm_add_app_icon emits
# nothing and `cmake --install` fails on the missing .ico files. This packs the
# branding/mimetype PNGs into real multi-resolution ICO containers (PNG-embedded,
# Vista+), writing them where the install step expects them.
#
# Usage: powershell -ExecutionPolicy Bypass -File gen-krita-icons.ps1
param(
    [string]$KritaSrc   = "C:\KritaARM\krita-src",
    [string]$BuildKrita = "C:\kritadeps\b\krita\krita"
)

function New-Ico {
    param([string[]]$Pngs, [string]$Out)
    $imgs = @()
    foreach ($p in $Pngs) {
        if (-not (Test-Path $p)) { continue }
        $name = Split-Path $p -Leaf
        $sz = [int]($name -replace '^(\d+).*', '$1')
        $imgs += [pscustomobject]@{ Size = $sz; Data = [System.IO.File]::ReadAllBytes($p) }
    }
    $imgs = $imgs | Sort-Object Size
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$imgs.Count)
    $offset = 6 + 16 * $imgs.Count
    foreach ($im in $imgs) {
        $wb = if ($im.Size -ge 256) { 0 } else { $im.Size }
        $bw.Write([byte]$wb); $bw.Write([byte]$wb)
        $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$im.Data.Length); $bw.Write([uint32]$offset)
        $offset += $im.Data.Length
    }
    foreach ($im in $imgs) { $bw.Write($im.Data) }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
    Write-Host "Wrote $Out ($($imgs.Count) images)"
}

$brand = Join-Path $KritaSrc "krita\pics\branding\default"
$appPngs = @(16, 32, 48, 64, 128, 256) | ForEach-Object { Join-Path $brand "$_-apps-krita.png" }
New-Ico -Pngs $appPngs -Out (Join-Path $BuildKrita "krita.ico")

$mimeDir = Join-Path $KritaSrc "krita\pics\mimetypes"
$mimePngs = Get-ChildItem $mimeDir -Filter "*-mimetypes-application-x-krita.png" |
    Where-Object { $_.Name -match '^(16|32|48|64|128|256)-' } | ForEach-Object { $_.FullName }
New-Ico -Pngs $mimePngs -Out (Join-Path $BuildKrita "kritafile.ico")
