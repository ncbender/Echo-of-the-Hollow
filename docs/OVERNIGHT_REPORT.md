# Overnight Report – Combat Prototype 0.1

**Datum:** 2026-10-26 · **Engine:** Godot 4.7.2.stable.official (ed1daf0bf), GDScript ·
**Testwerkzeug:** eigener Headless-Runner (`tests/run_tests.gd`), kein GdUnit4 ·
**Branch:** `dev/combat-prototype` (lokal, nicht gepusht)

## 1. Zusammenfassung
Ein startbarer, spielbarer Combat-Prototyp existiert: Bewegung, Mausziel, Dash mit 2 Ladungen,
Light-/Heavy-Angriffe mit 3 Charge-Stufen, datengetriebener Combo-Baum für zwei Waffenfamilien,
Input-Buffer, Dash-Cancelling ohne Ghost-Hits, Trainingspuppen mit Leben/Haltung, Trefferfeedback,
Hitstop, Debug-Overlay und ein einfacher Nahkampfgegner mit Telegraph. Alle Phasen A–F sind
abgeschlossen. **74 automatisierte Tests in 11 Suites sind grün.** Skriptierte visuelle Playtests
liefen in einem echten Fenster mit Screenshots. **Ein menschlicher Playtest mit Maus/Tastatur hat
nicht stattgefunden** – das Spielgefühl ist daher noch unbestätigt.

## 2. Abgeschlossene Phasen
| Phase | Commit | Ergebnis |
|---|---|---|
| A – Projekt & Doku | `cbc2abc` | Projekt, Input-Map, Arena, Testrunner (selbst geprüft), Doku-Grundlage |
| B – Bewegung & Dash | `30809d0` | Player-Komponenten, Kamera, Kollision, Dash |
| C – Combat-Kern | `5b1ea5c` | Attack-Daten, Combo-Baum, Charge, Buffer, Phasen, Cancels, Hitbox/Hurtbox |
| D – Spielbarer Schwertkampf | `5e5b5da` | Einhandschwert, Dummies, HP/Poise, Feedback, Hitstop, Overlay, visueller Playtest |
| E – Zweihandschwert | `5e793f7` | zweite Waffenfamilie (nur Daten), Waffenwechsel, Hitstop-Obergrenze |
| F – Erster Gegner | `149cb2d` | Grunt (Verfolgung, Telegraph, Stagger, Tod), Spieler-HP/Respawn, F2-Spawn |
| Doku/Abschluss | letzter Commit auf dem Branch | Input-Test, Architektur, Report |

## 3. Nicht abgeschlossene Phasen
Keine. Bewusst **nicht** begonnen: alles außerhalb von A–F (siehe Abschnitt 10).

## 4. Implementierte Gameplay-Features
- WASD-Bewegung in 8 Richtungen, 180 px/s, volle Geschwindigkeit nach 3 Ticks, kein Diagonal-Bonus.
- Maus-Zielrichtung unabhängig von der Bewegung; Kamera folgt mit leichter Glättung.
- Dash: 2 Ladungen, 300 ms, 180 ms iFrames, 2,5 s sequentielle Regeneration, Richtung aus WASD oder
  rückwärts zur Maus, 120 ms Buffer, kein Dash im Dash.
- Light: 1 Klick = 1 Angriff, 120-ms-Buffer, Chain aus der Recovery, neue Zielrichtung je Schritt.
- Heavy: Halten/Loslassen, Stufen Normal (< 250 ms) / Verstärkt / Voll (≥ 700 ms) mit Schaden-,
  Haltungs-, Reichweiten- und Hitstop-Multiplikatoren; Tap = normaler Heavy; 55 % Bewegung beim Laden;
  Combo-Timer pausiert beim Laden.
- Combos Einhandschwert: L, L→L, L→L→L, L→H (Stich), L→L→H (Crush), H; Mastery-Knoten L→L→L→L
  (Debug F3). Zweihandschwert: analoge, eigene Knoten.
- Cancels: Dash bricht Light (alle Phasen), Charge (immer) und Heavy (Startup/Recovery) ab; im
  Heavy-Active-Fenster wird der Dash gepuffert. Kein Ghost-Hit, kein Doppelauslösen, Combo endet.
- Treffer: Sektor-Hitbox nur im Active-Fenster, max. 1 Treffer pro Ziel und Schwung, Mehrfachziele,
  Team-Filter, Schaden, Haltung/Stagger, Knockback, Hitstop (≤ 0,15 s), Kamera-Shake,
  Schadenszahlen, Trefferblitz.
- Trainingspuppen (3) mit HP-/Haltungsbalken, „BROKEN“-Anzeige, Revive nach 1,5 s.
- Gegner „Grunt“: Verfolgung, 0,45 s Telegraph, Angriff, Cooldown, Knockback, Stagger unterbricht
  Angriff, Tod mit Ausblenden. Spieler: 100 HP, Respawn nach 1,5 s.
