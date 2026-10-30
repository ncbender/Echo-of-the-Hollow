# UI Scrollbars & Input Fields 1.0

Dark Classic Pixel Art für Scrollbars und Eingabefelder, über die bestehende Architektur (`UiSkin` +
`UiTheme.SKINNED`, keine neue Skin-Logik). Ohne die PNGs bleibt der prozedurale Fallback.

## Assets (reproduzierbar: `py -3 tools/ui_art/generate_core_ui_assets.py`)

| Id | Größe | Rand (`UiSkin.PATCH`) | Aufbau |
|---|---|---|---|
| `scroll/track` | 10 × 10 RGBA | 3 | vertiefte Rinne: Ink, dunkle Lippe (Plate / Slate dunkel), flaches Charcoal |
| `scroll/grabber` | 10 × 10 RGBA | 3 | erhabener Stahlbalken: Ink, Licht oben/links, Schatten unten/rechts, flaches Steel; 1 px Fase |
| `input/normal` | 24 × 24 RGBA | 4 | Schreibmulde: Ink, Steel-dunkel-Rand, Innenschatten oben/links, flaches Charcoal |
| `input/focus` | 24 × 24 RGBA | 4 | gleiche Geometrie, Rand in Resonanz (#78B8C5 / #4D7A83) - Tastaturfokus, nie Gold |
| `input/disabled` | 24 × 24 RGBA | 4 | Rand sinkt ins Dunkel, Mulde im Plate-Ton |

Beide Scroll-Bilder sind diagonal-symmetrisch (Bild = Transponierte): derselbe Rahmen für horizontale und
vertikale Leisten, keine richtungsabhängigen Ornamente.

## Theme (`scripts/ui/ui_theme.gd`, `ui_skin.gd`)

- `PATCH`: `input/normal|focus|disabled` = 4 (Scroll-IDs waren schon mit 3 eingetragen).
- `SKINNED`: LineEdit `normal` → `input/normal`, `focus` → `input/focus`, `read_only` → `input/disabled`.
  Scroll: `grabber_highlight` / `grabber_pressed` nutzen dasselbe Bild mit Tönung
  (`GRABBER_HOVER_TINT` 1,18, `GRABBER_PRESSED_TINT` 1,32) - Hover/Drag sichtbar, ohne Extra-PNG.
- LineEdit: `caret_width` 2 (bleibt bei 75 % sichtbar), `font_uneditable_color` = TEXT_MUTED.
- Content-Margins unverändert aus dem Fallback (LineEdit 8 px, Scrollbar 5 px → 10 px dicke Leiste):
  keine Layoutverschiebung.

## Prüfung

- `tools/ui_art/validate_ui_assets.py`: 35 PNGs, Maße, RGBA, harte Alpha, Palette (+ Resonanz-Paar),
  Nine-Patch-Ränder, gleiche Geometrie der Input-Zustände, H/V-Symmetrie, Grabber-Kontrast (Luma 123 vs 27).
- `tests/playtest/ui_art_check.gd`: Zustandstafel (Scroll- und LineEdit-Styles), Live-Tafel `inputs` (Klick-Fokus,
  getippter Text, Mausrad, Grabber-Drag nur vertikal, Klick in die H-Rinne blättert), `professions_search`
  (Klick, Tippen, Fokus bleibt, Feldhöhe gleich, Textzeile passt); 1080p 75/100/150 %, 1440p, 4K.
