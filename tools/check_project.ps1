# Technical startup check (separate from unit/gameplay tests):
#  1. re-imports the project (parse + import errors),
#  2. boots the main scene headless for a few hundred frames (runtime errors).
param(
    [int]$Frames = 300,
    [string]$Godot = $env:GODOT
)
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $project "..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" }

$importLog = & $Godot --headless --path $project --import 2>&1 | Out-String
$runLog = & $Godot --headless --path $project --fixed-fps 60 --quit-after $Frames 2>&1 | Out-String
$problems = ($importLog + $runLog) -split "`n" | Where-Object { $_ -match "ERROR|SCRIPT ERROR|Parse Error|WARNING: .*res://" }
if ($problems) {
    Write-Output "Startup check found problems:"
    $problems | ForEach-Object { Write-Output "  $_" }
    exit 1
}
Write-Output "Startup check OK (import + $Frames headless frames of main scene)."
exit 0
