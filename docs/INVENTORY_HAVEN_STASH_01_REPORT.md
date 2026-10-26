# Inventory & Haven Stash 1.0 – Bericht

Branch `dev/inventory-haven-stash-01`, Basis `210612a` (Ende von `dev/talent-ui-polish-12`), kein Push.
- `project.godot` hat weiterhin fremde uncommittete Änderungen; nicht angefasst, nicht committet.
- Keine echten Spielstände gelesen, verändert oder gelöscht. Tests nutzen nur `user://test_saves/`.
- Design: `docs/STASH.md`; Save-Format: `docs/SAVE_SYSTEM.md`.

## Architektur
- **Besitz:** Jede Iteminstanz liegt in genau einem besitzenden Container, `Character.inventory` (Tasche)
  oder `Character.stash` (Lager, ein `Inventory`). Ausrüstungsslots und Build-Presets referenzieren nur
  IDs in der Tasche.
- **Kategorien als Ansichten:** Equipment Chest, Material Vault und Collection Vault werden aus der
  Item-Definition abgeleitet (`StashService.category_of`), nicht gespeichert. Es gibt keine Kopien, nichts
  wird automatisch umsortiert.

| Kategorie | Inhalt | Kapazität (Ruine / restauriert) |
|---|---|---|
| Equipment Chest | ausrüstbare Items außer Unique/Set/Legendary | 60 / 120 Plätze |
| Collection Vault | Unique, Set, Legendary | 40 / 80 Plätze |
| Material Vault | Materialien, Essenzen, Komponenten, Verbrauchsgüter | keine Platzgrenze |

- **Kapazität** kommt aus `ProgressionRules`. Sie wächst durch die Restaurierung der Ruine mit
  `stash_access` und sinkt nie.
- **Nicht einlagerbar:** Gold (bleibt Zähler, belegt keinen Slot), Quest-Items (Story-Ziele zählen die
  Tasche) und ausgerüstete Items (in irgendeinem Klassen-Loadout).
- **`StashService`** (zustandslos) prüft immer vollständig, bevor er etwas ändert.
  - `deposit` / `withdraw` sind atomar und geben bei Ablehnung einen Grund zurück.
  - Stapel mischen nur mit schlichten Stapeln derselben Definition; der Rest behält seine Instanz-ID.
  - Entnahme ist alles oder nichts.
  - Dazu `deposit_all_materials`, `sort` (nur Reihenfolge) und `ownership_errors` (Konsistenzprüfung).
- **Presets** bleiben Referenzen. Liegt ein Preset-Item im Lager, nennt die Validierung das Lager („take it
  out to use this preset“).
- **Save:**
  - Version 6 mit `stash.items`; Migration 5→6 ergänzt ein leeres Lager.
  - Eine ID, die beim Laden schon in der Tasche liegt, wird nicht doppelt geladen, sondern als Orphan
    behalten und gemeldet.
  - Klassenfortschritt, Talente, Quests, Inventar und Loadouts bleiben unverändert.
  - Speicherfehler werden wie bisher über `SaveSystem` gemeldet und nicht als Erfolg ausgegeben.

## Haven-Integration
- Das **Old Storehouse** (`RuinDefinition.stash_access = true`) öffnet in jedem Zustand das Lager; ein
  Grundlager gibt es schon als Ruine.
- Ist das Haus noch eine Ruine, bietet das Fenster „Restore the Storehouse“ an. Das ist der bestehende,
  transaktionale Restaurierungsablauf mit Meilenstein-Save.
- Restored (später auch Revitalized) bringt mehr Plätze in Chest und Collection Vault und behält den
  bisherigen Bonus von +10 Taschenplätzen. Kein gelagertes Item wird dabei berührt (Test).
- Keine neuen Gebäude, keine frei platzierbaren Bauten.

## Oberfläche (`StashPanel`)
- **Aufbau:** Tasche (mit Gold-Zähler) und Lager gleichzeitig. Das Lager hat drei Tabs mit sichtbarer
  Kapazität („Equipment Chest 2 / 60“, „Material Vault · 18 stacks · no slot limit“), dazu
  „Deposit All Materials“ und „Sort“.
- **Bedienung:**
  - Rechtsklick in der Tasche lagert ein, im Lager entnimmt er.
  - Drag & Drop in beide Richtungen, auf Zellen oder freie Fläche.
  - Nach dem Einlagern zeigt das Fenster den Tab der Item-Kategorie.
- **Tooltip:** sofort bei Hover, mit „EQUIPPED“-Vergleich für Ausrüstung. Der automatische Erstfokus zeigt
  keinen Tooltip.
- **Feedback** in der Statuszeile, z. B. „… is equipped – unequip it first.“, „… stays with you (quest
  item).“, „The Equipment Chest is full (60 / 60).“, „Your bag is full“, „Not enough room in your bag for
  45 Iron Ore.“
- **Layout:** Tasche und Lager bleiben bei jeder UI-Skalierung nebeneinander, bei Bedarf mit weniger Spalten
  (7+9 bis 3+4). Jedes Raster scrollt für sich, beide bleiben gleichzeitig sichtbar, damit Ziehen nie
  Fensterscrollen braucht.
- Kein Discard, keine Platzhalterknöpfe. Außerhalb des Lagers bleibt der Rechtsklick im Inventar
  Equip/Unequip (Test).