- Debug-Overlay: Waffe, HP, Action State + Phase, Combo-Pfad + Fenster/Pause, Charge-Stufe,
  Dash-Ladungen + Regeneration, Hitbox aktiv, Mastery, FPS/Time-Scale. F1 Hitbox-Anzeige.

## 5. Wichtige Architekturentscheidungen (Details: `ARCHITECTURE.md`)
1. Bewegung, Dash und Aktionen sind getrennte Komponenten; Kopplung nur über `can_dash_cancel()` und
   `get_move_multiplier()` – keine kombinatorische State Machine.
2. Alle Angriffe/Combos/Charge-Stufen sind Resources; der Code enthält keine waffenspezifischen Zweige.
   Phase E kam ohne Änderung an der Combat-Logik aus.
3. Combo-Regel 1 ist strukturell erzwungen (ein Folgefeld pro Input) und wird zusätzlich validiert.
4. Hitbox = direkte Shape-Abfrage im Physics-Space → kein Frame-Lag, synchroner Cancel.
5. Gegner verwenden dieselbe `CombatComponent`; Telegraph = Startup-Phase ihrer Angriffsdaten.
6. Komponenten werden mit explizitem `delta` getrieben → deterministische Tests.
7. Keine Autoloads. Erweiterungspunkte: `AttackModifier`, `effect_tags`, `unlock_requirement`,
   Signale `hit_landed` / `attack_*` / `charge_tier_changed`.

## 6. Angelegte Hauptdateien
- **Projekt:** `project.godot`, `CLAUDE.md`, `.gitignore`, `tools/run_tests.ps1`, `tools/check_project.ps1`
- **Szenen:** `scenes/arena/test_arena.tscn`, `scenes/player/player.tscn`,
  `scenes/dummy/training_dummy.tscn`, `scenes/enemies/grunt.tscn`, `scenes/ui/debug_overlay.tscn`
- **Combat:** `scripts/combat/` – `combat_component`, `combo_controller`, `attack_definition`,
  `charge_profile`, `weapon_family`, `attack_hitbox`, `hurtbox`, `hit_data`, `health_component`, `attack_modifier`
- **Player:** `scripts/player/` – `player`, `player_input`, `movement_component`(+config),
  `dash_component`(+config), `player_view`; `scripts/core/` – `input_frame`, `input_buffer`, `debug_view`
- **Gegner/Arena/FX/UI:** `scripts/enemies/*`, `scripts/arena/*`, `scripts/fx/*`, `scripts/ui/debug_overlay.gd`
- **Daten:** `data/weapons/one_handed_sword.tres`, `data/weapons/two_handed_sword.tres`,
  `data/player/movement_config.tres`, `data/player/dash_config.tres`, `data/enemies/grunt_*.tres`
- **Tests:** `tests/run_tests.gd`, `tests/framework/*`, `tests/unit/*` (4 Suites),
  `tests/integration/*` (7 Suites), `tests/playtest/visual_playtest.gd`
- **Doku:** `docs/GAME_VISION.md`, `COMBAT_DESIGN.md`, `ARCHITECTURE.md`, `DEVELOPMENT_ROADMAP.md`,
  `TEST_STRATEGY.md`, `OVERNIGHT_REPORT.md`

## 7. Ausgeführte Tests (tatsächlich gelaufen, chronologisch)
| # | Anlass | Suites | Ergebnis |
|---|---|---|---|
| 1 | Phase A | project | 3/3 ✅ |
| 2 | Runner-Selbstprüfung (temporäre Datei, danach gelöscht) | zzselfcheck | erwartete 2 Fehlschläge erkannt (Laufzeitfehler + Assertion) ✅ |
| 3 | Phase B | movement, dash | 13/13 ✅ |
| 4 | Phase C (player.gd geändert → movement/dash mit) | combat_data, combo, light_attack, heavy_attack, movement, dash | 45/46 ❌ – Validierung übersah Links bei doppelter ID |
| 5 | Fix `weapon_family.gd` | combat_data | 4/4 ✅ |
| 6 | Phase D | hits, combat_data | 5/11 ❌ – View las Player-`@onready` zu früh; 180°-Sektor degeneriert; Hitstop maß Echtzeit |
| 7 | Fixes + Fehlerzähler zählt jetzt Warnungen (Infrastruktur → einmal alles) | alle (10 Suites) | 55/56 ❌ – Hitstop-Test prüfte zu spät |
| 8 | Testkorrektur | hits | 7/7 ✅ |
| 9 | Phase E | weapon_switch, combat_data | 10/10 ✅ |
| 10 | Hitstop-Obergrenze | hits | 7/7 ✅ |
| 11 | Phase F | enemy, hits, combat_data, dash | 27/28 ❌ – Light-Knockback kaum sichtbar |
| 12 | Knockback konfigurierbar + Test auf Heavy | enemy | 8/8 ✅ |
| 13 | player.gd (Kompositionswurzel) geändert → Volllauf | alle (10 Suites) | **70/70 ✅** |
| 14 | neue Suite Geräte-Input | input | **4/4 ✅** |

