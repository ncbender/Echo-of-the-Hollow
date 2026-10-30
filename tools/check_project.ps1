# Technical startup check (separate from unit/gameplay tests):
#  0. fresh checkout only: one preparatory import that generates the translations project.godot loads
#     at startup (see below),
#  1. re-imports the project (parse + import errors),
#  2. boots the main scene headless for a few hundred frames (runtime errors).
# Fresh Import Reliability 1.0 (docs/FRESH_IMPORT_RELIABILITY_1_0.md).
param(
    [int]$Frames = 300,
    [string]$Godot = $env:GODOT
)
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $project "..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" }

# Engine messages that fail the check. Case-sensitive: Godot writes ERROR / SCRIPT ERROR / WARNING: in
# capitals, while the first scan also prints class names such as "TestErrorCounter" in its progress lines.
function Get-Problems([string]$log) {
    return $log -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -cmatch "ERROR|Parse Error|WARNING:" }
}

function Get-FilePath([string]$resPath) {
    return Join-Path $project $resPath.Substring("res://".Length)
}

# Translations listed in project.godot (internationalization/locale/translations) that are missing on
# disk although a CSV translation import produces them (a *.csv.import names them in dest_files). Only
# a fresh checkout has such files: they are generated and ignored by git (*.translation).
function Get-PendingTranslations {
    $settings = Get-Content (Join-Path $project "project.godot") -Raw
    $listed = [regex]::Match($settings, '(?m)^locale/translations=PackedStringArray\((.*)\)\s*$')
    if (-not $listed.Success) { return @() }
    $generated = @()
    Get-ChildItem -Path $project -Filter "*.csv.import" -Recurse -File |
        Where-Object { $_.FullName -notlike "*\.godot\*" } | ForEach-Object {
            $import = Get-Content $_.FullName -Raw
            if ($import -match '(?m)^importer="csv_translation"') {
                $dest = [regex]::Match($import, '(?m)^dest_files=\[(.*)\]')
                $generated += [regex]::Matches($dest.Groups[1].Value, '"(res://[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
            }
        }
    return [regex]::Matches($listed.Groups[1].Value, '"(res://[^"]+)"') | ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -in $generated -and -not (Test-Path (Get-FilePath $_)) }
}

# 0. Import preparation. The engine loads the listed translations while it starts - before the import
# of that very run creates them - so on a fresh checkout the first import reports each of them as
# missing (two lines per file). This run exists only to generate them: exactly those lines are
# expected here; any other problem, or a translation still missing afterwards, fails the check.
$pending = @(Get-PendingTranslations)
if ($pending.Count -gt 0) {
    $prepareLog = & $Godot --headless --path $project --import 2>&1 | Out-String
    $expected = $pending | ForEach-Object { "ERROR: Cannot open file '$_'."; "ERROR: Failed loading resource: $_." }
    $prepareProblems = @(Get-Problems $prepareLog | Where-Object { $_ -notin $expected })
    $missing = @($pending | Where-Object { -not (Test-Path (Get-FilePath $_)) })
    if ($prepareProblems.Count -gt 0 -or $missing.Count -gt 0) {
        Write-Output "Import preparation failed:"
        $prepareProblems | ForEach-Object { Write-Output "  $_" }
        $missing | ForEach-Object { Write-Output "  not generated: $_" }
        exit 1
    }
    Write-Output "Import preparation: generated $($pending -join ', ')."
}

$importLog = & $Godot --headless --path $project --import 2>&1 | Out-String
$runLog = & $Godot --headless --path $project --fixed-fps 60 --quit-after $Frames 2>&1 | Out-String
$problems = Get-Problems ($importLog + $runLog)
if ($problems) {
    Write-Output "Startup check found problems:"
    $problems | ForEach-Object { Write-Output "  $_" }
    exit 1
}
Write-Output "Startup check OK (import + $Frames headless frames of main scene)."
exit 0
