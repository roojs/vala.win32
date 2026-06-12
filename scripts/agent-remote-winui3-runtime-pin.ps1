# §4 experiment: remove blocking framework >= 2.2, install vendored 2.1.3 MSIX, probe launch.
# Run via SSH only — no full rebuild required.
$ErrorActionPreference = 'Continue'
$buildWin = 'C:\msys64\tmp\vala.win32\build-win'
$out = Join-Path $buildWin 'agent-runtime-pin.txt'
$vendorMsix = 'C:\msys64\tmp\vala.win32\build\vendor\winui3-runtime\msix\x64'
$stageMsix = 'C:\msys64\tmp\vala-win32-winui3-runtime\msix\x64'

Set-Content -Path $out -Value "runtime-pin $(Get-Date -Format o)" -Encoding UTF8

function Log-Pkgs($label) {
    Add-Content $out "--- $label ---"
    $pkgs = @(
        Get-AppxPackage -Name '*WindowsAppRuntime*' -ErrorAction SilentlyContinue
        Get-AppxPackage -Name '*WinAppRuntime*' -ErrorAction SilentlyContinue
    ) | Where-Object { $_.Architecture -eq 'X64' -or $_.Architecture -eq 64 } |
        Sort-Object Name -Unique
    foreach ($pkg in $pkgs) {
        Add-Content $out ("  {0}  {1}" -f $pkg.Name, $pkg.Version)
    }
}

Log-Pkgs 'before'

Add-Content $out '--- remove WinApp runtime stack (dependents first) ---'
$removePatterns = @(
    '*WinAppRuntime.Singleton*',
    '*WinAppRuntime.Main*',
    '*WinAppRuntime.DDLM*',
    '*WindowsAppRuntime.DDLM*',
    'Microsoft.WindowsAppRuntime.2'
)
foreach ($pat in $removePatterns) {
    Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Architecture -ne 'X64' -and $_.Architecture -ne 64) { return }
        Add-Content $out "  Remove-AppxPackage $($_.PackageFullName)"
        try {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
            Add-Content $out '    OK'
        } catch {
            Add-Content $out "    FAIL: $($_.Exception.Message)"
        }
    }
}
# x86 framework blocks some operations — remove if still present
Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime.2' -ErrorAction SilentlyContinue |
    Where-Object { $_.Architecture -eq 'X86' -or $_.Architecture -eq 86 } |
    ForEach-Object {
        Add-Content $out "  Remove-AppxPackage (x86) $($_.PackageFullName)"
        try {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
            Add-Content $out '    OK'
        } catch {
            Add-Content $out "    FAIL: $($_.Exception.Message)"
        }
    }

Log-Pkgs 'after remove'

$msixDir = $vendorMsix
if (-not (Test-Path $msixDir)) { $msixDir = $stageMsix }
Add-Content $out "--- install vendored 2.1.3 from $msixDir ---"
if (-not (Test-Path $msixDir)) {
    Add-Content $out '  FAIL: no vendored msix dir (run vendor-winui3-runtime.sh once on Windows)'
} else {
    $order = @(
        @{ pat = '*Main*'; key = 1 },
        @{ pat = '*Singleton*'; key = 2 },
        @{ pat = '*DDLM*'; key = 3 },
        @{ pat = 'Microsoft.WindowsAppRuntime.2.msix'; key = 0 }
    )
    $files = Get-ChildItem -Path $msixDir -Filter '*.msix' -ErrorAction SilentlyContinue
    foreach ($k in 0..3) {
        foreach ($f in $files) {
            $match = $false
            switch ($k) {
                0 { $match = $f.Name -eq 'Microsoft.WindowsAppRuntime.2.msix' }
                1 { $match = $f.Name -like '*Main*' }
                2 { $match = $f.Name -like '*Singleton*' }
                3 { $match = $f.Name -like '*DDLM*' }
            }
            if (-not $match) { continue }
            Add-Content $out "  Add-AppxPackage $($f.Name)"
            try {
                Add-AppxPackage -Path $f.FullName -ForceUpdateFromAnyVersion -ErrorAction Stop
                Add-Content $out '    OK'
            } catch {
                Add-Content $out "    FAIL: $($_.Exception.Message)"
            }
        }
    }
}

Log-Pkgs 'after install'

$exe = Join-Path $buildWin 'winui3-widgets-native.exe'
if (Test-Path $exe) {
    Add-Content $out '--- launch probe ---'
    $p = Start-Process -FilePath $exe -WorkingDirectory $buildWin -PassThru -WindowStyle Hidden
    $null = $p.WaitForExit(12000)
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Add-Content $out "  exit=$($p.ExitCode)"
    $log = Join-Path $buildWin 'winui3-debug.log'
    if (Test-Path $log) {
        Add-Content $out '--- winui3-debug.log tail ---'
        Get-Content $log -Tail 15 | Add-Content $out
    }
}

Get-Content $out
