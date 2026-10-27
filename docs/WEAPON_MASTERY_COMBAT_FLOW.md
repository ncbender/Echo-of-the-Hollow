# Weapon Mastery 1.4 + Combat Flow 1.5 – Umsetzung

Verbindliche Spezifikation: `docs/Design/WEAPON_MASTERY_COMBAT_FLOW_1_4_1_5.md` (vom Nutzer, nicht im Repo
versioniert). Dieses Dokument beschreibt die Umsetzung, die Abweichungen und die offenen Punkte.
Was hier nicht steht, gilt unverändert aus `docs/COMBAT_DESIGN.md`. Dessen Abschnitte zu Light/Heavy/Combo
beschreiben seit diesem Rework das **Legacy-System der Gegner**.

## 1. Audit (Phase 1, Stand Branch-Start auf `3a44182`)

**Schutz:**
- Branch: `dev/combat-weapon-mastery-14-15`.
- Fremd und unangetastet: `project.godot` (uncommittet, Hash `68321b98…`), `docs/Design/` und `docs/tasks/` (untracked).
- Echte Saves und `settings.cfg` werden nach jedem Godot-Lauf per Hash geprüft.
- Tests schreiben nur nach `user://test_saves/`.

| Bereich | Bestand vorher | Entscheidung |
|---|---|---|
| Angriffe | `CombatComponent` für Spieler und Gegner: Phasen, `ComboController` (`next_light/next_heavy`), 120-ms-Buffer, `chain_delay`, Combo-Fenster nach der Recovery, RMB-Charge | **Flow-Modus** im selben Component für Familien mit `combo_paths` (Spieler); Gegner bleiben im Legacy-Modus |
| Familien | Einhandschwert, Zweihandschwert mit L-L-L ab Level 1, L-H, L-L-H, Charge-Heavy | neun Familien neu nach Spezifikation |
| Mastery | `WeaponMastery` je Familie, klassenunabhängig (Save `mastery`); XP pro Treffer und Kill-Bonus an die Familie des letzten Treffers | Level schaltet nur Pfade frei; XP nur beim Kill nach Beitrag |
| Input | Flanken L/H/Dash/Shift/Q-F/1/2, Pegel RMB/Shift, `weapon_slot` (Tasten 1/2 seit Systems 02 ungebunden) | Pegel `light_held` für den Bogen; Schnellwechsel entfernt |
| Equipment | Einhandwaffe auch in der Nebenhand (Dual Wield); Arcanist/Shadowrunner nur Einhandschwert | ein Waffen-Slot; alle Klassen alle Familien |
| Burden | `ArmorMasteryRules` = Spezifikationstabelle, wirkt über `Player.move_speed_multiplier` und `CombatComponent.recovery_multiplier` | wiederverwendet (keine zweite Quelle) |
| Save | Version 10 | **unverändert 10** (siehe §7) |

## 2. Daten

**Familien:**
- `data/weapons/<id>.tres`: `one_handed_sword`, `two_handed_sword` (Greatswords), `axe`, `dagger`, `spear`, `staff`, `wand` (Scepters/Wands), `mace` (Maces/Hammers), `bow`.
- Erzeugt von `tools/generate_weapon_families.gd`, reproduzierbar:

  ```
  Godot --headless --path . -s res://tools/generate_weapon_families.gd
  ```

**Klassen:**
- `ComboPathDefinition`: freischaltbarer vollständiger Pfad (`inputs` „LLH“/„PLLP“, `unlock_level`, englischer `display_name`, Art `PATH` oder `FLOWING_DRAW`).
- `WeaponFamily`:
  - Felder `input_scheme` (MELEE/BOW) und `combo_paths`.
  - Funktionen `node(sequence)`, `allows(sequence, level)`, `flowing_draw_level()` sowie die Validierung aller Pfade, Präfixe und Endknoten-Namen.
- `AttackDefinition`, Gruppe „Combat Flow“:
  - `combo_input`, `flow_role` (Cancel-Kategorie)
  - `windup_move` / `active_move`, `transition_ratio`, `defense_cancel_ratio`, `combo_open_at`, `special_cancel_phases`
  - `lunge_angle`; Treffer-Limits `max_hits_per_target`, `rehit_interval`, `max_targets`
  - Projektil-Daten; `animation_ref` und `placeholder_animation`
- `CombatFlowRules` (`data/combat/combat_flow_rules.tres`): Übergang 75 %, Vorpuffer 180 ms, Start-Puffer 120 ms, Cancel-Anteile 50/65/55/65/75 %, Recovery-Bewegung 50 %, Bogen-Halteschwelle 250 ms, 3 Schüsse, Precision Stance 65 %.

