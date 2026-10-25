# Echoes of the Hollow – Projektregeln

2D-Pixel-Art-Action-RPG, schräge Top-Down-Perspektive. **Godot 4.7.2, ausschließlich GDScript.**
Aktueller Meilenstein: Combat Prototype 0.1 (siehe `docs/DEVELOPMENT_ROADMAP.md`).

## Werkzeuge
- Godot: `../tools/godot/Godot_v4.7.2-stable_win64_console.exe` (oder `$env:GODOT`)
- Startprüfung (Import + Parse + 300 Frames Hauptszene): `./tools/check_project.ps1`
- Tests gezielt: `./tools/run_tests.ps1 -Suite dash,combo` (Suite = `tests/**/test_<name>.gd`)
- Neue `class_name`-Skripte brauchen vorher `--import` (macht `run_tests.ps1` automatisch).

## Feste Regeln
- Combat-Design in `docs/COMBAT_DESIGN.md` ist verbindlich. Nicht stillschweigend ändern –
  Konflikte dort im Abschnitt „Offene Designfragen“ dokumentieren.
- Spieldaten (Angriffe, Waffen, Timings) sind Resources unter `data/`. Keine `match`/`if`-Ketten
  für einzelne Waffen oder Angriffe im Code. Stabile `StringName`-IDs verwenden.
- Komponenten klein halten: Input, Movement, Dash, Combat, Combo, Hitbox/Hurtbox, Visuals getrennt.
  Visuals lesen nur Zustand; Spiellogik hängt nie von Visual-Nodes ab.
- Keine Autoload-Singletons ohne dokumentierten Grund (`docs/ARCHITECTURE.md`).
- Statische Typisierung verwenden.
- Combat-Logik wird über `physics_step()/step()` mit explizitem `delta` getrieben, damit Tests
  deterministisch sind.

## Tests (selektiv, siehe `docs/TEST_STRATEGY.md`)
- Nur Suites des geänderten Systems + direkte Abhängigkeiten ausführen.
- Grüne, unveränderte Suites nicht wiederholen. Volle Suite nur bei Änderungen an mehreren Kernsystemen.
- Nie behaupten, ein Test/Playtest sei gelaufen, wenn er nicht lief. Ergebnisse in `docs/OVERNIGHT_REPORT.md`.

## Git
- Arbeitsbranch `dev/combat-prototype`; kleine Commits pro Meilenstein. Kein Push, kein Force.
