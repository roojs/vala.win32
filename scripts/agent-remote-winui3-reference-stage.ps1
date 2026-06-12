# Flatten MsixContent into Release/ so self-contained exe can find runtime DLLs.
param(
    [Parameter(Mandatory)]
    [string]$ReleaseDir
)

$ErrorActionPreference = 'Stop'

function Find-MsixContent([string]$releaseDir) {
    $direct = Join-Path $releaseDir 'MsixContent'
    if (Test-Path $direct) { return $direct }
    $parent = Split-Path $releaseDir -Parent
    $root = Split-Path $parent -Parent
    $candidates = Get-ChildItem $root -Directory -Filter 'winui3-w.*' -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'x64\Release\MsixContent' } |
        Where-Object { Test-Path $_ }
    if ($candidates) { return ($candidates | Select-Object -First 1) }
    return $null
}

$msix = Find-MsixContent $ReleaseDir
if (-not $msix) {
    Write-Host "skip stage: no MsixContent near $ReleaseDir"
    exit 0
}
Write-Host "[reference] MsixContent source: $msix"

Write-Host "[reference] stage full MsixContent tree -> $ReleaseDir"
Get-ChildItem $msix -Force | ForEach-Object {
    $dest = Join-Path $ReleaseDir $_.Name
    if ($_.PSIsContainer) {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $_.FullName -Destination $ReleaseDir -Recurse -Force
    } else {
        Copy-Item $_.FullName -Destination $ReleaseDir -Force
    }
}

# PriGen often fails on VS 18; self-contained unpackaged still needs resources.pri.
$pri = Join-Path $ReleaseDir 'resources.pri'
if (-not (Test-Path $pri)) {
    $makepri = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makepri.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($makepri) {
        Write-Host "[reference] makepri -> resources.pri"
        $cfg = Join-Path $ReleaseDir 'makepri-config.xml'
        @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<resources targetOsVersion="10.0.0" majorVersion="1">
  <index root="\" startIndexAt="">
    <default>
      <qualifier name="Language" value="en-US" />
    </default>
  </index>
</resources>
'@ | Set-Content -Path $cfg -Encoding UTF8
        Push-Location $ReleaseDir
        try {
            & $makepri.FullName new /pr $ReleaseDir /cf $cfg /of resources.pri /o
        } finally {
            Pop-Location
        }
        if (-not (Test-Path $pri)) {
            Write-Host "WARN: makepri did not create resources.pri"
        }
    } else {
        Write-Host "WARN: makepri.exe not found; resources.pri missing"
    }
}

$exe = Join-Path $ReleaseDir 'winui3-without-xaml.exe'
if (Test-Path $exe) {
    Write-Host "OK staged: $exe"
    Get-Item $exe | Format-List FullName, Length, LastWriteTime
}
