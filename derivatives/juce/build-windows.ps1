param(
    [ValidateSet("Release", "Debug")]
    [string]$Config = "Release",
    [string]$Target = "WorldOfCakeGbloink_All",
[ValidateSet("Gbloink", "TimeSliders", "Goldenpond", "KDiagram", "Zewp")]
[string]$Plugin = "Gbloink",
    [string]$JuceDir = "G:\PRODUCTION\MUSIC\music-software\falling sand 2026\sandsonify-vst\JUCE"
)

$ErrorActionPreference = "Stop"

# Some shells launch Codex with both `Path` and `PATH` entries. MSBuild treats
# those as duplicate keys when it constructs the compiler environment.
$CanonicalPath = $env:Path
Remove-Item Env:Path -ErrorAction SilentlyContinue
$env:Path = $CanonicalPath

$CMake = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$VsDev = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$BuildRoot = Join-Path $Root "build\juce"
$pluginDir = if ($Plugin -eq "TimeSliders") { "timeslider" } elseif ($Plugin -eq "Goldenpond") { "goldenpond" } elseif ($Plugin -eq "KDiagram") { "kdiagram" } elseif ($Plugin -eq "Zewp") { "zewp" } else { "gbloink" }
$HxcppOutput = Join-Path $BuildRoot ("{0}\hxcpp" -f $pluginDir)
$CMakeBuild = Join-Path $BuildRoot "cmake-vs2022"
# Each plugin compiles its own Haxe build against the JUCE generated tree (generated\juce).
$HxmlDir = Join-Path $Root ("derivatives\juce\{0}" -f $pluginDir)

foreach ($Path in @($CMake, $VsDev, (Join-Path $JuceDir "CMakeLists.txt"))) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required build dependency not found: $Path"
    }
}

$HxcppLines = & haxelib path hxcpp
if ($LASTEXITCODE -ne 0 -or $HxcppLines.Count -eq 0) {
    throw "hxcpp is not available through haxelib"
}
$HxcppRoot = $HxcppLines[0].TrimEnd('/', '\')

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
$HxcppDebug = if ($Config -eq "Debug") { " -debug" } else { "" }
$hxmlName = "$pluginDir.hxml"
$HxcppCommand = "call `"$VsDev`" -arch=x64 -host_arch=x64 && haxe haxe\$hxmlName -cpp `"$HxcppOutput`" -D windows -D NO_AUTO_MSVC$HxcppDebug"
Push-Location $HxmlDir
try {
    & cmd.exe /d /c $HxcppCommand
    if ($LASTEXITCODE -ne 0) { throw "$Plugin hxcpp build failed" }
} finally {
    Pop-Location
}

$HxcppObjectPattern = if ($Config -eq "Debug") { "msvc*64-debug" } else { "msvc*64" }
$HxcppObjectDir = Get-ChildItem -LiteralPath (Join-Path $HxcppOutput "obj") -Directory |
    Where-Object { $_.Name -like $HxcppObjectPattern } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($null -eq $HxcppObjectDir) {
    throw "Could not locate the compiled hxcpp object directory"
}

& $CMake -S $PSScriptRoot -B $CMakeBuild -G "Visual Studio 17 2022" -A x64 `
    "-DWOC_JUCE_DIR=$JuceDir" `
    "-DWOC_HXCPP_ROOT=$HxcppRoot" `
    "-DWOC_GBLOINK_HXCPP_DIR=$((Join-Path $BuildRoot 'gbloink\hxcpp'))" `
    "-DWOC_GBLOINK_HXCPP_OBJECT_DIR=$((Join-Path $BuildRoot 'gbloink\hxcpp\obj'))" `
    "-DWOC_TIMESLIDER_HXCPP_DIR=$((Join-Path $BuildRoot 'timeslider\hxcpp'))" `
    "-DWOC_TIMESLIDER_HXCPP_OBJECT_DIR=$($HxcppObjectDir.FullName)" `
    "-DWOC_GOLDENPOND_HXCPP_DIR=$((Join-Path $BuildRoot 'goldenpond\hxcpp'))" `
    "-DWOC_GOLDENPOND_HXCPP_OBJECT_DIR=$((Join-Path $BuildRoot 'goldenpond\hxcpp\obj'))" `
    "-DWOC_KDIAGRAM_HXCPP_DIR=$((Join-Path $BuildRoot 'kdiagram\hxcpp'))" `
    "-DWOC_KDIAGRAM_HXCPP_OBJECT_DIR=$((Join-Path $BuildRoot 'kdiagram\hxcpp\obj'))" `
    "-DWOC_ZEWP_HXCPP_DIR=$((Join-Path $BuildRoot 'zewp\hxcpp'))" `
    "-DWOC_ZEWP_HXCPP_OBJECT_DIR=$((Join-Path $BuildRoot 'zewp\hxcpp\obj'))"
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }

& $CMake --build $CMakeBuild --config $Config --target $Target
if ($LASTEXITCODE -ne 0) { throw "CMake build failed" }

Write-Host "Artefacts: $CMakeBuild\WorldOfCakeGbloink_artefacts\$Config"
