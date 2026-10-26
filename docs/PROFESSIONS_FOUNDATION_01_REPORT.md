# Professions Foundation 1.0 – Bericht

Branch `dev/professions-foundation-01` (Basis `dev/inventory-haven-stash-01`). Lokale Commits, kein Push.
`project.godot` (fremde Änderungen) wurde nicht angefasst und nie committet. Echte Spielstände wurden weder
gelöscht noch überschrieben; alle Tests nutzen `user://test_saves/`.
Design und Regeln: `docs/PROFESSIONS.md`.

## Commits
| Commit | Phase |
|---|---|
| `cd464a1` | B – UI Scaling Standard 1.1 (75/100/125/150 %, 200 % entfernt, alte Werte → 150 %) |
| `e3239ca` | C–E – Datenmodell, `ProfessionService`, Save v7, Sammeln, Daten, Service-Tests |
| `c815c8f` | F–H – Artisan Quarter, Werkbänke, Sammelknoten, Berufefenster, UI-Tests, Galerie |
| (Doku-Commit nach diesem Bericht) | J–K – Dokumentation, Bericht |

## A – Bestandsaufnahme (genutzt statt neu gebaut)
- **Items:** `Inventory.count`, `remove_quantity`, `room_for`, `add_item`. Ergebnisse sind normale Iteminstanzen;
  Forge-Affixe bleiben unverändert.
- **Lager:** `Character.stash` und `StashService.is_upgraded` (Lager-Materialien an Werkbänken).
- **Haven-Ruinen:** `RuinDefinition`, `RuinSite`, `RestorationService` – Werkstätten sind Ruinen mit `profession_id`.
- **Sammeln:** `ResourceGathering` mit Erschöpfung in `WorldState`, dadurch save-sicher.
- **UI:** `UiWindow`, `BookTabs`, `ItemTooltip`, `ItemIcon`, `UiTheme`.
- **Save:** `SaveMigrations`.

## B – UI-Skalierung 1.1
- Wählbar: 75 / 100 (Standard) / 125 / 150 %. 200 % entfällt; gespeicherte Werte über 150 % werden zu 150 %.
- Tests, Playtests und Doku sind angepasst (`DISPLAY_AND_UI_STANDARD.md`, `TEST_STRATEGY.md`).

## C/D – Berufe, Ränge, XP, Rezepte
- **Berufe:** neun, klassenunabhängig.
  - Herstellung: Blacksmithing, Leatherworking, Tailoring, Woodworking, Alchemy.
  - Sammeln: Mining, Herbalism, Woodcutting, Skinning.
- **Stufen und Ränge:** Stufe 1–100, XP und XP bis zur nächsten Stufe.
  - Ränge: Apprentice 1–20, Journeyman 21–40, Artisan 41–60, Expert 61–80, Master 81–100.
- **XP-Bänder** (Stufen über dem Rezept): ≤ 5 → 100 %, 6–15 → 50 %, 16–25 → 15 %, darüber 0 %.
  - Erstherstellungsbonus: +100 % der Basis-XP, einmalig und im Save vermerkt.
- **Rezepte sind Daten** mit diesen Feldern:
  - id, Beruf, Stufe, Werkbank, Materialien, Ergebnis/Menge
  - Parameter für spätere Material-/Affixwerte (`output_parameters`)
  - XP, Verarbeitungs-Flag
  - Freischaltquelle (automatisch, Trainer, Rezeptgegenstand, Quest, Drop)
- **Verarbeitung** ist als Rezept modelliert: Schmelzen, Gerben, Weben, Bretter sägen.
- **Lernen** ist dauerhaft. Doppeltes Lernen gibt nichts. Ein Rezeptgegenstand wird nur verbraucht, wenn das Rezept neu ist.

## E – Herstellen als Transaktion
- **Vorabprüfung** in fester Reihenfolge; Ablehnungen ändern nichts (Test vergleicht Zustand und XP):
  1. Rezept existiert
  2. herstellbar
  3. gelernt
  4. Stufe
  5. Werkbank
  6. Materialien
  7. Platz für das Ergebnis
- **Ablauf:** Materialplan verbrauchen → Ergebnis → Rückabwicklung bei Fehler → Erstherstellung markieren → XP.
- **Schnelle Klicks:** Jeder Aufruf wird neu geprüft. Im Test geben 6 Versuche mit Material für 2 genau 2 Bretter
  und 2× XP.
- **Save/Load** kann keine Belohnung doppeln: Erstherstellung, Rezepte und Erschöpfung sind gespeichert.

## F – Artisan Quarter
- **Haven wächst sanft nach Westen.** Hinter dem verbreiterten Westdurchgang (±64 px) liegt ein ummauerter Bereich
  mit eigenem Boden und Weg. Darin stehen in zwei Reihen:
  - The Tanner's Lodge
  - The Weaver's House
  - The Woodwright's Workshop
  - The Alchemist's Cottage