## Tests
| Lauf | Ergebnis |
|---|---|
| `check_project.ps1` | OK |
| Volle Suite | **481 bestanden, 0 fehlgeschlagen** (inkl. Forge, Klassen, Combat, Save, Haven, Prolog-Logik) |
| `test_stash` (11 Tests) | grün: Kategorien als Ansichten; Identität und Crafting-Zustand (Affixe, Essenzen, Sockel, Qualität, Material); Stapel-Mischen inkl. Teilstapel und Stapel mit eigenem Zustand; volles Chest, volle Tasche, teilweise passender Stapel; ausgerüstete und Preset-Items; schnelle Wiederholungen; Deposit All (Gold, Quest-Items, Ausrüstung und Tränke bleiben); Sort ohne ID-Änderung; Kapazität vor/nach Restaurierung; Save/Load inkl. Klassenlevel und Talenten; Migration v5→v6; beschädigter Save mit doppelter ID |
| `test_stash_ui` (7 Tests, echte Mausereignisse über die Viewport-Eingabe) | grün: Lager an der Ruine; Rechtsklick ein/aus; schnelle Klicks; Drag & Drop in beide Richtungen; Ablehnungsgründe; Deposit All, Sort, Restaurierung aus dem Lager (gelagerte Items unverändert); Save/Load mitten in der Nutzung; Inventar-Rechtsklick außerhalb bleibt Equip |
| `stash_playtest.gd`, echtes Fenster, echter OS-Cursor + Mausereignisse, 720p/1080p/4K × 100/150/200 % (9 Pässe) | **135 Prüfungen, 0 Fehler**: Hover-Tooltip im Bild, Rechtsklick ein/aus, Drag ins Lager und zurück, Deposit All, Sort, Tabs, Layout im Viewport, Mengenbilanz ohne Verlust oder Duplikat, Besitzkonsistenz |
| UI-Galerie 1080p/4K/720p × 100/150/200 % (alle Bildschirme, neu `stash`, `stash_materials`, `stash_restored`) | **1053 Prüfungen, 0 Fehler** |
| `ui_playtest.gd` (Inventar-Rechtsklick und Hover mit echter Maus) | 225, 0 Fehler |
| `prologue_playtest.gd --fixed-fps 60` | OK: das ruinierte Old Storehouse öffnet das Lager, Restaurierung von dort (+10 Taschenplätze) |

**Angepasste Alttests:**
- `test_loop`: Die Ruine öffnet jetzt das Lager, die Restaurierung läuft über dessen Knopf.
- `test_save_foundation`: prüft jetzt „Version ≥ 5“ statt „= 5“.
- Prolog-Playtest: neuer Weg über das Lager.

**Bei der Prüfung gefundene und behobene Fehler:**
- **Absturz (Signal 11)** durch eine Größen-Rückkopplung zwischen Fenster und `HFlowContainer`. Ersetzt
  durch eine umschaltbare `BoxContainer`-Anordnung.
- **Tasche und Lager untereinander bei 1080p/100 %:** Das Fenster war nur so breit wie die breiteste Spalte.
- **200 %:** Die gestapelte Anordnung passte nicht ins Fenster, Ziehen war unmöglich. Jetzt weniger
  Spalten nebeneinander, plus eigener Scrollbereich je Raster.
- **Anordnung zu früh entschieden:** Die Wahl fiel vor dem Befüllen der Raster und damit mit falschen
  Breiten.
- **„Deposit All Materials“ nahm Tränke mit:** jetzt nur noch Kategorie MATERIAL.
- **Testartefakt:** Synthetische Mausbewegungen mit festem `relative` erreichten auf skalierten 4K-Canvases
  die Drag-Schwelle nicht. Die Testereignisse nutzen jetzt das echte Delta; mit echtem Cursor war alles grün.

## Screenshots (`docs/screenshots/inventory_haven_stash_01/`)
- **Galerie:** `gallery_<auflösung>_stash.png` (Equipment Chest mit Vergleichs-Tooltip, Ruine),
  `…_stash_materials.png`, `…_stash_restored.png` (Collection Vault, restauriert); 1080p/4K/720p bei
  100/150/200 %.
- **Echte Maus:** `mouse_<auflösung>_01_tooltip.png`, `_02_materials.png` (nach Deposit All und Sort),
  `_03_chest.png`.
- **Prolog:** `prologue_stash_ruined.png`.
- **Logs:** `stash_playtest_log.txt`, `gallery_log.txt`.

## Bekannte Einschränkungen
- **Restaurierung, Crafting und Quests** lesen nur die Tasche. Eingelagerte Materialien muss man vorher
  entnehmen; das Fenster weist im Lager nicht eigens darauf hin.
- **Kein Teil-Entnehmen** eines Stapels (Menge wählen). Passt ein Stapel nicht vollständig, wird abgelehnt.
- **Bei 200 %** sind beide Raster nur etwa anderthalb Reihen hoch; sie scrollen einzeln.
- **„Revitalized“** bringt noch nichts über „Restored“ hinaus; das System ist dafür vorbereitet.
- **Ausgerüstete Items anderer Klassen-Loadouts** sind ebenfalls gesperrt. Das ist bewusst so (Shared-Item-
  Policy), steht aber nur in der Meldung.
- **Provisorische Grafik:** keine eigenen Lagerkisten-Grafiken; Item-Icons sind prozedural.

## Lokale Commits
| Commit | Inhalt |
|---|---|
| `51baa5e` | A/E: Besitzmodell, StashService, Save v6 mit Migration, Preset-Meldung, Service-Tests |
| `5b63adb` | B/C/D: Old Storehouse öffnet das Lager in jedem Zustand, StashPanel, UI-Tests, Galerie, Prolog-Playtest |
| `7959f68` | F: Layout bei allen Skalierungen, Fenster-Playtest mit echter Maus, Loop-Test |
| (dieser Commit) | Doku (`STASH.md`, Save, Item-System, Teststrategie, Roadmap, `CLAUDE.md`), Screenshots, Bericht |
