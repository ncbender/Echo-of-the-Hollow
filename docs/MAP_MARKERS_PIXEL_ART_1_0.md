# Map Markers Pixel Art 1.0

Echte Pixel-Art für die Kartenmarker von Minimap, Gebietskarte (M → Area) und Kartenlegende. Welche Marker
es gibt und wo (nur erkundete Zellen, keine geschlossenen Ausgänge, nie Gegner / Loot), entscheidet weiter
allein `MapMarkers.collect` - unverändert, ebenso Fog, Erkundungsradius, Kartenfarben (FLOOR #393D44 /
WALL #1B1C20 = `is_solid`-Klassen), Zoom, Kamera, Save v15.

## Bisherige Logik

`MapPainter.draw_marker` lud schon optional `map/<kind>` bzw. `map/waystone_silent` (Label endet auf
„(silent)“) und zeichnete sie 16 × 16, sonst prozedurale Glyphen; `draw_player` lud `map/player` und drehte
ihn frei auf die Blickrichtung, gestreckt auf 14 (Minimap) / 18 (Gebietskarte) / 16 (Legende). Die
Regionskarte hat keine Marker (eigene Ortskästchen). Marker-Arten (`MapMarkers`): exit, waystone (wach /
still), rest, npc (mit „!“ / „?“ als Text), landmark, quest; der Goldring um questrelevante Marker bleibt Code.

## Assets (`tools/ui_art/generate_core_ui_assets.py`, 16 × 16 RGBA, 1 px Ink-Kontur, transparent)

| Id | Symbol | Farbe (= `UiTheme.MAP_*`) |
|---|---|---|
| `map/player` | Pfeilspitze nach oben, hinten gekerbt | Resonanz-Cyan |
| `map/exit` | Torbogen mit dunklem Durchgang | Violett |
| `map/waystone` | stehender Stein, leuchtende Rune | Steel, Rune Cyan |
| `map/waystone_silent` | derselbe Stein, gedämpft, Rune dunkel | Slate |
| `map/rest` | Flamme über Scheiten | Orange, Goldkern |
| `map/npc` | Kopf über breiten Schultern | Grün |
| `map/landmark` | Fahne am Mast | Bronze |
| `map/quest` | Goldraute mit „!“ | Gold |

Validator: Größe, RGBA, harte Alpha, Palette (+ Kartenfarben), geschlossene Kontur, keine Platte, kompakt;
Silhouetten paarweise < 0,8 Überlappung (ohne Farbe unterscheidbar); die beiden Wegsteine gleiche Form, der
stille klar dunkler (Helligkeit 84 → 38) mit dunkler Rune.

## Integration

- `MapPainter.marker_rect`: Grafik 1:1 (16 × 16), auf ganzen Pixeln, im Bild gehalten (Ausgänge am Kartenrand
  ragten sonst in die Legende). Anzeige 16 Design-px in Minimap und Gebietskarte (12 Bildschirm-px bei 75 %).
- Spielerpfeil: mit Grafik immer 16 × 16 (nicht mehr 14 / 18), Drehung in 90°-Schritten - freie und 45°-Winkel
  zerfransen Nearest-Pixel-Art (bei 75 % geprüft); die Blickrichtung zeigt vier Richtungen.
- Ohne Dateien bleiben die prozeduralen Glyphen (unveränderter Code-Pfad).

## Prüfung

`test_map_marker_art` (Art je Marker-Art, 1:1 / ganze Pixel / im Bild, rechte Winkel), `test_map_fog` (Sichtbarkeit,
Persistenz, keine Spoiler), `tests/playtest/ui_art_check.gd` Szene `map_markers` (Gebietskarte mit Legende aller
Arten, Region, Minimap, Spielerpfeil in acht Richtungen) bei 1080p 75 / 100 / 150 %, 1440p, 4K.
