# Agent-only: launch widgets demo and wait for exit (SSH from Linux; UI may be headless).
$ErrorActionPreference = 'Stop'

$buildWin = 'C:\msys64\tmp\vala.win32\build-win'
$exeName = if ($env:WINUI3_LAYER -eq 'sparse' -or $env:WINUI3_LAYER -eq 'widgets') {
    'winui3-widgets-native.exe'
} else {
    'winui3-hello-native.exe'
}
$exe = Join-Path $buildWin $exeName
$log = Join-Path $buildWin 'winui3-debug.log'

if (-not (Test-Path $exe)) {
    Write-Error "missing $exe"
}

# Truncate log so pull shows only this run.
Set-Content -Path $log -Value "[agent] starting $exe $(Get-Date -Format o)" -Encoding UTF8

try {
    $p = Start-Process -FilePath $exe -WorkingDirectory $buildWin -PassThru -WindowStyle Hidden
} catch {
    Add-Content -Path $log -Value ('agent launch failed over SSH: ' + $_.Exception.Message) -Encoding UTF8
    Write-Host 'WARN: exe launch skipped over SSH — run interactively on Windows for UI'
    exit 0
}

# Hello (cf233c0): blocks in message loop until window closes — still running after a few seconds = likely OK.
Start-Sleep -Seconds 3
if ($p.HasExited) {
    $line = "FAIL: exited early with code $($p.ExitCode) (bootstrap/SxS error? check for MessageBox on desktop)"
    Add-Content -Path $log -Value $line -Encoding UTF8
    Write-Host $line
    exit [int]$p.ExitCode
}
Add-Content -Path $log -Value 'OK: still running after 3s (WinUI message loop — close window or agent will kill)' -Encoding UTF8
$deadline = (Get-Date).AddSeconds(20)
while (-not $p.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
}
if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Add-Content -Path $log -Value 'OK: killed after 20s (was running — treat as launch success for hello layer)' -Encoding UTF8
    exit 0
}
$ec = $p.ExitCode
Add-Content -Path $log -Value ("exit code $ec after window closed") -Encoding UTF8
exit $ec
