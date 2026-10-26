# Class Foundation 0.2 – Abschlussbericht

Branch `dev/class-foundation` (von `dev/crafting-foundation`, HEAD `017a6f0`). Nur lokale Commits,
kein Push. Godot 4.7.2, GDScript.

Legende: ✅ vollständig · 🟡 teilweise · 🔧 nur vorbereitet

## Status der Phasen
| Phase | Inhalt | Status |
|---|---|---|
| A | Attack Speed, Bleeding, Chill, gemeinsame Effekt-Integration | ✅ |
| B | Talent-Engine (3 Bäume × 7 Tiers), Respec, Skills Q/E/R/F, Form-/Resonance-Mods | ✅ |
| C | Warrior: Rage + Combat Pressure, 7 Skills, 10 Mods, 3 Bäume, 3 Endtalente | ✅ |
| D | Arcanist: Mana + Arcane Marks, 7 Skills, 9 Mods, 3 Bäume, 3 Endtalente | ✅ |
| E | Shadowrunner: Focus + Weak Points, 7 Skills, 6 Mods, 3 Bäume, 3 Endtalente | ✅ |
| F | Prolog (Trials, eine dauerhafte Wahl), Klassenquests, Save v4 | ✅ (kurze Testsequenz, keine Story) |
| G | Presets, Klassen-/Talent-UI, Englisch + Lokalisierungs-Keys, visuelle Tests, Migration | ✅ |
| – | Guardian, Soulbinder | 🔧 Klassen-, Ressourcen- und Questdaten vorbereitet, nicht spielbar |

## Spielbare Klassen
**Warrior, Arcanist und Shadowrunner** sind vollständig spielbar: Skills, Talente, Ressource, Mods,
Presets und Save/Load. Der Basic Adventurer bleibt die Startklasse. Guardian und Soulbinder
erscheinen in der Klassenliste als „coming later“.

## Implementierte Skills (21)
| Warrior (Rage) | Arcanist (Mana) | Shadowrunner (Focus) |
|---|---|---|
| Furious Strike (Lv 1) | Arcane Bolt (Lv 1, Mark) | Shadow Strike (Lv 1, Bewegung + Weak Point) |
| Battle Cry (Lv 3, Buff + Rage) | Mana Pulse (Lv 3, detoniert Marks) | Expose Weakness (Lv 3, Weak Point + Focus) |
| Blade Rush (Lv 5, Ansturm) | Frostbind (Lv 5, Chill, +40 % gegen Chill) | Shadowstep (Lv 5, kein Dash, +15 % Krit) |
| Warbreaker (Lv 8, Haltungsbrecher) | Rune Sigil (Lv 8, Zone, verstärkt nächsten Zauber) | Execution (Lv 8, verbraucht Weak Point) |
| Whirlwind (Talent) | Arcane Rift (Talent) | Blade Fan (Talent) |
| Blood Frenzy (Talent) | Astral Lance (Talent, durchschlagend) | Smoke Veil (Talent, Kontrolle) |
| Unbound Fury (Endtalent) | Astral Ascension (Endtalent) | Death Mark (Endtalent) |

## Talente und Endtalente
9 Bäume mit je 13 Knoten (117 Knoten). Jeder Knoten hat einen echten, testbaren Effekt: Stats pro
Rang, bedingte Treffer-Boni, Auslöser, Skill-Freischaltung oder Transformation.
| Baum | Endtalent | Art |
|---|---|---|
| Berserker | Unbound Fury | aktiv: 10 s Angriffstempo +25 %, Schaden +20 %, Life on Hit, keine Rage-Abnahme |
| Warbreaker | Worldbreaker | transformativ: voll aufgeladene Heavy-Finisher +30 % Haltung und Beben (56 px, 60 %) |
| Bloodblade | Blood Oath | Blutung heilt 30 %; Finisher zerreißen ≥ 3 Stacks (8 je Stack) |
| Elemental Weaver | Winter's Grasp | +40 % gegen 3 Chill-Stacks; Skills zerschmettern den Chill |
| Runemaster | Glyph Cascade | Rune Sigil +20 % Fläche und zweites Siegel |
| Astral Scholar | Astral Ascension | aktiv: Skills −40 % Kosten, +25 % Schaden, −20 % Cooldown |
| Assassin | Death Mark | aktiv: Markierung; +60 % gegen markierte Ziele; Kill → −4 s Cooldowns, +30 Focus |
| Bladestorm | Thousand Cuts | Light-Finisher erzeugen einen Klingenring (50 %, Blutung) |
| Night Hunter | Nightfall | Smoke Veil +40 %; 3 s nach Shadowstep +25 % Schaden und Weak Points |

