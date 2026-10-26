# Haven-Lager (Stash) – Design

Umgesetzt mit Inventory & Haven Stash 1.0. Code: `scripts/rpg/haven/stash_service.gd`,
`scripts/ui/stash_panel.gd`. Tests: `test_stash`, `test_stash_ui`, `tests/playtest/stash_playtest.gd`.

## Besitzmodell
- Jede Iteminstanz liegt in genau **einem** besitzenden Container: `Character.inventory` (Tasche) oder
  `Character.stash` (Lager, ein `Inventory`).
- Ausrüstungsslots und Build-Presets **referenzieren** nur Instanz-IDs in der Tasche. Sie sind keine
  Container.
- Die drei Lagerkategorien sind **Ansichten** des einen Lagers. Die Kategorie wird aus der
  Item-Definition abgeleitet, nicht gespeichert. Ein Item kann deshalb nie in zwei Kategorien stehen und
  wird nie automatisch verschoben.

| Kategorie | Inhalt | Kapazität (Ruine / restauriert) |
|---|---|---|
| Equipment Chest | ausrüstbare Items außer Unique/Set/Legendary | 60 / 120 Plätze |
| Collection Vault | Unique-, Set- und Legendary-Ausrüstung | 40 / 80 Plätze |
| Material Vault | alles Übrige (Materialien, Essenzen, Komponenten, Verbrauchsgüter) | **keine Platzgrenze** |

- Die Werte stehen in `ProgressionRules` (`stash_equipment_slots`, `stash_collection_slots`,
  `stash_restored_*_bonus`).
- Die Kapazität wächst, sobald eine Ruine mit `stash_access` (Old Storehouse) restauriert ist (später
  auch „revitalized“). Sie sinkt nie, deshalb wird nie etwas verdrängt.
- **Nie einlagerbar:** Gold (`is_currency`, bleibt Zähler in der Tasche), Quest-Items (Story-Ziele zählen
  die Tasche) und ausgerüstete Items (in irgendeinem Klassen-Loadout).

## Transfers (`StashService`)
- `deposit` / `withdraw` prüfen erst vollständig und ändern dann. Beide sind **alles oder nichts**; im
  Fehlerfall gibt es eine verständliche Begründung, und nichts ändert sich.
- **Ausrüstung** wird als Instanz verschoben, nie kopiert. ID, Affixe, Essenzen, Sockel, Qualität, Material
  und Evolution bleiben erhalten.
- **Stapel:** Gemischt wird nur mit Stapeln derselben Definition ohne Instanzzustand („schlicht“). Erst
  werden vorhandene Stapel aufgefüllt; der Rest behält seine Instanz-ID. Stapel mit eigenem Zustand bleiben
  getrennt.
- **Entnehmen:** Passt ein Stapel nicht vollständig in die Tasche, wird abgelehnt (kein Teiltransfer).
- `deposit_all_materials` lagert jeden Stapel der Kategorie MATERIAL ein (Erze, Essenzen, Komponenten);
  Tränke bleiben in der Tasche. Jeder Einzeltransfer ist atomar.
- `sort` ändert nur die Reihenfolge (Kategorie, Seltenheit, Name), nie IDs oder Mengen.
- **Presets:** Ein Preset-Item im Lager macht das Preset ungültig. Die Meldung sagt dann „is in the Haven
  stash – take it out to use this preset“.
- Sehr schnelle Wiederholungen (Rechtsklicks auf veraltete Zellen) werden abgelehnt („no longer in your
  bag“), nie doppelt ausgeführt.
- `ownership_errors` prüft die Konsistenz: keine ID in beiden Containern, kein Loadout-Verweis ins Lager,
  Integrität beider Container.

## Haven
- Zugang über das **Old Storehouse** (`RuinDefinition.stash_access`), schon im Zustand **Ruined** (Grundlager).
- Interagieren öffnet immer das Lager. Ist das Haus noch eine Ruine, bietet das Fenster „Restore the
  Storehouse“ an; das ist der bestehende, atomare Restaurierungsablauf.
- Die Restaurierung zahlt aus der **Tasche**. Eingelagerte Materialien zählen dafür nicht, wie bei allen
  Restaurierungen und beim Crafting.
- Keine frei platzierbaren Gebäude.

## Oberfläche (`StashPanel`, „The Forgotten Chronicle“)
- **Aufbau:** Tasche links, Lager rechts mit drei Tabs, Kapazität, „Deposit All Materials“ und „Sort“.
  Darunter ein Hinweis und eine Statuszeile für Erfolg oder Ablehnungsgrund.
- **Bedienung:** Rechtsklick lagert ein (Tasche) bzw. entnimmt (Lager). Drag & Drop geht zwischen beiden
  Rastern in beide Richtungen. Nach dem Einlagern zeigt das Fenster die Kategorie des Items.
- **Hover:** sofortiger `ItemTooltip` mit „EQUIPPED“-Vergleich (auch für Lager-Items).
- **Layout:** Beide Raster bleiben bei jeder UI-Skalierung nebeneinander, bei Bedarf mit weniger Spalten.
  Jedes Raster scrollt für sich, beide bleiben gleichzeitig sichtbar, damit Ziehen nie Fensterscrollen
  braucht.
- Kein Discard, keine Platzhalterknöpfe. Außerhalb des Lagers bleibt der Rechtsklick im Inventar
  „Equip/Unequip“.

## Save
Save-Version 6 (`stash.items`), Migration 5→6 mit leerem Lager. Doppelte IDs zwischen Tasche und Lager
werden beim Laden nicht doppelt geladen, sondern als Orphan behalten. Details: `docs/SAVE_SYSTEM.md`.
