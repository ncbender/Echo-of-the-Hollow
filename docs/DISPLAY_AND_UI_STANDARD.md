# Display & UI Standard (verbindlich)

Stand: UI Foundation 0.1. Gilt für alle neuen Maps, HUD-Elemente und RPG-Fenster.

## 1. Designauflösung
- **Referenz: 1920×1080** (`display/window/size/viewport_width/height`). Alle UI-Maße sind
  **Design-Pixel** dieser Fläche.
- Stretch: `canvas_items`, Seitenverhältnis `keep` (andere Formate → Letterbox, nie Verzerrung).
- Fenster: Standard ist ein 16:9-Fenster mit 80 % der nutzbaren Bildschirmfläche, zentriert.
  `UserSettings.fit_window_to_screen` rechnet in physischen Pixeln, ein 4K-Bildschirm bekommt also
  ein großes Fenster. Fallback ohne Session ist 1600×900. **F11** oder Options → Vollbild
  (`Window.MODE_FULLSCREEN`).
- `allow_hidpi` ist an (Godot-Standard). Windows-Skalierung (z. B. 150 %) führt deshalb **nicht** zu
  Bitmap-Skalierung oder Doppelskalierung, denn die Skalierung hängt nur von der Fenstergröße ab.

## 2. Skalierungsstrategie

| Schicht | Mechanismus | Wirkung |
|---|---|---|
| Auflösung | `canvas_items`-Stretch | 1920×1080-Design wird auf jedes Fenster abgebildet (720p ×0,667, 1440p ×1,333, 4K ×2) |
| UI-Skalierung (Spieler) | `Window.content_scale_factor` = 0,75 / 1,0 / 1,25 / 1,5 (UI Scaling Standard 1.1) | UI-Fläche = 1920/f × 1080/f Design-Px; Anker und Container passen sich an |
| Spielwelt | `Camera2D.zoom = 3,75 / f` (`CameraShake.base_zoom`) | sichtbare Welt **immer 512×288 Welt-Px**, unabhängig von Auflösung und UI-Skalierung |

- Eine Doppelskalierung auf 4K gibt es nicht. Der Stretch-Faktor (×2) kommt von der Auflösung, die
  UI-Skalierung ist eine reine Spielerpräferenz obendrauf. 100 % sieht auf 4K proportional genauso
  aus wie auf 1080p.
- **Nie `Control.scale` oder Transform-Skalierung für UI verwenden.** Im Probe-Test war so
  vergrößerter Text auf 4K treppig. `content_scale_factor` rastert Schrift dagegen in Zielgröße und
  bleibt scharf.
- Die Gameplay-Physik ist unabhängig davon: Reichweiten, Kollisionen, Dash und Gegnerverhalten
  arbeiten in Welt-Px und sind unverändert.

## 3. Pixel-Art-Rendering – Entscheidung
| Option | Bewertung |
|---|---|
| **`canvas_items` (gewählt)** | Welt und UI in Zielauflösung, Schrift scharf, moderne VFX (Glow, Partikel, Shader) in voller Auflösung. Pixel-Art-Texturen mit Nearest-Filter (`default_texture_filter=0`) bleiben unverschwommen. |
| `viewport` | pixelgenaue Low-Res-Welt, aber UI und Schrift würden mitgerastert (unscharf, treppig), VFX nur in Low-Res → abgelehnt |
| Welt-SubViewport + Hi-Res-UI | möglich, wenn echtes Pixel-Snapping nötig wird; derzeit kein Bedarf (nur Platzhaltergrafik), deutlich komplexer → **nicht umgesetzt**, siehe offene Frage |

- **Weltmaßstab:** 1 Welt-Px = 3,75 Bildschirm-Px bei 1080p (720p 2,5 · 1440p 5 · 4K 7,5). Das ist
  identisch mit dem Stand vor dieser Änderung (640×360-Basis × Zoom 1,25). Sichtbarer Ausschnitt,
  Kamera und Gameplay haben sich nicht verändert.
- **Offene Entscheidung:** 3,75 ist nicht ganzzahlig. Echte Pixel-Art-Sprites hätten mit
  Nearest-Filter ungleich breite Pixel (3 bzw. 4 Bildschirm-Px). Zoom 3 (sichtbar 640×360) wäre bei
  allen vier Zielauflösungen ganzzahlig (2/3/4/6×), zeigt aber 25 % mehr Welt. Das ist eine
  Gameplay-Entscheidung für den Playtest, sobald Sprites existieren (`CameraShake.base_zoom`).
- **Welttexte** (Schadenszahlen, Bauplatz-/Stationsnamen, Dummy-Labels, Stagger-„!“) laufen über
  `WorldText.draw()`. Der Text wird in Endgröße gerastert und gegenskaliert, dadurch ist er bei
  Kamera-Zoom scharf. `size` bleibt in Welt-Px.

## 4. UI-Theme (`scripts/ui/ui_theme.gd`)
- Schrift: Godots eingebaute dynamische Standardschrift (gut lesbare Sans, keine Pixel-Font, keine
  zusätzliche Lizenz/Installation).
- **Schriftgrößen (Design-Px):** Klein 15 · Text 18 (Standard) · Überschrift 22 · Titel 26.
  Tooltip 18, Debug-Overlay 16/15.
- Farben: `COLOR_TEXT`, `COLOR_DIM`, `COLOR_ACCENT`, `COLOR_WARN`, `COLOR_ERROR`, `COLOR_PROMPT`,
  Panel-/Fenster-/Rahmen-/Button-Farben als Konstanten.
- Typvariationen: `HeaderLabel`, `SmallLabel`, `InventorySlot` (Button), `WindowPanel` (fast
  deckend).
