# Combat Polish 0.2 – Knockback · Attack Lunge · Dash-Richtung · Feedback

**Engine:** Godot 4.7.2 · **Branch:** `dev/rpg-foundation` (lokal, nicht gepusht)
Combat-Timings (Phasen, Combo-Fenster, Chain-Delays), Dash-Werte (Ladungen, Dauer, Distanz, iFrames,
Regeneration), Bewegungstempo, Hitstop und Animationen sind **unverändert**.

## 1. Veränderte Mechaniken
1. **Dash-Richtung = Blickrichtung (Maus)**, WASD wird ignoriert. Ersetzt die alte Regel „WASD, ohne
   Eingabe rückwärts zur Maus“ vollständig.
2. **Knockback ist eine Distanz in px** mit einem gemeinsamen Modell (`KnockbackMotion`) für Spieler und
   Gegner; waffenabhängige Werte pro Angriff; exakte Distanz.
3. **Gegnerresistenz** datengetrieben (−1…1) mit Stufen klein/Standard/schwer/Elite/Boss; der Test-Boss
   Grove Warden erhält Boss-Resistenz (kein Positions-Knockback, Haltung wirkt voll).
4. **Attack Lunge:** existierte bereits (`lunge_distance`). Korrigiert: Er konnte bis zu einen Tick über
   seine Distanz hinauslaufen (z. B. 6,25 statt 6 px). Jetzt ist die Strecke exakt begrenzt.
5. **Gegner pausieren eigene Schritte während des Rückstoßes** (vorher lief der Grunt gegen den Stoß an
   und hob ihn teilweise auf).
6. **Debug (F1):** Lunge- (grün) und Knockback-Vektoren (rot), Overlay-Zeilen „Lunge“ und „Knockbk“.
7. Kosmetischer Trefferversatz (`HitReactionFx`) auf die neue Einheit umgerechnet.

## 2. Betroffene Dateien
| Bereich | Dateien |
|---|---|
| Neu | `scripts/combat/knockback_motion.gd`, `data/enemies/grove_warden_config.tres` |
| Combat | `attack_definition.gd` (Doku/Standardwert), `combat_component.gd` (`take_lunge_velocity`, Lunge-Budget) |
| Spieler | `player.gd` (Dash-Richtung, KnockbackMotion), `player_input.gd` (`AIM_DEADZONE` 4 px), `player_view.gd` (Debug-Vektoren) |
| Gegner | `enemy.gd` (KnockbackMotion, KI-Pause beim Rückstoß), `enemy_config.gd` (Resistenz −1…1, `knockback_scale` entfernt, `knockback_taken()`), `enemy_view.gd` |
| Daten | `one_handed_sword.tres`, `two_handed_sword.tres`, `grunt_attacks.tres`, `grunt_config.tres`, `whisper_forest.tscn` (Warden-Config) |
| Feedback/Debug | `hit_reaction_fx.gd`, `debug_view.gd`, `debug_overlay.gd`, `debug_overlay.tscn` (Hilfetext) |
| Items | `echo_shockwave_effect.gd` (`knockback_distance` 5 px statt fester Stärke 40) |
| Tests | neu: `test_knockback.gd`, `test_lunge.gd`, `test_combo_reach.gd`; geändert: `test_dash.gd`, `test_hit_reaction.gd`, `visual_playtest.gd` |
| Doku | `COMBAT_DESIGN.md`, `ARCHITECTURE.md`, `TEST_STRATEGY.md`, dieser Bericht |

`project.godot` hatte vor Beginn bereits lokale, nicht von mir stammende Änderungen (Editor-Neuspeicherung).
Ich habe sie nicht angefasst und nicht committet.

## 3. Knockback vorher → nachher
**Vorher:** `AttackDefinition.knockback` war eine Stärke. Gegner: Startgeschwindigkeit =
`knockback × (1 − 0,2) × knockback_scale 3`, Abbau 1000 px/s². Die Distanz ergab sich nur indirekt
(Schwert-Light ≈ 2,6 px, Schwert-Heavy ≈ 18 px, Zweihand-Heavy ≈ 56 px). Der Grunt lief währenddessen
weiter auf den Spieler zu und verkürzte den Stoß. Spieler: Startgeschwindigkeit `knockback` (× 1,8 bei
KNOCKBACK-Reaktion), Abbau 900 px/s². Die Hand-Integration stand doppelt im Code (Player und Enemy).

**Nachher:** `knockback` = Distanz in px gegen ein Standardziel. Der Empfänger skaliert genau einmal
(Gegner × `1 − Resistenz`, Spieler × Reaktions-Multiplikator) und übergibt an `KnockbackMotion`. Die
Distanz wird mit konstanter Verzögerung über `move_and_slide` zurückgelegt. Wände und Körper stoppen sie,
der Rest verfällt, es gibt keinen Teleport und keine gespeicherte Energie. Treffer addieren Distanzen,
nicht Geschwindigkeiten. Der Haltungsschaden bleibt unabhängig.

