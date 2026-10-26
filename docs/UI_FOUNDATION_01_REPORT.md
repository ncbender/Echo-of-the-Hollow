# UI Foundation 0.1 – Bericht

**Engine:** Godot 4.7.2 · **Branch:** `dev/rpg-foundation` (lokal, nicht gepusht) · Standard:
`DISPLAY_AND_UI_STANDARD.md`. Combat-Timings, Reichweiten, Dash und Gegnerverhalten sind **unverändert**.

## 1. Ausgangslage (Analyse)
| Punkt | Vorher |
|---|---|
| Viewport | 640×360, Fenster 1280×720, Stretch `canvas_items` (Aspect implizit `keep`) |
| Filter | Nearest (`default_texture_filter=0`) – korrekt für Pixel Art |
| Kamera | Spieler-`Camera2D` Zoom 1,25 → sichtbar 512×288 Welt-Px |
| UI | alles in 640×360-Einheiten, Schrift 8 (= 24 Px bei 1080p), feste Offsets, ein minimales Theme; Fenster ohne Größenbegrenzung oder Scrollen (bei 4K korrekt skaliert, bei großen Inhalten Abschneiden möglich) |
| Testsystem | primär 3840×2160 @150 % Windows-Skalierung, Zweitmonitor 2880×1620 @150 % (links, Desktop-Position 0,0) |

**`project.godot`:** Die vorhandene lokale Änderung habe ich geprüft. Sie war eine reine
Editor-Neuspeicherung:
- Kopfkommentar, Abschnittsreihenfolge und Leerzeilen waren neu geschrieben.
- `inferred_declaration=0` war entfernt. Das ist Godots Standardwert.

Ein Vergleich nach Sortierung zeigte keine weitere Abweichung. Ich habe sie als **eigenen Commit
`a0b1e64`** gesichert und dokumentiert, getrennt von dieser Arbeit. Danach habe ich nur die
Display-Einträge und zwei neue Input-Actions geändert.

## 2. Probe (Belege für die Entscheidung)
Auf echtem 4K (3840×2160-Fenster) gerendert und als 1:1-Ausschnitte geprüft:
- Ein normales 18-px-Label bei 1080p-Basis ist scharf.
- Ein 18-px-Label mit `Control.scale = 2` ist **treppig**. UI-Skalierung per Transform ist deshalb
  ausgeschlossen.
- 8-px-Welttext unter Kamera-Zoom 3,75 ist **blockig**. Daraus entstand `WorldText` (gegenskaliert).

## 3. Implementierte Änderungen
| Bereich | Änderung | Dateien |
|---|---|---|
| Projekt | Viewport 1920×1080, `aspect=keep`, Fallback-Fenster 1600×900, Actions `ui_options` (O), `toggle_fullscreen` (F11) | `project.godot` |
| Einstellungen | `UserSettings` (UI-Skalierung, Fenstermodus, `user://settings.cfg`, Validierung, Reset, Anwenden, 16:9-Startfenster); geladen/angewendet/gespeichert durch `GameSession`; F11 | `scripts/core/user_settings.gd`, `scripts/rpg/session_state.gd` |
| Kamera | `base_zoom` 3,75 ÷ UI-Faktor → sichtbare Welt konstant 512×288 | `scripts/fx/camera_shake.gd`, `scenes/player/player.tscn` |
| Welttext | `WorldText.draw()` für alle 8 Welttext-Stellen | `scripts/fx/world_text.gd`, Views (Dummy, Gegner, Schadenszahl, Bauplatz, Gebäude, Station, Durchgang, Ressourcenknoten) |
| Theme | Schriftgrößen, Farben, Layout-Konstanten, Button-Zustände inkl. Fokus, Tooltip, Scrollbars, Slot- und Fenster-Varianten | `scripts/ui/ui_theme.gd` |
| Fenster | `UiWindow` (Titel, Scroll-Body, Schließen, Einpassen/Zentrieren); Inventar, Klassen- und Baufenster darauf umgestellt; neues Options-Fenster | `ui_window.gd`, `inventory_panel.gd`, `class_panel.gd`, `build_panel.gd`, `options_panel.gd` |
| Inventar | Flow-Spalten, `ItemSlotButton` mit Item-Tooltip (Details, Umbruch, Maximalbreite, kein leerer Tooltip bei leeren Slots) | `inventory_panel.gd`, `item_slot_button.gd` |
| HUD | Anker und Konstanten statt Pixel-Offsets, Prompt und Toasts in einer unteren Spalte, Neu-Einpassen bei Einstellungswechsel | `game_hud.gd`, `class_info_panel.gd`, `mastery_panel.gd`, `toast_feed.gd` |
| Debug-Overlay | Design-Px-Größen, Hilfetext unten über volle Breite, neue Tasten | `scenes/ui/debug_overlay.tscn` |

