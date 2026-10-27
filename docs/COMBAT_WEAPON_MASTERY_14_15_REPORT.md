# Combat Rework & Weapon Mastery 1.4–1.5 – Abschlussbericht

**Branch:** `dev/combat-weapon-mastery-14-15` (lokal, nicht gepusht), Basis `3a44182` (Overnight Systems 02).

**Spezifikation:**
- Vorgabe: `docs/Design/WEAPON_MASTERY_COMBAT_FLOW_1_4_1_5.md` (untracked, unverändert).
- Umsetzung: `docs/WEAPON_MASTERY_COMBAT_FLOW.md`.

**Schutz:**
- `project.godot`: fremde, uncommittete Änderung, Hash `68321b98…` vor und nach allen Läufen identisch, nie gestaged.
- Echte Saves und `settings.cfg`: nach jedem Godot-Lauf per SHA-256 geprüft, unverändert.
- Tests und Playtests schreiben nur nach `user://test_saves/`.
- Kein Push, keine Force-Operation.
- Der temporäre Vergleichs-Worktree lag im Scratchpad und ist entfernt.

## Commits

| Phase | Commit | Inhalt |
|---|---|---|
| 1 Audit | `c7fe29f` | Bestandsaufnahme und Integrationsplan |
| 2 State-Machine | `7946d7a` | Flow-Modus: Windup/Active/Recovery, Pfad-Bäume, ein Puffer, Übergang bei 75 %, Treffer-Limits, Projektile |
| 3 Familien | `fb0f999` | 9 Familien, 64 Nahkampf-Endknoten und 8 Bogen-Freischaltungen per Generator; Legacy-Fixtures für Gegner-Engine-Tests |
| 4 Bewegung/Cancel | `fd2ba29` | Phasenbewegung, Defense-Cancel-Fenster, Burden nur auf Recovery, UI/Stun leeren Eingaben |
| 5 Bogen | `ecfda69` | Bogentests (Logik seit Phase 2 in der State-Machine) |
| 6 Mastery/Equipment/UI/Save | `40b4ef4`, `8fe17dd` | Pfad-Gates, Kill-XP nach Beitrag, ein Waffen-Slot, kein Quick-Swap, Weapons-Seite, sieben Items |
| 7 Tests/Doku | `47fb1a6` + dieser Bericht | Playtests auf Combat Flow, Dokumentation |

114 Dateien, +6749 / −921 Zeilen (ohne diesen Bericht).

## Umgesetzt

**Zustandsmaschine:**
- NEUTRAL → WINDUP → ACTIVE → RECOVERY auf einer Attack-Clock in Sekunden, die bei Hitstop pausiert.
- Mastery und Burden werden beim Angriffsstart festgehalten.
- Ein gepufferter Input; Annahme ab `max(Windup-Ende, Übergang − 180 ms)`, Übergang bei 75 % der Recovery.
- Gesperrte, zu frühe oder überzählige Eingaben werden verworfen. Ein Druck ergibt höchstens einen Schritt; nach der Recovery wird der Puffer geleert.

**Familien:**
- Einhandschwert, Zweihänder, Axt, Dolch, Speer, Stab, Zepter/Zauberstab, Streitkolben, Bogen.
- Referenz-W/A/R und Bewegungsfaktoren exakt aus der Tabelle, alle Pfadnamen und Level exakt.
- Level 1 hat nur die Grundangriffe; RMB-Heavy startet sofort.

**Cancel:**
- Windup und Active sind gebunden.
- Dash, Parry und Block erst ab 50/65/55/65/75 % der Recovery. Vorher wird der Druck abgelehnt, nicht gespeichert, und kostet keine Ladung.
- Skills und Tränke nur im neutralen Zustand.
- Dash- und Parry-Werte unverändert.

**Burden:** bestehende Armor-Mastery-Tabelle, wirkt nur auf die Recovery; Übergang und Cancel-Fenster rechnen mit der verlängerten Recovery.

