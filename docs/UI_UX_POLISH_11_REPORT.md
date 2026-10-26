# UI/UX Polish 1.1 + Dash Direction Update – Bericht

Branch `dev/ui-ux-polish-11` (Basis `1f59fb7`, Ende von `dev/ui-ux-redesign-01`). Kein Push.
`project.godot` enthält weiterhin fremde uncommittete Änderungen; sie wurden nicht angefasst und nicht
mitcommittet. Keine Save-Dateien gelöscht; alle Tests nutzen nur `user://test_saves/`.

**Umfang:** Behoben wurden die Bedienungs- und Layoutprobleme aus dem ersten menschlichen UI-Review.
- Klassenkarten und Talentbäume
- Inventar-Interaktion und Gold
- Dash-Richtung
- Rezeptfenster, Toasts, HUD bei hoher Skalierung, Forge-Ergebnisse

Unverändert:
- Gameplay, Items, Crafting-Regeln und -Wahrscheinlichkeiten
- Talentpunkte und Schwellen
- Dash-Ladungen, -Distanz, -Dauer und iFrames
- Save-Schema (v5, keine Migration)

## Phasen und Ergebnisse

### A – Prüfung
- Ausgangslage: Branch sauber bis auf `project.godot`.
- `CLAUDE.md` und die betroffenen Komponenten und Tests gelesen.
- Der Stil „The Forgotten Chronicle“ wird weiterverwendet. Neu ist nur die Typvariation `CardButton`.

### B – Klassenübersicht
- **Kompakte Karten** (320×104), je mit:
  - `ClassEmblem` (provisorisch)
  - Name und Status ACTIVE / UNLOCKED / LOCKED
  - Level
  - zwei Zeilen `ClassDefinition.tagline` (neues Datenfeld, nur Anzeige)
- **Detailbereich** der gewählten Karte:
  - Level-Balken
  - Klassenressource, aus den Ressourcendaten formuliert (`resource_text`)
  - Spielstil (`description`)
  - Namen der Talentbäume
  - bei Locked: Voraussetzungen aus echten Daten (Prolog-Regel `prologue_class_ids`, Zustand und Startbedingung der Klassenquest über `QuestService.can_start`)
- **Klassenwechsel** nur an der Station: Der Activate-Knopf ist sonst gesperrt und mit einem Hinweis versehen. Talente bleiben überall lernbar, wie bisher.
- **Guardian/Soulbinder** bleiben ausgeblendet. Der Auftrag verlangt nur, sie nicht als spielbar zu zeigen; das Ausblenden entspricht der festen Entscheidung aus dem Haven-Slice (`test_shrine`). `requirements()` würde sie als „Not playable in this version.“ ausweisen.

### C – Talentbäume
- `TalentTreeView` ist neu als Knotengraph aufgebaut.
  - Tier 1 oben bis Tier 7 unten; Punkteschwelle je Tier in der Randspalte, bronze, sobald erreicht.
  - Quadratische Knoten mit Symbol: Raute passiv, Kreis Skill, Stern Transformation.
  - Rang-Badge „2/5“, Capstone mit Doppelrahmen.
  - Zustände: Learned/Maxed bronze gefüllt, Available Cyan-Rahmen, Locked gedimmt.
- **Linien:**
  - dünn: Weg nach unten (gleiche Spalte bzw. Tiers mit einem einzelnen Knoten)
  - dick: explizite Voraussetzungen (warnfarben, solange nicht erfüllt)
- **Tooltip:** Name, Art, Tier, Effekt, Rang, Voraussetzungen und Sperrgrund (`Cannot learn: …`). Zusätzlich eine Detailleiste über den Bäumen für Hover, Tastaturfokus und Klick.
- Ein Klick lernt einen Rang über `TalentService`, wie bisher. Regeln unverändert.
- **Layout:** Die drei Bäume stehen immer nebeneinander in einer `HBoxContainer`-Zeile innerhalb von `TreeScroll`. Bei wenig Platz scrollt nur dieser Bereich; Kopf und Detailleiste bleiben sichtbar. Die Legende bricht um.
- Geprüft: Bei 1080p/100 % stehen alle drei Bäume mit allen 7 Tiers ohne Scrollen nebeneinander (`1080p_100_talents_full.png`, vollständige Belegung mit 47 Punkten, Berserker-Capstone erreicht).

