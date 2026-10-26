# Echoes of the Hollow – Projektregeln

2D-Pixel-Art-Action-RPG, schräge Top-Down-Perspektive. **Godot 4.7.2, ausschließlich GDScript.**
Stand: Combat-Prototyp + RPG-Fundament (Overnight 2). Roadmap: `docs/DEVELOPMENT_ROADMAP.md`.

## Werkzeuge
- Godot: `../tools/godot/Godot_v4.7.2-stable_win64_console.exe` (oder `$env:GODOT`)
- Startprüfung (Import + Parse + 300 Frames, Fehler UND Warnungen): `./tools/check_project.ps1`
- Tests gezielt: `./tools/run_tests.ps1 -Suite dash,combo` (Suite = `tests/**/test_<name>.gd`)
- Playtests (Fenster): `-s res://tests/playtest/visual_playtest.gd` (Combat), `rpg_playtest.gd` (RPG)
- Neue `class_name`-Skripte brauchen vorher `--import` (macht `run_tests.ps1` automatisch).

## Feste Regeln
- Combat-Design in `docs/COMBAT_DESIGN.md` ist verbindlich. Timings/Tempo/Balance nicht ohne Playtest
  ändern; Vorschläge dort unter „Vorschläge für den Feel-Test“ sammeln.
- Spieldaten sind Resources unter `data/` mit stabilen `StringName`-IDs. Keine `match`/`if`-Ketten
  für einzelne Waffen, Angriffe, Items oder Klassen.
- Definitionen (Resources) ≠ Laufzeitinstanzen (`Character`, `ItemInstance`, …) ≠ Spielstand (Dict/JSON).
- Combat ↔ RPG nur über `PlayerProgressionBridge`; Items wirken über `AttackModifier`, nie über
  geänderte `AttackDefinition`-Daten oder eigene Schadenslogik.
- Items existieren nur im `Inventory`; Loadouts referenzieren Instanz-IDs (Shared-Item-Policy).
- Stats immer über `StatResolver` neu berechnen, nie inkrementell addieren.
- Einziges Autoload: `GameSession` (hält den Character über Szenenwechsel). Keine weiteren ohne Begründung.
- Signale langlebiger RefCounted-Objekte: Methoden-Callables statt Lambdas mit `self` (sonst Leck).
- Schemaänderung am Save → `SaveSystem.VERSION` + Migration + `save`-Tests (`docs/SAVE_SYSTEM.md`).
- Tests nutzen nie `user://saves/`, nur `user://test_saves/`.

## Tests (selektiv, siehe `docs/TEST_STRATEGY.md`)
- Nur Suites des geänderten Systems + direkte Abhängigkeiten. Grüne, unveränderte Suites nicht wiederholen.
- Nie behaupten, ein Test/Playtest sei gelaufen, wenn er nicht lief. Ergebnisse in den Overnight-Reports.

## Git
- Arbeitsbranch der jeweiligen Sitzung (`dev/rpg-foundation`); kleine Commits pro Phase. Kein Push, kein Force.
