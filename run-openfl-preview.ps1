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

$action = if ($BuildOnly) { 'build' } else { 'test' }
$arguments = @('run', 'openfl', $action, $projectFile, 'windows')
if ($Configuration -eq 'debug') { $arguments += '-debug' }

Write-Host "$action standalone OpenFL preview: $App"
& haxelib @arguments
exit $LASTEXITCODE
