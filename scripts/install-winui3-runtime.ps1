# Install Windows App Runtime 2.x (x64) if the framework package is missing.
param(
	[string]$InstallerPath = '',
	[string]$MsixDir = '',
	[switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Test-WinAppRuntimeReady {
	$fw = Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime.2' -ErrorAction SilentlyContinue |
		Where-Object { $_.Architecture -eq 'X64' -or $_.Architecture -eq 64 }
	return [bool]$fw
}

function Test-IsFrameworkMsix {
	param([string]$Name)
	return $Name -match '^Microsoft\.WindowsAppRuntime\.2\.msix$'
}

function Install-FromMsix {
	param([string]$Dir)
	$files = Get-ChildItem -LiteralPath $Dir -Filter '*.msix' -ErrorAction SilentlyContinue |
		Sort-Object {
			$name = $_.Name
			if ($name -match 'DDLM') { 3 }
			elseif ($name -match 'Singleton') { 2 }
			elseif ($name -match 'Main') { 1 }
			else { 0 }
		}, Name
	if (-not $files) {
		Write-Error "No .msix files in $Dir"
		exit 1
	}
	foreach ($msix in $files) {
		if (-not $Quiet) {
			Write-Host "[install-winui3-runtime] Add-AppxPackage $($msix.Name)"
		}
		try {
			Add-AppxPackage -Path $msix.FullName -ForceUpdateFromAnyVersion -ErrorAction Stop
		} catch {
			Write-Error "Add-AppxPackage failed for $($msix.Name): $_"
			exit 1
		}
		if (Test-IsFrameworkMsix $msix.Name) {
			if (-not (Test-WinAppRuntimeReady)) {
				Write-Error "Microsoft.WindowsAppRuntime.2 (x64) not registered after $($msix.Name)"
				exit 1
			}
			if (-not $Quiet) {
				Write-Host "[install-winui3-runtime] framework Microsoft.WindowsAppRuntime.2 (x64) OK"
			}
		}
	}
}

function Invoke-Installer {
	param(
		[string]$Path,
		[switch]$Elevated
	)
	$args = @('--quiet', '--force')
	if ($Elevated) {
		$p = Start-Process -FilePath $Path -ArgumentList $args -Wait -PassThru -Verb RunAs
	} else {
		$p = Start-Process -FilePath $Path -ArgumentList $args -Wait -PassThru
	}
	return $p.ExitCode
}

if (Test-WinAppRuntimeReady) {
	if (-not $Quiet) {
		Write-Host "[install-winui3-runtime] Microsoft.WindowsAppRuntime.2 (x64) already installed"
	}
	exit 0
}

if ($InstallerPath -and (Test-Path -LiteralPath $InstallerPath)) {
	if (-not $Quiet) {
		Write-Host "[install-winui3-runtime] Running installer:"
		Write-Host "  $InstallerPath"
	}
	$code = Invoke-Installer -Path $InstallerPath
	if ($code -ne 0) {
		$code = Invoke-Installer -Path $InstallerPath -Elevated
	}
	if ($code -ne 0) {
		Write-Error "WindowsAppRuntimeInstall.exe exited with code $code"
		exit $code
	}
} elseif ($MsixDir -and (Test-Path -LiteralPath $MsixDir)) {
	if (-not $Quiet) {
		Write-Host "[install-winui3-runtime] Installing from MSIX packages in:"
		Write-Host "  $MsixDir"
	}
	Install-FromMsix -Dir $MsixDir
} else {
	Write-Error "No installer exe or MSIX directory provided"
	exit 1
}

if (-not (Test-WinAppRuntimeReady)) {
	Write-Error "Microsoft.WindowsAppRuntime.2 (x64) still missing after install. Run MSYS2 UCRT64 as Administrator and retry."
	exit 1
}

if (-not $Quiet) {
	Write-Host "[install-winui3-runtime] OK - Windows App Runtime 2.x (x64) installed"
}
exit 0
