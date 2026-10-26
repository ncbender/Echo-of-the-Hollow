# UI/UX Redesign 1.0 – „The Forgotten Chronicle“ – Bericht

Branch `dev/ui-ux-redesign-01` (Basis `94a4c41`, Prologue & Haven Slice 0.1). Kein Push.
`project.godot` enthält fremde uncommittete Änderungen; sie wurden weder verworfen noch mitcommittet. Das
Redesign braucht keine Änderung an `project.godot`: J/M werden zur Laufzeit registriert, siehe 2.

**Stand:**
- Fast alle Spieler-Bildschirme sind neu gebaut oder überarbeitet.
- Nicht überarbeitet sind das Rezeptfenster der Schmiede (`build_panel.gd`) und die Toast-Zeilen
  (`toast_feed.gd`). Beide bekommen nur das neue Theme.
- Alle Grafiken sind provisorisch (prozedurale Icons, Systemschriften).
- Ein menschlicher Playtest steht aus.
- Das Redesign ist **nicht final**.

## 1. Ergebnis in Kürze
- **Designsystem** (`UiTheme`):
  - Palette aus dem Auftrag als semantische Tokens; Serifenschrift für Titel.
  - 17 Typvariationen, Seltenheitstabelle aus Wort, Farbe und Punkten (nicht nur Farbe).
  - Komponenten: `UiWindow`, `UiTabs`, `UiConfirmDialog`, `ItemIcon`, `ItemCell`, `ItemDescriber`.
  - „Reduce Motion“ als Einstellung.
- **Inventar/Charakter:**
  - Paperdoll mit allen 15 Slots, Taschenraster mit Kategorien, Sortierung und adaptiven Spalten.
  - Detailkarte mit fester Abschnittsreihenfolge und Vergleich mit dem angelegten Item.
  - Drag & Drop über die vorhandenen Equipment-Aufrufe; Verwerfen fragt nach.
- **Resonance Forge 2.0:**
  - Sieben Bereiche: Craft, Imprint, Affixes, Essences, Sockets, Quality, Evolution.
  - Pro Bereich eine Zustands- und eine Aktionskarte; Kosten mit Bestand.
  - Wahrscheinlichkeiten nur aus dem echten `CraftingService`/Affixpool.
- **Klassenstation:**
  - Übersichts-Chips, Klassenkarten und Talentbaum mit vier Zuständen (Maxed, Learned, Available, Locked).
  - Respec als Gefahrenknopf.
  - Skill-Slots als Karten, Presets mit Bestätigung beim Löschen, Klassenquests als Karten.
- **HUD:**
  - Spielerrahmen (Leben, Ressource, Dash-Pips, Abwehr, Buffs, Mastery), Charge-Leiste und Skillleiste.
  - Gegnerrahmen mit Rang (ELITE/BOSS) und Bossleiste; Loot-Feed mit Icon und Seltenheit.
  - Todesanzeige mit Respawn-Zeit; Quest-Tracker mit [J]/[M].
  - Debug-Overlay standardmäßig aus (F12).
- **Welt:**
  - Journal (Main Story / Side Quests / Haven) und Regionskarte (Graph aus `MapDefinition`).
  - Dialog als Notiz mit Zeilenzähler und Eingabeschutz.
  - Wegsteine (frei, nur außerhalb des Kampfs) und Restaurierung (Kosten, Ergebnis, transaktional).
- **Menüs:**
  - Titel mit Hintergrund; New Game fragt bei vorhandenen Saves nach.
  - Laden mit getrennten manuellen Saves und Autosaves, Badges und markierten defekten Saves.
  - Pausemenü: Überschreiben und Quit to Title fragen nach.
  - Optionen mit Seiten und Steuerungsübersicht (nur lesend).

## 2. Architektur und Komponenten
| Baustein | Datei | Aufgabe |
|---|---|---|
| `UiTheme` | `scripts/ui/ui_theme.gd` | Tokens, Theme, Typvariationen, Fabriken (`section`, `card`, `stat_row`, `bar`, `button`, `key_chip`, …), Seltenheit, `motion_enabled` |
| `UiWindow` | `ui_window.gd` | Rahmen mit Eckwinkeln, Titel, Größenregel, Einblendung, Fokus auf den ersten Nicht-Reiter |
| `UiTabs` | `ui_tabs.gd` | umbrechende Reiterleiste (`Tab<Id>`, Signal `tab_selected`) |
| `UiConfirmDialog` | `ui_confirm_dialog.gd` | einziger Bestätigungsdialog (`ask/confirm/cancel`, Esc = Abbrechen) |
| `ItemIcon` / `ItemCell` | `item_icon.gd`, `item_cell.gd` | prozedurales Icon mit Seltenheitsrahmen; Zelle mit Menge und Drag & Drop |
| `ItemDescriber` | `item_describer.gd` | alle Item-Texte (Tooltip, Details, Vergleich, Summen) |
| HUD-Teile | `scripts/ui/hud/*.gd`, `skill_bar.gd`, `objective_panel.gd` | nur lesend; Layout in `GameHud._layout_bottom/_layout_hint` |
| `JournalPanel`, `WorldMapPanel` | `journal_panel.gd`, `world_map_panel.gd` | Questseiten (`StageTrack`), Kartengraph (`MapGraph`) |
| `SaveSlotList` | `save_slot_list.gd` | Slotliste für Titel und Pausemenü |

