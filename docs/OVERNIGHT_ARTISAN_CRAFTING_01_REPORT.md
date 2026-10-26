# Overnight Artisan Crafting 01 – Bericht

Auftrag: `docs/tasks/OVERNIGHT_ARTISAN_CRAFTING_01.md`. Alles lokal, nichts gepusht.

## 1. Ausgangsstand
- Basis-Branch `dev/professions-foundation-01`, Ausgangs-Commit `1218554` („Report: commit id of the documentation
  commit“). Die gemeldeten Professions-Foundation-Commits (`cd464a1`, `e3239ca`, `c815c8f`, `3bdad7f`, `1218554`)
  lagen lokal vor.
- Die Baseline-Zahlen 498/498 (Unit-Suite) und 1206/1206 (Galerie) stammen aus der Vorsession. In dieser Session
  wurden sie **nicht** erneut bestätigt (keine volle Suite, keine volle Galerie).

## 2. Branch und Commits
Neuer Branch `dev/overnight-artisan-crafting-01`, lokal aus `dev/professions-foundation-01` per `git switch -c`
(behält den Arbeitsbaum, nichts überschrieben).

| Commit | Inhalt |
|---|---|
| `e5763e0` | fix: repair targeted profession playtests and scaled crafting footer (Phase 1) |
| `209e079` | feat: add persistent artisan workshop restoration states (Phase 2) |
| `a0ad214` | feat: allow haven restoration materials from stash (Phase 5) |
| `b3d8a5d` | feat: expand hollowwood gathering and supported crafting (Phase 3) |
| dieser Commit | docs: add overnight artisan crafting report (Doku + Bericht) |

Phase 5 wurde vor Phase 3 committet: Sie ist eine Einzeilen-Folge der Phase-2-Architektur (Restaurierung lief
schon über den gemeinsamen Materialplan).

## 3. Fremde Änderungen und Spielstände
- Vorbestehend uncommittet: `project.godot` (Diff: `window/stretch/aspect` entfernt, `[internationalization]`
  verschoben, `locale/fallback` entfernt) und der ungetrackte Ordner `docs/tasks/` (der Auftrag).
- `project.godot` geschützt durch:
  - Kopie und SHA-256 vor Beginn (`68321b98…`)
  - einen Wrapper um jeden Godot-Aufruf, der danach den Hash prüft
- Er blieb nach jedem Lauf unverändert, wurde nie gestaged, committet, gestasht oder zurückgesetzt. Endstand:
  derselbe Hash, weiterhin uncommittet. `docs/tasks/` blieb ungetrackt.
- Echte Spielstände (`%APPDATA%/Godot/app_userdata/Echoes of the Hollow/saves/*`, `settings.cfg`): vorher
  gehasht und kopiert, nach jedem Godot-Lauf geprüft – unverändert.
  - Skriptläufe nutzen nur `user://test_saves/`.
  - Die Startprüfung (Hauptszene, nicht geskriptet) lief nur in einer Projektkopie mit anderem Projektnamen,
    also mit eigenem Benutzerordner. Kopie und Ordner wurden danach gelöscht.
- Keine Test- oder Debug-Saves im Repository. Kein Push, kein Remote, kein Tag, kein PR.

## 4. Phasen
| Phase | Status |
|---|---|
| 0 Audit | erledigt |
| 1A `Plots/PlotWest` | erledigt |
| 1B Prolog-Flake | **nicht reproduziert**, Ursache offen (Diagnose-Hilfe eingebaut, kein spekulativer Fix) |
| 1C Craft-Knopf bei 150 % | erledigt |
| 2 Werkstatt-Restaurierung | erledigt |
| 3 Hollowwood-Loop | erledigt (Alchemie bewusst ohne herstellbares Ergebnis) |
| 4 Salvage | **blockiert / ausgelassen** (siehe 11) |
| 5 Restaurierung aus dem Lager | erledigt |
| 6 Verifikation | gezielt, siehe 13 |

### 1A – Veraltete Bauplatz-Referenz
- `loop_playtest.gd` (Standard und `--build-only`) und `crafting_playtest.gd` (Standard und `--loop`) erreichen
  die Schmiede jetzt über die Ruine Old Smithy:
  - Loop: zu Fuß, G, Klick auf „Restore“
  - Crafting-Playtest: `RestorationService.restore`
  - Haven-Flag und zwei Supply Crates stehen für den Prolog
