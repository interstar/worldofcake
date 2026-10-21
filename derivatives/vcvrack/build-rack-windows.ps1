param(
    [ValidateSet('gbloink', 'goldenpond', 'kdiagram', 'tileland', 'timeslider', 'zewp')]
    [string]$Module = 'gbloink',
    [switch]$Clean,
    [switch]$Package,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$rackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$derivativesRoot = Split-Path -Parent $rackRoot
$moduleRoot = Join-Path $rackRoot $Module
$sdkRoot = Join-Path $derivativesRoot 'Rack-SDK-2.6.4-win-x64\Rack-SDK'
$msysShell = 'C:\msys64\msys2_shell.cmd'
$haxeRoot = 'C:\HaxeToolkit\haxe'
$hxcppRoot = (haxelib libpath hxcpp).Trim()

if (!(Test-Path -LiteralPath $msysShell)) { throw "MSYS2 is missing: $msysShell" }
if (!(Test-Path -LiteralPath $sdkRoot)) { throw "Rack SDK 2.6.4 is missing: $sdkRoot" }
if (!(Test-Path -LiteralPath $moduleRoot)) { throw "Unknown module directory: $moduleRoot" }
if (!$hxcppRoot) { throw 'haxelib could not resolve hxcpp' }

$oldPath = $env:PATH
$oldMingwRoot = $env:MINGW_ROOT
try {
    $env:PATH = "C:\msys64\mingw64\bin;C:\msys64\usr\bin;$haxeRoot;$oldPath"
    $env:MINGW_ROOT = 'C:\msys64\mingw64'

    $moduleMsys = (& 'C:\msys64\usr\bin\cygpath.exe' -u $moduleRoot).Trim()
    $sdkMsys = (& 'C:\msys64\usr\bin\cygpath.exe' -u $sdkRoot).Trim()
    $rackUserRoot = Join-Path $env:LOCALAPPDATA 'Rack2'
    $rackUserMsys = (& 'C:\msys64\usr\bin\cygpath.exe' -u $rackUserRoot).Trim()
    $repoRoot = Split-Path -Parent $derivativesRoot
    $artifactRoot = Join-Path $repoRoot "build\vcvrack\$Module\windows"
    $msysTempRoot = Join-Path $artifactRoot 'msys-tmp'
    New-Item -ItemType Directory -Path $msysTempRoot -Force | Out-Null
    $msysTemp = (& 'C:\msys64\usr\bin\cygpath.exe' -u $msysTempRoot).Trim()
    # Force the MinGW runtime path inside MSYS2 as well as in the parent
    # PowerShell process. g++ launches cc1plus.exe from libexec, so Windows
    # must resolve libisl/libgmp/libmpfr from mingw64/bin.
    $shellPrefix = "export PATH='/mingw64/bin:/usr/bin:`$PATH' TMP='$msysTemp' TEMP='$msysTemp' HOME='$msysTemp';"
    $hxcppMake = $hxcppRoot.Replace('\', '/')
    # Rack panel SVGs are generated and checked in with outlined branding already.
    # The optional title reinjection uses the Linux development virtualenv, which
    # is not part of the Windows Rack toolchain and is unnecessary for compilation.
    $makeOptions = "RACK_DIR='$sdkMsys' RACK_USER_DIR='$rackUserMsys' HXCPP='$hxcppMake' WOC_SKIP_CODEGEN=1 WOC_PANEL_TITLE=0"
    if ($Clean) {
        $cleanCommand = "$shellPrefix cd '$moduleMsys' && make $makeOptions clean"
        & $msysShell -defterm -no-start -mingw64 -c $cleanCommand
        if ($LASTEXITCODE -ne 0) { throw "Rack clean failed for $Module" }
        New-Item -ItemType Directory -Path $msysTempRoot -Force | Out-Null
    }

    # Run the Windows Haxe/hxcpp toolchain directly from PowerShell. Invoking
    # the Windows haxelib executable inside MSYS2 loses its configured library
    # repository when that shell has to fall back to a temporary HOME.
    $nativeRoot = Join-Path $artifactRoot 'native'
    $hxml = Join-Path $moduleRoot "haxe\$Module.hxml"
    Push-Location $moduleRoot
    try {
        & (Join-Path $haxeRoot 'haxe.exe') $hxml -cpp $nativeRoot -D HXCPP_MINGW
        if ($LASTEXITCODE -ne 0) { throw "Haxe/hxcpp generation failed for $Module" }
    }
    finally {
        Pop-Location
    }
    $hxcppObjectRoot = Join-Path $nativeRoot 'obj\mingw64'
    $hxcppMain = Get-ChildItem -LiteralPath $hxcppObjectRoot -Filter '*___main__.o' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$hxcppMain) {
        throw "Haxe/hxcpp did not produce the expected Windows main object under: $hxcppObjectRoot"
    }
    $targets = @('build')
    if ($Install) {
        $targets = @('install')
    }
    elseif ($Package) {
        $targets = @('dist')
    }
    $targetText = $targets -join ' '
    $command = "$shellPrefix cd '$moduleMsys' && make $makeOptions $targetText"
    & $msysShell -defterm -no-start -mingw64 -c $command
    if ($LASTEXITCODE -ne 0) { throw "Rack make failed for $Module" }
}
finally {
    $env:PATH = $oldPath
    $env:MINGW_ROOT = $oldMingwRoot
}