**Knoten pro Familie:**
- Nahkampf: 2 Grundangriffe + 4 Zwischenschritte (LL, LH, HL, HH) + 8 benannte Endknoten = 14 Angriffe.
- Bogen: L, P, LL, LP, PL, PLL, LLP, PLP, LPL, PLLP = 10 Angriffe.
- Insgesamt 64 Nahkampf-Endknoten + 7 Bogen-Pfade + Flowing Draw = **72 freischaltbare Pfade**.
- Bestehende IDs bleiben erhalten:
  - Schwert: `sword_light_1`/`_2`/`_3`, `sword_heavy`, `sword_lh_thrust`, `sword_llh_crush`. Letztere ist jetzt Guard Splitter; `crushing_oath` wirkt weiter darauf.
  - Zweihänder: analog.
  - Etablierte Namen der Zwischenschritte bleiben ebenfalls: Backhand, Lunging Thrust, Return Swing, Overhead Slam.

## 3. Zustandsmaschine (Flow-Modus, `CombatComponent`)

- Zustände: NEUTRAL → WINDUP (Startup) → ACTIVE → RECOVERY → NEUTRAL. Die Kette hält `chain` (Eingaben inkl. laufendem Angriff), `chain_level` (Mastery beim Kettenstart), `buffered` (eine Eingabe) und beim Bogen `flowing_draw`/`flowing_shot`.
- Die Attack-Clock läuft in Sekunden. Bei Hitstop wird der Spieler nicht gestept, die Uhr steht also still.
- Fenster:
  - Annahme ab `max(Windup-Ende + combo_open_at, Übergang − 180 ms)`.
  - Übergang bei Windup + Active + 75 % der Recovery. Die Recovery ist dabei durch Burden verlängert und wird beim Angriffsstart festgehalten.
  - Ende = Ende der Recovery.
- Vor dem Übergang wird gepuffert; danach erfolgt der Übergang sofort. Der Rest-Tick wird in den neuen Angriff übertragen, deshalb ist der Ablauf frameraten-unabhängig (getestet bei 30/60/144 Hz).
- Verworfen werden: zu frühe Eingaben, gesperrte oder unbekannte Fortsetzungen, Eingaben bei vollem Puffer. Nichts davon wird zum Start einer neuen Kette.
- Ein Druck ergibt höchstens einen Schritt. Nach dem Ende der Recovery wird der Puffer geleert; erst eine neue Flanke im neutralen Zustand startet einen neuen Angriff.
- Neutral mit blockierender Aktion (Dash, Skill, Trank): ein Start-Puffer von 120 ms, der erste Druck bleibt.
- Heavy (RMB) startet sofort; es gibt kein Aufladen mehr.
- Puffer und Halte-Zustand werden geleert bei: Abbruch (Dash, Parry/Block, Treffer-Reaktion INTERRUPT+, Tod, Skill, Trank), Waffen- und Klassenwechsel, offenem Fenster oder Pausemenü (`Player.input_blocker`, wird beim Öffnen einmal geleert), Laden (neue Szene).

## 4. Bewegung, Cancel, Burden

**Bewegung:**
- Gehgeschwindigkeit = Basis × Burden/Movement-Speed (`move_speed_multiplier`) × Phasenfaktor × Precision Stance.
- Phasenfaktoren: Windup- und Active-Faktor aus den Daten. In der ersten Hälfte der Recovery gilt der Windup-Faktor, danach steigt er linear auf 100 %. Die Richtung bleibt lenkbar.
- Angriffsrichtung: wird bei jedem Schritt neu von der Maus genommen und während Active nicht nachgedreht (Hitbox fest).

**Cancel-Fenster:**
- Windup und Active sind gebunden.
- Ein Defense-Cancel (Dash, Parry, Block) ist ab diesem Anteil der Recovery möglich: Grund-Quick 50 %, Grund-Heavy 65 %, Combo-Schritt 55 %, Quick-Finisher 65 %, Heavy-Finisher 75 %.
- Ein Dash- oder Shift-Druck davor wird **abgelehnt, nicht gespeichert**: keine Ladung verbraucht, kein Phantom-Cancel. Ein gehaltenes Shift startet später nichts.
- Priorität: Tod/Reaktion > Dash > Parry > Block > Combo > neue Aktion (Reihenfolge in `Player.physics_step`).
- Skills und Tränke starten **nur im neutralen Zustand** (`CombatComponent.allows_other_action`). Pauschale Skill- oder Trank-Cancels gibt es nicht.

