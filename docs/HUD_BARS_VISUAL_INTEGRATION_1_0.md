# HUD Bars Visual Integration 1.0

Pixel-Art für alle Status- und Fortschrittsleisten über **einen** Rahmen und **eine** Füllung. HUD-Anordnung,
Progressionslogik, EXP-Balken (genau einer, 426 × 14, 6 px unter der Kampfleiste, nur Prozent / MAX) und
`BarText` bleiben unverändert.

## Bestand vorher

| Leiste | Größe (Design-px) | Darstellung |
|---|---|---|
| Player HP | Breite PlayerFrame × 18 | `ProgressBar` (UiTheme.bar), Hintergrund StyleBoxFlat (55 % Schwarz, 1 px Bronze), Füllung flach `HEALTH` **über den Rand**, BarText 13 |
| Klassenressource | × 12 | wie oben, Füllung = Farbe der Ressource (`pool.definition.color`), BarText 13 |
| Ziel / Boss HP, Poise | × 10 / × 5 | wie oben (`HEALTH`, `POISE`), kein Text |
| HUD EXP | 426 × 14 | eigene Zeichnung: Rahmen + Füllung innen auf ganze Pixel; Hooks `hud/xp_frame` / `hud/xp_fill` ohne PNG |
| Fensterleisten | × 3 / 6 / 8 | dieselbe `ProgressBar`-Architektur (Klassen, Berufe, Schmiede) |

`ProgressBar` zeichnet die Füllung über die ganze Höhe und mit der Mindestbreite ihrer StyleBox (Godot 4.7,
gemessen): eine NinePatch-Füllung mit Seitenrändern hätte bei 1 % eine falsche Mindestfüllung und gestauchte Ecken.

## Neue Assets

| Id | Größe | Rand | Inhalt |
|---|---|---|---|
| `bar/frame` | 3 × 3 | 1 | Steel-dunkler Ring (Ink-Ecken) um eine dunkle Rinne - trägt auch 3-px-Leisten |
| `bar/fill` | 4 × 6 | oben 1 / unten 1 / Seiten 0 | neutrale **Tönungsmaske**: helle Oberkante, Körper (0xD8), Schattenkante; alle Spalten gleich |

Die Füllung wird mit der Bedeutungsfarbe moduliert (Körper ÷ 0,847 → exakt die bisherige Farbe: HP rot,
Ressource der Klasse, EXP gedämpftes Bronze, Poise, Berufsfarben). Keine Seitenränder → jede Breite ab 1 px
ohne Verzerrung, Füllung exakt proportional (Innenabstand 0, also keine Mindestbreite).

## Hooks (kleinstmöglich)

- `UiSkin.PATCH` erlaubt `Vector4i(links, oben, rechts, unten)` (für `bar/fill`); `hud/xp_frame` / `hud/xp_fill`
  entfallen - der EXP-Balken nutzt dieselben `bar/frame` / `bar/fill`.
- `UiTheme.SKINNED`: `ProgressBar.background` → `bar/frame`.
- `UiTheme.fill_box(color, inset := true)`: Füllung aus der Maske, 1 px in den Rahmen eingerückt (negativer
  Expand-Margin); `UiTheme.bar` nutzt die Art ab 5 px Höhe (`BAR_ART_MIN_HEIGHT`), darunter flach wie bisher.
- Ressourcentext (12-px-Leiste): Kontur 2 statt 4 - bei 75 % passte mit Kontur 4 nur noch Schrift 9 (matschig).

## Kleine Füllstände

Füllung sichtbar = `round(ratio × Breite) − 2` (der Rahmen); 1 % HP auf der 340-px-Leiste = 1 px; 0 % = leer.
EXP zeichnet weiter `floor(innen × ratio)` ganze Pixel.

## Prüfung

`validate_ui_assets.py` (53 PNGs; Maske: Spalten gleich, Zeilen hell / Körper / Schatten, deckend; Rahmen: Ring
≠ Rinne), `tests/playtest/ui_art_check.gd` Szene `bars` (HP voll / 8 % / 1 %, Boss, EXP 0 / 1 / 58 / 99 % / MAX,
Ressourcen Rage / Mana / Focus; Art aktiv, EXP 426 × 14 und 6 px Abstand, nur Prozent) bei 1080p 75 / 100 / 150 %,
1440p, 4K; `test_ui_usability` (BarText zentriert und im Balken bei 75-150 %).
