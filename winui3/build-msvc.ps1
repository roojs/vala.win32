# WinUI3 C++ sandbox — MSVC build (primary toolchain).
# Run on Windows:  powershell -File build-msvc.ps1
# From Linux agent: scripts/agent-remote-winui3-sandbox.sh

param(
    [switch]$Run,
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

$WinUi3Dir = $PSScriptRoot
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $WinUi3Dir '..')).Path
}
$Sdk = Join-Path $RepoRoot 'build\vendor\winui3'
$Exe = Join-Path $WinUi3Dir 'winui3-sandbox.exe'
$BootstrapDll = Join-Path $Sdk 'bin\x64\Microsoft.WindowsAppRuntime.Bootstrap.dll'

if (-not (Test-Path (Join-Path $Sdk 'include\MddBootstrap.h'))) {
    throw "missing $Sdk - run vendor-winui3-sdk from repo root first"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw 'vswhere not found - install Visual Studio 2022 with Desktop development with C++'
}

$vsPath = & $vswhere -version '[18.0,19.0)' -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath 2>$null
if (-not $vsPath) {
    $vsPath = & $vswhere -latest -property installationPath
}
if (-not $vsPath) {
    throw 'no Visual Studio installation found'
}

$vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) {
    throw "missing $vcvars"
}

$clArgs = @(
    '/nologo', '/EHsc', '/std:c++20', '/W3', '/permissive-',
    "/I$Sdk\include",
    "/I$Sdk\cppwinrt",
    '/DWIN32', '/D_UNICODE', '/DUNICODE', '/DNOMINMAX', '/D_CRT_SECURE_NO_WARNINGS',
    (Join-Path $WinUi3Dir 'main.cpp'),
    '/link', '/SUBSYSTEM:WINDOWS',
    (Join-Path $Sdk 'lib\x64\Microsoft.WindowsAppRuntime.Bootstrap.lib'),
    'ole32.lib', 'oleaut32.lib', 'runtimeobject.lib', 'uuid.lib', 'user32.lib',
    "/OUT:$Exe"
)

Write-Host "[winui3-msvc] vcvars: $vcvars"
Write-Host "[winui3-msvc] cl $($clArgs -join ' ')"

$clLine = 'cl ' + ($clArgs | ForEach-Object {
    if ($_ -match '\s') { "`"$_`"" } else { $_ }
}) -join ' '

$batch = @"
@echo off
call "$vcvars" >nul
cd /d "$WinUi3Dir"
$clLine
if errorlevel 1 exit /b 1
"@

$batchFile = Join-Path $env:TEMP 'winui3-sandbox-msvc.cmd'
Set-Content -Path $batchFile -Value $batch -Encoding ASCII
cmd.exe /C $batchFile
if ($LASTEXITCODE -ne 0) {
    throw "cl failed (exit $LASTEXITCODE)"
}

if (-not (Test-Path $Exe)) {
    throw "build succeeded but missing $Exe"
}

Copy-Item -Path $BootstrapDll -Destination $WinUi3Dir -Force
Write-Host "OK: $Exe"

if ($Run) {
    & (Join-Path $PSScriptRoot '..\scripts\agent-remote-winui3-sandbox-run.ps1') `
        -ExeName 'winui3-sandbox.exe' -WorkDir $WinUi3Dir
}
