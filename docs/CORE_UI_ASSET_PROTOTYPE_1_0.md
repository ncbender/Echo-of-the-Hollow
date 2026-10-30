# Core UI Asset Prototype 1.0

Erster Satz echter UI-Pixel-Art: acht Einzel-PNGs (RGBA), reproduzierbar erzeugt, über das bestehende
`UiSkin` eingebunden. Kein Atlas, keine neue Skin-Architektur, kein Layout verschoben.

## Dateien
| Asset-ID | Größe | NinePatch | Inhalt |
|---|---|---|---|
| `window/panel` | 48 × 48 | 12 | Tinte, abgeschrägtes Stahlband, Tinte, 1-px-Goldlinie, Schiefer-Passepartout, flaches Charcoal-Zentrum; goldene Eckwinkel + Niet nur in den 12-px-Ecken |
| `button/normal`, `button/hover` | 24 × 24 | 4 | Tinte, Stahlrand, Fase, flacher Schiefer; Hover gleiche Geometrie, heller |
| `slot/normal`, `slot/selected` | 24 × 24 | 4 | Vertiefte Mulde; Selected = 2-px-Goldrand, gleiche Geometrie |
| `hud/slot_frame` | 64 × 64 | – (ganz gezeichnet) | Stahlrahmen, Gold-Eckwinkel, Tastenplatte oben links, Innenfläche Charcoal α 232 |
| `menu/inventory`, `menu/journal` | 32 × 32 | – | Rucksack, Buch; transparent, Tintenkontur + Randschattierung |

Palette: Charcoal `#191B20`, Slate `#30343B`, Steel `#777C83`, Parchment `#C7BDAA`, Old Gold `#B39A70` plus
wenige abgeleitete Töne (Tinte `#0E0F12`, hellere/dunklere Stufen; Liste in `PALETTE` des Generators).

## Werkzeuge
- `py -3 tools/ui_art/generate_core_ui_assets.py [--force] [--preview DIR]` - schreibt nur fehlende Dateien
  (`--force` ersetzt sie); Rahmen über Querschnittsprofile (Kanten längs gleichförmig, Zentrum flach),
  Icons über Formen + automatische Kontur/Schattierung.
- `py -3 tools/ui_art/validate_ui_assets.py [--render DIR]` - Pfade, Maße, RGBA, harte Alpha (0/255, HUD-Innen
  232), nur Palettenfarben, NinePatch-Kanten gleichförmig und Zentrum flach, gleiche Geometrie der Zustände,
  Icons ohne Hintergrund; `--render` streckt das Fenster auf 320×160, 800×700, 1200×850.
- `tests/playtest/ui_art_check.gd` (Fenster): Inventar mit ausgewähltem Taschenslot und echtem Maus-Hover
  über einem Button, Journal, HUD; Layoutprüfung + Screenshots `tests/output/ui_art/`.
- Godot-Import: verlustfrei, keine Mipmaps, Nearest (Projektstandard).

## Code
- `HudSlot`: fehlt `hud/slot_frame_disabled`, zeichnet ein nicht nutzbarer Slot den vorhandenen Rahmen
  abgedunkelt (eine Optik pro Leiste); ohne jede Grafik unverändert prozedural.
- `test_ui_window_foundation`: Fallback-Prüfung mit einer garantiert fehlenden ID (es gibt jetzt echte Art).

## Offen (bewusst nicht in diesem Batch)
- Fehlende Zustände fallen prozedural zurück: Primary-Buttons, Karten-/Inset-/Tooltip-Panels, Scrollbars
  (Button-/Slot-/Tab-Zustände und HUD-Slot disabled: erledigt in `docs/UI_CORE_STATES_1_0.md`).
- `UiTheme`-Farbtokens (Panels, `ItemIcon`-Hintergrund) sind noch grünlich - sichtbarer Kontrast zu Charcoal/Slate.
- Fenster ohne Schlagschatten (StyleBoxTexture hat keinen). (Menü-Icons: erledigt in Menu Icons 1.0, s. u.)

## Menu Icons 1.0 (Folgebatch)
Alle sieben Menü-Icons als eine Familie aus demselben Generator (`menu_*` in
`tools/ui_art/generate_core_ui_assets.py`), 32 × 32, Motiv ~22–26 px zentriert, 380–480 deckende Pixel:
| Datei | Motiv | Material + Akzent |
|---|---|---|
| `menu/inventory.png` | Rucksack | Altgold-Leder, Stahlschnalle |
| `menu/character.png` | geschlossener Helm | Stahl, Goldkamm + Stirnband |
| `menu/skills.png` | Vierpunkt-Funke durch einen Siegelring | Gold, Stahlring |
| `menu/professions.png` | Hammer über Amboss | Stahl, Goldgriff |
| `menu/journal.png` | Codex mit Lesebändchen | Stahl, Pergament, Goldbeschlag |
| `menu/map.png` | gefaltete Karte mit Route und Pin | Pergament, Gold-Pin |
| `menu/settings.png` | Zahnrad | Stahl, Goldnabe |

Gemeinsame Regeln: 1 px Tintenkontur + 1 px Randlicht (oben links hell, unten rechts dunkel), Tinte nur für
Öffnungen und Trennkanten. `HudMenuBar.ENTRIES` trägt pro Eintrag den Icon-Namen (Skills & Talents = `skills`).
Prüfung: `validate_ui_assets.py` (13 Dateien), `ui_art_check.gd` prüft, dass jeder Eintrag seine Grafik lädt.
