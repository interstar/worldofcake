[CmdletBinding()]
param(
    [ValidateSet('gbloink', 'timeslider', 'goldenpond', 'kdiagram', 'tileland', 'zewp')]
    [string]$App,
    [switch]$BuildOnly,
    [ValidateSet('debug', 'release')]
    [string]$Configuration = 'debug'
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$projectFile = Join-Path $repoRoot "derivatives\openfl\project-$App.xml"
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "No standalone OpenFL preview has been migrated for '$App'."
}

# Always build, then launch the exe by full path ourselves: `openfl test` launches it by
# bare name through cmd, which fails when NoDefaultCurrentDirectoryInExePath is set.
$arguments = @('run', 'openfl', 'build', $projectFile, 'windows')
if ($Configuration -eq 'debug') { $arguments += '-debug' }

Write-Host "build standalone OpenFL preview: $App"
& haxelib @arguments
if ($LASTEXITCODE -ne 0 -or $BuildOnly) { exit $LASTEXITCODE }

$exeName = ([xml](Get-Content -LiteralPath $projectFile)).project.app.file
$binDir = Join-Path $repoRoot 'derivatives\openfl\Export\windows\bin'
$exe = Join-Path $binDir "$exeName.exe"
Write-Host "run $exe"
& $exe
exit $LASTEXITCODE