### D – Inventar-Interaktion
- **Sofortiger Tooltip** (`ItemTooltip`), ohne die 0,5-s-Verzögerung von Godot:
  - Hover oder Tastaturfokus zeigt die vollständige Itemkarte (`ItemDescriber`) und daneben die ausgerüsteten Items der passenden Slots als „EQUIPPED · Main Hand“ (höchstens zwei).
  - Position: rechts der Zelle, sonst links, sonst darunter/darüber; immer im Bild.
  - Auf kleinen Canvases fallen zuerst die Vergleichskarten weg, dann folgen zwei Spalten, dann eine kompakte dreispaltige Karte ohne gedimmte Zeilen mit „Click the item for all details“.
- **Rechtsklick:**
  - Ausrüstbares Item → `CharacterEquipment.quick_slot`: erster freier passender Slot (Ring 1 vor Ring 2; Main Hand vor Off Hand, Off Hand nur bei Dual Wield und ohne Zweihänder), sonst Ersatz des ersten Slots.
  - Ausgerüstetes Item (Paperdoll oder Markierung in der Tasche) → ablegen. Ein freier Platz ist nie nötig, denn nach der Shared-Item-Policy liegt das Item ohnehin im Inventar.
  - Nicht ausrüstbare Items: nur ein Hinweis, nie eine Änderung.
- **Knöpfe entfernt:** Equip, Unequip, Equip Off-hand, Equip Ring 1/2 und Discard. Es gibt keinen Ersatz, der Items löscht. Drag & Drop wählt weiterhin gezielt einen Slot (Ring 2, Off Hand).
- **Gold:**
  - Bisher ein Inventar-Stapel `gold_coin`, der einen Taschenplatz belegte.
  - Jetzt: `ItemDefinition.is_currency`. Gold bleibt als Stapel im Inventar, Save-Format unverändert, keine Migration. Es belegt aber keinen Taschenplatz (`Inventory.used_slots/free_slots/room_for/add_instance/transfer_to/integrity_errors`).
  - In der Tasche ausgeblendet; im Kopf als Zähler „Gold 1,234“.
  - Respec-Kosten lesen Gold weiter über `inventory.count`.
- Item-IDs bleiben erhalten; Equipment und Inventar sind nach jedem Schritt konsistent (Integritätsprüfungen im Test).

### E – Dash-Richtung
- `DashComponent.direction_for(move, aim)`: mit WASD-Eingabe die normalisierte Bewegungsrichtung (Totzone 0,1), sonst die Blickrichtung zur Maus. WASD hat Vorrang, auch wenn die Maus woandershin zeigt.
- `Player._start_dash` nutzt nur noch diese Funktion.
- Ladungen, Recharge, Distanz, Dauer, iFrames und Timings sind unverändert. Shadowstep und andere Skill-Bewegungen sind nicht betroffen; sie laufen über `start_skill_motion`.
- Angepasst: `COMBAT_DESIGN.md`, `ARCHITECTURE.md`, die Projektregel in `CLAUDE.md` sowie der Text „Dash (movement direction; standing still: towards the cursor)“ in der Steuerungsliste.

### F – Weitere UI-Korrekturen
- **`BuildPanel`:** Rezeptkarten mit Ausgabe-Icon, Name, „Makes … · Rarity“ und Beschreibung, Kostenzeilen „have / need“ (grün/rot) und Craft-Knopf (`Craft_<id>`) mit Sperrgrund. Logik weiter nur über `BaseBuilder`.
- **`ToastFeed`:** kompakte HUD-Paneele mit Farbakzent und Body-Schrift, höchstens 4. Gleiche Meldungen werden zu „x2“ zusammengefasst statt gestapelt.
- **Forge:** drei Spalten bei 1080p (Items 300 | Zustand + Mögliche Ergebnisse 490 | Aktionen 560). „Possible results“ ist eine eigene Karte unter dem Zustand, im Bild und neben Bestätigen. Die Werte stammen unverändert aus `CraftingService.preview`. Bei 150 % stapelt sich das Layout wie bisher.
- **HUD bei 150/200 %:** erneut in der Galerie geprüft (Überlappungsprüfung aller HUD-Teile); keine neuen Probleme.

