# MSBuild a synced reference sample (winui3-without-xaml or cpp-winui-unpackaged).
param(
    [Parameter(Mandatory)]
    [string]$ProjectDir,
    [Parameter(Mandatory)]
    [string]$Solution,
    [Parameter(Mandatory)]
    [string]$ExeRel
)

$ErrorActionPreference = 'Stop'

$sln = Join-Path $ProjectDir $Solution
if (-not (Test-Path $sln)) {
    throw "missing solution $sln"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw 'vswhere not found'
}

# Require VS 18 (2026). Do not use vswhere -latest alone: VS 2017 may still be registered.
$vs = & $vswhere -version '[18.0,19.0)' -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath 2>$null
if (-not $vs) {
    $vs = 'C:\Program Files\Microsoft Visual Studio\18\Community'
    if (-not (Test-Path (Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'))) {
        throw 'VS 18 (2026) with C++ x64 tools required; found only older VS or incomplete install'
    }
}

$msbuild = Join-Path $vs 'MSBuild\Current\Bin\MSBuild.exe'
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) {
    throw "missing $vcvars (Desktop development with C++ / MSVC x64)"
}
Write-Host "[reference] VS: $vs"

$nuget = Get-Command nuget.exe -ErrorAction SilentlyContinue
if ($nuget) {
    Write-Host "[reference] nuget restore $sln"
  # nuget.exe auto-detects MSBuild 15 from VS 2017 unless -MSBuildPath is set.
    & nuget.exe restore $sln -MSBuildPath $msbuild
}

# VS 18 ships v145 (MSVC 14.51).
$toolset = 'v145'
$vcVer = & $vswhere -version '[18.0,19.0)' -latest -property catalog_buildVersion 2>$null
if ($vcVer -and $vcVer -notmatch '^18\.') {
    Write-Host "WARN: unexpected catalog_buildVersion $vcVer"
}

$msbuildArgs = @(
    $sln,
    '/restore',
    '/p:Configuration=Release',
    '/p:Platform=x64',
    '/m'
)
if ($toolset) {
    $msbuildArgs += "/p:PlatformToolset=$toolset"
}

Write-Host "[reference] msbuild $($msbuildArgs -join ' ')"
$logFile = Join-Path $env:TEMP 'winui3-reference-msbuild.log'
$argLine = ($msbuildArgs | ForEach-Object {
    if ($_ -match '\s') { "`"$_`"" } else { $_ }
}) -join ' '
$batch = @"
@echo off
call "$vcvars" >nul
"$msbuild" $argLine >"$logFile" 2>&1
exit /b %ERRORLEVEL%
"@
$batchFile = Join-Path $env:TEMP 'winui3-reference-msbuild.cmd'
Set-Content -Path $batchFile -Value $batch -Encoding ASCII
cmd.exe /C $batchFile
$msbuildRc = $LASTEXITCODE
$log = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
if ($log) { Write-Host $log }

$exe = Join-Path $ProjectDir $ExeRel
if ($msbuildRc -ne 0) {
    $compileFailed = $log -match 'error C\d+'
    $priOnly = -not $compileFailed -and ($log -match 'ExpandPriContent|Pri\.Tasks|PriGen')
    if (-not $priOnly) {
        throw "msbuild failed ($msbuildRc)"
    }
    if (-not (Test-Path $exe)) {
        throw "msbuild PriGen warn but missing $exe"
    }
    Write-Host "WARN: msbuild exit $msbuildRc (PriGen only) but exe exists - continuing"
} elseif (-not (Test-Path $exe)) {
    throw "missing $exe"
}

Write-Host "OK: $exe"
Get-Item $exe | Format-List FullName, Length, LastWriteTime