Für die Punkteschwellen 0/5/…/30 zählen nur Punkte in niedrigeren Tiers desselben Baums. Ab Level 10
gibt es einen Punkt pro Level, insgesamt 51. Mit 51 Punkten ist höchstens ein Endtalent möglich
(getestet).

## Klassenressourcen
| | Rage | Mana | Focus |
|---|---|---|---|
| Verhalten | zerfällt nach 3 s | regeneriert 8/s | zerfällt nach 4 s |
| Aufbau | Treffer, Finisher, Heavies, Haltungsbruch, Kills, Getroffenwerden; Combat Pressure bis +50 % | Treffer (+3), Kills | Treffer, Finisher, Weak-Point-Treffer, Krits, Kills |

Details: `CLASS_DESIGN.md`.

## Statusmechaniken
- **Bleeding:** echter Schaden über Zeit. 5 Stacks, jede Anwendung erneuert die Dauer, der Schaden
  wird dem Spieler zugeordnet, Kills geben Klassen-XP.
- **Chill:** echte Verlangsamung der Fortbewegung. 3 Stacks, maximal 45 %, beim Boss maximal 25 %.
  Keine globale Zeitänderung, kein Einfluss auf Dash oder Spieler.
- **Resistenzen und Immunität** sind pro Gegner datengetrieben.
- **Marken:** Arcane Mark, Weak Point, Death Mark. Dazu Smoked (Verlangsamung).
- **Attack Speed** verändert jetzt die Timings, begrenzt auf 0,75–1,4 und mit Lunge-Distanz exakt.
  Heavy-Charge und Dash bleiben unverändert.
- **Gemeinsamer Trefferstrom:** `ItemEffectRunner.dispatch_hit` mit Quelle (direkt, Skill, ausgelöst,
  Status), Kettentiefe ≤ 1 und Status-Snapshot. Waffenhits, Finisher, aufgeladene Heavies,
  Haltungsbruch, Skill-Treffer, Essenzen, Status und Kills sind dieselben Ereignisse für Items,
  Talente, Trials und Quests.

## Skill-Modifikationen
25 Mods, je zwei Plätze pro Skill (Form und Resonance), jeweils datengetrieben geprüft.
- **Transformation:** Piercing Lunge ersetzt Furious Strike durch einen Ausfallschritt.
- **Inkompatible Paare:** Split Bolt ↔ Double Mark, Piercing Lunge ↔ Rage Refund.
- **Freischaltung:** über Klassenlevel oder Talent (Glyph Lore, Concussive Rush). Quest-, Boss- und
  Erkundungsquellen sind über `ClassBuild.unlocked_mods` vorbereitet 🔧.
- **Talent-Transformationen** (z. B. Furious Cleave, Ice Lance, Phantom Step) wirken immer, ohne Slot.

## Prolog-Freischaltregeln
Der Spieler startet als Basic Adventurer. Das Tor „Prologue“ in der Heimatbasis führt zu den Prologue
Grounds mit drei Trials, je einer pro Klasse auf Level 12.

**Trials sind temporär:**
- keine Freischaltung, keine Punkte, keine Items, kein Save-Eintrag
- abbrechbar und erneut betretbar
- das Verlassen der Map bricht die Trial ab
- Speichern während einer Trial speichert den Zustand davor