- Keine Produktionsszene geändert.
- Danach lief die eigentliche Testlogik und deckte zwei weitere veraltete Stellen in den Tests auf, beide behoben:
  - Der Confirm-Knopf der Forge heißt seit dem UI-Redesign nach der Operation; er wird jetzt per Name gefunden.
  - Der Save/Load-Vergleich im Loop zählte Spielzeit und `count.enter:`-Zähler mit (laufende Zähler wie die schon
    ausgenommenen `visits`).

### 1B – Prolog-Flake
- Beleg aus dem Transkript der Vorsession: Der Lauf hatte 16 Fehlschläge. Sichtbar waren nur die letzten 12
  Zeilen:
  - `Node not found: "Edrin" (relative to "/root/WhisperingStone")`
  - Die Schnellreise nach Haven war also nicht passiert; Mara/Edrin fehlten als Folgefehler.
  - Der erste Fehlschlag ist nicht erhalten.
- Reproduktionsversuche, alle grün:
  - zwei Läufe direkt nach `--import` im Projekt
  - ein Lauf in einer frischen Kopie ohne `.godot`-Cache, mit Import
  - ein Lauf nach Phase 3
- Gegenprobe: Eine frische Kopie **ohne** Import scheitert mit Parse-Fehlern (unbekannte `class_name`s). Das ist
  ein anderes, bekanntes Symptom (CLAUDE.md: vorher `--import`).
- Einzige Änderung: Ein fehlgeschlagener Lauf behält sein vollständiges Log
  (`tests/output/prologue_playtest_failed_<zeit>.txt`), damit der nächste Fall diagnostizierbar ist.
  Kein Timing-Fix ohne belegte Ursache.

### 1C – Craft bei 150 %
- `UiWindow` hat eine optionale feste Fußzeile `footer` (zwischen Body und Schließen, versteckt solange leer,
  in der Größenberechnung enthalten).
- `ProfessionsPanel` legt Rezeptname, Sperrhinweis, Craft und die Ergebnismeldung dorthin. Rezeptliste und
  -karte scrollen, Craft bleibt sichtbar.
- Fokus/Tastatur:
  - Der Craft-Knopf bleibt ein normaler fokussierbarer Button im Fenster.
  - Die Fokuswiederherstellung nach einem Neuaufbau sucht ihn im ganzen Fenster.
  - Der Erstfokus bleibt wie bisher auf der ersten Berufskarte.
- `test_professions_ui` prüft bei 75/100/125/150 %, dass Craft in der Fußzeile liegt und ohne Scrollen sichtbar ist.
  Sichtprüfung über Galerie-Screenshots bei 1080p 75/100/150 %.

## 5. Hauptdateien und Architektur
- `scripts/rpg/haven/ruin_definition.gd`
  - `revitalize_costs`, `restored_text`, `revitalized_text`
  - `revitalized_flag()`, `can_revitalize()`
- `scripts/rpg/haven/restoration_service.gd`
  - `next_stage`, `costs_for`, `material_plan`, `uses_stash`, `advance_error`, `advance(character, ruin, target)`
  - `restore`/`restore_error` bleiben als Schritt nach `restored`
  - Die Zielstufe muss genau die nächste sein. Damit kann kein Doppelklick eine Stufe überspringen: Zwei
    „Restore“-Anfragen geben einmal Erfolg und einmal „already restored“, auch wenn das Material fürs
    Revitalisieren in der Tasche liegt.
- `scripts/rpg/professions/profession_service.gd`
  - `consume_plan`/`refund_plan` aus `craft` herausgezogen, reiner Umbau ohne Verhaltensänderung
  - Restaurierung und Herstellen verbrauchen damit über denselben Code
- `scripts/world/ruin_site.gd`
  - `is_workshop()`: Werkstatt = `profession_id`, aber keine `building_id`; G öffnet in jeder Stufe die Werkbank
  - `advance()`, Stufenzeichnung
- `scripts/ui/restoration_panel.gd`
  - beide Schritte, Kostenzeilen aus dem Plan (Bestand, Tasche/Lager, Fehlmenge), Ergebnisvorschau
  - Aktion in der Fußzeile, schließt nach Erfolg