**Minimale Änderungen außerhalb der UI (nur Anzeige oder Ereignisse, keine Spielregeln):**
- `PlayerProgressionBridge.item_received` (Signal für den Loot-Feed), ausgelöst von `item_pickup.gd`.
- `Player.respawn_time_left()` (nur lesend).
- `EnemyConfig.rank` (0/1/2, nur Anzeige):
  - Grove Warden: Rang 2, Name „Grove Warden“ und eine id in `grove_warden_config.tres`.
  - Hardened Husk: Rang 1.
- `MapDefinition.map_cell/neighbors/show_on_map` (Karte; Prolog-Map versteckt).
- `UserSettings.reduce_motion` in `settings.cfg`, nicht im Save.
- Eingabeaktionen `ui_journal` (J) und `ui_map` (M), zur Laufzeit in `GameHud.ensure_input_actions()`.
- Dialog-Eingabeschutz 0,18 s Spielzeit nach jeder Zeile, gegen versehentliches Überspringen.
- Beschreibungstext in `data/base/buildings/smithy.tres`.

Unverändert: Combat-Timings, Skills, Balance, Save-Schema (v5), Crafting-Regeln, Trials,
Klassenwahl, Restaurierung, Wegstein-Regeln. Gelöscht wurden `class_info_panel.gd` und `mastery_panel.gd`;
der Spielerrahmen ersetzt sie.

## 3. Bildschirme
| Bildschirm | Status | Screenshot (`docs/screenshots/ui_ux_redesign_01/`) |
|---|---|---|
| Titel | neu | `1080p_100_title.png` |
| HUD (Ruhe, Kampf, Boss, Tod) | neu | `1080p_100_hud*.png`, `1080p_150_hud_combat.png`, `2160p_150_hud_combat.png`, `1080p_200_hud_boss.png`, `720p_150_hud.png` |
| Inventar / Paperdoll / Details | neu | `1080p_100_inventory.png`, `1080p_150_inventory.png`, `2160p_100_inventory.png`, `2160p_150_inventory.png`, `1080p_200_inventory.png` |
| Charakter (Übersicht) | neu | `1080p_100_character.png` |
| Klassenstation: Classes/Talents/Skills/Presets | neu | `1080p_100_classes.png`, `_talents`, `_skills`, `_presets`, `1080p_150_talents.png`, `2160p_150_talents.png` |
| Klassenwahl | überarbeitet | `1080p_100_choice.png` |
| Resonance Forge (7 Bereiche) | neu | `1080p_100_forge_*.png`, `1080p_150_forge_affixes.png`, `2160p_150_forge_affixes.png` |
| Schmiede-Rezepte (`build_panel`) | **nur Theme** | `1080p_100_recipes.png` |
| Restaurierung | überarbeitet | `1080p_100_restoration.png` |
| Dialog | überarbeitet | `1080p_100_dialogue.png` |
| Wegsteine | überarbeitet | `1080p_100_waystones.png` |
| Journal (Story, Haven) | neu | `1080p_100_journal.png`, `1080p_100_journal_haven.png` |
| Regionskarte | neu | `1080p_100_map.png` |
| Pause / Save / Load | überarbeitet | `1080p_100_pause.png`, `_save`, `_load` |
| Optionen / Steuerung | überarbeitet | `1080p_100_options.png` |
| Bestätigungsdialog | neu | `1080p_100_confirm.png` |
| Toast-Zeilen | **nur Theme** | in den HUD-Screenshots („Quest complete: …“) |

**Vorher/Nachher:**
- Vorher-Bilder liegen in `docs/screenshots/ui_foundation_01/` (Stand UI Foundation 0.1).
- Den Stand direkt an `94a4c41` gibt es nicht als eigene Bildserie. Die Vorher-Bilder sind älter, zeigen
  aber dieselben Fenster.

