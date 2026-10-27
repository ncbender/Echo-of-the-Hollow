# Weapon Mastery 1.4 + Combat Flow 1.5 – Umsetzung

Verbindliche Spezifikation: `docs/Design/WEAPON_MASTERY_COMBAT_FLOW_1_4_1_5.md` (vom Nutzer, nicht im Repo
versioniert). Dieses Dokument beschreibt die Umsetzung, die Abweichungen und die offenen Punkte.
Combat-Regeln, die hier nicht stehen, gelten unverändert aus `docs/COMBAT_DESIGN.md`.

## 1. Audit (Phase 1, Stand Branch-Start auf `3a44182`)

**Schutz:**
- Branch: `dev/combat-weapon-mastery-14-15`.
- Fremd und unangetastet: `project.godot` (uncommittet, Hash `68321b98…`), `docs/Design/` und `docs/tasks/` (untracked).
- Echte Saves und `settings.cfg` werden nach jedem Godot-Lauf per Hash geprüft.
- Tests schreiben nur nach `user://test_saves/`.

| Bereich | Bestand | Folge für 1.4/1.5 |
|---|---|---|
| Angriffe | `CombatComponent` (Phasen Startup/Active/Recovery, `ComboController` mit `next_light/next_heavy`, 120-ms-Buffer, `chain_delay`, Combo-Fenster *nach* Recovery, RMB-Charge mit `ChargeProfile`) wird von Spieler **und** Gegnern genutzt | Neuer **Flow-Modus** im selben Component für Familien mit `combo_paths`; Gegner (Grunt, Warden, Husks, Wolf) bleiben im bisherigen Modus (unverändert, inkl. getesteter Timings) |
| Waffenfamilien | zwei: `one_handed_sword`, `two_handed_sword` (Greatswords) mit 3er-Light-Kette ab Level 1, L-H/L-L-H, Charge-Heavy | neu aufgebaut nach Spezifikation; sieben weitere Familien |
| Mastery | `WeaponMastery` (Level/XP je Familie, klassenunabhängig, im Save `mastery`), `MasteryTrack` (XP-Kurve, Unlocks per `requirement_id`), XP **pro Treffer** + Kill-Bonus an die Familie des letzten Treffers, Trainingsziele 50 % XP | Unlocks werden aus den Combo-Pfaden abgeleitet; XP nur noch nach Beitrag beim Kill; Trainingsziele geben keine Mastery-XP |
| Input | `InputFrame`/`PlayerInput`: Flanken L/H/Dash/Shift/Q-F/1/2, Pegel RMB/Shift; `weapon_slot` (Tasten 1/2 seit Systems 02 zur Laufzeit ungebunden) | Pegel `light_held` für Bogen; Waffen-Schnellwechsel entfällt komplett |
| Equipment | ein Main-Hand-Slot; Einhandwaffen dürfen in die Nebenhand (Dual Wield bei Basic Adventurer/Warrior); Arcanist/Shadowrunner nur Einhandschwert | genau **ein** Waffen-Slot: keine Waffen mehr in der Nebenhand (Schilde bleiben), alle Klassen alle Familien |
| Burden | `ArmorMasteryRules`-Tabelle = Spezifikation (0–14/15–25/26–37/38+, 0/2/5/8 %, Iron Discipline −7 %), wirkt über `Player.move_speed_multiplier` und `CombatComponent.recovery_multiplier` | wiederverwendet, keine zweite Quelle; Combo-Übergang und Cancel-Fenster rechnen mit der verlängerten Recovery |
| Dash/Parry | 2 Ladungen, 180 ms iFrames, 2,5 s; Parry/Block über `DefenseComponent`, Start nur, wenn ein Dash-Cancel erlaubt wäre | Werte unverändert; im Flow-Modus ist ein Defense-Cancel nur im Recovery-Anteil der Tabelle erlaubt, sonst wird der Druck verworfen |
| Skills/Consumables | Skills und Tränke starten, wenn ein Dash-Cancel erlaubt wäre | im Flow-Modus nur noch im neutralen Zustand (Spezifikation §4: keine pauschalen Skill-/Trank-Cancels) |
| Animationen | keine Sprite-Animationen; `PlayerView` zeichnet Platzhalter-Schwünge aus Reichweite/Bogen/Phasenfortschritt | alle neuen Angriffe nutzen diese Platzhalter (`animation_ref = placeholder.*`) |
| Save | Version 10, Mastery-Dict pro Familie existiert | v11: Waffen aus der Nebenhand nehmen (Ein-Slot-Regel); Mastery-Schema unverändert, kein Angriffszustand im Save |

**Abhängige Systeme, die auf Angriffsdaten schauen:**
- Tags `heavy`/`finisher`: Essenzen, Evolution, Klassenressourcen, Stat-Modifier.
- `crushing_oath` hängt am Angriff `sword_llh_crush`; diese ID bleibt erhalten.
- HUD-Charge-Meter, Debug-Overlay, `PlayerView`.

## 2. Integrationsplan

1. **Daten:**
   - `AttackDefinition` bekommt Flow-Felder:
     - Pfadknoten `combo_input`, Rolle (Cancel-Kategorie)
     - Bewegungsfaktoren Windup/Active, Übergangsanteil
     - Treffer-Limits, Projektil-Daten, Animationsreferenz
   - `ComboPathDefinition` beschreibt einen freischaltbaren Pfad mit Eingabe, Level und englischem Namen.
   - `WeaponFamily.combo_paths` und `input_scheme` (Melee/Bow).
   - `CombatFlowRules` (`data/combat/combat_flow_rules.tres`) hält die Prototypwerte der Spezifikation.
   - Die neun Familien werden reproduzierbar von `tools/generate_weapon_families.gd` erzeugt.
2. **State-Machine:**
   - Flow-Modus in `CombatComponent`: Attack-Clock in Sekunden, die bei Hitstop pausiert.
   - Trie-Prüfung gegen das Mastery-Level beim Angriffsstart; Ein-Slot-Puffer; Übergang bei 75 % Recovery.
   - Gesperrte oder ungültige Eingaben werden verworfen.
3. **Familien:** 9 Familien, 18 Grundangriffe, 64 Nahkampf-Endknoten + 8 Bogen-Unlocks, Validierung.
4. **Bewegung/Cancel:**
   - Phasenfaktoren und Recovery-Interpolation.
   - Defense-Cancel-Fenster je Kategorie; Dash/Parry/Block vor dem Fenster werden abgelehnt, nicht gepuffert.
   - Burden gilt nur auf Recovery; Dash und Parry unverändert.
5. **Bogen:**
   - Precision Stance (RMB, 65 %); P = neue LMB-Flanke bei gehaltenem RMB.
   - Tap-Combos; Flowing Draw ab Lv10 (Hold ≥ 250 ms, drei Schüsse, Pflicht-Recovery).
6. **Mastery/Equipment/UI/Save:**
   - Level → Combo-Gates, XP nach Beitrag, keine Stat-Boni.
   - Ein Waffen-Slot; Mastery-Seite mit den Pfaden; Save v11.
7. **Tests/Doku/Bericht.**