| Waffe (px) | L1 | L2 | L3 | L4 Mastery | Heavy | L-H | L-L-H |
|---|---|---|---|---|---|---|---|
| Einhandschwert | 6 | 6 | 10 | 22 | 18 | 14 | 30 |
| Zweihandschwert | 12 | 12 | 18 | 30 | 35 | 28 | 45 |

Die Grunt-Angriffe gegen den Spieler sind so umgerechnet, dass der Rückstoß gleich bleibt: Wischer 3,5 px
(vorher ≈ 3,3), Slam 13 px × 1,8 = 23,4 px (vorher ≈ 23,4). Der Grunt hat jetzt Resistenz 0 (Standard,
vorher 0,2 als Teil der alten Formel), der Grove Warden 1,0 (Boss).
Nur die zwei vorhandenen Waffenfamilien wurden belegt, neue Waffenarten gibt es nicht.

## 4. Lunge-Werte
Unverändert aus dem bestätigten Playtest-Stand (in den Daten bereits vorhanden):

| Waffe (px) | L1 | L2 | L3 | L4 | Heavy | L-H | L-L-H |
|---|---|---|---|---|---|---|---|
| Einhandschwert | 6 | 12 | 14 | 22 | 8 | 36 (Stoß) | 10 |
| Zweihandschwert | 8 | 12 | 16 | 20 | 10 | 20 | 24 |

Die Light-Werte liegen im vorgeschlagenen Bereich (5–10 / 8–15). Ausreißer sind bewusst so belassen:
L2 des Schwerts mit 12 px, der Stoß L-H mit 36 px und die Finisher mit 20–24 px. Sie wurden nicht
gesenkt, weil der Playtest das aktuelle Gefühl bestätigt hat. Kandidaten für den nächsten Playtest.
Zusammenspiel: Der Light-Knockback (6/12) ist kleiner als der Lunge des Folgeangriffs plus Reichweite.
Getestet: L-L-L, L-L-H und L-H treffen im Stand (ohne WASD) einen Standard-Grunt mit jedem Schlag, mit
beiden Waffen.

## 5. Dash-Richtung – Implementierung
`Player._start_dash()` ruft `dash.try_start(aim_direction)` auf. `aim_direction` ist die zuletzt
gültige, normalisierte Mausrichtung. `PlayerInput` liefert keine Zielrichtung, wenn der Cursor näher
als 4 px an der Figur liegt; dann bleibt die vorherige Blickrichtung erhalten. `DashComponent` speichert
die Richtung beim Start und ändert sie bis zum Ende nicht. Ladungen, Dauer, Distanz, iFrames,
Regeneration, Dash-Buffer und Cancel-Regeln sind unverändert.

## 6./7. Ausgeführte Tests (chronologisch, alle tatsächlich gelaufen)
| # | Anlass | Suites | Ergebnis |
|---|---|---|---|
| 1 | nach Code-Umstellung | Startprüfung (Import + 300 Frames) | OK |
| 2 | neue/geänderte Suites | dash (16), knockback (13), lunge (8) | 34/37 ❌ – 3 Lunge-Tests: **echter Fehler**, Lunge 1 Tick zu lang (6,25 statt 6 px) → Lunge-Budget eingebaut |
| 3 | nach Fix | lunge, knockback | 21/21 ✅ |
| 4 | Integration Knockback × Lunge × Combo | combo_reach (neu) | 10/11 ❌ – Testfehler (Zugriff auf despawnten Grunt) → `defeated`-Signal → 11/11 ✅ |
| 5 | direkt betroffene bestehende Suites (Kernkomponenten `player.gd`, `enemy.gd`, `combat_component.gd`, Angriffsdaten) | collision, enemy, hit_reaction, hits, light_attack, heavy_attack, combo, movement, weapon_switch, combat_data, input, item_effects | 86/87 ❌ – `hit_reaction`: Testdaten in alter Einheit (−60 = jetzt 60 px) → auf −3 px umgerechnet → hit_reaction 10/10 ✅ |
| 6 | Forest-Szene/Grunt-Config, Hauptszene | world, loop (E2E), project | 11/11 ✅ |
| 7 | Abschluss | Startprüfung | OK |

Erfolgreich am Ende: alle oben genannten Suites (dash 16, knockback 13, lunge 8, combo_reach 11, plus 12
bestehende Combat-Suites und world/loop/project). **Nicht ausgeführt:** mastery, classes, inventory,
pickup, equipment, save, base, gathering. Ihr Code und ihre Daten sind nicht betroffen (keine Schema-,
Item- oder Klassenänderung). Kein vollständiger Testlauf. Weil gemeinsame Kernkomponenten geändert
wurden, liefen aber alle Player- und Gegner-basierten Combat-Suites (siehe Zeile 5).

