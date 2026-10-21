[CmdletBinding()]
param(
    [ValidateSet("all", "interp", "native")]
    [string] $Target = "all"
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Invoke-HaxeInterpreterTests {
    Push-Location $repoRoot
    try {
        & haxe "hxml/tests/test-gbloink-headless.hxml"
        if ($LASTEXITCODE -ne 0) {
            throw "Haxe interpreter tests failed with exit code $LASTEXITCODE"
        }
        & haxe "hxml/tests/test-timeslider-headless.hxml"
        if ($LASTEXITCODE -ne 0) {
            throw "TimeSlider interpreter tests failed with exit code $LASTEXITCODE"
        }
        & haxe "hxml/tests/test-tileland-headless.hxml"
        if ($LASTEXITCODE -ne 0) {
            throw "TileLand interpreter tests failed with exit code $LASTEXITCODE"
        }
        & haxe "hxml/tests/test-kdiagram-headless.hxml"
        if ($LASTEXITCODE -ne 0) { throw "K-Diag interpreter tests failed with exit code $LASTEXITCODE" }
        & haxe "hxml/tests/test-zewp-headless.hxml"
        if ($LASTEXITCODE -ne 0) { throw "Zewp interpreter tests failed with exit code $LASTEXITCODE" }
        & haxe "hxml/tests/test-sequencer-core-status-headless.hxml"
        if ($LASTEXITCODE -ne 0) { throw "SequencerCore status tests failed with exit code $LASTEXITCODE" }

        $goldenpondRoot = if ($env:GOLDENPOND_ROOT) { $env:GOLDENPOND_ROOT } else { Join-Path (Split-Path $repoRoot -Parent) 'goldenpond\goldenpond' }
        $goldenpondSource = Join-Path $goldenpondRoot 'current\haxe\src\goldenpond'
        if (Test-Path -LiteralPath $goldenpondSource) {
            & haxe --interp -cp (Join-Path $repoRoot 'Source') -cp $goldenpondSource --main test.TestGoldenpondScoreCompiler
            if ($LASTEXITCODE -ne 0) { throw "Goldenpond compiler test failed with exit code $LASTEXITCODE" }
        } else {
            Write-Warning "Goldenpond source not found at $goldenpondSource; skipping Goldenpond app/test."
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-HxcppNativeTests {
    $vcvars = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    if (-not (Test-Path -LiteralPath $vcvars)) {
        throw "Visual Studio x64 environment script not found: $vcvars"
    }

    Push-Location $repoRoot
    try {
        & cmd.exe /d /c "build-headless-native.cmd"
        if ($LASTEXITCODE -ne 0) {
            throw "hxcpp native build failed with exit code $LASTEXITCODE"
        }

        $testExe = Join-Path $repoRoot "build\headless-gbloink\TestGbloinkHeadless.exe"
        if (-not (Test-Path -LiteralPath $testExe)) {
            throw "Native test executable was not produced: $testExe"
        }
        & $testExe
        if ($LASTEXITCODE -ne 0) {
            throw "Native Gbloink tests failed with exit code $LASTEXITCODE"
        }
        $timeSliderExe = Join-Path $repoRoot "build\headless-timeslider\TestTimeSliderHeadless.exe"
        if (-not (Test-Path -LiteralPath $timeSliderExe)) {
            throw "Native TimeSlider test executable was not produced: $timeSliderExe"
        }
        & $timeSliderExe
        if ($LASTEXITCODE -ne 0) {
            throw "Native TimeSlider tests failed with exit code $LASTEXITCODE"
        }
        $tileLandExe = Join-Path $repoRoot "build\headless-tileland\TestTileLandHeadless.exe"
        if (-not (Test-Path -LiteralPath $tileLandExe)) {
            throw "Native TileLand test executable was not produced: $tileLandExe"
        }
        & $tileLandExe
        if ($LASTEXITCODE -ne 0) {
            throw "Native TileLand tests failed with exit code $LASTEXITCODE"
        }
        $kdiagExe = Join-Path $repoRoot "build\headless-kdiagram\TestKDiagramHeadless.exe"
        if (-not (Test-Path -LiteralPath $kdiagExe)) { throw "Native K-Diag test executable was not produced: $kdiagExe" }
        & $kdiagExe
        if ($LASTEXITCODE -ne 0) { throw "Native K-Diag tests failed with exit code $LASTEXITCODE" }
        $zewpExe=Join-Path $repoRoot "build\headless-zewp\TestZewpHeadless.exe"
        if(-not(Test-Path -LiteralPath $zewpExe)){throw "Native Zewp executable missing: $zewpExe"}
        & $zewpExe
        if($LASTEXITCODE-ne 0){throw "Native Zewp tests failed: $LASTEXITCODE"}
    }
    finally {
        Pop-Location
    }
}

if ($Target -in @("all", "interp")) {
    Invoke-HaxeInterpreterTests
}
if ($Target -in @("all", "native")) {
    Invoke-HxcppNativeTests
}
