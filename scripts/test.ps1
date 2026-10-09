$ErrorActionPreference = "Stop"

$luau = Get-Command luau -ErrorAction Stop
Get-ChildItem -Path (Join-Path $PSScriptRoot "..\tests\Unit") -Filter "*.spec.luau" | ForEach-Object {
    & $luau.Source $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Luau unit test failed: $($_.Name)" }
}

$rojo = if ($env:ROJO_BIN) { $env:ROJO_BIN } else { "rojo" }

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$output = Join-Path $projectRoot ".tmp-EmberUI.rbxlx"
try {
    & $rojo build (Join-Path $projectRoot "default.project.json") --output $output
    if ($LASTEXITCODE -ne 0) { throw "Rojo build failed" }
}
finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