## Tests

| Lauf | Ergebnis |
|---|---|
| `check_project.ps1` (Import, Parse, 300 Frames, Fehler/Warnungen) | OK |
| Volle Suite `run_tests.ps1` | **458 bestanden, 0 fehlgeschlagen** |
| Neu/erweitert: `class_ui` (+2: Kartenstatus/Details, Bäume nebeneinander/Tiers/Linien/Detailleiste) | grün |
| `inventory_ui` (+5 statt 2 alter: Rechtsklick mit Ring-/Waffen-Slotwahl über echte Mausereignisse via `push_input`, keine Aktions-/Discard-Knöpfe, Hover-Tooltip mit Vergleich im Bild inkl. rechter Rand, Gold-Zähler ohne Slot, Save/Load nach Ausrüstungswechsel mit Instanz-IDs) | grün |
| `dash` (+5 statt 2 alter: vier Richtungen, Diagonalen, WASD schlägt Maus, Maus-Fallback, Regel isoliert; 2 alte Tests auf die neue Regel umgestellt) | 18/18 |
| `forge_ui` (+3: Ergebnisse neben den Aktionen bei 1080p mit unveränderten Chancen, Rezeptkarten, Toasts) | 8/8 |
| UI-Galerie, 35 Bildschirme × 1080p/4K/720p × 100/150/200 % (Fenster offen, im Bild, nichts gestaucht, keine HUD-Überlappung) | **891 Prüfungen, 0 Fehler**, 315 Screenshots |
| `ui_playtest.gd` (720p–4K, alle UI-Skalierungen, **echter Cursor**: Hover-Tooltip an linkem und rechtem Rand, **echter Rechtsklick** Ausrüsten/Ablegen bei 720p/1080p/1440p/4K) | 225 Prüfungen, 0 Fehler |
| `class_playtest.gd` (echter Hover-Tooltip und echter Klick auf Talentknoten, 1080p/4K × 100/150 %) | 41, 0 Fehler |
| `prologue_playtest.gd --fixed-fps 60` (kompletter Prolog, Save/Load, Quit → Continue) | OK |
| `visual_playtest.gd` und `-- --polish` | gelaufen; nur Log und Screenshots, keine Prüfungen. Log: Dash folgt WASD bei abweichender Maus |

**Nicht gelaufen:** `crafting_playtest.gd` (ohne `--loop`) und `loop_playtest.gd`. Beide sind schon vor diesem Branch veraltet (entfernte Bauplätze, siehe Redesign-Bericht).

## Screenshots (`docs/screenshots/ui_ux_polish_11/`)
- **Klassen:** `{1080p,2160p}_{100,150}_classes.png`, `…_classes_locked.png` (Arcanist mit Voraussetzungen aus Daten)
- **Talente:** `…_talents.png`, `…_talents_full.png` (volle Belegung), `1080p_200_talents_full.png`
- **Inventar:**
  - `…_inventory.png`, `…_inventory_tooltip.png` (Vergleich, zwei Spalten bei 150 %), `1080p_200_inventory_tooltip.png` (kompakt)
  - `ui_playtest_1080p_tooltip_left_edge.png`, `ui_playtest_1080p_tooltip_right_edge.png` (echter Cursor)
- **Forge:** `1080p_100_forge_affixes.png`, `1080p_100_forge_imprint.png`, `1080p_150_forge_affixes.png`, `2160p_150_forge_affixes.png`
- **Rezepte:** `1080p_100_recipes.png`, `2160p_150_recipes.png`
- **HUD und Toasts:** `1080p_150_hud_combat.png`, `1080p_200_hud_boss.png`, `720p_150_hud.png`
- **Dash:** `dash_wasd_left_mouse_right.png`
- `gallery_log.txt` (alle 891 Prüfungen)

