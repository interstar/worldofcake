[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8765,
    # Source directories placed ahead of the bundled generator JAR (which already
    # provides the Layla parser and the target resolver). Normally none.
    [string[]]$ExtraSource = @(),
    [switch]$BuildOnly,
    [switch]$SkipBuild,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($path in $ExtraSource) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Extra source directory not found: $path" }
    }
    $extraPaths = ($ExtraSource | ForEach-Object { '"' + (Resolve-Path -LiteralPath $_).Path.Replace('\', '/') + '"' }) -join ' '
    $mavenCache = (Join-Path $env:USERPROFILE '.m2/repository').Replace('\', '/')
    $extraDeps = '{:mvn/local-repo "' + $mavenCache + '" :aliases {:live {:extra-paths [' + $extraPaths + ']}}}'
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
