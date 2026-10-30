# Main Window Layout Lock 1.0 - Compact Unified Main Menus

Die sieben Hauptmenüs (I Inventory, C Character, T Skills & Talents, P Professions, J Journal, M Map,
O Options) teilen **ein** äußeres Fenster. Ausnahmen: Tooltips, Dialoge, Bestätigungen, kleine Popups,
Werkstatt-/Lager-/Belohnungsfenster.

## Maße

| | vorher (1080p / 100 %, gemessen) | jetzt |
|---|---|---|
| Inventory / Character | 1402 × 760 | 1120 × 760 |
| Skills & Talents (Klassenstation) | 1772 × 1048 (ganze Canvas) | 1120 × 760 |
| Professions | 1062 × 820 | 1120 × 760 |
| Journal | 806 × 760 | 1120 × 760 |
| Map | 1346 × 831 | 1120 × 760 |
| Options | 800 × 700 | 1120 × 760 |

`UiTheme.MAIN_WINDOW_SIZE = (1120, 760)` Design-px. Position: für alle gleich - zentriert mit dem Platz der
Buchregister (116 px) immer reserviert (`UiWindow.main_window`, `_register_room`), also dasselbe Rechteck mit
und ohne Register (1080p / 100 %: x 458, y 160).

Begründung: Der Inhaltsbedarf (gemessen über `preferred_body_size`) lag nach dem Umbau bei 1032-1076 px
Breite (Inventar, Talente, Berufe, Klassen); Körper = 1120 − 36 = 1084. Die Breite 1120 ist die größte, die
die 150-%-Canvas (1280) neben den Registern noch zulässt (1280 − 32 − 116 = 1132) - damit ist die Breite bei
75 / 100 / 125 / 150 % gleich. Höhe 760 trägt Paper Doll (576), Kartenfläche und Talentbäume; bei 150 %
(720 hoch) begrenzt die Canvas alle sieben Fenster gleich auf 688 (dort scrollen die inneren Bereiche).

## Struktur der Menüs

| Menü | Aufbau | eigene Scrollbereiche |
|---|---|---|
| Inventory / Character | links Seite (Equipment-Doll / Overview / Details), rechts Tasche (9 Spalten) mit Kategorien, Sort, Gold, Hinweis, Status | `LeftScroll` (Doll, Overview, alle Details-Werte), `BagScroll` |
| Skills & Talents | Kopfzeile, Seite (Classes: 2 Kartenspalten + Details; Talents: Bäume passen sich `body_room()` an; Skills: 4 Slot-Karten in einer Reihe, Mod-Dropdowns fester Breite) | Fensterkörper; `TreeScroll` |
| Professions | Berufe-Karten links, Detail rechts mit Suche + Rezeptliste + Rezeptkarte, Craft im Footer | `RecipeScroll` (Liste), Fensterkörper |
| Journal | Tabs fest; links Questliste (Kapitel, Titel, Status, Belohnungszeile), rechts Details der gewählten Quest; Haven über die ganze Breite | `QuestList`, `QuestDetail` |
| Map | Area: Karte so groß wie der Körper erlaubt (max. 1060 × 620), Legende darunter; Region: Graph | `RegionScroll` |
| Options | Tabs fest, Seite, Reset fest unten; Steuerung zweispaltig | `PageScroll` |

Inventar: kein „Empty“ an leeren Slots, kein Erklärtext über der Doll, kein dauerhaftes „No item
selected“-Panel (Beschreibung und Vergleich = Hover-Tooltip), Details ohne Einleitungssatz.

## Regeln

- Neues Hauptmenü: `main_window = true` im `_ready`, nie eigene `stable_size`; Inhalte, die den Körper
  füllen, rechnen mit `body_room()`, nie mit der Canvas.
- Breiter als der Körper (1084) darf keine Seite werden (`test_main_window_layout`); lange Listen scrollen in
  einem eigenen `ScrollContainer` mit `SIZE_EXPAND_FILL`.

## Tests

`test_main_window_layout` (alle Menüs und Seiten: gleiches Rechteck bei 75 / 100 / 125 / 150 %, im Bild,
Register im Bild, nichts breiter als der Körper; innere Scrollbereiche, Journal Liste | Details mit jedem
Schritttext). Galerie: `inventory_overview`, `inventory_details` (neu) und die bestehenden Fenster-Szenen.


> **Playtest Corrections 1.0:** Die sieben Hauptmenüs zeigen keinen Close-Button mehr (Esc, eigene Taste, Menüicon);
> die Close-Zeile entfällt, ihr Platz gehört dem Inhalt. Rahmen 1120 × 760 und Position unverändert.
