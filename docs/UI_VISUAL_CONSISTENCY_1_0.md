# UI Visual Consistency 1.0 - Global Theme Color Pass

Die prozeduralen UI-Flächen folgen jetzt denselben Designankern wie die UI-Art (Charcoal `#191B20`,
Slate `#30343B`, Steel `#777C83`, Parchment `#C7BDAA`, Old Gold `#B39A70`). Ein universelles Theme, keine
Varianten nach Region, Kapitel, Akt, Biom oder Tageszeit. Keine neuen Assets, keine Layout- oder Fontänderung.

## Geänderte Tokens (`scripts/ui/ui_theme.gd`, nur neutrale UI-Dekoration)
| Token | vorher (grünlich) | jetzt |
|---|---|---|
| `BG` | `#171C1A` | `#16181C` |
| `PANEL` | `#252E28` | `#23262C` |
| `PANEL_ELEVATED` | `#303A33` | `#30343B` (Slate) |
| `PANEL_INSET` | `#1C2320` | `#191B20` (Charcoal) |
| `TEXT_SECONDARY` | `#AFB9AD` | `#B3AEA4` |
| `TEXT_MUTED` | `#7F877E` | `#85827B` |
| `COLOR_PANEL` | (0,145 / 0,18 / 0,157) α 0,94 | `PANEL` α 0,94 |
| `COLOR_WINDOW` | (0,145 / 0,18 / 0,157) α 0,99 | `#1D1F24` α 0,99 |
| `COLOR_BUTTON` / `_HOVER` / `_DISABLED` | `#2C3630` / `#37443B` / `#1F2622` | `#2E3238` / `#383C44` / `#1F2125` |
| `COLOR_BUTTON_PRESSED` | `#3D3A2C` | `#3B372F` (bleibt warm: gedrückt = Bronze-Richtung) |

Über die Tokens folgen automatisch: Fenster-/HUD-/Karten-/Inset-Panels, Tooltips, Buttons aller Varianten,
Tabs, Slots, `ItemIcon`-Hintergrund, Menüleistenzellen, Minimap-Rahmen, Titelbildschirm-Silhouetten.

## Bewusst unverändert
- Semantik: `HEALTH`, `POISE`, `RESONANCE(_DIM)`, `SUCCESS`, `WARNING`, `DANGER`, `XP`, Rarity-Farben
  (`UiTheme.RARITY`), Kartenmarker (`MAP_*`), Klassen-/Baumfarben, Danger-Button (rot).
- Akzente: `BRONZE` / `BRONZE_DIM` / `BRONZE_DARK`, `PARCHMENT`, `TEXT_PRIMARY`.
- Warme Ledertöne der Seitenregister (`BookTabs`), Glyphenfarben in `ItemIcon` (Itemsemantik).
- Welt: Gelände, Effekte, Monster. Das Kartenbild (`AreaMap` FLOOR/WALL, leicht grün) ist Teil der Karten-
  darstellung und blieb unverändert (Weltkarten im Auftrag geschützt) - verbleibender Stilbruch.
- Menüleiste: 85-%-Ruhedimmung bleibt. Belegt mit Kontrast auf `PANEL_INSET`: Stahl 3,12 : 1, Gold 4,67 : 1,
  Pergament 6,66 : 1 (≥ 3 : 1 für Grafiken); Hover/aktiv bleiben über Fläche, Rand und volle Helligkeit getrennt.

## Kontrast (WCAG, vorher → nachher)
Textfarben auf `BG` / `PANEL` / `PANEL_ELEVATED` / `PANEL_INSET` gleich oder besser, z. B. `TEXT_PRIMARY` auf
`PANEL` 10,41 → 11,27, `TEXT_MUTED` auf `PANEL` 3,78 → 3,95, `DANGER` auf `PANEL` 4,27 → 4,63; `TEXT_SECONDARY`
minimal schwächer (6,91 → 6,86), weiter deutlich über 4,5 : 1.

## Prüfung
Suites `ui_layout_lock`, `ui_window_foundation`, `hud`, `hud_xp_bar`, `class_ui`, `world_ui` (38/38),
Startprüfung OK; Gallery (HUD, Boss, Inventar+Tooltip, Journal, Talente, Karte, Optionen, Berufe, Lager) bei
1080p/1440p/4K 100 % (75 Checks) und 1080p 75/150 % (50), `ui_art_check` 1080p/1440p (34): alle OK.
Sichtprüfung der Screenshots, nativ vergrößert (kein manueller Gameplay-Playtest).