## Geänderte Dateien

**Code:**
- `scripts/ui/class_station_panel.gd`, `talent_tree_view.gd`, `class_emblem.gd` (neu)
- `inventory_panel.gd`, `item_cell.gd`, `item_tooltip.gd` (neu), `item_describer.gd` (Kompaktmodus)
- `build_panel.gd`, `toast_feed.gd`, `crafting_panel.gd`, `options_panel.gd`, `ui_theme.gd` (`CardButton`)
- `scripts/rpg/items/inventory.gd`, `item_definition.gd` (`is_currency`)
- `scripts/rpg/equipment/character_equipment.gd` (`quick_slot`)
- `scripts/rpg/classes/class_definition.gd` (`tagline`)
- `scripts/player/dash_component.gd`, `player.gd`

**Daten:** `data/classes/*.tres` (Taglines), `data/items/gold_coin.tres` (`is_currency`)

**Tests:**
- `tests/integration/test_class_ui.gd`, `test_inventory_ui.gd`, `test_dash.gd`, `test_forge_ui.gd`
- `tests/playtest/gallery_screens.gd`, `ui_gallery.gd`, `ui_playtest.gd`, `class_playtest.gd`, `visual_playtest.gd`

**Doku:**
- `CLAUDE.md`
- `docs/COMBAT_DESIGN.md`, `ARCHITECTURE.md`, `ITEM_SYSTEM.md`, `UI_DESIGN_SYSTEM.md`, `TEST_STRATEGY.md`, `DEVELOPMENT_ROADMAP.md`, dieser Bericht

## Bekannte Einschränkungen
- **Dash-Regel geändert:** Das ist eine Änderung am Spielgefühl auf ausdrücklichen Auftrag; Werte und Timings sind unverändert. Ein menschlicher Feel-Test steht aus (Ausweichen rückwärts, während man auf den Gegner zielt).
- **Talentbäume bei 1080p/150 %:** Nur etwa 2–3 Tiers sind ohne Scrollen sichtbar, weil Kopf-Chips und Detailleiste Höhe kosten. Der Baumbereich scrollt per Mausrad. Ein Klick lernt sofort, ohne Bestätigung, wie bisher; Respec an der Station ist kostenlos.
- **Sofort-Tooltip nur im Inventar.** Forge-Itemliste und Skill-Auswahl nutzen weiter den Godot-Tooltip mit Verzögerung.
- **Bei 200 %** bedeckt der kompakte Tooltip eines voll gecrafteten Items fast den ganzen Bildschirm. Er verschwindet, sobald die Maus die Zelle verlässt.
- **Ohne Discard** gibt es im Spiel keinen Weg, Items loszuwerden. Händler und Lager fehlen; das war so gewollt (keine Löschung als Ersatz). Eine volle Tasche bleibt voll, bis Händler oder Lager kommen.
- **Gold** belegt keinen Taschenplatz mehr. Ältere Saves mit Gold bekommen dadurch einen freien Platz dazu; das Save-Format bleibt gleich.
- **Galerie:** 1440p nur im `ui_playtest`. Gamepad-Navigation weiterhin nicht vorhanden.
- **Provisorische Grafik:** Klassen-Embleme, Knoten- und Item-Symbole sind prozedural gezeichnet.

## Lokale Commits

| Commit | Inhalt |
|---|---|
| `e689c6d` | B: kompakte Klassenkarten mit Detailbereich |
| `bc7bf47` | C: Talentbäume als Knotengraph, nebeneinander, Detailleiste |
| `dcad2ba` | D: Sofort-Tooltip mit Vergleich, Rechtsklick-Ausrüsten, Knöpfe entfernt, Gold-Zähler |
| `86fdd92` | E: Dash nach WASD, sonst Maus |
| `3c6eeb9` | F: Rezeptkarten, Toasts, Forge-Ergebnisse sichtbar |
| `c0a6060` | G: vorbereitete Klassen ausgeblendet, kompakter Tooltip für kleine Canvases |
| (dieser Commit) | G: Doku, Screenshots, Bericht |
