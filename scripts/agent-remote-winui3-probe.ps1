# Agent probe: extract embedded manifest, launch exe, capture result.
$ErrorActionPreference = 'Continue'
$buildWin = 'C:\msys64\tmp\vala.win32\build-win'
$exe = Join-Path $buildWin 'winui3-widgets-native.exe'
$out = Join-Path $buildWin 'agent-probe.txt'
$manifestOut = Join-Path $buildWin 'agent-extracted.manifest'

Set-Content -Path $out -Value "probe $(Get-Date -Format o)" -Encoding UTF8

$mt = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter mt.exe |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if ($mt) {
    & $mt -nologo -inputresource:"${exe};#1" -out:$manifestOut 2>&1 | Out-String | Add-Content $out
    if (Test-Path $manifestOut) {
        Add-Content $out '--- embedded manifest ---'
        Get-Content $manifestOut | Add-Content $out
    }
}

Add-Content $out '--- appx ---'
Get-AppxPackage -Name 'vala.win32.WinUI3' -ErrorAction SilentlyContinue |
    Select-Object PackageFullName, InstallLocation | Format-List | Out-String | Add-Content $out

Add-Content $out '--- launch ---'
$log = Join-Path $buildWin 'winui3-debug.log'
$etl = 'C:\msys64\tmp\agent-sxs.etl'
$txt = 'C:\msys64\tmp\agent-sxs.txt'
Remove-Item $etl, $txt -ErrorAction SilentlyContinue
& sxstrace.exe Trace -logfile:$etl | Out-Null
$p = Start-Process -FilePath $exe -WorkingDirectory $buildWin -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
if (-not $p) {
    Add-Content $out 'Start-Process returned null'
} else {
    $null = $p.WaitForExit(15000)
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Add-Content $out "exit=$($p.ExitCode) hasExited=$($p.HasExited)"
}
Stop-Process -Name sxstrace -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
& sxstrace.exe Parse -logfile:$etl -outfile:$txt 2>&1 | Out-Null
if (Test-Path $txt) {
    Add-Content $out '--- sxstrace ---'
    Get-Content $txt | Select-String -Pattern 'ERROR|error|cannot|resolve|msix|vala' | Select-Object -First 40 | ForEach-Object { $_.Line } | Add-Content $out
}
if (Test-Path $log) {
    Add-Content $out '--- winui3-debug.log ---'
    Get-Content $log -Tail 30 | Add-Content $out
}
