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
`weapon_switch`, `enemy`, `input`; Overnight 2: `collision`, `hit_reaction`, `mastery`, `classes`,
`inventory`, `pickup`, `equipment`, `item_effects`, `save`; Overnight 3: `world`, `base`, `gathering`,
`loop` (End-to-End); Combat Polish 0.2: `knockback`, `lunge`, `combo_reach` (Knockback × Lunge ×
Combo-Fenster gegen echte Grunts). UI Foundation 0.1: `settings` (Persistenz, Skalierung, Kamera-Ausgleich),
`ui_layout` (alle Fenster bei allen UI-Skalierungen im Bild, Scrollen bei 200 %).

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
| `knockback_motion.gd`, Knockback-/Resistenzwerte | knockback, combo_reach, collision, hit_reaction |
| `lunge_distance`, Lunge-Logik in `combat_component.gd` | lunge, combo_reach |
| Dash-Richtung (`player.gd`) | dash (+ visueller Playtest `--polish`) |
| `ui_theme.gd`, `ui_window.gd`, Panels, `game_hud.gd` | ui_layout (+ UI-Playtest) |
| `user_settings.gd`, Display-Einstellungen, Kamera-Zoom | settings, ui_layout (+ UI-Playtest) |
| `world_text.gd` / Welttext-Views | hits, enemy (+ Screenshot-Prüfung) |
| Testinfrastruktur (`tests/framework/`) | alle (einmalig) |
| `character.gd`, `player_progression_bridge.gd` | mastery, classes, equipment, item_effects, save |
| `inventory.gd`, Items | inventory, pickup, equipment, save |
| `character_equipment.gd` | equipment, item_effects, save |
| `save_system.gd` / Schema (`to_dict`) | save (+ Playtest-Schritt Save/Load) |
| `game_map.gd`, Map-Szenen, `session_state.gd` | world, project, enemy, pickup (+ loop bei Loop-relevanten Änderungen) |
| `base_builder.gd`, Gebäude-/Platzdaten | base |
| `resource_gathering.gd`, Ressourcenknoten | gathering, loop |

**Pflicht:** Änderungen am Persistenzschema → `save`; Änderungen an Ausrüstung → `equipment` (Stats,
Loadout- und Inventar-Invarianten).

## RPG-Playtest
```
Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/rpg_playtest.gd
```
Skriptierter Integrationsablauf mit echten Input-Events und UI-Buttons: Klassenstation → Pickups →
Inventar/Ausrüstung → Legendary-Effekt → F3 Mastery → F6 Speichern → Zustand ändern → F9 Laden →
Vergleich. Nutzt `user://test_saves/rpg_playtest.save.json`. Exit-Code 1 bei fehlgeschlagenem Check.

## Loop-Playtest (Overnight 3)
```
Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/loop_playtest.gd [-- --tour | --build-only]
```
Ohne Argument: kompletter Gameplay-Loop (Basis → Wald → Kampf → Sammeln (G) → zurück → Bauen (UI) →
F6 → F9 → Vergleich). Nutzt `user://test_saves/loop_playtest.save.json`.

## Visueller Playtest
```
Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/visual_playtest.gd
  [-- --weapon=1]   # Zweihänder
  [-- --enemy]      # Gegner: Telegraph, Dash-Ausweichen, Kampf bis zum Tod
  [-- --polish]     # Combat Polish 0.2: Lunge-/Knockback-Vektoren, gemessene Distanzen, Dash zur Maus
```
Öffnet ein Fenster, spielt eine feste Eingabesequenz, schreibt Screenshots und ein Event-Log nach
`tests/output/` (git-ignoriert). Prüft Lesbarkeit, nicht das Spielgefühl unter echter Maus/Tastatur.

## UI-/Display-Playtest (UI Foundation 0.1)
```
Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/playtest/ui_playtest.gd [-- --quick]
```
Kein `--fixed-fps` nötig. Durchläuft 1280×720, 1920×1080, 2560×1440 und 3840×2160 (randloses Fenster
auf dem Primärmonitor) mit Basis-HUD, Inventar, Item-Tooltips (echter Cursor-Hover), Klassen-, Bau-
und Options-Fenster und Arena-Kampf. Ohne `--quick` zusätzlich alle UI-Skalierungen auf 720p/4K, F11
Vollbild ↔ Fenster und Reset. Prüft automatisch:
- Controls im Bild
- Fensterrand
- keine Unterschreitung der Mindestgröße
- sichtbare Welt = 512 Px

Screenshots und Log liegen in `tests/output/ui/`. **Bewegt den echten Mauszeiger und belegt kurz den
Bildschirm.**