## 4. Tests (tatsächlich ausgeführt)
| # | Anlass | Lauf | Ergebnis |
|---|---|---|---|
| 1 | nach Kernumbau | Startprüfung (Import + 300 Frames, Fehler/Warnungen) | OK |
| 2 | visuell, alle Auflösungen | `ui_playtest.gd --quick` | 52 Layout-Checks ✅, 4 ❌ Tooltip-Erkennung (Testskript: Hover nicht ausgelöst) |
| 3–7 | Tooltip-Harness | Hover per Cursor-Warp + Bewegungsereignis, Wartezeit in Echtzeit statt Frames, rekursive Popup-Suche | danach 64/64 ✅. Gefunden: **leere Tooltip-Box über leeren Ausrüstungsslots** → behoben (`_make_custom_tooltip` liefert `null`) |
| 8 | voll (Skalierungen, Vollbild) | `ui_playtest.gd` | 116/116 ✅. Dabei fiel auf, dass das Testfenster auf dem Zweitmonitor lag (Desktop-Pos. 0,0) → Test auf den Primärmonitor fixiert, 4K randlos |
| 9 | voll, korrigiert | `ui_playtest.gd` | 117/117 ✅ (Vollbild echt 3840×2160) |
| 10 | neue Suites | settings (9), ui_layout (2) | 9/11 ❌ – 2 Testfehler (falsche erwartete Signalanzahl, unescaptes `%`) → 11/11 ✅ |
| 11 | betroffene Suites (Szenen, Session, HUD, Input) | base, loop, pickup, save, world, project, input | 36/36 ✅ |
| 12 | Spielerszene (Kamera), Welttext-Views | hits, enemy, dash | 33/33 ✅ |
| 13 | nach Fenster-Opazität | Startprüfung + `ui_playtest.gd` voll | OK, 117/117 ✅ |

**Nicht ausgeführt:**
- combo, light_attack, heavy_attack, movement, collision, hit_reaction, knockback, lunge, combo_reach,
  weapon_switch, combat_data: keine Combat-Logik, -Daten oder -Timings geändert.
- mastery, classes, inventory, equipment, item_effects, gathering: keine Logik geändert, nur die
  Darstellung der Panels, und die ist durch Playtest und `ui_layout` geprüft.

Kein vollständiger Testlauf.

**Was der UI-Playtest prüft** (je Auflösung 720p/1080p/1440p/4K bei 100 %):
- Heimatbasis-HUD und Inventar inklusive Ausrüstung.
- Item-Tooltips links und rechts, jeweils im Bild.
- Klassenfenster, Baufenster und Options-Fenster (per echter O-Taste).
- Arena-Kampf-HUD mit Schadenszahlen.

Außerdem:
- Alle fünf UI-Skalierungen auf 720p und 4K, jeweils Inventar, Options und HUD.
- F11 → Vollbild → Fenster → Reset auf Standard.

Automatische Checks:
- Jede sichtbare Control liegt im Bild.
- Fenster halten den Randabstand ein.
- Keine Control ist kleiner als ihre Mindestgröße (= kein abgeschnittener Text).
- Die sichtbare Welt ist immer 512,00 Welt-Px breit.

## 5. Screenshots (`docs/screenshots/ui_foundation_01/`, alle 46 in `tests/output/ui/`)
| Datei | Zeigt |
|---|---|
| `720p_01_home_hud.png` | HUD auf 720p |
| `720p_05_build_panel.png` | Baufenster 720p |
| `1080p_02_inventory.png` | Inventar und Ausrüstung, drei Spalten |
| `1080p_06_options.png` | Options-Fenster (Skalierung, Fenster, Reset) |
| `1440p_04_class_panel.png` | Klassenstation, scharfer Welttext |
| `2160p_03_tooltip_0.png` | Item-Tooltip auf 4K (1:1 geprüft: scharf) |
| `2160p_07_combat.png` | Kampf-HUD 4K, Schadenszahlen scharf |
| `720p_scale200_inventory.png` / `_hud.png` | 200 % auf 720p: Inventarspalten gestapelt mit Scrollbar, HUD passt |
| `2160p_scale80_inventory.png` | 80 % auf 4K |
| `fullscreen_inventory.png` | echtes Vollbild 3840×2160 |

## 6. Bekannte Probleme / Risiken
Siehe `DISPLAY_AND_UI_STANDARD.md` §8:
- 80 % auf 720p ist kaum lesbar.
- Bei 200 % ist die HUD-Spalte breit.
- Der Welt-Pixelmaßstab ist nicht ganzzahlig (Zoom-Entscheidung offen).

Testharness-Hinweis: Den Cursor-Warp habe ich anfangs relativ zum Zweitmonitor gemessen. Seit die
Tests auf dem Primärmonitor laufen, ist er stabil. Bei einem Fenster, das den ganzen Bildschirm
abdeckt, können echte Mausbewegungen des Nutzers während des Tests stören (Retry eingebaut).

## 7. Für den menschlichen Test
1. Spiel normal starten: Das Fenster sollte etwa 80 % des 4K-Bildschirms einnehmen. **O** →
   Skalierung durchklicken, **F11**. Danach Spiel neu starten: Einstellungen bleiben erhalten
   (`%APPDATA%\Godot\app_userdata\Echoes of the Hollow\settings.cfg`).
2. Welche Standard-Skalierung fühlt sich auf 4K am Schreibtisch richtig an? Eventuell 125 % als Standard.
3. Kamera-Zoom 3,75 vs. 3 (ganzzahlig, mehr Weltsicht) entscheiden, sobald echte Sprites kommen.

```powershell
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path .
.\tools\run_tests.ps1 -Suite "settings,ui_layout"
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/playtest/ui_playtest.gd   # öffnet Fenster/Vollbild auf dem Primärmonitor
```