| Vorher | Nachher |
|---|---|
| `ui_foundation_01/1080p_02_inventory.png` | `ui_ux_redesign_01/1080p_100_inventory.png` |
| `ui_foundation_01/1440p_04_class_panel.png` | `ui_ux_redesign_01/1080p_100_talents.png` |
| `ui_foundation_01/720p_01_home_hud.png` | `ui_ux_redesign_01/720p_150_hud.png` / `1080p_100_hud.png` |
| `ui_foundation_01/2160p_07_combat.png` | `ui_ux_redesign_01/2160p_150_hud_combat.png` |
| `ui_foundation_01/720p_scale200_hud.png` | `ui_ux_redesign_01/1080p_200_hud_boss.png` |
| `ui_foundation_01/1080p_06_options.png` | `ui_ux_redesign_01/1080p_100_options.png` |
| `ui_foundation_01/720p_05_build_panel.png` | `ui_ux_redesign_01/1080p_100_forge_craft.png` (Rezepte jetzt auch im Forge-Bereich Craft) |

Alle Screenshots (32 Bildschirme × 1080p/4K/720p × 100/150/200 %) erzeugt die Galerie neu in
`tests/output/gallery/` (git-ignoriert). Das Log des letzten Laufs liegt in
`docs/screenshots/ui_ux_redesign_01/gallery_log.txt`.

## 4. Tests
| Lauf | Ergebnis |
|---|---|
| Volle Suite `./tools/run_tests.ps1` (nach dem letzten Commit) | 448 bestanden, 0 fehlgeschlagen |
| Neue UI-Suites: `inventory_ui` (6), `forge_ui` (5), `hud` (7), `world_ui` (5), `menus_ui` (4) | 27 / 27 grün |
| `check_project.ps1` (Import, Parse, 300 Frames, Fehler und Warnungen) | OK |
| UI-Galerie `ui_gallery.gd`, 1080p/4K/720p × 100/150/200 % | 810 Prüfungen, 0 Fehler |
| `ui_playtest.gd` (720p–4K, alle UI-Skalierungen, echter Hover, F11) | 217 Prüfungen, 0 Fehler |
| `prologue_playtest.gd --fixed-fps 60` (kompletter Prolog über echte Eingaben, Save/Load, Quit → Continue) | OK, 0 Fehler |
| `class_playtest.gd` | 41 Prüfungen, 0 Fehler |
| `crafting_playtest.gd`, `loop_playtest.gd` | **nicht lauffähig**, schon vor diesem Branch: nutzen die mit Prologue & Haven 0.1 entfernten Bauplätze; ersetzt durch Galerie und `forge_ui` |

**Was die Galerie pro Bildschirm prüft:**
- Das Fenster ist wirklich offen; dafür räumt sie zwischen den Bildschirmen Gegner weg und wartet auf den
  Respawn.
- Alle Controls sind im Bild und innerhalb des Rands, nichts ist gestaucht.
- Spielerrahmen, Skillleiste, Tracker, Ziel, Hinweis, Loot-Feed und Save-Anzeige überlappen sich paarweise
  nicht.

In Phase H hat die Galerie diese Fehler gefunden und behoben:
- Die Skillleiste überlappte bei 150 % den Spielerrahmen; sie war auf die volle Spaltenbreite gestreckt.
- Bei 200 % lief die untere Spalte über den Bildrand; Loot-Feed, Tracker und Hinweis überlappten.
- Die Bossleiste lief unter den Tracker.
- Nach der Todesanzeige öffneten sich Stationen in der Galerie nicht. Die Prüfungen liefen trotzdem grün,
  weil gar kein Fenster offen war; die Prüfung „Fenster offen“ ist neu.
- Der Prolog-Playtest drückte innerhalb des Dialog-Eingabeschutzes; der Test wartet jetzt.

## 5. Offene Fehler, Grenzen und nicht umgesetzte Wünsche
- **Nicht überarbeitet:** Rezeptfenster `build_panel` und Toast-Zeilen (nur Theme).
- **Gameplay fehlt; das Redesign erfindet es nicht:**
  - Händler, Lager-Inventar, Charakterauswahl
  - Antwortauswahl in Dialogen
  - Tasten umbelegen (die Steuerungsliste ist nur lesend)
  - Tränke benutzen
  - Weltkarte mit Gelände (die Karte ist ein Graph)
- **Keine Gamepad-Navigation.** Tastatur: Fokusreihenfolge, Tab, Enter, Esc. Nicht jede Liste ist
  vollständig per Pfeiltasten bedienbar.
- **Drag & Drop** ist über `ItemCell`-Aufrufe getestet, nicht mit der echten Maus im Playtest.
- 1440p wurde nur im `ui_playtest` geprüft, nicht in der Galerie.
- `crafting_playtest.gd` und `loop_playtest.gd` sind veraltet (siehe 4) und sollten neu geschrieben oder
  entfernt werden.

## 6. Provisorische Assets
- **Item-Icons:** prozedurale Glyphen pro Item-Art (`ItemIcon`); vorgesehen ist `texture` für echte
  Sprites.