- `scripts/ui/professions_panel.gd`
  - Werkstattstufe und Knopf „Restore/Revitalize the workshop“ (Signal → `GameHud.open_restoration`)
  - Craft-Fußzeile; Tag „Level N“ für automatische Rezepte
- `scripts/ui/journal_panel.gd`: Haven-Seite nennt den nächsten Schritt.
- `scripts/ui/game_hud.gd`: das neue Signal verbunden.
- Daten:
  - `data/haven/ruins/` (4 Werkstätten)
  - `data/world/resource_nodes/` (4 neu)
  - `data/professions/recipes/` (4 neu)
- Karten: `scenes/maps/whisper_forest.tscn`, `whispering_stone.tscn`.
- Tests:
  - neu: `test_workshops.gd`, `test_hollowwood.gd`
  - angepasst: `test_haven.gd` (6 restaurierbare Ruinen), `test_professions_ui.gd`
  - Playtests: `loop_playtest.gd`, `crafting_playtest.gd`, `prologue_playtest.gd`, `gallery_screens.gd`
    (+2 Screens)
- Doku: `PROLOGUE_AND_HAVEN.md`, `PROFESSIONS.md`, `TEST_STRATEGY.md`, `DISPLAY_AND_UI_STANDARD.md`,
  `DEVELOPMENT_ROADMAP.md`, `CLAUDE.md`.
- Kein Power Creep: Restaurieren/Revitalisieren der Werkstätten ändert weder Werte noch Kapazität noch
  Produktionsmengen. Der Test vergleicht `get_stats()` und die Taschenkapazität. Kein Rezept verlangt eine
  Werkstattstufe.

## 6. Restaurierungskosten (provisorisch balanciert)
Alle IDs sind in `data/items` vorhanden. Quellen:
- `timber`: Oak Tree / Old Oak
- `stone`: Forest Rock
- `raw_hide`: Stag / Elk Remains
- `flax_fiber`: Wild Flax
- `duskleaf`: Duskleaf / Duskleaf Cluster
- `oak_plank`: Saw Oak Planks
- `cured_leather`: Tan Hide
- `linen_cloth`: Weave Linen
- `iron_ingot`: Smelt Iron Ingot aus `iron_ore` (Iron Vein im Whisper Forest, keine Mine)

`test_workshops` prüft, dass jede Kostenposition eine platzierte Quelle oder ein Stufe-1-Verarbeitungsrezept aus
solchen Quellen hat.

| Werkstatt | Restore | Revitalize |
|---|---|---|
| Tanner's Lodge | 6 `timber`, 3 `stone`, 2 `raw_hide` | 4 `oak_plank`, 3 `cured_leather`, 2 `iron_ingot` |
| Weaver's House | 6 `timber`, 3 `stone`, 4 `flax_fiber` | 4 `oak_plank`, 3 `linen_cloth`, 1 `cured_leather` |
| Woodwright's Workshop | 8 `timber`, 4 `stone` | 6 `oak_plank`, 2 `iron_ingot`, 1 `cured_leather` |
| Alchemist's Cottage | 6 `timber`, 3 `stone`, 2 `duskleaf` | 4 `oak_plank`, 2 `linen_cloth`, 4 `duskleaf` |

Bedingung: `prologue.haven_discovered`. Old Smithy und Old Storehouse bleiben unverändert (nur Restored).

## 7. Save
- **Version 7 beibehalten, keine Migration.**
- Begründung: Die Stufen standen schon in `world.restoration`; das Laden akzeptierte schon `revitalized`.
  Neu sind nur die Flags `haven.<id>.revitalized` (normale Weltflags).
- Alte v7-Stände ohne Werkstatteintrag laden die Werkstätten als Ruined und buchen nichts ab. Getestet
  (`test_v7_save_without_workshop_stages_loads_ruined`, aus einem Dict; kein echter Save benutzt).

