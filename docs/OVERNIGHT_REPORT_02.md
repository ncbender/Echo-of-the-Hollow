# Overnight Report 02 – Combat Stabilization & RPG Foundation

**Engine:** Godot 4.7.2.stable.official (ed1daf0bf), GDScript · **Branch:** `dev/rpg-foundation`
(abgezweigt von `dev/combat-prototype` @ `16c243d`, lokal, nicht gepusht) · **Tests:** eigener Headless-Runner

## 1. Entwicklungsstand
| Phase | Status | Commit |
|---|---|---|
| 1 Combat-Bugfixes (Kollision, lokaler Hitstop, Trefferreaktionen) | ✅ | `08b8eb1` |
| 2 Waffenbeherrschung | ✅ | `1328f6a` |
| 3 Klassen (Basic Adventurer, Warrior) | ✅ | `d7329d5` |
| 4 Items & Inventar | ✅ | `bcd0e92` |
| 5 Equipment & Klassen-Loadouts | ✅ | `1347d8e` |
| 6 Legendary/Unique/Set | ✅ | `8cc43a2` |
| 7 Save/Load | ✅ | `3b2ed56` |
| Doku-Zwischenstand | ✅ | `f0a0df7` |
| 8/9 (optional) | im Folgeauftrag umgesetzt → `OVERNIGHT_REPORT_03.md` | |

Keine Combat-Timings, Bewegungs-, Dash- oder Combo-Werte geändert (Details `COMBAT_DESIGN.md`,
Abschnitt „Änderungen Overnight 2“).

## 2. Funktionierende Systeme (Kurzfassung; Details in den Systemdokumenten)
- **Combat-Fixes:** Spieler/Gegner durchdringen sich nicht und schieben sich nicht (`BodyContact`),
  Knockback ohne Sprünge/Wanddurchdringung; Hitstop friert nur Angreifer + Ziel ein (Max statt Summe,
  Eingaben werden gepuffert); Trefferreaktionen NONE/FLINCH/INTERRUPT/KNOCKBACK/STUN als Angriffsattribut,
  iFrames verhindern sie, Resistenz/Hyper-Armor vorbereitet; Grunt-Slam (jeder 3. Angriff) = KNOCKBACK.
- **Waffenbeherrschung** (`PROGRESSION_SYSTEM.md`): Level 1–20 je Familie, Daten-Kurven, Technik auf Lv 3
  (je Familie ein gesperrter L-L-L-L-Knoten), Meilensteine, XP mit Exploit-Schutz, HUD.
- **Klassen** (`CLASS_SYSTEM.md`): Registrierung, Freischalten, Klassenstation, getrennte Level/XP, geteilte
  Beherrschung, Klassenwerte, generische Ressourcen (Wut).
- **Items/Inventar** (`ITEM_SYSTEM.md`): Definition/Instanz getrennt, 7 Kategorien, 7 Seltenheiten,
  Slot-Inventar mit Integritätsgarantien, Pickups, Drops, UI (I).
- **Equipment** (`EQUIPMENT_SYSTEM.md`): 15 Slots, Hand-/Ring-/Klassenregeln, Loadout je Klasse mit
  geteilten Referenzen, zentraler Stat-Resolver.
- **Besondere Effekte:** Echo Blade (Legendary, Schockwelle bei Heavy-Finishern), Crushing Oath (Unique,
  modifiziert nur L-L-H), Set „Hollow Warden“ (2/3 Teile) – ein Effekt-Runner, eine Signalverbindung.
- **Save/Load** (`SAVE_SYSTEM.md`): versioniert, Prüfsumme, Temp+Verify+Backup, robuste Reparatur, Migrationen.

## 3. Tests (tatsächlich gelaufen)
| Anlass | Suites | Ergebnis |
|---|---|---|
| Initialprüfung | Startprüfung, project, combat_data | 8/8 ✅ |
| P1 | collision, hit_reaction, hits | 21/24 ❌ (Ratschen-Schieben, Testtiming) |
| P1 Fix 1 | collision, hits | 12/14 ❌ (halbiertes Schieben) |
| P1 Fix 2 (`test_move`) | collision | 5/5 ✅ |
| P1 Abhängigkeiten (player.gd, combat input, enemy) | movement, dash, light/heavy_attack, combo, enemy, weapon_switch, hit_reaction, hits | 74/74 ✅ |
| P2 | mastery | 10/11 ❌ (Testerwartung) → 11/11 ✅ |
| P2 Abh. | combat_data, weapon_switch, project, enemy, hits | 30/30 ✅ |
| P3 | Startprüfung: **Leck 58 Objekte** → Lambda-Zyklus behoben → OK; classes | 10/10 ✅ |
| P3 Abh. | mastery, hits, project, enemy | 31/31 ✅ |
| P4 | inventory, pickup | 14/14 ✅ |
| P4 Abh. | classes, mastery, enemy, project | 32/32 ✅ |
| P5 | equipment | 12/12 ✅ |
| P5 Abh. | classes, mastery, pickup, project, weapon_switch | 32/32 ✅ |
| P6 | item_effects | 7/7 ✅ |
| P6 Abh. | light/heavy_attack, hits, classes, mastery, equipment | 61/61 ✅ |
| P7 | save | 10/10 ✅ |
| P7 Abh. | classes, equipment, project, enemy, pickup | 36/36 ✅ |
| P7 Anti-Duplikations-Fix | pickup, project | 7/7 ✅ |

Kein vollständiger Testlauf in Overnight 2 (die gezielten Läufe deckten jede Änderung ab).

## 4. Playtests (grafisch, skriptiert, echte Input-Events)
- `visual_playtest.gd --enemy` (P1, P2): Kollision, Slam unterbricht L3, HUD.
- `rpg_playtest.gd` (P3–P7, wachsend): Klassenstation, Pickups, Inventar, Ausrüsten (Schild → Zweihänder
  verdrängt Schild), Echo-Schockwelle, F3/F6/F9 Speichern-Laden. Gefundene Fehler: HUD-Überlauf, `%g`-
  Formatfehler in der Itemanzeige, **Item-Duplikation durch Neuladen platzierter Pickups** – alle behoben.
- Kein menschlicher Playtest; Balance und Spielgefühl der neuen Systeme sind unbestätigt.

## 5. Offene Punkte
Siehe Systemdokumente, Abschnitt „Offen“; Feel-Vorschläge in `COMBAT_DESIGN.md`.
