# UI Usability & Haven Crafting 1.0

Vier beobachtete Probleme, behoben ohne neue Assets, ohne Save-Änderung (v15 bleibt, keine Migration).

## 1. Zahlen in Statusbalken

**Ursache:** Die Balkentexte waren `Label`s über voller Balkenfläche. Ein Label hat als Mindesthöhe die volle
Zeilenhöhe der Schrift (IBM Plex Mono 13 px: ~18–20 px + Rand = 23 px), die Balken sind 18 / 12 / 14 px hoch
(Leben, Ressource, EXP). Der Container vergrößerte das Label über den Balken hinaus; vertikal zentriert wurde die
Zeilenbox (Ascent + Descent), nicht die Ziffern - die Zahl saß zu tief bzw. ragte heraus, je nach Skalierung um
einen anderen Pixelwert.

**Lösung:** `BarText` (`scripts/ui/hud/bar_text.gd`) zeichnet den Text selbst:
- horizontal mittig, vertikal auf die Tinte der Ziffer „0“ (Glyph-Offset/-Größe aus dem TextServer) zentriert,
  auf ganze Pixel gerundet;
- passt die Schriftgröße schrittweise an (bis `min_font_size` 9), bis Ziffernhöhe + Kontur und Breite in den Balken passen;
- ignoriert die Maus, ändert nie die Balkengröße.

Verwendet in `PlayerFrame` (Leben, Ressource) und `HudXpBar` (426 × 14, 6 px unter der Kampfleiste, unverändert).
Ergebnis bei 75–150 %: Leben 13 px, Ressource ≈ 9–10 px, EXP 12 px; für „0%“ … „MAX“ gilt je Skalierung eine Größe.

## 2. Tab-Fenster mit fester Geometrie

`UiWindow.stable_size` (Design-px, äußere Größe; eine 0-Komponente = Achse nach Inhalt, Scrollbalken immer
reserviert). Inhalt scrollt innen, wenig Inhalt lässt freien Raum. Bei Seiten-/Tabwechsel `reset_scroll()`.

| Fenster | vorher (1080p/100) | jetzt |
|---|---|---|
| Inventory (Equipment/Overview/Details × Kategorien) | 1370–1650 × 691–1048 | Höhe 760, linke Spalte auf Paper-Doll-Breite fixiert |
| Journal | 405 → 709/1048 hoch | Höhe 760 |
| Professions (Seiten × Berufe) | 455–951 hoch | Höhe 820, Detailbreite 740 |
| Map (Area/Region) | 876 / 1336 breit | 1346 × 831 |
| Options | 459 / 987 hoch | 800 × 700 |
| Class Station | bereits stabil | unverändert |

## 3. Professions: Rezeptliste und Suche

Aufbau des Crafting-Beruf-Details: Kopf (Beruf, XP, Werkstatt) → `RECIPES` → `RecipeBench`:
links eine Spalte (300 px) mit `RecipeSearch` (LineEdit) über `RecipeScroll` (ScrollContainer 300 × 300,
vertikaler Balken immer sichtbar) mit `Recipes`; rechts die Rezeptkarte (`RECIPE_CARD_WIDTH`).
- Zeilen 40 px, lange Namen mit „…“ gekürzt, Tooltip = voller Name (+ Sperrgrund).
- Mausrad über der Liste: nur die Liste scrollt (`_on_recipe_list_input`, `accept_event`); außerhalb unverändert.
- Neuaufbau (Auswahl, Craft) behält die Listenposition; neue Seite/neuer Beruf: oben, Suche leer.

Suche: Platzhalter „Search recipes...“, filtert live beim Tippen (nur die Liste wird neu gefüllt, der Fokus
bleibt im Feld), ohne Groß-/Kleinschreibung, über Rezeptname, Ergebnis- und Materialnamen. Kein Treffer:
„No recipes found.“; leeres Feld zeigt alles. Die Suche filtert nur die Rezepte, die der Beruf ohnehin zeigt
(`ProfessionService.recipes_of`) - sie deckt nichts Gesperrtes/Geheimes zusätzlich auf. Pro Beruf (Wechsel leert sie).

## 4. Haven-Crafting mit Tasche + Lager

Entscheidung: an **jeder** Haven-Werkbank und der Schmiede **immer** Tasche + Haven-Lager, in jeder Stufe des
Old Storehouse (vorher erst nach dessen Restaurierung). Außerhalb einer Haven-Ruine nie.

Datenfluss: `ProfessionService.uses_stash(character, station_id)` (Station ist eine Haven-Ruine) →
`ProfessionService.material_plan(character, inputs, with_stash)` → `{plan: [{item_id, bag, stash}], missing}`.
Derselbe Plan dient Anzeige („24 / 3  (bag 18, stash 6)“), Prüfung und Verbrauch (`consume_plan`).
- Berufe: `ProfessionService.craft` (Rezept gelernt, Werkstatt, Stufe, Platz für das Ergebnis - alles vorab).
- Schmiede: `BaseBuilder.craft_error/craft(character, recipe, with_stash)`; Anzeige in `BuildPanel`
  (Fenster „Smithy“) und `CraftingPanel`; Baukosten (`BaseBuilder.build`) bleiben taschengebunden.
- Restaurierung: `RestorationService.uses_stash` = immer (Haven).

Transaktionssicherheit: Erst vollständige Prüfung (Summe Tasche + Lager, Ergebnisplatz), dann Verbrauch erst Tasche,
dann Lager, dann Ergebnis in die Tasche; scheitert das Ablegen, `refund_plan` zurück in die Quellen. Kein
Teilerfolg, keine Doppelung, kein Verlust; das Ergebnis landet immer in der Tasche (Stack-Regeln).

## Tests

- `test_ui_usability` - Balkentext zentriert/innerhalb bei 75/100/125/150 %, kurze/lange Zahlen, %, MAX;
  Suche Treffer/kein Treffer/Löschen/Berufswechsel; Liste begrenzt, Mausrad innen/außen, lange Namen.
- `test_ui_tab_geometry` - konstante Außengeometrie und Titelzeile bei 100/125/150 %.
- `test_haven_crafting` - Fälle A–K und Schmiede.
- Galerie: neue Ansicht `recipes_stash` (Schmiede mit Lageraufteilung).