**Burden:**
- `ArmorMasteryRules`: Light / Balanced / Burdened / Heavy = 100/98/95/92 % Gehen und ×1,00/1,02/1,05/1,08 Recovery; Iron Discipline (Plate Lv 20) −1 Punkt.
- Wirkt nur auf die Recovery, nie auf Dash (2 Ladungen, 180 ms iFrames, 2,5 s, 110 px) oder Parry.

## 5. Bogen

- Neue LMB-Flanke ohne RMB = Quick Shot (L), mit gehaltenem RMB = Precision Shot (P). RMB allein = Precision Stance (65 % Gehen), kein Angriff.
- Pfeile fliegen erst beim Fire-Event (Beginn Active) als `SkillProjectile`. Eine Momentaufnahme des Schwungs geht mit, damit ein Cancel einen abgeschossenen Pfeil nie zurücknimmt. Ein RMB-Wechsel während eines Schusses löst nichts aus. Standardpfeile sind unbegrenzt.

**Flowing Draw (ab Lv 10):**
- Der kettenstartende LMB-Druck wird ≥ 250 ms gehalten, RMB ist nicht gehalten. Der laufende erste Schuss zählt als Schuss 1.
- Schuss 2 und 3 folgen an ihren Übergängen. Nach Schuss 3 kommt die volle Recovery, auch wenn LMB inzwischen losgelassen wurde. Bleibt LMB gehalten, startet danach der nächste Zyklus.
- Loslassen: keine weiteren Auto-Schüsse; ein bereits laufender Schuss vor Schuss 3 übergibt an manuelle Taps.
- RMB beendet die Folge, ohne automatisch einen P auszulösen.
- Getrennte Taps werden nie als Flowing Draw gewertet.

## 6. Mastery, Equipment, UI

**Mastery:**
- Level → `CombatComponent.mastery_level` (Bridge), `WeaponMastery.path_unlocked` mit der Meldung „Combo unlocked: …“.
- Keine Stat-Boni (getestet: Stats und Angriffsdaten auf Lv 20 identisch).

**XP (`CombatRewardTracker`):**
- Treffer zählen als Beitrag (Waffenschaden je Familie und Ziel). Beim Kill wird `mastery_xp_reward` nach diesem Anteil verteilt, auch wenn ein Skill oder Status tötet.
- Keine XP pro Treffer, keine XP von Trainingszielen.
- Entfernt: die Werte `mastery_xp_per_hit`, `finisher_bonus_xp`, `full_charge_bonus_xp`, `training_xp_*`.

**Equipment:**
- Genau ein Waffen-Slot: `EquipSlot` erlaubt Einhandwaffen nur in der Hauptwaffe.
- Jede Klasse darf jede Familie führen.
- Tasten 1/2 bleiben Hearth Flask und Spezialtrank; `weapon_slot` und der Quick-Swap sind entfernt.
- Sieben schlichte Items für die neuen Familien: Iron Dagger, Iron Axe, Iron Mace, Oak Wand (Einhand); Ash Spear, Oak Staff, Hunting Bow (Zweihand). Sie stehen in keiner Loot-Tabelle und sind nur über das Debug-Itemkit erhältlich.

**UI:**
- Klassenstation, Seite **Weapons** (`UI_PAGE_WEAPONS`): neun Familien mit Level, XP und Pfaden. Galerie-Screen `character_weapons`, geprüft bei 1080p 100/150 %.
- `PlayerView`: Platzhalter für Schüsse und Zauber (Bogen/Fokus, Blitz beim Fire-Event).
- Debug-Overlay: Kette, Puffer, Flowing Draw.
- Steuerungstexte in den Optionen angepasst.

**Effekte:**
- „voll aufgeladen“ (Stone Golem, Stormcaller, Warbreaker-Talente) gilt im Flow-Modus für **Heavy-Finisher** (`HitData.is_full_power`, eine Stelle). Die Spielertexte sind entsprechend angepasst.

## 7. Save

- **Keine Schemaänderung, Version bleibt 10.** Die Mastery war schon pro Familie gespeichert; neue Familien erscheinen beim ersten XP. Angriffszustand, Puffer und gehaltene Tasten werden nie gespeichert (getestet).
- Alte Spielstände mit einer Waffe in der Nebenhand: Die bestehende Ladeprüfung (`CharacterEquipment.from_dict` → `can_equip`) verwirft die Referenz mit einer Warnung, die Waffe bleibt in der Tasche. Presets lassen eine Nebenhandwaffe beim Anwenden weg.
- Eine reine Dict-Migration hätte die Item-Daten gebraucht, um Waffen zu erkennen.

