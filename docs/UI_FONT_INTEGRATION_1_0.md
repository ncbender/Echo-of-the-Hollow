# UI Font Integration 1.0

Verbindliche Schriftwahl (Projektleitung nach Body Font Final Selection 1.1): **IBM Plex Mono Regular** für
allen Text, **Silkscreen** für Titel und Überschriften. Genau zwei Familien, global für alle Kapitel und Biome.
Keine Änderung an Gameplay, XP, Bossen, Quests, Save oder `project.godot`.

## Dateien und Lizenzen
| Datei | Quelle | Lizenz |
|---|---|---|
| `assets/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf` | `google/fonts/ofl/ibmplexmono` (IBM Corp.) | OFL 1.1, Reserved Font Name „Plex“ (`OFL.txt` daneben) |
| `assets/fonts/silkscreen/Silkscreen-Regular.ttf` | `google/fonts/ofl/silkscreen` (Jason Kottke) | OFL 1.1 (`OFL.txt` daneben) |

Byte-identisch mit den geprüften Kandidaten (`assets/fonts/candidates/`, bleibt mit `.gdignore` als Vergleichsarchiv).
OFL: mitliefern mit Lizenztext erlaubt, nicht einzeln verkaufen; veränderte Fassungen nicht unter „Plex“.

## Rendering (`UiTheme`)
- `UiTheme.body_font()`: Plex, Graustufen-Antialiasing, leichtes Hinting, **Subpixel-Positionierung aus**
  (Ganzpixel). Mit Subpixel-Positionen verlor kleiner Text bei 75 % UI-Skala unter dem Nearest-Canvasfilter
  Striche („+0.5%“ las sich wie „+9.5%“, „Gem“ wie „Gəm“).
- `UiTheme.display_font()`: Silkscreen ohne Antialiasing/Hinting, Ganzpixel; Fallback = Plex.
- `theme.default_font` = Plex; `HeaderLabel`/`TitleLabel`/`DisplayLabel` = Silkscreen.
  `ThemeDB.fallback_font` = Plex (Godot-eigene Popups, Controls außerhalb des HUD-Baums).
- Zeichen-Code nutzt `UiTheme.body_font()` statt `ThemeDB.fallback_font`: `WorldText`, Schadenszahlen,
  `CombatFx`, `ItemIcon` (Stapelzahl, „E“), Inventar-Paperdoll, Stationen, Tore, Übergänge, Bauplätze, Dummy.

## Größen (Design-px)
| Stufe | Schrift | Größe |
|---|---|---|
| Beschriftung / Klein / Fließtext / Zwischenüberschrift | Plex | 14 / 15 / 18 / 20 (unverändert, optisch wie bisher) |
| `FONT_SECTION` (Tracker-Titel, Bossname) | Silkscreen | 16 (vorher 20) |
| `FONT_HEADING` (`HeaderLabel`: Item-, Quest-, Klassen-, Baumnamen) | Silkscreen | 24 (vorher 22) |
| `FONT_TITLE` (`TitleLabel`: Fenstertitel) | Silkscreen | 32 (vorher 28) |
| `FONT_DISPLAY` (Titelbildschirm, Todesbildschirm) | Silkscreen | 64 (vorher 60) |

Silkscreen-Größen auf dem 8-px-Raster; Überschriften liegen über dem Fließtext (Versalhöhe 15 / 20 / 40 px).
EXP-Balken: unverändert 426 × 14, Prozent in Plex 13 (CaptionLabel), Outline 4.

## Layout-Anpassung
`TalentTreeView`: Baumtitel 30 px hoch, „points invested“ bei y 28 (vorher 26 / 24) - innerhalb der
reservierten `TalentLayout.HEADER` (46 px), Baumgeometrie unverändert.

## Prüfung
- Suites: `ui_layout_lock`, `ui_window_foundation`, `hud`, `hud_xp_bar`, `world_ui`, `class_ui`, `talents` (48/48).
- `ui_gallery.gd` alle Bildschirme bei 1080p 100 % und 150 % (398 Layoutprüfungen), gezielte Bildschirme
  bei 1440p/4K 100 % (64) und 1080p 75 % (32): alle OK.
- Sichtprüfung (vergrößerte native Ausschnitte): Item-Tooltip (Zahlen, 5/S), Talente, Journal, Berufe,
  BookTabs, HUD (Statuswörter, EXP „58%“, Bossname, Tracker), Titelbildschirm, 75 % nach der Korrektur.

## Offen
- 0/O in Plex nur über die Breite unterscheidbar (die OpenType-Funktion `zero` wirkte im Test nicht).
- Plex ist glatt gerendert (bewusster Stilkontrast zu den Silkscreen-Überschriften und der Pixel-Art).
- Bei 75 % wirken Outlines auf kleinen Zahlen (z. B. „350 / 350“ im Lebensbalken) kräftig.
