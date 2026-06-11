# Agent-only: trust sparse dev cert + register MSIX (run via SSH from Linux host).
# Usage (on Windows): powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...\agent-remote-winui3-setup.ps1
$ErrorActionPreference = 'Stop'

$buildWin = 'C:\msys64\tmp\vala.win32\build-win'
$cer = Join-Path $buildWin 'vala.win32.sparse.cer'
$msix = Join-Path $buildWin 'vala.win32.winui3.sparse.msix'
$logo = Join-Path $buildWin 'Assets\StoreLogo.png'
$log = Join-Path $buildWin 'agent-winui3-setup.log'

function Write-SetupLog([string]$Message) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $log -Value $line -Encoding UTF8
    Write-Host $line
}

New-Item -ItemType Directory -Force -Path $buildWin | Out-Null
Set-Content -Path $log -Value "agent-winui3-setup start $(Get-Date -Format o)" -Encoding UTF8

if (-not (Test-Path $msix)) {
    Write-SetupLog "ERROR: missing $msix"
    exit 1
}
if (-not (Test-Path $logo)) {
    Write-SetupLog "ERROR: missing $logo (sparse external location)"
    exit 1
}

if (Test-Path $cer) {
    try {
        Import-Certificate -FilePath $cer -CertStoreLocation Cert:\CurrentUser\TrustedPeople | Out-Null
        Write-SetupLog "OK: cert imported to CurrentUser\TrustedPeople"
    } catch {
        Write-SetupLog "WARN: Import-Certificate TrustedPeople failed: $($_.Exception.Message)"
    }
    & $env:WINDIR\System32\certutil.exe -addstore -user TrustedPeople $cer 2>&1 | Out-Null
    & $env:WINDIR\System32\certutil.exe -addstore -user Root $cer 2>&1 | Out-Null
}

$existing = Get-AppxPackage -Name 'vala.win32.WinUI3' -ErrorAction SilentlyContinue
if ($existing) {
    Remove-AppxPackage -Package $existing.PackageFullName -ErrorAction SilentlyContinue
    Write-SetupLog "OK: removed prior package $($existing.PackageFullName)"
}

Add-AppxPackage -Path $msix -ExternalLocation $buildWin -ForceUpdateFromAnyVersion
$pkg = Get-AppxPackage -Name 'vala.win32.WinUI3' -ErrorAction Stop
Write-SetupLog "OK: registered $($pkg.PackageFullName)"
exit 0
