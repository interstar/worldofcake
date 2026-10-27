[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8765,
    [string]$LaylaRoot = 'G:\PRODUCTION\MAIN_PROJECTS\language_oriented\langdev\layla',
    [switch]$BuildOnly,
    [switch]$SkipBuild,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $LaylaRoot 'src/layla/core.cljc'))) {
        throw "Layla source not found at $LaylaRoot. Pass -LaylaRoot with its repository path."
    }
    # The live canonical .cljc source takes precedence over the bundled generator's copy.
    $laylaSource = (Join-Path $LaylaRoot 'src').Replace('\', '/')
    $mavenCache = (Join-Path $env:USERPROFILE '.m2/repository').Replace('\', '/')
    $extraDeps = '{:mvn/local-repo "' + $mavenCache + '" :aliases {:live {:extra-paths ["' + $laylaSource + '"]}}}'
    # Windows PowerShell 5.1 strips embedded quotes in native arguments. Preserve
    # EDN string quotes for clojure.exe; PS7's Standard argument mode does this itself.
    if ($PSVersionTable.PSVersion.Major -lt 7 -or
        (Get-Variable PSNativeCommandArgumentPassing -ErrorAction SilentlyContinue).Value -eq 'Legacy') {
        $extraDeps = $extraDeps.Replace('"', '\"')
    }
    $cacheHome = Join-Path $PSScriptRoot '.cache'
    New-Item -ItemType Directory -Force -Path $cacheHome | Out-Null
    $jvmHome = '-J-Duser.home=' + $cacheHome
    if ($Test) {
        & clojure $jvmHome -Sdeps $extraDeps -M:live:test
        if ($LASTEXITCODE -ne 0) { throw 'Panel editor checks failed.' }
        return
    }
    if (-not $SkipBuild) {
        & clojure $jvmHome -Sdeps $extraDeps -M:live:build
        if ($LASTEXITCODE -ne 0) { throw 'ClojureScript build failed.' }
    }
    if (-not $BuildOnly) {
        & clojure $jvmHome -Sdeps $extraDeps -M:live:serve $Port
        if ($LASTEXITCODE -ne 0) { throw 'Panel editor server failed.' }
    }
} finally { Pop-Location }