- **Haven hat jetzt zehn feste Gebäude.** Jedes hat eine stabile ID, einen eigenen Platz, ein Schild mit dem
  Berufsnamen und eine gezeichnete Werkbank.
  - Die Stufen Ruined/Restored/Revitalized kommen aus dem bestehenden Restaurierungssystem.
  - Die Restaurierung der neuen Werkstätten ist bewusst noch nicht freigegeben.
- **Grundherstellung schon als Ruine:** „Work at …“ öffnet das Berufefenster an dieser Werkbank.
- **Old Smithy = Blacksmithing:**
  - Als Ruine bleibt das Restaurierungsfenster (Prolog unverändert), mit Knopf „Use the Workbench (Blacksmithing)“.
  - Restauriert öffnet sich die Resonance Forge, im Reiter Craft mit Knopf „Blacksmithing Workbench“.
- **Keine Werkbänke** in Common Hall, Trading House, Barracks, Study (Test prüft die Zuordnung).
- **Unverändert:**
  - Prolog-Orte, Mara, Edrin, Wegstein, Nordtor, Nord-/Süd-/Ostübergänge
  - alle alten Ruinenpositionen
- **Proving Arena:** Das Tor sitzt jetzt an der Westmauer des Viertels; das Ziel bleibt gleich.
- **Hinweis:** Ein einmaliger Hinweis beim Betreten des Viertels nennt G und P.

## G – Inhalte
- **Herstellbare Rezepte pro Beruf:**
  - Blacksmithing: Eisen schmelzen, Militia Sword.
  - Leatherworking: gerben, Leather Gloves, Leather Bracers – Letztere ab Stufe 3 über Pattern: Leather Bracers.
  - Tailoring: Leinen weben, Linen Trousers.
  - Woodworking: Bretter sägen, Oak Shield (vorhandener Schild-Itemtyp, keine Bögen).
- **Alchemy:** Es gibt noch keine Verbrauchsgut-Buffs, daher ist Stoneskin Draught nur als Daten angelegt.
  Es ist sichtbar als „Potions cannot be used yet …“ markiert und wird nie hergestellt oder ausgegeben.
- **Neue Materialien:**
  - Raw Hide, Cured Leather, Flax Fiber, Linen Cloth, Iron Ingot, Oak Plank, Duskleaf
  - Pattern: Leather Bracers
- **Sammeln:** Die vorhandenen Knoten sind Mining und Woodcutting zugeordnet.
  - Neu in Whisper Forest: Wild Flax ×2 (Herbalism), Duskleaf Patch (Herbalism), Stag Remains (Skinning),
    jeweils mit eigenen Grafiken (HERB, CARCASS).
  - Stufenanforderung und Sammel-XP mit denselben Bändern.
  - Erschöpfung übersteht Save/Load.

## H – Berufefenster (`ProfessionsPanel`, Taste P oder Werkbank)
- **Aufbau:** Book Tabs Crafting/Gathering, kompakte Berufskarten (Name, Stufe, Rang, XP-Balken in Berufsfarbe)
  und eine Detailseite (Rang, Stufe, XP-Balken, Beschreibung, Werkstatt, „you are here“, „stash materials in reach“).
- **Rezeptliste:** Verarbeitung ist markiert. Gesperrte Rezepte sind gedimmt mit Kurzgrund („Not learned“, „Level 3“,
  „Not yet available“); der volle Grund steht im Tooltip.
- **Rezeptkarte:**
  - Ergebnis mit dem bestehenden `ItemTooltip` (inkl. Vergleich)
  - Werkbank, benötigte Stufe, XP-Vorschau inkl. Erstbonus
  - Materialien mit Bestand („24 / 3 (bag 18, stash 6)“)
  - Craft-Knopf (gesperrt mit Grund), Learn-Knopf bei vorhandenem Rezeptgegenstand
  - Ergebnisrückmeldung („Crafted 1 x Cured Leather · +16 XP (first craft)“)
- **Gathering-Seite:** Knoten mit Ertrag, XP und Stufe.
- **Stabilität:** Das Klassen-/Talentfenster ist unberührt (`class_playtest` 399 OK). Das Fenster schließt sich,
  wenn man die Werkbank verlässt. P ist eine Laufzeit-Aktion (wie J/M) und steht in Options › Controls.

## I – Lager
- **Save v6** bleibt die Grundlage. An einer Haven-Werkbank werden nach der Restaurierung des Old Storehouse auch
  Lager-Materialien genutzt: erst die Tasche, dann das Lager.
- **Freischaltregel:** das bestehende `StashService.is_upgraded`.
- **Ein Plan für alles:** Anzeige, Prüfung und Verbrauch nutzen denselben `material_plan`; jede Einheit wird einmal
  gezählt. Der Test prüft die Besitzkonsistenz (`ownership_errors`).
- **Ohne Werkbank** wird nie aufs Lager zugegriffen.

## J – Save und Migration
- **Version 7:** neues Feld `professions` mit `levels`, `known_recipes`, `first_crafts`.
- **Migration 6→7:** Alle Berufe starten auf Stufe 1, und automatische Stufe-1-Rezepte werden beim Laden gelernt.
  Unverändert bleiben (getestet):
  - Tasche, Lager
  - Restaurierungen
  - Builds/Talente
