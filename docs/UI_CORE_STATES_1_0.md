# UI Core States & Map Palette 1.0

Die fehlenden zentralen Grafikzustände und neutrale Karten-/Minimap-Töne. Kein neues Design, keine Layout-,
Font-, Gameplay- oder Save-Änderung. Generator/Validator: `tools/ui_art/` (`docs/CORE_UI_ASSET_PROTOTYPE_1_0.md`).

## Neue PNGs (alle RGBA, harte Pixel, Palette wie die bestehenden 13)
| Datei | Größe | NinePatch | Zustand |
|---|---|---|---|
| `button/pressed.png` | 24 × 24 | 4 | Fase umgekehrt (dunkel oben/links), Bronze-Rand: eingedrückt = ausgewählt (auch Toggle-Buttons) |
| `button/disabled.png` | 24 × 24 | 4 | flach, gedämpfter Stahlrand, dunkle Fläche |
| `slot/hover.png` | 24 × 24 | 4 | hellerer Stahlrand, etwas hellere Mulde (nie Gold) |
| `slot/disabled.png` | 24 × 24 | 4 | Rand versinkt, dunklere Mulde |
| `tab/normal.png`, `tab/hover.png`, `tab/selected.png` | 24 × 24 | 4 | Platte mit gekappten oberen Ecken, 3-px-Unterstrich (Zeilen 20-22): Stahl dunkel / Stahl / Altgold |
| `hud/slot_frame_disabled.png` | 64 × 64 | – | gleiche Form und Tastenplatte, Stahl und Goldwinkel abgesenkt |

Geometrie (Alpha-Maske) je Gruppe identisch; die 13 bestehenden Dateien sind unverändert (Prüfsummen).
Tab-Unterstrich 3 px statt 2: bei 75 % UI-Skala verschwand eine 2-px-Linie vollständig (Sichtprüfung).

## Karte und Minimap (`scripts/world/area_map.gd`)
| | vorher | jetzt |
|---|---|---|
| FLOOR | `#334036` (0,2 / 0,25 / 0,21) | `#393D44` (0,225 / 0,24 / 0,265) |
| WALL | `#171F1A` (0,09 / 0,12 / 0,10) | `#1B1C20` (0,105 / 0,11 / 0,127) |

Kontrast (WCAG) vorher → jetzt: Boden : Wand 1,55 → 1,56; gedimmt (Fog 32 %) 1,27 → 1,28; Wand : unerkundet
1,20 → 1,19; Boden : Seitenpfad 1,30 → 1,29. Die Farben sind zugleich Klassen für `is_solid` (Toleranz 0,01):
kein Paar kollidiert, Abstand Wand/VOID 0,077 (vorher 0,075). Unverändert: VOID, SIDE, ROAD, Fog (`MapFog`),
Marker, Erkundungslogik, gespeicherter Fog, Save v15, Weltgrafik.

## Offen
- `BookTabs` (Seitenregister von Class Station und Professions) zeichnen sich selbst (`BookTab`-Typ, eigene
  Ledertöne) und nutzen `UiSkin` nicht.
- Ohne Grafik weiter prozedural: Danger-/Card-/Flat-/Option-/Check-Buttons, `TabButton`-disabled, `scroll/*`
  (Primary-Buttons und Panels: erledigt in `docs/UI_PANELS_PRIMARY_1_0.md`).
- Kartenlegende „Explored“ zeigt weiterhin den ROAD-Ton (unverändert, nicht FLOOR).

## Prüfung
Validator (21 Dateien) OK; Generator reproduziert alle 21 pixelgenau. `ui_art_check.gd` mit Zustandstafel
(jede Zustands-StyleBox ist die Grafik), echtem Hover über Button und Taschenzelle, Toggle-, Disabled- und
Tab-Zuständen, Karte und HUD: 1080p 75/100/150 % (96) und 1440p/4K 100 % (64) OK. Suites `map_fog`,
`quest_turnin_mara_ui`, `ui_window_foundation`, `ui_layout_lock`, `hud`, `hud_xp_bar` (44/44), Startprüfung OK.
