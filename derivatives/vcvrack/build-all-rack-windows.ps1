param(
    [switch]$Clean,
    [switch]$Package,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$rackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modules = @('gbloink', 'timeslider', 'kdiagram', 'tileland', 'zewp')
$goldenpondSource = Join-Path $rackRoot '..\..\..\goldenpond\goldenpond\current\haxe\src\goldenpond'
if (Test-Path -LiteralPath $goldenpondSource) {
    $modules += 'goldenpond'
}
else {
    Write-Warning "Goldenpond source not found at $goldenpondSource; skipping it."
}

foreach ($module in $modules) {
    Write-Host "=== $module ==="
    & (Join-Path $rackRoot 'build-rack-windows.ps1') -Module $module -Clean:$Clean -Package:$Package -Install:$Install
    if ($LASTEXITCODE -ne 0) {
        throw "Rack build failed for $module"
    }
}
