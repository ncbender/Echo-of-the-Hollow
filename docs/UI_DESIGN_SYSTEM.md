# UI-Designsystem „The Forgotten Chronicle“ (UI/UX Redesign 1.0)

Verbindlich für alle spielerseitigen Oberflächen. Technische Grundregeln (Design-Pixel, UI-Skalierung,
`UiWindow`-Größenregel) stehen in `DISPLAY_AND_UI_STANDARD.md`.

## Leitlinien
- Dark Fantasy und matt: dunkle grüngraue Flächen, verwitterte Bronze für Rahmen und Titel,
  Pergamenttöne für Text, sparsames Resonanz-Cyan für Aktives, Fokus und Magisches.
- Wenig Dekor: Bronze-Eckwinkel an Fenstern, dünne Trennlinien, keine Goldornamente, kein Leuchten
  ohne Grund.
- Information vor Schmuck: klare Hierarchie (Titel → Abschnitt → Inhalt → Hinweis).
- Zustände nie nur über Farbe: Seltenheit über Farbe plus Punkte am Icon plus Wort, Sperren über
  Text, wichtige Meldungen über Symbol oder Wort.

## Tokens (`UiTheme`)
| Token | Wert | Verwendung |
|---|---|---|
| `BG` | `#171C1A` | tiefster Hintergrund, HUD-Panels (transparent) |
| `PANEL` | `#252E28` | Fenster, Panels |
| `PANEL_ELEVATED` | `#303A33` | Karten, ausgewählte Bereiche, Popups |
| `PANEL_INSET` | `#1C2320` | Listen, Slots, Eingabefelder |
| `BRONZE` / `BRONZE_DIM` / `BRONZE_DARK` | `#C5AD85` / `#7D6C52` / `#4A4134` | Titel, Rahmen, Trennlinien |
| `TEXT_PRIMARY` / `TEXT_SECONDARY` / `TEXT_MUTED` | `#E9DDC5` / `#AFB9AD` / `#7F877E` | Text-Hierarchie |
| `RESONANCE` / `RESONANCE_DIM` | `#78B8C5` / `#4D7A83` | Aktiv, Fokus, Fortschritt, Magie |
| `SUCCESS` / `WARNING` / `DANGER` | `#9CBF7E` / `#D9B46A` / `#D27461` | Status, Kosten erfüllt/fehlend, Fehler |
| `HEALTH` / `POISE` / `PARCHMENT` | `#B4493F` / `#C9A95C` / `#EADCB8` | Leisten, hervorgehobener Text |

Alte Namen (`COLOR_TEXT`, `COLOR_ACCENT` …) sind Aliase dieser Tokens.

## Typografie
| Stufe | Größe | Variation |
|---|---|---|
| Display (Titelbildschirm) | 60 | `DisplayLabel` (Serif) |
| Fenstertitel | 28 | `TitleLabel` (Serif, Bronze) |
| Überschrift | 22 | `HeaderLabel` (Serif, Bronze) |
| Zwischenüberschrift | 20 | `SubheadingLabel` |
| Fließtext | 18 | Standard |
| Klein | 15 | `SmallLabel` |
| Beschriftung | 14 | `CaptionLabel`; Abschnittsköpfe in Versalien und Bronze |

- Serifenschrift: System-Serif (Georgia → Palatino → Cambria → Times) mit eingebauter Sans als
  Fallback. **Provisorisch**, bis eine lizenzierte Spielschrift gewählt ist.
- Fließtext: die eingebaute Sans.

## Abstände
- Fensterrand und HUD: 16
- Panel-Innenabstand: 14 (Fenster 18)
- Lücke: 8
- Slot-Lücke: 4
- Rahmen: 2
- Ecke: 3

## Komponenten
- `UiWindow` (Fenster): Bronze-Rahmen mit Eckwinkeln, Titel mit Trennlinie, scrollender Inhalt,
  Schließen-Knopf.
  - Größe nach Inhalt, nie größer als die sichtbare Fläche abzüglich Rand.
  - Kurze Einblendung, die „Reduce Motion“ abschaltet.
  - Der erste Knopf erhält beim Öffnen den Tastaturfokus.
- `UiTabs`: Reiterleiste, `TabButton` unterstrichen; Knoten `Tab<Id>`.
- `UiConfirmDialog`: einziger Bestätigungsdialog. Abbrechen hat den Fokus; Esc bricht ab. Zerstörerische
  Aktionen nutzen `DangerButton`.
- `ItemIcon`: provisorisches prozedurales Icon. Der Rahmen zeigt die Seltenheit über Farbe und Punkte,
  die Glyphe die Item-Art. Später durch Sprites ersetzbar (`texture`).
- Fabriken: `section`, `key_chip`, `card`, `stat_row`, `button(text, variation)`, `styled`,
  `wrapped`, `bar(height, fill)`, `tooltip`, `fade_in`.
- Typvariationen:
  - Panels: `WindowPanel`, `HudPanel`, `CardPanel`, `SelectedCardPanel`, `InsetPanel`, `KeyChip`
  - Buttons: `PrimaryButton`, `DangerButton`, `TabButton`, `InventorySlot`, `FlatButton`
- Zustände Hover, Pressed, Focus (Cyan-Rahmen) und Disabled sind für jeden Button-Typ definiert.

## Seltenheit
| Seltenheit | Wort | Punkte |
|---|---|---|
| Common | „Common“ | 0 |
| Magic | „Magic“ | 1 |
| Rare | „Rare“ | 2 |
| Epic | „Epic“ | 3 |
| Set | „Set“ | 3 |
| Legendary | „Legendary“ | 4 |
| Unique | „Unique“ | 4 |

Die Farben stehen in `UiTheme.RARITY`.
