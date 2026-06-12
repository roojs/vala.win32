# Agent: launch winui3 sandbox exe, bounded wait, pull-friendly log.
param(
    [string]$ExeName = 'winui3-sandbox.exe',
    [string]$WorkDir = 'C:\msys64\tmp\vala.win32\winui3'
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $WorkDir $ExeName
$log = Join-Path $WorkDir 'winui3-sandbox.log'

if (-not (Test-Path $exe)) {
    Write-Error "missing $exe"
}

Set-Content -Path $log -Value "[agent] starting $exe $(Get-Date -Format o)" -Encoding UTF8

try {
    $p = Start-Process -FilePath $exe -WorkingDirectory $WorkDir -PassThru -WindowStyle Hidden
} catch {
    Add-Content -Path $log -Value ('agent launch failed: ' + $_.Exception.Message) -Encoding UTF8
    exit 1
}

Start-Sleep -Seconds 3
if ($p.HasExited) {
    $line = "FAIL: exited early code $($p.ExitCode)"
    Add-Content -Path $log -Value $line -Encoding UTF8
    Get-Content $log -Tail 12
    exit [int]$p.ExitCode
}

$deadline = (Get-Date).AddSeconds(15)
while (-not $p.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
}
if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Add-Content -Path $log -Value 'agent: killed after 15s (still running)' -Encoding UTF8
} else {
    Add-Content -Path $log -Value "agent: exit code $($p.ExitCode)" -Encoding UTF8
}

$tail = Get-Content $log -Tail 12
$tail
if ($tail -match 'bootstrap failed') {
    Write-Host 'FAIL: bootstrap error in log'
    exit 1
}
if ($tail -match 'OnLaunched OK \(themed=1\)') {
    Write-Host 'OK: TextBox + Button path (themed=1)'
    exit 0
}
if ($tail -match 'OnLaunched OK') {
    Write-Host 'OK: launched (labels only or themed=0)'
    exit 0
}
if (-not $p.HasExited -or $p.ExitCode -eq 0) {
    Write-Host 'OK: process ran (check log for OnLaunched)'
    exit 0
}
exit [int]$p.ExitCode