- Buttons: Zustände normal/hover/pressed/hover_pressed/disabled, **Fokus** als Akzentrahmen (Tastatur,
  später Gamepad).
- Tooltips: `TooltipPanel`/`TooltipLabel` im Theme. Item-Tooltips laufen über
  `UiTheme.tooltip()`, mit Umbruch und maximal 420 Px Breite. Godot hält das Popup im Viewport.
- Scrollbars, Fortschrittsbalken und Panels kommen zentral aus dem Theme.
- **Layout-Konstanten:** `SCREEN_MARGIN` 16, `PANEL_PADDING` 12, `GAP` 8, `HUD_COLUMN_WIDTH` 360,
  `TEXT_WIDTH` 520, `FEED_WIDTH` 900, `SLOT_SIZE` 150×40, `TOOLTIP_MAX_WIDTH` 420,
  `WINDOW_MIN_SIZE` 320×160.

## 5. Responsive Layouts
- HUD: Anker (rechte Spalte oben rechts, Prompt und Toasts unten mittig), keine absoluten Positionen.
- **Alle RPG-Fenster erben von `UiWindow`:**
  - Aufbau: Titel, scrollbarer Body, Schließen-Button.
  - Größe: bevorzugte Inhaltsgröße, höchstens sichtbare Fläche minus `SCREEN_MARGIN`; der Rest scrollt.
  - Optionale feste Fußzeile `footer` (zwischen Body und Schließen): die primäre Aktion eines scrollenden
    Fensters (Craft, Restore/Revitalize) bleibt bei jeder UI-Skalierung sichtbar; versteckt, solange leer.
  - Zentriert und neu eingepasst bei Inhalts-, Fenster- und Skalierungsänderungen. Mindestgröße ist
    `WINDOW_MIN_SIZE`.
- Inventar: drei Spalten (Taschenraster, Details, Ausrüstung) in einem `HFlowContainer`. Auf breiten
  Flächen stehen sie nebeneinander, bei großer UI-Skalierung oder kleinem Fenster untereinander, mit
  vertikalem Scrollen.
- Künftige Crafting- oder Händlermenüs: `extends UiWindow`, Inhalt in `body`. Bei Flow-Layouts
  `preferred_body_size()` überschreiben.

## 6. Benutzereinstellung UI-Skalierung
- `UserSettings` (`scripts/core/user_settings.gd`): `ui_scale` ∈ {0,75; 1,0 (Standard); 1,25; 1,5 (Maximum)}
  (UI Scaling Standard 1.1, Professions Foundation 1.0; 200 % ist keine Option mehr). Gespeicherte Werte
  werden beim Laden auf den nächsten erlaubten Wert abgebildet: über 150 % → 150 %, alte 80 % → 75 %.
  `window_mode` (Fenster/Vollbild).
- Gespeichert in **`user://settings.cfg`**, unabhängig von Spielständen (kein Feld im Save).
  Beschädigte Werte fallen auf die Standards zurück. Die UI selbst verkraftet weiter jeden Faktor
  (Tests setzen 2,0 direkt, um den Platzmangel-Fall abzusichern).
- Ort in der Laufzeit: `GameSession.settings` (kein neues Autoload). Sie werden beim Start geladen und
  angewendet und bei jeder Änderung gespeichert.
- Skriptläufe (Tests, Playtests: MainLoop ist ein Skript) nutzen nur In-Memory-Standards und berühren
  die Spielerdatei nie.
- UI: **O** öffnet Options mit Skalierung, Fenster/Vollbild und „Reset to defaults“. **F11** schaltet
  Vollbild um.

## 7. Unterstützte Auflösungen (getestet, siehe UI_FOUNDATION_01_REPORT.md)
| Auflösung | UI-Fläche bei 100 % | Welt-Px → Bildschirm-Px | Status |
|---|---|---|---|
| 1280×720 | 1920×1080 | 2,5 | ✅ (75–150 %; 75 % sehr klein, s. u.) |
| 1920×1080 | 1920×1080 | 3,75 | ✅ |
| 2560×1440 | 1920×1080 | 5 | ✅ |
| 3840×2160 | 1920×1080 | 7,5 | ✅ (Fenster randlos und echtes Vollbild) |
| 2880×1620 (Zweitmonitor des Testsystems) | 1920×1080 | 5,625 | ✅ (Vollbild, unbeabsichtigt mitgetestet) |

UI/UX Redesign 1.0 hat alle Bildschirme zusätzlich bei 1080p und 4K mit 100 % und 150 % sowie bei 720p
geprüft (UI-Galerie, `UI_UX_REDESIGN_01_REPORT.md`). Farben, Schriften und Komponenten:
`UI_DESIGN_SYSTEM.md`.

## 8. Bekannte Probleme / Grenzen
- **75 % auf 720p:** Kleinschrift ist dort nur noch ~7 physische Px hoch, funktional, aber kaum lesbar.
  75 % ist für 1440p/4K gedacht; bei 720p mindestens 100 % verwenden.
- Bei 150 % nimmt die rechte HUD-Spalte einen großen Teil der Breite ein.
- Welt-Pixelmaßstab nicht ganzzahlig (s. 3). Ohne echte Sprites derzeit unsichtbar.
- Das Debug-Overlay ist Entwicklerwerkzeug, seit dem Redesign standardmäßig aus (F12 schaltet es ein).
- Das HUD-Layout für sehr schmale Canvases (Skillleiste über dem Spielerrahmen, Loot-Feed unten rechts,
  Hinweis unter dem Tracker) bleibt erhalten, greift mit dem 150-%-Maximum aber nicht mehr im Spiel.
- Exklusives Vollbild (Modus 4) wird nicht angeboten, nur randloses Vollbild.