**Die Wahl:** Erst nach allen drei Trials wählt man am Altar genau eine Klasse; das geht nie ein
zweites Mal. Die beiden anderen bleiben gesperrt. Ihre Klassenquests („Path of …“: 8 Kills sowie
3 Hollow Essence und 20 Gold) schalten sie später frei. Guardian und Soulbinder haben vorbereitete,
noch nicht verfügbare Quests.

## Build-Presets
Fünf Plätze pro Klasse. Ein Preset enthält Talente, Skills, Mods, Equipment-Referenzen und eine freie
Zusatzkonfiguration.
- **Kostenlos:** Speichern, Umbenennen, Löschen, Ausrüstung, Skills und Mods an der Station.
- **Respec-Kosten:** nur bei abweichender Talentverteilung.
- **Validierung vor dem Aktivieren:** Klasse, Talente, Skills, Mods, Items und Gold. Fehlende Items
  werden gemeldet, nie erzeugt.

## Save-Version und Migration
- **Version 4.** Neue Schlüssel: `class_builds`, `prologue`, `quests`.
- **Migration v3→v4:** leere Builds und Quests. Eine bereits per Debug freigeschaltete Prolog-Klasse
  gilt als Prolog-Wahl, es wird nichts gesperrt. Items und Crafting-Zustand bleiben unverändert.
  Getestet mit eigener Alt-Payload.
- **Beim Laden:** Builds werden repariert (unbekannte Knoten, Ränge, ungültige Verteilung, Slots,
  Mods). Laufende Trials werden nie gespeichert.

## Ausgeführte Tests (nur `user://test_saves/`)
| Zeitpunkt | Suites | Ergebnis |
|---|---|---|
| Phase A neu | attack_speed (5), status_effects (9) | 14/14 |
| Phase B neu | talents (9), skills (8) | erst 17/18 (Testfehler: Capstone-Grenzfall falsch berechnet; ein statisches Helfer-`test_*` lief als Test), dann grün |
| A+B Regression | light_attack, heavy_attack, combo, lunge, combo_reach, dash, movement, input, hits, enemy, knockback, hit_reaction, collision, weapon_switch, item_effects, essences, sockets_quality, evolution, classes, mastery, equipment, save, crafting_save/stats/ops, affix_pool, pickup + neue | erster Lauf **hing** (siehe Fehler 1), nach Fix **257/257** |
| C | warrior (8), classes | erst 15/18 (3 echte Befunde, siehe unten), dann grün |
| D | arcanist (9) | erst 7/9 (Testtiming und Slots), dann 9/9 |
| E | shadowrunner (6) + warrior, skills, movement, dash, lunge, hit_reaction, collision | erst 4/6 (Skill-Bewegung zu weit, siehe unten), dann 22/22 und 44/44 |
| F | prologue, classes, world, save, ui_layout, loop, pickup, Klassen-Suites | 1 Fehler (world: Map-Anzahl der Region um die Prolog-Map gewachsen, Erwartung angepasst), dann grün |
| G | presets (5), class_ui (2), ui_layout, prologue, equipment, loop, save, classes, settings | 60/60 (nach Korrektur eines eigenen Tippfehlers) |
| Abschluss | **volle Suite (begründet durch Änderungen an CombatComponent, Player, HealthComponent, Save-Schema)** | **348/348 in 47 Suites** |
| Nachtrag | prologue (+ Test der Debug-Taste F10), project, world, input | 10/10, 14/14 |

### Gefundene und behobene Fehler
1. **Endlosschleife (Hänger)** im neuen Trefferstrom: Ein Effekt, der denselben Treffer erneut
   verteilt, landete immer wieder in der Warteschlange. Behoben: Jeder Treffer wird pro Zyklus nur
   einmal verteilt (der Bestandstest `test_effects_cannot_recurse` deckte es auf).
2. **Blood Oath** zerriss die Blutungsstacks, die Hemorrhage im selben Treffer gesetzt hatte.
   Behoben: Bedingungen sehen einen Status-Snapshot vor dem Treffer.
