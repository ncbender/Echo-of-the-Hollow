# Teststrategie

## Werkzeuge
- **Kein GdUnit4** (nicht vorhanden; für v0.1 unnötig). Eigener, leichter Runner:
  `tests/run_tests.gd` + `tests/framework/test_case.gd`.
- Ein `Logger` (`tests/framework/error_counter.gd`) lässt jeden Test fehlschlagen, der Engine- oder
  Skriptfehler erzeugt – Laufzeitfehler können also nicht unbemerkt bleiben.
- Tests laufen headless mit `--fixed-fps 60`; Combat-Logik wird mit explizitem `delta = 1/60`
  getrieben → deterministisch, unabhängig von der Rechnerleistung.

## Ebenen
| Ebene | Ort | Zweck |
|---|---|---|
| Startprüfung | `tools/check_project.ps1` | Import, Parse-Fehler, Hauptszene 300 Frames ohne Laufzeitfehler |
| Unit | `tests/unit/` | reine Logik: Combo-Auflösung, Buffer, Dash-Ladungen, Charge-Stufen, Datenvalidierung |
| Integration / Gameplay | `tests/integration/` | Player-Szene mit skriptierten Eingaben: Bewegung, Kollision, Treffer, Cancels |
| Visueller Playtest | `tests/playtest/visual_playtest.gd` | nicht headless; skriptierte Sequenz in der echten Arena, speichert Screenshots in `tests/output/` |

## Suites (Name = `test_<name>.gd`)
`project`, `combat_data`, `combo`, `dash`, `movement`, `light_attack`, `heavy_attack`, `hits`,
`weapon_switch` (Phase E), `enemy` (Phase F), `input` (Geräte-Eingabe → Flanken).

## Auswahlregeln
1. Vor jedem Lauf feststellen, welche Systeme geändert wurden.
2. Suites des geänderten Systems + direkte Abhängigkeiten ausführen
   (z. B. Änderung an `combat_component.gd` → `light_attack, heavy_attack, combo`, ggf. `dash`).
3. Grüne, unveränderte Suites nicht wiederholen.
4. Volle Suite nur bei Änderungen, die mehrere Kernsysteme betreffen.
5. Fehlschlag → Ursache beheben → betroffene Suite + direkte Nachbarn erneut.
6. Ergebnisse (ausgeführt / bestanden / fehlgeschlagen / ausgelassen) in `OVERNIGHT_REPORT.md`.

## Abhängigkeiten (für die Auswahl)
| Geändert | Mitlaufen |
|---|---|
| `combo_controller.gd`, Waffen-`.tres` | combo, combat_data |
| `combat_component.gd` | light_attack, heavy_attack, combo |
| `attack_hitbox.gd`, `hurtbox.gd`, `health_component.gd` | hits |
| `dash_component.gd` | dash |
| `movement_component.gd` | movement |
| `player.gd` (Kompositionswurzel) | movement, dash + alle Player-basierten Integrations-Suites |
| Gegner | enemy, hits |
| `player_input.gd` | input |
| Testinfrastruktur (`tests/framework/`) | alle (einmalig) |

## Visueller Playtest
```
Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/visual_playtest.gd
  [-- --weapon=1]   # Zweihänder
  [-- --enemy]      # Gegner: Telegraph, Dash-Ausweichen, Kampf bis zum Tod
```
Öffnet ein Fenster, spielt eine feste Eingabesequenz, schreibt Screenshots und ein Event-Log nach
`tests/output/` (git-ignoriert). Prüft Lesbarkeit, nicht das Spielgefühl unter echter Maus/Tastatur.