- **Robustes Laden:**
  - Unbekannte Berufe werden mit Warnung ignoriert.
  - Stufe/XP werden auf gültige Werte begrenzt.
  - Unbekannte Rezept-IDs bleiben erhalten (aber unbenutzbar).

## Tests
| Lauf | Ergebnis |
|---|---|
| `check_project.ps1` (Import + 300 Frames, Fehler und Warnungen) | OK |
| Volle Suite `run_tests.ps1` | **498 passed, 0 failed** |
| `test_professions` (10 Tests: Berufe, Ränge/Bänder, Lernen, Transaktion, Ablehnungen inkl. volle Tasche, schnelle Wiederholungen, Vertical Slice aller herstellbaren Rezepte, Lager-Plan, Sammeln über Save/Load, Save/Load + Migration) | grün |
| `test_professions_ui` (6 Tests: zehn Gebäude, Viertel zu Fuß erreichbar inkl. Westtor, alte Orte unverändert, Werkstatt per Klick, Sperrgründe/Pattern, P ohne Station, Old Smithy ruiniert/restauriert, Fenster bei 75–150 %) | grün |
| `test_haven`, `test_base` (Gebäudeanzahl 6 → 10 angepasst) | grün |
| `ui_gallery.gd` 720p/1080p/4K × 100/125/150 %, alle Bildschirme inkl. 6 neuer | **1206 checks OK** |
| `prologue_playtest.gd` (`--fixed-fps 60`) | 3 von 4 Läufen OK; der erste Lauf direkt nach dem Import schlug im Whispering Stone fehl (Mara/Edrin nicht gefunden – Timing, außerhalb von Haven). Die drei Wiederholungen waren grün. Als flaky vermerkt. |
| `loop_playtest.gd` | OK (Weg zum Arena-Tor jetzt durchs Viertel, Limit 900 Frames). Er meldet einen alten Fehler `Plots/PlotWest` – die Plots gibt es seit dem Haven-Slice nicht mehr; nicht Teil dieser Aufgabe. |
| `stash_playtest.gd` | 135 checks OK |
| `class_playtest.gd` | 399 checks OK |
| `ui_playtest.gd` | 213 checks OK |
| Nicht gelaufen | `crafting_playtest.gd` (enthält dieselbe veraltete `Plots/PlotWest`-Referenz), `class_playtest -- --prologue`, `visual_playtest`, `rpg_playtest` (Combat/RPG-Kern unverändert; deren Suites sind in der vollen Suite grün) |

1080p und 4K haben bei gleicher UI-Skalierung dieselbe Canvasgröße. Die Headless-Tests prüfen deshalb die
Skalierungen; die echten Auflösungen prüft die Galerie.

## Screenshots (`docs/screenshots/professions_foundation_01/`)
- `1080p_100_professions.png`: Tanner's Lodge nach der ersten Herstellung.
- `1080p_100_professions_tooltip.png`: Item-Tooltip am Ergebnis, fehlendes Material.
- `1080p_100_professions_locked.png`: gesperrtes Rezept mit Grund.
- `1080p_100_professions_gathering.png`: Herbalism.
- `1080p_100_professions_smithy.png`, `2160p_125_*`, `2160p_150_*`: Blacksmithing mit Lager-Materialien.
- `1080p_100_hud_artisan_quarter.png`: das Viertel in der Welt.
- `1080p_100_forge_craft.png`: Forge mit Workbench-Knopf.
- `720p_100_professions.png`

## Nicht umgesetzt (bewusst, außerhalb des Umfangs)
- **Werkstätten:** Restaurierung und Revitalized-Stufen der neuen Werkstätten. Sie existieren im Stufenmodell,
  sind aber nicht freigegeben.
- **Rezeptquellen:** Trainer-, Quest- und Drop-Quellen sind nur als Datenfeld vorhanden. Es gibt keine Trainer-NPCs
  und keine Pattern-Drops; das Pattern kommt bisher nur über Tests/Galerie in die Tasche.
- **Inhalte:** Alchemie-Herstellung (fehlendes Verbrauchsgut-System), die 25 Hollowwood-Rezepte, Bögen,
  Armor Mastery, Salvaging, Beutetabellen, Resonance Awakening, Hearth Flask.
- **Systeme:** Affix-Rework; `output_parameters` wird noch nicht ausgewertet.

## Einschränkungen
- **Platz bei 150 %:** Bei 1280×720 Canvas (1080p/150 % bzw. 4K/150 %) liegt der Craft-Knopf unter dem Falz;
  das Fenster scrollt nach Standard. Ein kompakterer Zwei-Spalten-Modus wäre ein Polish-Kandidat.
- **Tooltip-Vorschau:** Der Item-Tooltip des Rezeptergebnisses zeigt das Grunditem; nichts wird vorab gewürfelt.
- **Proving Arena:** Der Weg zur Arena ist durch das Viertel etwa 320 px länger.
- **Balance:** Die XP-Kurve (60 · 1,045^(n−1)) ist ein Startwert ohne Balance-Playtest.
