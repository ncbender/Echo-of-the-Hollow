# UI Panels & Primary Controls 1.0

Neun weitere Einzel-PNGs im bestehenden Stil (Generator/Validator `tools/ui_art/`), über die vorhandenen
`UiSkin`-IDs eingebunden. Einzige Code-Ergänzung: die Zuordnung `PrimaryButton.disabled` →
`button/primary_disabled` (`UiTheme.SKINNED`) samt `UiSkin.PATCH`-Rand 4. Kein Layout-, Font- oder Gameplay-Eingriff.

## Neue PNGs (RGBA, harte Pixel, Palette)
| Datei | Größe | NinePatch | Gestaltung |
|---|---|---|---|
| `button/primary_normal.png` | 24 × 24 | 4 | doppelter Goldrahmen, warme Fläche `#3B372F`, erhabene Fase |
| `button/primary_hover.png` | 24 × 24 | 4 | Gold heller, Fläche `#46413A` |
| `button/primary_pressed.png` | 24 × 24 | 4 | Fase umgekehrt, dunkle warme Fläche `#2E2B25` |
| `button/primary_disabled.png` | 24 × 24 | 4 | schwache Bronzespur `#4A4134` auf Schiefer - inaktiv, aber als Hauptaktion lesbar |
| `panel/hud.png` | 24 × 24 | 6 | Tinte + dunkler Stahlrand, Fläche `#16181C` α 200 (≈ 78 %), dunkelgoldene Eckhäkchen |
| `panel/card.png` | 24 × 24 | 6 | Tinte, dunkler Stahl, Innenlicht, flacher dunkler Schiefer, Eckhäkchen |
| `panel/card_selected.png` | 24 × 24 | 6 | gleiche Geometrie, Altgoldrand über Dunkelgold, helle Eckhäkchen |
| `panel/inset.png` | 16 × 16 | 4 | vertieft: dunkel oben/links, helle Unterlippe, flaches Charcoal |
| `tooltip/panel.png` | 24 × 24 | 6 | ruhiger Rahmen (Tinte, dunkler Stahl) um `#16181C`, Eckhäkchen |

Abgrenzung: Primary normal (doppeltes Gold, warme Fläche) ≠ normaler Button pressed (ein Bronzerand, dunkle
Fläche, umgekehrte Fase). Ornamente nur in den Eckquadraten; Kanten längs gleichförmig, Zentren flach.
`tooltip/panel` gilt für Godots Text-Tooltips (`TooltipPanel`); Item-Tooltips bleiben `window/panel`.

## Prüfsummen der 21 vorherigen PNGs (unverändert, MD5)
| Datei | MD5 |
|---|---|
| `button/disabled.png` | `b74c194bb7fcca32d9b68b1a22a48c06` |
| `button/hover.png` | `10833cbf8e11be74d80ccd0be89d3284` |
| `button/normal.png` | `9c2c43e610b98cce9f73c40e5124a360` |
| `button/pressed.png` | `327f1550a7f522a1969a00bcd82b583c` |
| `hud/slot_frame.png` | `491cff95a83091b073224c7aadb3d590` |
| `hud/slot_frame_disabled.png` | `9d34c1f95b7e4ab818f21c6fc260930d` |
| `menu/character.png` | `a52e56495cfb5a5be3c8dad02b1a5c54` |
| `menu/inventory.png` | `cde6fe577e3b1b4837d1d26ee4df03b3` |
| `menu/journal.png` | `34b905d286249697fe2949f045aa45b9` |
| `menu/map.png` | `18a8e6bdf339ab5f71220fefabd9e63b` |
| `menu/professions.png` | `cb65be440959fa0a8e1ff35d2ec5bb3d` |
| `menu/settings.png` | `a3eaf42c59eb9edb6440f2772c785602` |
| `menu/skills.png` | `4c742901d9c4c4cd59b3ca55a84228c6` |
| `slot/disabled.png` | `c5479c4d4f9d4e9fc1d852326b71099a` |
| `slot/hover.png` | `38648e0720af699614a0bc4a891b1d8b` |
| `slot/normal.png` | `abbd4a0efa11e3c8dc526f6ea7a3a533` |
| `slot/selected.png` | `78837dc26a5dcf296ef58186d8dc72be` |
| `tab/hover.png` | `a8d56dadd58051b6f14d1d0ac2ff9898` |
| `tab/normal.png` | `bd81ac2732695553dad7ad1cff9db111` |
| `tab/selected.png` | `d1ad2d71c921b29ab3594f6fb280898c` |
| `window/panel.png` | `2e64cacd80ae11a12e7012c4ae2021f5` |

## Offen
- (Fenster und Item-Tooltips: gelöst in `docs/UI_SELECTION_POLISH_1_0.md`; Text-Tooltips offen.) `StyleBoxTexture` hat keinen Schlagschatten: Fenster und Tooltips mit Grafik verlieren den Schatten der
  prozeduralen Variante (Fenster 10 px, Tooltip 6 px). Bewusst nicht über große transparente PNG-Ränder gelöst
  (würde Content-Margins und Mindestgrößen verschieben). Möglich später: `expand_margin_*` plus eigenes
  Schatten-Asset oder eine Schatten-StyleBox unter dem Fenster.
- Ohne Skin-ID und weiter prozedural (`CardButton` seit UI Selection & Surface Polish 1.0 erledigt): `DangerButton`, `FlatButton`, Option-/Check-
  Buttons, `TabButton`-disabled, `KeyChip`, LineEdit/PopupMenu/Slider, `BookTabs`, Scrollbars (`scroll/*`).

## Prüfung
Validator 30 Dateien OK, Generator reproduziert alle 30 pixelgenau, 21 alte byte-identisch. `ui_art_check.gd`
(Zustandstafel mit Primary-Zuständen und allen Panels klein/groß, echte Primary-Buttons aktiv/deaktiviert,
echter Text-Tooltip über der Menüleiste): 1080p 75/100/150 %, 1440p/4K 100 % - OK. Gallery (HUD, Inventar +
Tooltip, Journal, Berufe, Forge, Klassen, Quest-Belohnungen) in denselben Stufen OK. Suites
`ui_window_foundation`, `ui_layout_lock`, `hud`, `hud_xp_bar`, `class_ui`, `world_ui` 38/38, Startprüfung OK.