**Bogen:**
- Quick Shot (L), Precision Shot (P = LMB bei gehaltenem RMB); RMB allein ist die Precision Stance mit 65 % Gehen.
- Tap-Pfade Lv 2–20.
- Flowing Draw ab Lv 10: Halten ≥ 250 ms, der erste Schuss zählt, drei Schüsse, Pflicht-Recovery, neuer Zyklus nur bei weiterem Halten.

**Mastery:**
- Neun Familien je Charakter über alle Klassen, Level 1–20.
- Level schaltet nur Pfade frei („Combo unlocked: …“), **keine Stat-Boni**.
- XP nur beim Kill, aufgeteilt nach Waffenschaden je Familie (auch bei Skill-Kills); keine Treffer- oder Trainings-XP.

**Equipment:**
- Genau ein Waffen-Slot, kein Dual Wield, jede Klasse jede Familie.
- Quick-Swap entfernt; Tasten 1/2 bleiben Flask und Trank.

**UI:**
- Klassenstation, Seite „Weapons“.
- Platzhalter-Optik für Schüsse und Zauber, Debug-Overlay mit Kette und Puffer.
- Steuerungstexte.

**Save:** Schema unverändert (Version 10). Alte Nebenhandwaffen werden beim Laden verworfen, das Item bleibt; Presets lassen sie weg.

## Tests (alle gezielt, keine volle Suite, keine volle Galerie)

**Abschlusslauf: 395 / 395 grün in 49 von 75 Suite-Dateien.** Davon neu oder umgebaut:

| Suite | Tests | Inhalt |
|---|---|---|
| `combat_flow` | 13 | Gates aller Level, Millisekunden-Fenster, Puffer, 30/60/144 Hz, Cancel-Anteile, Burden, Bewegung |
| `weapon_families` | 3 | Katalog, 72 Pfade, W/A/R aller Familien, **alle 64 Nahkampf-Endknoten real mit Treffern** |
| `combat_flow_player` | 10 | Dash/Parry-Fenster, Werte unter Heavy-Burden, Gehen je Familie und Phase, Wand, Seitschritt, Pivot, Skills, Stun/UI |
| `bow` | 8 | L/P/RMB, alle Tap-Pfade an der Levelgrenze, Flowing Draw, Kollision, Stance, Pfeil nach Cancel |
| `mastery` | 12 | Kurve, Pfad-Freischaltung, keine Stats, Kill-XP nach Beitrag, Klassenwechsel |
| `weapon_switch` | 4 | kein Quick-Swap, Wechsel über Ausrüstung, alle Familien |
| `equipment`, `save`, `input`, `inventory_ui` | angepasst | ein Waffen-Slot, alte Nebenhandwaffe, Tasten 1/2 |
| `item_effects`, `essences`, `evolution` | angepasst | Effekte im Flow-Modus (L-L-H als Heavy-Finisher) |

Legacy-Engine-Suites (Gegner nutzen sie weiter) laufen mit `tests/fixtures/legacy_*.tres`: `combo`, `heavy_attack`, `light_attack`, `lunge`, `combo_reach`, `attack_speed`, `hits`, `dash`, `defense`, `knockback`, `enemy`, `combat_data`.

**Playtests und Prüfungen:**

| Lauf | Ergebnis |
|---|---|
| Startprüfung (Import + 300 Frames) | 0 Fehler, 0 Warnungen |
| `prologue_playtest` | OK (0 Fehler) – nach der Bot-Anpassung, siehe Probleme |
| `class_playtest` | 460 / 460 OK; die 1080p/125-Tooltip-Abweichung aus Systems 02 trat diesmal nicht auf |
| `loop_playtest` | OK (0 Fehler) |
| `crafting_playtest` | 65 / 65 OK (Storm Wolf, Stone Golem, Thunderquake über L-L-H) |
| `rpg_playtest` | 8 Fehler, **identisch auf dem Ausgangscommit** `3a44182` (fehlende Buttons „Activate“/„Equip“ nach dem UI-Redesign, älter). Die geänderten Prüfungen (Mastery-Gates, Shockwave über L-L-H, Load) sind grün |
| `visual_playtest` | Schwert (L-L-L, L-L-H, H-H-H, Dash) und Bogen (`--family=bow`: Precision, Twin Arrow, Flowing Draw) im Arena-Fenster. Übergänge nach ~475 ms (Schwert) und ~505 ms (Bogen), Flowing-Draw-Zyklus nach 600 ms Pflicht-Recovery; Screenshots geprüft |
| UI-Galerie | 1080p 100 % und 150 %: `character_weapons`, `options`, `hud` ohne Überlappung (je 8 Prüfungen OK) |