## 8. Hollowwood-Knoten
| Knoten (neu fett) | Karte, Position | Beruf | Stufe | Ertrag | XP | Respawn |
|---|---|---|---|---|---|---|
| **Old Oak** | Whispering Stone (−210, 250) | Woodcutting | 3 | 5 Timber | 14 | 150 s |
| **Rich Iron Vein** | Whispering Stone (210, 250) | Mining | 3 | 3 Iron Ore | 16 | 180 s |
| **Duskleaf Cluster** | Whispering Stone (−210, 100) | Herbalism | 3 | 2 Duskleaf | 14 | 180 s |
| **Elk Remains** | Whispering Stone (215, 40) | Skinning | 3 | 3 Raw Hide | 16 | 240 s |
| **Stag Remains B** | Whisper Forest (−270, 135) | Skinning | 1 | 2 Raw Hide | 8 | 180 s |
| bestehende Stufe-1-Knoten | Whisper Forest / Old Road | alle vier | 1 | unverändert | | |

- Persistenz: die bestehende Echtzeit-Erschöpfung in `WorldState.map_states`. Getestet:
  - nach Save/Load erschöpft
  - nach Ablauf der Respawnzeit wieder verfügbar
- Erreichbarkeit: `test_hollowwood` läuft mit echter Bewegung vom Ankunftspunkt zu allen neuen und mehreren
  alten Knoten sowie zum Hunter's Pack.
  - Jeder Knoten wurde erreicht.
  - Unterwegs wurde keine Begegnung ausgelöst.
  - Die Pflichtbegegnung auf dem Schreinpfad (Radius 110 um (0, 150)) wird umgangen.
- Stufe 3 aus Stufe 1 braucht 123 Sammel-XP (z. B. ca. 16 Iron Veins à 8 XP). Die XP-Kurve bleibt ungetestet gegen echtes
  Spielgefühl (provisorisch).

## 9. Rezepte
| Rezept | Beruf | Stufe | XP | Materialien → Ergebnis | Nutzen |
|---|---|---|---|---|---|
| Rope Belt | Tailoring | 1 | 20 | 4 Flax Fiber | Gürtel (+max_health), hatte keine Quelle |
| Padded Mantle | Tailoring | 2 | 28 | 3 Linen Cloth + 1 Cured Leather | Schultern (+armor), hatte keine Quelle |
| Traveler's Cloak | Tailoring | 3 | 32 | 5 Linen Cloth | Umhang (+max_health), hatte keine Quelle |
| Worn Boots | Leatherworking | 2 | 28 | 3 Cured Leather + 1 Linen Cloth | Füße (+armor), hatte keine Quelle |

- Alle vier sind bestehende, ausrüstbare Items (Normal); es gibt keine neuen Item-Definitionen.
- Verarbeitungsergebnisse (Bretter, Leder, Leinen, Barren) haben jetzt auch über die Revitalisierung einen Zweck.
- Bewusst nicht ergänzt:
  - Bögen (nur Schwertfamilien im Spiel)
  - Tränke (kein Verbrauchsgut-System; Stoneskin Draught bleibt Daten)
  - Alchemie-Ergebnisse
  - weitere Woodworking-/Blacksmithing-Gegenstände (keine unterstützten neuen Ergebnisse ohne neue Items)
- Ein Test sichert ab:
  - kein herstellbares Rezept gibt ein Verbrauchsgut aus
  - Waffen nur aus vorhandenen Familien
  - jedes Material-Ergebnis wird weiterverarbeitet oder restauriert
- Leatherworking-Pfad bis Stufe 3 (Bracers):
  - Tan Hide (16 XP beim ersten Mal)
  - Leather Gloves (50)
  - Worn Boots (56)
  - ein weiteres Tan Hide
  - Ergebnis: 130 XP ≥ 123

## 10. Leather Bracers
- Quelle: „Hunter's Pack“ im Whisper Forest bei (−285, −112), nahe dem Eingang aus Haven, ohne Kampf erreichbar.
- Umsetzung: `StoryPickup` mit `persistent_id = forest_hunters_pack`, Item `pattern_leather_bracers`.
- Einmalig über das Flag `pickup.forest_hunters_pack`, das mit dem Item gespeichert wird.
- Lernen:
  - über den bestehenden „Learn from …“-Knopf
  - dauerhaft; ein zweites Pattern wird abgelehnt und bleibt erhalten
- Getestet:
  - Aufheben
  - kein zweites Mal, auch nicht nach Save/Load
  - Lernen und Doppellernen
  - Herstellen auf Stufe 3 an der Tanner's Lodge
  - gelerntes Rezept nach Save/Load

