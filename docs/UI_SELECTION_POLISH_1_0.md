# UI Selection & Surface Polish 1.0

Eine Auswahlsprache für alle Karten und ein harter Pixel-Schatten für Fenster mit Grafik. Keine neuen PNGs
(alle 30 unverändert), keine Layout-, Font-, Fokuslogik- oder Gameplay-Änderung.

## Zustandsbedeutungen
| Zustand | Darstellung |
|---|---|
| normal | neutrale dunkle Fläche (`panel/card`) |
| hover | dieselbe Card-Grafik, leicht aufgehellt (`UiTheme.CARD_HOVER_TINT` 1,16) |
| selected / active | Gold (`panel/card_selected`) - wie Journal (aktuelle Quest) und Klassenwahl |
| keyboard focus | unverändert eigene Resonanz-Kontur (`focus`-StyleBoxFlat, außen, 2 px, ohne Füllung) |
| disabled | Card-Grafik abgedunkelt (`CARD_DISABLED_TINT` 0,6) |

Selected und Fokus sind getrennte Stile: die Kontur liegt außerhalb der Karte, also bleiben Gold und Cyan
gemeinsam sichtbar. Fokuslogik/Tastaturnavigation unverändert.

## Umsetzung (`scripts/ui/ui_theme.gd`)
- `UiTheme.SKINNED`: `CardButton` normal/hover/pressed/hover_pressed/disabled → `panel/card` bzw.
  `panel/card_selected`; optionaler 4. Wert = Tönung (`StyleBoxTexture.modulate_color`), nur auf Art, nie auf
  den prozeduralen Fallback. Content-Margins bleiben die der prozeduralen Variante (12 / 10).
- Betroffen: nur die Klassenkarten der Class Station (`class_station_panel.gd`, einzige `CardButton`-Nutzung).

## Fensterschatten
- Ursache: `StyleBoxFlat` hatte `shadow_size` (Fenster 10, Tooltip 6); `StyleBoxTexture` kennt keinen Schatten.
- Umsetzung: `UiTheme.draw_hard_shadow(control)` zeichnet zwei harte Streifen (4 px, Schwarz α 0,45) direkt
  außerhalb des eigenen Rechtecks, rechts und unten (Licht von oben links). Aufgerufen aus `UiWindow._draw`
  und für die Item-Tooltip-Karten (`ItemTooltip`, `draw`-Signal) - nur solange `window/panel` existiert.
  Keine Größen-, Margin-, Anker-, Eingabe- oder Z-Order-Änderung (reine Zeichnung im selben CanvasItem).
- Bewusst nicht umgesetzt: Text-Tooltips (`TooltipPanel`). Godot zeigt sie in einem eigenen Popup-Fenster in
  Größe des Panels; außerhalb gezeichnete Streifen würden abgeschnitten. Ein Schatten bräuchte ein größeres
  Popup (expand margins → andere Popup-Größe/-Position) - mehr Umbau als vertretbar.

## Prüfung
`test_ui_selection_polish` (3: Card-Zustände = Card-Art samt Tönung und Margins, Fokus separat und auch bei
ausgewählter Karte, Schatten ohne Geometrie-/Eingabeänderung) + `ui_window_foundation`, `ui_layout_lock`,
`class_ui`, `hud` (31/31), Startprüfung OK. `ui_art_check.gd` mit Class-Station-Sequenz (geöffnet, Hover per
Maus, Fokus allein, Auswahl + Fokus): 1080p 75/100 %, 1440p/4K 100 % OK; Gallery Klassen/Journal/Tooltip/
Optionen 1080p/1440p/4K OK. Sichtprüfung der Screenshots (kein manueller Spieltest).