Nicht gelaufen: `ui_playtest` (nur ein Hinweistext geändert), `stash_playtest`, `feedback_playtest`, volle Suite und volle Galerie.

## Platzhalter (funktional, nicht final – Details in `WEAPON_MASTERY_COMBAT_FLOW.md` §8)

- **Animationen:**
  - Alle 122 Angriffe nutzen die generischen Platzhalter-Schwünge bzw. -Schüsse von `PlayerView` (`placeholder_animation = true`).
  - Kein Angriff ist final animiert.
- **Werte:**
  - Schaden, Haltung, Knockback, Hitstop: kein Finisher-Bonus.
  - Neue Familien haben denselben Schaden pro Sekunde wie das Schwert; Schwert und Zweihänder behalten ihre Grundwerte.
- **Form und Bewegung:**
  - Hitbox-Geometrie, Projektilwerte und Angriffsbewegungen sind nur dort gesetzt, wo Name oder Familie es nahelegen.
  - Verteidigungsprofile werden nach Händigkeit wiederverwendet.
- **Namen:** Zwischenschritte heißen „Quick/Heavy Follow-up“ (etablierte Namen wie Backhand bleiben).

## Bekannte Probleme

- **Prolog schwerer:** Mit Mastery 1 sind die Echo-Prüfungen spürbar schwerer (Quick 550 ms statt 380 ms, gebundenes Windup, keine L-L-L-Kette).
  - Der Skript-Bot des Prolog-Playtests starb als Shadowrunner dreimal.
  - Er drückt jetzt im neutralen Zustand und weicht Telegraphen aus; danach schafft er alle drei Prüfungen.
  - Das ist ein Balancing-Befund und wurde nicht geändert.
- **Skills während eines Angriffs:** Ein Q/E/R/F-Druck mitten im Angriff verfällt, wenn er mehr als 120 ms vor dem neutralen Zustand kommt (keine Skill-Cancels laut Spezifikation).
- **Mastery-Tempo:** Ohne Treffer-XP braucht Lv 5 etwa 25 Grunt-Kills.
- **`rpg_playtest`:** 8 ältere UI-Fehler (s. o.).

## Offene Punkte (brauchen deine Entscheidung)

1. **„Voll aufgeladen“ → Heavy-Finisher:**
   - Betrifft Stone Golem, Stormcaller und drei Warbreaker-Talente (inkl. Worldbreaker).
   - Vorläufige Abbildung in `HitData.is_full_power`; die Texte sind angepasst.
   - Bitte bestätigen oder anders festlegen.
2. **Schaden, Haltung, Guard, Hitbox, Finisher-Werte:** alle offen (Spezifikation §11). Konkret für:
   - Mace/Hammer: Guard- und Poise-Druck.
   - Thousand Cuts: Treffer und Schaden.
   - Stab: Echos.
3. **Beschaffung der sieben neuen Waffen** (Loot, Crafting, Händler); bisher nur das Debug-Itemkit.
4. **Händigkeit und Verteidigungsprofil:**
   - Händigkeit: Axt und Streitkolben 1H, Speer, Stab und Bogen 2H.
   - Verteidigungsprofil des Bogens: Heavy Guard.
5. **Skill-Cancel-Fenster** (separates Design laut Spezifikation).
6. **Mastery-XP-Kurve und Kill-XP:** Balancing auf das Ziel „Lv 5–8 am Ende von Hollowwood“; dazu ein Schutz gegen das Farmen trivialer Gegner (es gibt noch keine Gegnerstufen).
7. **Prolog-Schwierigkeit** auf Mastery 1 (s. o.).
8. **Prototypwerte zum Feel-Test:** Bogen-Halteschwelle 250 ms, Precision Stance 65 %, 180-ms-Vorpuffer, 75-%-Übergang, Cancel-Anteile.