3. **Skill-Bewegung** lief 88,9 statt 80 px. Behoben: exakte Distanz wie beim Lunge.
4. **Generator:** Typisierte Dictionaries (z. B. Rage-Gewinn pro Tag) wurden still nicht gespeichert.
   Behoben mit `assign` und erneut generiert.
5. **UI:**
   - Talentbäume nutzten die Fensterbreite nicht; Namen wurden abgeschnitten.
   - Gleichnamige Zeilen kollidierten beim Neuaufbau, weil `queue_free` verzögert läuft.
6. **Parse-Fehler:** `PackedStringArray.any` und Variant-Inferenz.

## Grafische Playtests (Fenster, echter Renderer)
| Playtest | Ergebnis |
|---|---|
| `class_playtest.gd` (1920×1080 und 3840×2160, je 100 % und 150 %) | **41/41**: alle Seiten im Bild, nicht gequetscht, Fensterrand eingehalten; Hover-Tooltip eines Talents mit echter Maus; ein echter Mausklick lernt einen Rang; Preis der Preset-Aktivierung angezeigt. Screenshots selbst angesehen; danach Talent-Layout verbessert und erneut geprüft. |
| `class_playtest.gd -- --prologue` (1600×900, --fixed-fps 60) | **16/16**: G am Tor, alle drei Trials von einem Skript gegen echte Grunts mit Skills gekämpft (2,4–3,9 s je Trial), Wahl Shadowrunner, andere gesperrt, F6/F9 → unverändert |
| `rpg_playtest.gd` | OK (Debug-Unlock-Schritt durch Stand-in ersetzt) |
| `loop_playtest.gd -- --build-only` | OK |
| `ui_playtest.gd -- --quick` | 64/64 |

**Kein menschlicher Playtest.** Spielgefühl und Balance der Klassen sind nicht bewertet. Die Werte sind
konservative Startwerte.

## Bekannte Fehler / Beobachtungen
- Die Trials sind sehr leicht: drei eng stehende Grunts sterben in 2–4 s gegen Level-12-Builds.
  Notiert unter „Vorschläge für den Feel-Test“ in `COMBAT_DESIGN.md`.
- Spamt man einen Skill auf Cooldown, erscheint jede Ablehnung als Toast (im skriptgesteuerten
  Playtest sichtbar).
- Beim ersten `--import` eines frischen Klons meldet Godot einmalig die noch fehlende
  `ui.en.translation`. Sie wird dabei erzeugt; danach ist der Lauf sauber.

## Einschränkungen
- Pro Klasse sind 6–7 statt langfristig 8 aktive Skills implementiert.
- **Keine eigenen Waffen für Arcanist/Shadowrunner:** Sie nutzen das Einhandschwert. Light- und
  Heavy-Angriffe sind für alle Klassen gleich; die Unterschiede entstehen über Skills, Ressource,
  Talente und Mechanik.
- **Keine VFX/SFX pro Skill**, nur einfache Platzhalter: Ringe, Projektile, Zonen, Status-Punkte und
  farbige Zahlen.
- **Shift (Block/Parry)** ist nicht umgesetzt.
- **Mod-Quellen:** Boss- und Erkundungsquellen nur vorbereitet.
- **Prolog:** keine Story, keine NPCs. Die Klassenquests sind generisch (Kills und Abgabe).
- **Lokalisierung:** Für die neue Klassen-UI-Chrome gibt es stabile Keys (`localization/ui.csv`). Ältere
  UI-Texte, Item- und Talentdaten sind englische Quelltexte ohne Keys. Es gibt keine weitere Sprache.
- **Forge-UI** wurde bewusst nicht überarbeitet.
- **Commits:** Phase A und B sind ein gemeinsamer Commit, weil Bridge, Runner und Character in einem
  Durchgang für beide Phasen erweitert wurden.

