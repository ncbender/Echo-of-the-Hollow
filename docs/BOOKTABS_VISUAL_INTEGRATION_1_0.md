# BookTabs Visual Integration 1.0

Die Buchregister links an Klassenstation (Classes … Weapons) und Professions (Crafting, Gathering, Salvage)
im universellen Dark-Classic-Stil. Keine Layout- oder Funktionsänderung; Fenster bleiben 1120 × 760
(Main Window Layout Lock 1.0), Registerplatz (`BookTabs.reserved_width` 116) unverändert.

> **Menu UX Polish 1.1:** Register liegen hinter dem Fenster (z -1) bis unter den Rahmen; der gewählte liegt davor
> und reicht bis an die Seite (`BookTabs.bridge`, `UiWindow.tab_bridge`). Professions nutzt wieder dieselben Register
> (Crafting / Gathering / Salvage). Siehe `docs/MENU_UX_POLISH_1_1.md`.

## Bestand (`scripts/ui/book_tabs.gd`)

- `BookTabs` (VBox, Abstand 4): pro Seite ein `BookTabButton` 112 × 46, der gewählte 122 × 46 (ragt 10 px
  weiter heraus); 6 px liegen unter dem Fensterrahmen (`OVERLAP`). Toggle-Gruppe, Fokus per Tastatur.
- Styles waren Instanz-Overrides mit braunen „Leder“-Flächen außerhalb der Palette; Stiche + Niete per `_draw`.
- Disabled wird nirgends benutzt. Die vorhandenen `tab/*`-PNGs passen nicht (waagerechte Tabs, Unterstrich unten).

## Neue PNGs (reproduzierbar, `tools/ui_art/generate_core_ui_assets.py`)

| Id | Größe | Rand | Zustand |
|---|---|---|---|
| `booktab/normal` | 24 × 24 | 4 | dunkles Slate, Steel-dunkler Rand |
| `booktab/hover` | 24 × 24 | 4 | helleres Slate, Steel-Rand |
| `booktab/selected` | 24 × 24 | 4 | Old-Gold-Rand um die hellste Fläche (= Kartenauswahl) |

Ringe nur links / oben / unten, rechts offen zur Seite (Validator prüft es); gleiche Geometrie aller Zustände.
Disabled = `booktab/normal` mit `CARD_DISABLED_TINT` (kein PNG). Fokus = eigene quadratische Cyan-Kontur 3 px
außerhalb, rechts offen - Auswahl (Gold) und Fokus (Cyan) zugleich sichtbar.

## Code

- `UiSkin.PATCH`: `booktab/*` = 4. `BookTabButton` nutzt `UiSkin.stylebox` (die bisherigen Flat-Styles bleiben
  Fallback); Stiche und Niete ganzpixlig in Palettenfarben (Gold am gewählten Register).
- Schrift 16 statt 18, Innenabstand 18 / 6 statt 24 / 8: „Gathering“ ragte vorher als *inaktives* Register 129 px
  breit weiter heraus als das gewählte (122). Jetzt sind alle inaktiven Register 112 px, jede Beschriftung endet
  vor dem Teil unter dem Rahmen.

## Prüfung

`tests/playtest/ui_art_check.gd`, Szenen `booktabs_class`, `booktabs_professions`: Art aktiv, gewähltes Register
ragt heraus, Hover (echte Maus) + Fokus auf dem gewählten, Fokus auf einem anderen, Rahmen bewegt sich nie,
jede Beschriftung passt, inaktive Register 112 px - 1080p 75 / 100 / 150 %, 1440p, 4K.