## 11. Salvage – blockiert
Ausgelassen nach den Exit-Kriterien des Auftrags:
- **Favoriten/gesperrte Items sind nicht modelliert.** Es gibt kein Lock-/Favoriten-Feld an
  `ItemInstance`/`Inventory`.
  - Ein Schutz würde nur vorgetäuscht.
  - Den Schutz „konservativ“ auszuschließen, hieße, jedes Item auszuschließen.
- **Keine Instanz-Provenienz:** Eine Iteminstanz weiß nicht, ob sie hergestellt, gefunden oder Startausrüstung
  ist (z. B. Leather Cap als Startitem).
  - Rückgewinnung aus Rezeptinputs wäre nur auf Definitionsebene belegbar.
  - Startitems ließen sich dann in Material umwandeln.

Die übrigen Schutzklassen wären prüfbar gewesen:
- ausgerüstet: `CharacterEquipment`
- Presets/Loadouts: Instanz-IDs
- Quest: Kategorie
- Unique/Set: Rarität

Kleinster Folgeauftrag:
1. Item-Sperre (Flag an `ItemInstance`, gespeichert, Rechtsklick-/Tooltip-Anzeige)
2. optionale Herkunft `crafted_by_recipe` an neu hergestellten Instanzen
3. danach Salvage nur für gesperrt=nein, hergestellt=ja, Normal, ohne Forge-Zustand

## 12. Restaurierung aus dem Lager
- Gemeinsamer Pfad, kein zweiter Materialdienst:
  - `RestorationService.uses_stash` = `StashService.is_upgraded` (dieselbe Regel wie an den Werkbänken)
  - Plan: `ProfessionService.material_plan` (Tasche zuerst, dann Lager, jede Einheit einmal über
    `Inventory.count`)
  - Verbrauch: `ProfessionService.consume_plan`
- Anzeige, Prüfung und Verbrauch lesen denselben Plan. Das Fenster zeigt „have N (bag x, stash y)“.
- Getestet:
  - gesperrt (Old Storehouse ruiniert: Lager zählt nicht, nichts bewegt)
  - nur Lager, genau ausreichend
  - gemischt: Tasche 4 + Lager 4 für 6 → Tasche 4, Lager 2
  - eins zu wenig über Tasche + Lager: abgelehnt, nichts bewegt
  - drei schnelle Anfragen: genau eine Restaurierung
  - Besitzkonsistenz (`ownership_errors`)
  - Fenstertext
- Die Restaurierung des Old Storehouse selbst nutzt das Lager nicht, weil es vorher nicht freigeschaltet ist.

## 13. Tests dieser Session
Godot `../tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .`, jeder Lauf über einen Wrapper mit
Hash-Prüfung von `project.godot` und den echten Saves.