Abdeckung der geforderten Fälle: Dash 1–8 einzeln (`test_dash`), dazu Wand-Kollision, Ladungen und
Regeneration (bestehende Tests grün). Knockback: Profile, Resistenzen, Light/Heavy, Einmaligkeit, Wände,
kein Schieben anderer Gegner, KI hebt Stoß nicht auf, Reaktions-Multiplikator nur einmal. Lunge:
Richtung, konfigurierbare Distanz, 0 = stationär, Richtung fix bei Mausdrehung, keine Bewegung nach dem
Ende, Stun-Cancel, Dash-Cancel, Wände. Integration: L-L-L, L-L-H, L-H (beide Waffen), aufgeladener Heavy
(Aufladung multipliziert Knockback nicht), Dash-Cancel + neue Combo, Waffenwechsel, zwei Gegner pro
Schwung, Kampf gegen aktiven Grunt.

## 8. Visuelle Playtests (Fenster, skriptiert, `tests/output/`, git-ignoriert)
1. **`visual_playtest.gd -- --polish` (neu):** Arena, F1-Debug an. Gemessen gegen einen Standard-Grunt:
   Schwert-Light 6,00 px, Schwert-L3 10,00 angewendet / 9,84 zurückgelegt (Kontakt mit Dummy in der
   Nähe), Schwert-Heavy 18,00, Zweihand-Light 12,00, Zweihand-Heavy 35,00. Dash mit WASD links und Maus
   rechts ging nach (1, 0). Anschließend Kampf gegen den aktiven Grunt: besiegt. Screenshots zeigen
   grünen Lunge- und roten Knockback-Pfeil; der Rückstoß beginnt sichtbar erst nach dem lokalen Hitstop.
   Erster Lauf brach ab, weil der Test-Grunt vor Sequenzende starb (Skriptfehler) → HP für die
   Messphase erhöht.
2. **Standardsequenz (Schwert):** L-L-L, L-H, Ausweich-Dash (jetzt per Blickrichtung weg vom Dummy:
   (−0,996, 0,087)), L-L-H mit Poise-Break → unverändert ✅.
3. **`--enemy`:** erster Lauf: Dash ging zum Gegner statt weg. Ursache war Skript-Timing, das die
   Zielrichtung vor dem Spieler-Tick überschrieb; mit der alten WASD-Regel fiel das nicht auf. Korrigiert
   → Dash (−1, 0) bei WASD rechts, Gegner besiegt ✅.

Ein **menschlicher** Playtest hat nicht stattgefunden.

## 9. Bekannte Probleme & Risiken
- **Schwung nach dem Dash:** Nach Dash-Ende läuft die Figur mit voller Geschwindigkeit in Dash-Richtung
  weiter und dreht dann zur WASD-Richtung (bestehendes Verhalten). Bei Dash ≠ WASD kann das
  ungewohnt wirken.
- **4-px-Totzone** für die Zielrichtung gilt auch für Angriffe (vorher 1 px). Praktisch kaum spürbar.
- **Gegner stehen während des Rückstoßes still** (keine eigenen Schritte). Das macht die Distanz exakt,
  Grunts wirken dadurch nach starken Treffern aber etwas länger „getroffen“.
- Rückstoß gegen Wände verfällt (gewollt, keine Wand-Abpraller oder Wand-Schaden).
- Kosmetischer Treffer-Versatz: Für Schwert-Light-Treffer sieht er aus wie vorher. Der Grunt-Wischer am
  Spieler wirkt optisch etwas schwächer (≈2,7 statt ≈4,8 px Versatz, reine Darstellung).
- Grove Warden ist weiterhin ein skalierter Grunt. Nur seine Knockback-Resistenz ist boss-typisch.
- Kleine, schwere und Elite-Gegner existieren noch nicht. Ihre Stufen sind nur per Test mit Konfig-Kopien
  geprüft.
- Lunge-Ausreißer (Stoß 36 px, Finisher 20–24 px) wurden bewusst nicht verändert.

## 10. Für den nächsten menschlichen Playtest
1. **Dash zur Maus:** Ausweichen nach hinten erfordert jetzt, die Maus wegzudrehen. Fühlt sich das in
   Gegnergruppen gut an? Schwung nach dem Dash prüfen.
2. **Light-Knockback** 6 px (Schwert) / 12 px (Zweihänder): sichtbar genug, aber Combo bleibt im Ziel?
3. **Heavy/Finisher:** 18/35 px und L-L-H 30/45 px: genug „Wucht“, ohne dass Gegner zu weit fliegen?
4. **Rückstoßtempo** (`knockback_decay` 1000 Gegner / 900 Spieler): zu langsam oder zu ruckartig?
5. **Lunge:** Schwert-Stoß 36 px und Finisher 20–24 px; kleben Combos am Gegner oder rutscht man vorbei?
6. **Grunt-Slam** gegen den Spieler: unverändert ≈23 px, nur zur Bestätigung.
7. **Grove Warden** ohne Positions-Knockback: wirkt er dadurch „schwer“ oder nur unbeeindruckt?
8. F1-Debug-Vektoren und Overlay-Zeilen: lesbar und hilfreich?

```powershell
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path .     # Basis → Nord-Durchgang = Arena; oder test_arena.tscn im Editor mit F6
.\tools\run_tests.ps1 -Suite "dash,knockback,lunge,combo_reach"
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/visual_playtest.gd -- --polish
```