## Git-Commits (lokal, `dev/class-foundation`)
- `ef3f1cf` A+B: Attack Speed, Status, Trefferstrom, Talent-Engine, Skills
- `172f306` C: Warrior
- `5c72778` D: Arcanist
- `9728905` E: Shadowrunner
- `7bd0719` F: Prolog, Klassenwahl, Klassenquests, Save v4
- `a090b66` G: Presets, Klassen-UI, Lokalisierung, visuelle Playtests
- Doku-Commit (dieser Bericht, Design-Dokumente, F10-Debugtaste)

## Startanleitung und Bedienung
1. Branch `dev/class-foundation` öffnen und `scenes/maps/home_base.tscn` starten (Hauptszene).
2. Neuer Charakter = Basic Adventurer. Das goldene Tor **„Prologue“** links unterhalb des Startpunkts
   mit **G** betreten.
3. Am Podest **G** startet bzw. verlässt die Trial. Die Ziele stehen rechts im HUD, die Skills unten
   (Q/E/R/F).
4. Nach drei Trials: **Altar of Choice** (G), Klasse wählen und erneut klicken zum Bestätigen.
5. Zurück durch das Tor „Home Base“. **Klassenstation** in der Basis (G): Klassen, Talente, Skills/Mods,
   Presets, Quests. Mit **C** öffnet sich das Talentfenster überall.

**Steuerung:**
- WASD, Maus, LMB light, RMB heavy, Space Dash, Q/E/R/F Skills
- C Klasse/Talente, G Interaktion, I Inventar, F6/F9 Speichern/Laden

**Debug:**
- **F10** +5 Klassenlevel und 100 Gold (nicht während einer Trial)
- F8 +100 Klassen-XP, F2 Grunt, F4 Crafting-Kit, F7 Item-Kit

## Menschliche Playtest-Aufgaben
**Allgemein:**
- Prolog komplett spielen.
- Prüfen, ob die Trial-Ziele verständlich sind und sich die drei Klassen unterscheiden.
- Wahl treffen, F6/F9: Bleibt alles korrekt?

**Warrior:**
- Mit L-L-L-Ketten Rage und Pressure aufbauen (Anzeige rechts) und Furious Strike direkt in eine
  Combo einbauen. Fühlt sich das Abbrechen der Light-Angriffe gut an?
- Mit F10 auf ca. Level 40: Berserker bis Whirlwind und Relentless ausbauen. Ist Whirlwind mit 1,2 s
  Lock zu lang?
- Warbreaker-Baum bis Worldbreaker (Level 60): Voll aufgeladene L-L-H-Finisher in Gruppen. Ist das
  Beben spürbar, ohne zu stark zu sein?
- Bloodblade: Wird Blutung (rote Punkte und Zahlen) sichtbar und verständlich? Wirkt Blood Oath als
  Heilung?

**Arcanist:**
- Rotation Arcane Bolt ×2–3 → Mana Pulse (Detonation). Ist der Mana-Verbrauch knapp genug, um zu
  planen?
- Rune Sigil: Erkennt man, dass der nächste Zauber +30 % hat?
- Frostbind gegen bereits gekühlte Gegner, mit Fokus darauf, ob die Verlangsamung sichtbar ist
  (blauer Ring).
- Mod Split Bolt gegen Gruppen; prüfen, ob Double Mark (Talent Glyph Lore) bewusst nicht mit Split
  kombiniert werden kann.

**Shadowrunner:**
- Light-Finisher legen Weak Points frei (gelber Punkt); prüfen, ob Execution sie zuverlässig trifft.
- Shadowstep (R) gegen Space-Dash: Ist der Unterschied klar (kein iFrame, keine Ladung, 80 px)? Ist
  der Krit-Buff spürbar?
- Expose Weakness → Execution als Burst. Sind Focus-Aufbau und -Abbau (nach 4 s) angenehm?
- Mit Talenten: Blade Fan und Thousand Cuts in Gruppen, Smoke Veil gegen Grunts.

**Presets und Respec:**
- Zwei Presets mit unterschiedlichen Talenten anlegen und an der Station wechseln. Ist die Kostenanzeige
  klar?
- Ein ausgerüstetes Item zerstören und das Preset aktivieren: Ist die Fehlermeldung verständlich?