## 8. Platzhalter (funktional, nicht final)

| Bereich | Platzhalter |
|---|---|
| Animationen | alle 122 Angriffe (8 × 14 + 10) nutzen die generischen `PlayerView`-Schwünge (`animation_ref = placeholder.swing/thrust/arcane_strike/bolt/shot`, `placeholder_animation = true`); keine finale Animation |
| Schaden/Haltung | Schwert und Zweihänder behalten ihre Grundwerte (12/8 Quick, 26/30 Heavy bzw. 22/16, 48/50); neue Familien skalieren das Schwert nach Gesamtdauer (gleicher Schaden pro Sekunde); **jeder Knoten hat den Wert seines Eingabetyps, Finisher haben keinen Bonus** |
| Knockback/Hitstop | neue Familien 6 px / 18 px, Heavy-Hitstop 0,06 s |
| Geometrie | Reichweite/Bogen pro Familie (z. B. Dolch 24/90°, Speer 50/30°, Zweihänder 44/130°); Speer-Sweeps 160°; Zauberstab als Arkan-Sektor auf Abstand (40–48 px) |
| Projektile | Zepter/Stab 360–300 px/s, 220–240 px; Bogen Quick 520 px/s, 300 px, Precision 700 px/s, 380 px; Twin Spark / Forked Current 2 Projektile (Schaden geteilt) |
| Bewegung | nur namentlich oder durch die Familie deklariert: Backhand 12, Lunging Thrust 36, Duelist's Advance 24, March of Iron 24, Ravager's Step 20, Shadow Rhythm/Serpent's Dance Seitschritt 28 (±90°), Driving Thrust 32, Advancing Spear 26, Hammer March 22 px; Grundangriffe stehen |
| Multi-Hit | Thousand Cuts 3 Treffer pro Ziel (Abstand Active/3, Schaden geteilt); sonst 1 Treffer pro Ziel und Schwung |
| Zwischennamen | unbenannte Zwischenschritte heißen „Quick Follow-up“ / „Heavy Follow-up“, Grundangriffe neuer Familien „Quick/Heavy Attack“ bzw. „Quick/Heavy Spell“, Bogen „Quick Shot“/„Precision Shot“ |
| Verteidigung | Einhandfamilien (Schwert, Dolch, Axt, Streitkolben, Zepter) nutzen Sword Guard, Zweihandfamilien (Zweihänder, Speer, Stab, Bogen) Heavy Guard |
| Händigkeit | Axt und Streitkolben einhändig, Speer, Stab und Bogen zweihändig |

## 9. Bewusste Abweichungen und offene Punkte

- **Echos und Procs der Stäbe** (Echo Reversal, Crossing Echoes …): bisher nur Sektor-Schläge. Für eine Echo-Mechanik fehlt das Design, Proc-Bounds sind daher nicht betroffen.
- **Mace/Hammer-Druck:** Haltungs- und Guard-Werte fehlen im Design; die Familie unterscheidet sich derzeit nur durch Timing und Geometrie. Garantierte Stuns gibt es nicht.
- **Skill-Cancel-Fenster:** offen (separates Design). Ein Q/E/R/F-Druck während eines Angriffs wirkt nur, wenn er höchstens 120 ms vor dem neutralen Zustand kommt.
- **Erreichbarkeit:** Die Prolog-Prüfungen sind auf Mastery 1 spürbar schwerer (Quick 550 ms statt 380 ms, gebundenes Windup, keine L-L-L-Kette). Der Skript-Bot des Prolog-Playtests weicht deshalb jetzt telegrafierten Angriffen aus.
- **Beschaffung der neuen Waffen:** Loot, Crafting oder Händler sind nicht entschieden.
- **„Voll aufgeladen“ → Heavy-Finisher:** vorläufige Abbildung (eine Funktion); bitte bestätigen oder anders entscheiden.
- **Mastery-Tempo:** Ohne Treffer-XP braucht Lv 5 etwa 25 Grunt-Kills (499 XP). Balancing ist offen; Ziel laut Design ist Lv 5–8 am Ende von Hollowwood.
- **Farmen trivialer Gegner:** ohne Gegnerstufen nicht lösbar; dokumentiert.
