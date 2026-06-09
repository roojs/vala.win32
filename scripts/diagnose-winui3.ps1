# Report loader/DLL issues for winui3-hello-native.exe
# Exit code -1073741515 (0xC0000135) = STATUS_DLL_NOT_FOUND (fails before main).
param(
	[string]$ExeDir = (Join-Path $PSScriptRoot '..\build-win' | Resolve-Path -ErrorAction SilentlyContinue)
)

if (-not $ExeDir) {
	$ExeDir = Join-Path (Get-Location) 'build-win'
}

$exe = Join-Path $ExeDir 'winui3-hello-native.exe'
$bootstrap = Join-Path $ExeDir 'Microsoft.WindowsAppRuntime.Bootstrap.dll'

Write-Host "=== winui3-hello-native diagnostics ==="
Write-Host "Exe:       $exe"
Write-Host "Exists:    $(Test-Path $exe)"
Write-Host "Bootstrap: $bootstrap"
Write-Host "Exists:    $(Test-Path $bootstrap)"
Write-Host ""

$mingwDlls = @(
	'libstdc++-6.dll',
	'libgcc_s_seh-1.dll',
	'libwinpthread-1.dll'
)

Write-Host "MinGW runtime DLLs beside exe (needed if not statically linked):"
foreach ($dll in $mingwDlls) {
	$p = Join-Path $ExeDir $dll
	$ok = Test-Path $p
	Write-Host ("  {0,-24} {1}" -f $dll, ($(if ($ok) { 'OK' } else { 'MISSING' })))
}

Write-Host ""
Write-Host "Run from this directory:"
Write-Host "  cd $ExeDir"
Write-Host "  .\winui3-hello-native.exe"
Write-Host "  echo `$LASTEXITCODE"
Write-Host ""
Write-Host "0xC0000135 = a DLL in the import table was not found at process start."
Write-Host "If Bootstrap.dll is present, install Windows App SDK runtime:"
Write-Host "  https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/downloads"

if (Get-Command dumpbin -ErrorAction SilentlyContinue) {
	Write-Host ""
	Write-Host "--- dumpbin /dependents ---"
	dumpbin /nologo /dependents $exe
}
