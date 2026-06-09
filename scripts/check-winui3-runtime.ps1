# Verify Windows App Runtime 2.x (x64) framework is installed for WinUI3 bootstrap.
param(
	[switch]$Quiet
)

function Test-WinAppRuntimeReady {
	# Package family is Microsoft.WindowsAppRuntime.2 (not .2.1); version 2.1.3 => 8002.1.3.0.
	$fw = Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime.2' -ErrorAction SilentlyContinue |
		Where-Object { $_.Architecture -eq 'X64' -or $_.Architecture -eq 64 }
	return [bool]$fw
}

if ($Quiet) {
	if (Test-WinAppRuntimeReady) { exit 0 }
	exit 1
}

Write-Host "=== Windows App Runtime packages on this machine ==="
Get-AppxPackage -Name '*WindowsAppRuntime*' -ErrorAction SilentlyContinue |
	Select-Object Name, Version, Architecture, PackageFullName |
	Format-Table -AutoSize

Write-Host ""
Write-Host "=== DDLM packages ==="
Get-AppxPackage -Name '*WinAppRuntime.DDLM*' -ErrorAction SilentlyContinue |
	Select-Object Name, Version, Architecture |
	Format-Table -AutoSize

if (-not (Test-WinAppRuntimeReady)) {
	Write-Host ""
	Write-Host "MISSING: Microsoft.WindowsAppRuntime.2 (x64) framework not installed." -ForegroundColor Red
	Write-Host "Run: ./scripts/install-winui3-runtime.sh"
	Write-Host "Or:  ./scripts/build-win.sh  (installs automatically)"
	exit 1
}

Write-Host ""
Write-Host "OK: Microsoft.WindowsAppRuntime.2 (x64) is installed."