- **Schriften:** Serife über `SystemFont` (Georgia mit Fallbacks), Fließtext mit der Godot-Standardschrift.
  Eine echte Pixel- oder Buchschrift fehlt.
- Titelhintergrund (prozedurale Baumsilhouetten), Paperdoll-Silhouette, Kartenknoten als Kästen.
- Keine UI-Sounds.

## 7. Usability-Befunde (aus der visuellen Prüfung)
- **Forge Imprint/Affixes bei 1080p 100 %:** Die Tabelle „Possible results“ liegt unter dem Falz; man muss
  scrollen.
- **200 % UI-Skalierung:** Das HUD ist überlappungsfrei, bedeckt aber etwa die Hälfte der Spielfläche.
  Der Loot-Feed zeigt dann nur 2 Zeilen.
- **Lange Item-Namen im Paperdoll** werden gekürzt („Wanderer's…“); der volle Name steht in der Detailkarte.
- **Talentbaum:** 3 Bäume × 7 Tiers passen bei 1080p 100 % knapp. Die Erklärung oben ist lang und
  sollte gekürzt oder einklappbar werden.
- **Schadenszahlen und Gegnerbalken** (Welttexte) können sich bei dicht stehenden Gegnern überdecken.
  Das ist kein HUD-Thema, fällt aber in den Screenshots auf.

## 8. Commits
| Commit | Inhalt |
|---|---|
| `6f165a8` | A: Designsystem, Komponenten, Reduce Motion, Galerie, UI-Inventur |
| `255108d` | B: Inventar, Paperdoll, Item-Beschreibung, Vergleich |
| `097e455` | C: Resonance Forge 2.0 |
| `b820c1b` | D: Klassen, Talente, Skills, Presets, Klassenquests |
| `4bccdcb` | E: HUD und Kampf-Feedback |
| `187b5b5` | F: Journal, Karte, Dialog, Wegsteine, Restaurierung |
| `6799fdc` | G: Titel, Pause, Save/Load, Optionen, Steuerung |
| `e73a6e7` | H: HUD-Überlappungen bei 150/200 %, Überlappungsprüfung, Prolog-Playtest |
| `0e202ce` | H: Galerie räumt zwischen Bildschirmen auf, Prüfung „Fenster offen“ |
| `12c1e84` | H: HUD bei 200 %, Doku, Screenshots |
| (dieser Commit) | H: Bericht |

## 9. Anleitung für den menschlichen Playtest
Vorher in den Optionen „Reduce Motion“ aus lassen, UI-Skalierung 100 %. Danach den Durchgang bei 150 %
und, wenn möglich, auf einem 4K-Monitor wiederholen.

1. **Titel:**
   - Ohne Saves: Continue und Load sind gesperrt.
   - New Game starten.
   - Später mit Saves: New Game muss nachfragen, Abbrechen bleibt auf dem Titel.
2. **Prolog (Old Road):**
   - Lesbarkeit von Hinweis, Tracker und Spielerrahmen im Kampf.
   - Gegnerrahmen erscheint nach eigenem Treffer und verschwindet nach ~5 s.
   - Elite-Gegner zeigen ELITE.
3. **Dialoge:** schnelles G-Drücken darf keine Zeile überspringen, die man nicht gesehen hat. Fühlt sich die
   Sperre von 0,18 s zu träge an?
4. **Haven:**
   - Ruine restaurieren: Kosten verständlich? Ergebnis klar?
   - J (Journal) und M (Karte) öffnen; Wegstein reisen und prüfen, dass im Kampf kein Reisen möglich ist.
5. **Inventar (I):**
   - Item ziehen und ablegen auf Slots, Ring 1/2, Off-Hand.
   - Vergleich lesen, Kategorien und Sortierung benutzen.
   - Verwerfen muss nachfragen.
6. **Forge (Old Smithy):**
   - Alle sieben Bereiche durchgehen, mindestens ein Imprint und ein Augment.
   - Stimmen angezeigte Kosten und Chancen mit dem Ergebnis überein?
   - Ist „Possible results“ ohne Scrollen auffindbar?
7. **Klassenstation:**
   - Talent lernen, Respec (fragt nach), Skill-Slot wechseln.
   - Preset speichern, aktivieren, löschen (fragt nach).
8. **Tod:** absichtlich sterben, dann Todesanzeige und Respawn-Zeit lesen.
9. **Pause (Esc):**
   - Speichern in einen belegten Slot muss nachfragen.
   - Laden; Quit to Title muss nachfragen; danach Continue.
10. **Optionen:**
    - UI-Skalierung 80–200 %, Fenster/Vollbild (F11), Reduce Motion.
    - Steuerungsliste mit der echten Belegung vergleichen.
11. **Notieren:** Wo sucht man etwas länger als 3 Sekunden? Welche Texte sind zu klein oder zu
    kontrastarm? Wo verdeckt das HUD Telegraphs?
