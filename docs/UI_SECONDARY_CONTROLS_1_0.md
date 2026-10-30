# UI Secondary Controls 1.0

Dropdowns, Check-Toggles, Slider und Key-Chips im Dark Classic Pixel Art UI - über die bestehende Architektur
(`UiSkin` + `UiTheme.SKINNED`); einziger neuer Hook: `UiTheme.SKINNED_ICONS` (gleiche Mechanik für Theme-Icons).
Ohne PNG bleibt der prozedurale Stil bzw. Godots Standard-Icon.

## Tatsächliche Controls und Theme-Slots (Godot 4.7.2, Default-Theme abgefragt)

| Control | Wo | Styles | Icons (Standardgröße) |
|---|---|---|---|
| `OptionButton` | Inventar „Sort“, Klassenstation Skill-Slots und Mods (gesperrte Einträge disabled) | normal, hover, pressed (= offen), disabled, focus, *_mirrored | `arrow` 12 × 12 |
| `PopupMenu` (Liste des Dropdowns) | dito | panel, hover, separator | `radio_checked/unchecked(_disabled)` 16 × 16, `checked/unchecked(_disabled)` 16 × 16 |
| `CheckButton` | Optionen: Periodic Autosave, Show Save Indicator, Reduce Motion | normal, hover, pressed, hover_pressed, disabled, focus | `checked/unchecked(_disabled)(_mirrored)` - Standard 32 × 16 (Schalter); hier 16 × 16 Kästchen |
| `CheckBox` | (nicht verwendet, gleich gestylt) | wie CheckButton | `checked/unchecked(_disabled)` 16 × 16 |
| `HSlider` | Optionen: Effects volume | slider, grabber_area, grabber_area_highlight | `grabber`, `grabber_highlight` (Hover **und** Fokus), `grabber_disabled` 16 × 16 |
| `KeyChip` (PanelContainer-Variation) | HUD-Interaktionshinweis „G“, Klassenstation Q/E/R/F, Optionen-Steuerung | panel (Innenabstand 6 / 1) | - |

## Neue PNGs (reproduzierbar: `py -3 tools/ui_art/generate_core_ui_assets.py`)

| Id | Größe | Rand | Verwendung |
|---|---|---|---|
| `dropdown/arrow` | 12 × 12 | Icon | OptionButton `arrow` |
| `dropdown/radio_on` / `radio_off` / `radio_off_disabled` | 16 × 16 | Icon | PopupMenu `radio_*` (gewählter Eintrag = Gold-Juwel) |
| `check/on` / `off` / `on_disabled` / `off_disabled` | 16 × 16 | Icon | CheckButton/CheckBox/PopupMenu `checked`/`unchecked` |
| `slider/fill` | 10 × 10 | 3 | HSlider `grabber_area` (+ Hover-Tönung) |
| `slider/grabber` / `grabber_hover` / `grabber_disabled` | 16 × 16 | Icon | HSlider `grabber*` |
| `chip/key` | 12 × 12 | 3 | KeyChip `panel` |

Wiederverwendet (kein neues PNG): OptionButton-Zustände = `button/*` (offen = pressed, Bronze), PopupMenu-Panel =
`panel/card`, Slider-Schiene = `scroll/track`, CheckButton/CheckBox-Rahmen = `button/*` (pressed = normaler Rahmen:
„an“ zeigt nur das goldene Häkchen). Fokus bleibt überall die Resonanz-Kontur der Button-Styles - nie Gold.

## Regeln

- Gold = an / ausgewählt; Cyan (Resonanz) = Tastaturfokus; disabled = Slate/Plate, Häkchen dunkles Gold.
- Häkchen: 10 Spalten, 2 px Strich (Validator), bei 75 % noch durchgehend.
- Slider: Godot zeigt `grabber_highlight` bei Hover und Fokus - beides hebt den Griff (Gold-Grip); die
  gespeicherten Einstellungswerte sind unverändert.
- Dropdown-Breite: `fit_to_longest_item` (Godot-Standard) - lange Einträge werden nie abgeschnitten.

## Prüfung

`tools/ui_art/validate_ui_assets.py` (48 PNGs; Kontur, keine Platte, Zustandsgeometrie, H/V-Symmetrie der Füllung,
Häkchenstärke) und `tests/playtest/ui_art_check.gd`: Tafel `controls` (echte Maus: Hover, Klick an/aus, deaktiviert
bleibt; Tastatur am Slider, Drag; Dropdown öffnen, Rand-Dropdown im Bild, lange Texte; Key-Chips) und echte Fenster
`inventory_sort`, `skills_mods`, `options_gameplay|audio|controls`.