**Endstand: 74/74 grün.** Startprüfung (`check_project.ps1`: Import + 300 Headless-Frames, Fehler
*und* Warnungen) nach jeder Phase: OK.
Bewusst ausgelassen: Wiederholungen grüner, unveränderter Suites (z. B. `combo`, `light_attack` nach
Phase C bis zum Volllauf #13).

## 8. Tatsächlich ausgeführte Playtests
Alle skriptiert (`tests/playtest/visual_playtest.gd`), **nicht headless**, Vulkan/Forward+ auf der
lokalen AMD RX 9070 XT, Screenshots in `tests/output/` (git-ignoriert):
1. **Einhandschwert:** Annähern → L-L-L → L→H voll geladen → Rückwärts-Dash → L-L-H.
   Erster Lauf deckte einen Fehler **im Playtest-Skript** auf (Flags vor dem Player-Tick gelöscht);
   nach Fix: alle Angriffe, Pfade, Treffer, 2 Haltungsbrüche wie erwartet. Screenshots geprüft:
   Hitbox nur im Active-Fenster, Charge-Ring färbt sich je Stufe, Schadenszahlen, „BROKEN“,
   Dash-Nachbilder mit iFrame-Tönung, Overlay korrekt.
2. **Zweihandschwert** (`--weapon=1`): gleiche Sequenz, eigene Angriffs-IDs, größere Bögen,
   voll geladener Overhead 126 Schaden (führte zur Hitstop-Obergrenze 0,15 s).
3. **Gegner** (`--enemy`): Telegraph sichtbar, Dash-Ausweichen ohne Schaden, Gegner nach 192 Ticks
   besiegt.

**Nicht durchgeführt:** interaktives Spielen mit echter Maus/Tastatur. Kamera-Gefühl, Timing-Feel,
Lesbarkeit in Bewegung und Hitstop-Empfinden sind daher **Annahmen**, keine bestätigten Ergebnisse.

## 9. Offene Fehler und technische Risiken
- **Keine bekannten offenen Fehler** in den getesteten Kernmechaniken.
- Spielgefühl unbestätigt (siehe 8). Werte sind Startwerte in `data/`.
- Hitstop ist global (`Engine.time_scale`): pausiert auch Dash-Timer und Gegner. Für viele
  gleichzeitige Treffer ggf. auf lokalen Hitstop umstellen.
- Zwei Klicks innerhalb desselben 16-ms-Physik-Ticks zählen als einer.
- Spielerkörper kollidiert nicht mit Gegnern → Überlappung möglich.
- Spieler wird von Treffern nicht unterbrochen (Design offen, siehe `COMBAT_DESIGN.md`).
- Visuals sind `_draw()`-Platzhalter; Sprite-Animationen müssen später an Attack-Phasen gekoppelt
  werden (Logik-Timing bleibt maßgeblich).
- `WeaponFamily` enthält zwei reine Darstellungs-Hinweise (`display_color`, `visual_blade_length`).
- Godot erzeugt `.uid`-Dateien; diese sind eingecheckt (empfohlene Praxis ab Godot 4.4).

## 10. Bewusst nicht implementiert
Crafting, Weltsysteme/Maps/Ladeübergänge, Heimatbasis, NPCs, Inventar-UI, Klassen/Talentbäume,
Skills auf Q/E/R/F, defensiver Slot auf Shift (nur gebunden), echte Waffenbeherrschung (nur
Unlock-Mechanik + Debug-Schalter), Items/Uniques (nur `AttackModifier`-Hook), Elite/Boss-KI,
Sound, Sprites/Animationen, Speichern.

## 11. Prototyp starten
```powershell
cd "C:\Users\ncbha\GameDev\Echo of the Hollow"
# Spielen:
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path .
# Oder im Editor öffnen und F5:
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path . -e
# Tests (gezielt / alle):
.\tools\run_tests.ps1 -Suite combo,dash
.\tools\run_tests.ps1
# Startprüfung:
.\tools\check_project.ps1
```
Steuerung: WASD, Maus zielen, LMB Light, RMB halten/loslassen Heavy, Space Dash, 1/2 Waffe,
F1 Hitboxen, F2 Gegner spawnen, F3 Mastery-Knoten, F5 Arena neu laden.

## 12. Empfohlene nächste drei Schritte
1. **Menschlicher Feel-Playtest (30–60 min)** mit Checkliste: Dash-Distanz, Light-Chain-Rhythmus,
   Heavy-Charge-Schwellen, Hitstop, Kamera-Zoom/Glättung. Änderungen nur in `data/`, Ergebnisse in
   `COMBAT_DESIGN.md` festhalten.
2. **Design-Entscheidung Spieler-Trefferreaktion** (Stagger/Hyperarmor/Poise für den Spieler) und
   danach den **defensiven Slot (Shift)** – beides bestimmt, wie Gegner-Encounter funktionieren.
3. **Animations-Pipeline:** Sprite-Animationen, die aus Attack-Phasen normalisiert abgespielt werden
   (`AnimationPlayer` liest Phase + Fortschritt), plus Sound-Hooks über `effect_tags`.