| Lauf | Ergebnis |
|---|---|
| `--headless --import` (mehrfach) | PASS (keine Fehler) |
| Startprüfung = Inhalt von `check_project.ps1` (Import + 300 Frames Hauptszene, ERROR/WARNING-Filter) in isolierter Projektkopie | PASS (0 Treffer) |
| `--fixed-fps 60 -s res://tests/playtest/loop_playtest.gd` | erst FAIL (veralteter Vergleich: Spielzeit/Zähler), nach Fix PASS; nach Phase 3 erneut PASS |
| `loop_playtest.gd -- --build-only` | erst FAIL (Weg aus dem Viertel, Klick traf den Craft-Reiter), nach Fix PASS |
| `-s res://tests/playtest/crafting_playtest.gd` (1080p/4K × 100/150 %) | erst FAIL (Confirm-Knopf veraltet gesucht), nach Fix PASS 65/65 |
| `crafting_playtest.gd -- --loop` | PASS 18/18 |
| `prologue_playtest.gd` (`--fixed-fps 60`) | PASS ×2 nach Import, PASS ×1 in frischer Kopie mit Import, PASS ×1 nach Phase 3 |
| Prolog in frischer Kopie **ohne** Import | FAIL erwartbar (Parse-Fehler unbekannter Klassen), nur als Gegenprobe |
| `ui_playtest.gd` | PASS 213/213 |
| `ui_gallery.gd -- --res=1920x1080 --scale=0.75/1.0/1.5 --only=professions,professions_smithy,professions_locked` | PASS je 9/9 |
| `ui_gallery.gd … --scale=1.0/1.5 --only=hud_artisan_stages,restoration_revitalize,restoration,journal_haven` | PASS je 11/11 |
| `ui_gallery.gd … --scale=0.75/1.5 --only=restoration_revitalize,restoration` (nach Fußzeile) | PASS je 6/6 |
| `ui_gallery.gd … --scale=1.0/1.5 --only=professions,professions_locked,professions_gathering` | PASS je 9/9 |
| `world_ui` nach Phase 2 | FAIL 1 (Hinweis „Revitalized: not available“ fehlte für die Schmiede), Fix, dann PASS |
| Abschluss, gezielt: `run_tests.gd -- --suite=workshops,hollowwood,haven,world_ui,stash_ui,stash,professions,professions_ui,base,loop,crafting_loop,forge_ui,ui_layout,menus_ui,inventory_ui,class_ui,hud,shrine,prologue,old_road,gathering,equipment,project,save` | **PASS 163/163** (24 von 67 Suite-Dateien) |
| Volle Unit-Suite | NOT RUN (Auftrag) |
| Volle UI-Galerie, große Auflösungsmatrix | NOT RUN (Auftrag) |
| `class_playtest`, `stash_playtest`, `visual_playtest`, `rpg_playtest`, `feedback_playtest` | NOT RUN (Systeme nicht berührt) |
| Sichtprüfung Screenshots | MANUAL ONLY: Berufefenster 1080p 75/100/150 %; Restaurierungsfenster 150 %; Artisan Quarter mit allen drei Stufen |

Geprüft wurde dabei: keine Überlappung, Fußzeile sichtbar, Stufen in der Welt klar unterscheidbar, Werkbank
und Schild am alten Platz.

## 14. Bekannte Probleme und Annahmen
- **Prolog-Flake:** Ursache unbekannt (siehe 1B). Der nächste Fehlschlag wird mit vollem Log aufbewahrt.
- **Balance:** Kosten, Knotenwerte und Rezept-XP sind provisorisch, ohne menschlichen Playtest.
- **Stufe-3-Knoten** liegen am Whispering Stone, das nach Edrins Gespräch (Nordtor) frei zugänglich ist.
  Spieler sehen die Stufenanforderung im Prompt bzw. als Ablehnungsgrund.
- **Werkstattgrafik** ist Platzhalter-Zeichnung im bestehenden Stil. Die Laternen überlagern leicht das
  Berufsschild; es bleibt lesbar.
- **Gallery-Seiteneffekt:** Die Gallery-Screens `hud_artisan_stages`/`restoration_revitalize` setzen Stufen am
  gemeinsamen Galerie-Charakter. Sie stehen deshalb hinter den `professions*`-Screens.
- **Kein Hinweis auf den Fundort des Patterns:** Das Rezept sagt „Learn it from Pattern: Leather Bracers“, nennt
  aber keinen Ort.
- **„Worn Boots“** heißen als hergestelltes Item weiterhin so (bestehende Item-Daten, nicht umbenannt).

## 15. Bestätigung
- Keine echten Spielstände oder Einstellungen verändert (Hash-Prüfung nach jedem Lauf).
- `project.godot` unverändert und uncommittet.
- Kein Push, kein Remote-Branch, kein PR, kein Tag.
- Keine volle Suite und keine volle Galerie behauptet: Alle Zahlen oben sind Teilläufe.

## 16. Empfohlene Folgeaufgaben
1. Item-Sperre/Favoriten + optionale Herkunft an hergestellten Instanzen. Danach Salvage-MVP (siehe 11).
2. Kurzer Fundort-Hinweis für Rezeptgegenstände (z. B. Journal-Notiz oder Text am Rezept „found in the Whisper
   Forest“).
3. Menschlicher Balance-Playtest der Werkstattkosten und Sammel-XP (Stufe 1 → 3).
4. Prolog-Playtest bei Gelegenheit nach frischem Import wiederholen. Das aufbewahrte Log auswerten, falls er
   scheitert.
5. Fußzeile für weitere Fenster mit scrollender Hauptaktion prüfen (Forge-Confirm bei 150 %).
