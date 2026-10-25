# Runs the headless test suites selectively.
#   ./tools/run_tests.ps1 -Suite dash,combo   # only these suites
#   ./tools/run_tests.ps1                     # everything (use sparingly, see docs/TEST_STRATEGY.md)
param(
    [string]$Suite = "",
    [string]$Godot = $env:GODOT
)
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $project "..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $Godot)) { throw "Godot executable not found. Set `$env:GODOT or pass -Godot." }

& $Godot --headless --path $project --import | Out-Null
$userArgs = @()
if ($Suite) { $userArgs = @("--", "--suite=$Suite") }
& $Godot --headless --path $project --fixed-fps 60 -s res://tests/run_tests.gd @userArgs
exit $LASTEXITCODE
