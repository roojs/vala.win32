# Diagnose winui3-without-xaml self-contained layout and runtime HRESULTs.
param(
    [string]$ReleaseDir = 'C:\msys64\tmp\winui3-without-xaml\x64\Release'
)

$ErrorActionPreference = 'Stop'
$log = Join-Path $ReleaseDir 'reference-probe.log'
Remove-Item $log -ErrorAction SilentlyContinue

function Log([string]$msg) {
    $line = "$(Get-Date -Format o) $msg"
    Add-Content -Path $log -Value $line
    Write-Host $line
}

Log "probe start ReleaseDir=$ReleaseDir"

$exe = Join-Path $ReleaseDir 'winui3-without-xaml.exe'
if (-not (Test-Path $exe)) {
    Log "FAIL missing exe"
    exit 1
}

$checks = @(
    'resources.pri',
    'Microsoft.UI.Xaml.Controls.pri',
    'Microsoft.ui.xaml.dll',
    'Microsoft.WindowsAppRuntime.dll',
    'Microsoft.WindowsAppRuntime.Bootstrap.dll'
)
foreach ($c in $checks) {
    $p = Join-Path $ReleaseDir $c
    Log "$(if (Test-Path $p) { 'OK' } else { 'MISSING' }) $c"
}

$mui = Join-Path $ReleaseDir 'Microsoft.UI.Xaml'
Log "$(if (Test-Path $mui) { 'OK' } else { 'MISSING' }) Microsoft.UI.Xaml\"

# Try makepri for minimal app resources.pri if missing.
$pri = Join-Path $ReleaseDir 'resources.pri'
if (-not (Test-Path $pri)) {
    $makepri = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makepri.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($makepri) {
        Log "makepri: $($makepri.FullName)"
        $cfg = Join-Path $ReleaseDir 'makepri-config.xml'
        @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<resources targetOsVersion="10.0.0" majorVersion="1">
  <index root="\" startIndexAt="\">
    <default>
      <qualifier name="Language" value="en-US" />
    </default>
  </index>
</resources>
'@ | Set-Content -Path $cfg -Encoding UTF8
        Push-Location $ReleaseDir
        try {
            & $makepri.FullName new /pr $ReleaseDir /cf $cfg /of resources.pri /o 2>&1 | ForEach-Object { Log "makepri $_" }
            Log "$(if (Test-Path $pri) { 'OK created' } else { 'FAIL create' }) resources.pri"
        } finally {
            Pop-Location
        }
    } else {
        Log 'makepri.exe not found in Windows Kits'
    }
}

# Stage full MsixContent tree (not only locale folders).
$msix = Join-Path $ReleaseDir 'MsixContent'
if (-not (Test-Path $msix)) {
    $root = Split-Path (Split-Path $ReleaseDir -Parent) -Parent
    $alt = Get-ChildItem $root -Directory -Filter 'winui3-w.*' -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'x64\Release\MsixContent' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
    if ($alt) { $msix = $alt }
}
if (Test-Path $msix) {
    Log 'staging full MsixContent merge'
    Get-ChildItem $msix -Force | ForEach-Object {
        $dest = Join-Path $ReleaseDir $_.Name
        if ($_.PSIsContainer) {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $_.FullName -Destination $ReleaseDir -Recurse -Force
        } else {
            Copy-Item $_.FullName -Destination $ReleaseDir -Force
        }
    }
}

# Run exe; capture exit code (GUI may still fail over SSH).
$stderr = Join-Path $ReleaseDir 'reference-probe-stderr.txt'
$stdout = Join-Path $ReleaseDir 'reference-probe-stdout.txt'
Remove-Item $stderr, $stdout -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -WorkingDirectory $ReleaseDir -PassThru -Wait `
    -RedirectStandardError $stderr -RedirectStandardOutput $stdout -NoNewWindow
Log "exe exit $($p.ExitCode)"
if (Test-Path $stderr) { Get-Content $stderr | ForEach-Object { Log "stderr $_" } }
if (Test-Path $stdout) { Get-Content $stdout | ForEach-Object { Log "stdout $_" } }

Log 'probe done'
Write-Host "Wrote $log"
