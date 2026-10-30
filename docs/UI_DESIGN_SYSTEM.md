# UI-Designsystem „The Forgotten Chronicle“ (UI/UX Redesign 1.0)

Verbindlich für alle spielerseitigen Oberflächen. Technische Grundregeln (Design-Pixel, UI-Skalierung,
`UiWindow`-Größenregel) stehen in `DISPLAY_AND_UI_STANDARD.md`.

## Leitlinien
- Dark Classic Pixel Art und matt: neutrale Charcoal-/Slate-Flächen (UI Visual Consistency 1.0, ohne
  Grünstich), verwitterte Bronze für Rahmen und Titel,
  Pergamenttöne für Text, sparsames Resonanz-Cyan für Aktives, Fokus und Magisches.
- Wenig Dekor: Bronze-Eckwinkel an Fenstern, dünne Trennlinien, keine Goldornamente, kein Leuchten
  ohne Grund.
- Information vor Schmuck: klare Hierarchie (Titel → Abschnitt → Inhalt → Hinweis).
- Zustände nie nur über Farbe: Seltenheit über Farbe plus Punkte am Icon plus Wort, Sperren über
  Text, wichtige Meldungen über Symbol oder Wort.

## Tokens (`UiTheme`)
| Token | Wert | Verwendung |
|---|---|---|
| `BG` | `#16181C` | tiefster Hintergrund, HUD-Panels (transparent) |
| `PANEL` | `#23262C` | Fenster, Panels |
| `PANEL_ELEVATED` | `#30343B` (Slate) | Karten, ausgewählte Bereiche, Popups |
| `PANEL_INSET` | `#191B20` (Charcoal) | Listen, Slots, Eingabefelder |
| `BRONZE` / `BRONZE_DIM` / `BRONZE_DARK` | `#C5AD85` / `#7D6C52` / `#4A4134` | Titel, Rahmen, Trennlinien |
| `TEXT_PRIMARY` / `TEXT_SECONDARY` / `TEXT_MUTED` | `#E9DDC5` / `#B3AEA4` / `#85827B` | Text-Hierarchie |
| `RESONANCE` / `RESONANCE_DIM` | `#78B8C5` / `#4D7A83` | Aktiv, Fokus, Fortschritt, Magie |
| `SUCCESS` / `WARNING` / `DANGER` | `#9CBF7E` / `#D9B46A` / `#D27461` | Status, Kosten erfüllt/fehlend, Fehler |
| `HEALTH` / `POISE` / `PARCHMENT` | `#B4493F` / `#C9A95C` / `#EADCB8` | Leisten, hervorgehobener Text |

Alte Namen (`COLOR_TEXT`, `COLOR_ACCENT` …) sind Aliase dieser Tokens.

## Typografie
| Stufe | Größe | Variation |
|---|---|---|
| Display (Titelbildschirm) | 64 | `DisplayLabel` (Silkscreen) |
| Fenstertitel | 32 | `TitleLabel` (Silkscreen, Bronze) |
| Überschrift | 24 | `HeaderLabel` (Silkscreen, Bronze) |
| Kurzer Abschnittstitel (Tracker, Bossname) | 16 | `FONT_SECTION` (Silkscreen) |
| Zwischenüberschrift | 20 | `SubheadingLabel` |
| Fließtext | 18 | Standard |
| Klein | 15 | `SmallLabel` |
| Beschriftung | 14 | `CaptionLabel`; Abschnittsköpfe in Versalien und Bronze |


Dichte Menüseiten (Menu UX Polish 1.0, `docs/MENU_UX_POLISH_1_0.md`; Skills, Quests, Professions, Journal): eigene
Variationen, globale Werte unverändert - `MenuHeadingLabel` 16 (Silkscreen, Bronze), `MenuTitleLabel` 18,
`MenuTextLabel` 15 (Fließtext, Aufgaben), `MenuMetaLabel` 14 (Metadaten, sekundär); Helfer `UiTheme.menu_text`.

- Schriften (UI Font Integration 1.0, `docs/UI_FONT_INTEGRATION_1_0.md`): **IBM Plex Mono Regular** für allen Text
  (`UiTheme.body_font()`), **Silkscreen** nur für Titel, Überschriften und Display (`UiTheme.display_font()`,
  8-px-Raster: 16 / 24 / 32 / 64). Keine weiteren Schriften, keine biomeabhängigen Fonts.

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
  „Ausgewählt“ (toggle pressed) hat einen Bronze-Rahmen und ist damit vom Fokus (Cyan) unterscheidbar.

### Komponenten der Phasen B–G
- `ItemCell` (Inventar- und Paperdoll-Zelle): Icon, Menge, Seltenheitsrahmen, Drag & Drop. Drop ruft nur
  die vorhandenen Equipment-Aufrufe auf, nie direkte Datenänderungen.
- `ItemDescriber`: einzige Quelle für Item-Texte (Tooltip, Detailkarte, Vergleich). Feste Reihenfolge:
  Kopf, Basis, Material, Affixe, Essenzen, Sockel, Qualität, Unique/Set/Evolution, Vergleich.
- HUD-Teile unter `scripts/ui/hud/`: `PlayerFrame`, `ChargeMeter`, `TargetFrame` (Gegner/Boss),
  `LootFeed`, `DeathOverlay`; dazu `SkillBar`, `ObjectivePanel` (Tracker), `SaveIndicator`.
  Nur lesend; die Knoten tragen feste Namen (`PlayerFrame`, `SkillBar`, `QuestTracker`, …).
- `JournalPanel` (`StageTrack`), `WorldMapPanel` (`MapGraph` aus `MapDefinition.map_cell/neighbors`),
  `SaveSlotList` (gemeinsame Slotliste für Titel und Pausemenü).

### Komponenten aus UI/UX Polish 1.1
- `CardButton` (Typvariation): klickbare Karte, ausgewählt = Bronze-Rahmen (Klassenkarten).
- `ClassEmblem`: provisorisches Klassen-Icon (Raute in der Ressourcenfarbe, Initiale), gesperrt gedimmt.
- Klassenseite: kompakte Karten (Emblem, Name, Status Active/Unlocked/Locked, Level, zwei Zeilen
  `ClassDefinition.tagline`) links, Detailbereich rechts (Ressource aus Daten, Spielstil, Bäume,
  Voraussetzungen aus Prolog-Regeln und Klassenquest). Vorbereitete Klassen bleiben ausgeblendet.
- `TalentTreeView`: Knotengraph statt Textknöpfe. Tier 1 oben bis 7 unten, quadratische Knoten mit
  Symbol (Raute passiv, Kreis Skill, Stern Transformation), Rang-Badge, Zustandsfarbe; Linien für den
  Weg nach unten (dünn) und explizite Voraussetzungen (dick). Die drei Bäume stehen immer
  nebeneinander in `TreeScroll`, das bei wenig Platz selbst scrollt. Darüber eine Detailleiste
  (Hover/Fokus/Klick).
- `ItemTooltip`: sofortiger Item-Tooltip des Inventars mit „EQUIPPED“-Vergleichskarten. Liegt neben
  der Zelle, sonst links davon, sonst darunter/darüber, immer im Bild. Auf kleinen Canvases fallen
  zuerst die Vergleichskarten weg, dann zwei Spalten, dann eine kompakte dreispaltige Karte ohne
  gedimmte Zeilen.
- `ToastFeed`: kompakte HUD-Paneele mit Farbakzent; gleiche Meldungen werden zusammengefasst („x2“).
- `BuildPanel`: Rezeptkarten (Ausgabe-Icon, „have / need“, Grund bei Sperre).

### Komponenten aus Talent UI Polish 1.2
- `BookTabs`: senkrechte Seitenregister außen am linken Fensterrand (Leder, Bronze-Kante, Naht,
  Niete; aktives Register Pergament und weiter herausragend). Gleiche API wie `UiTabs`
  (`Tab<Id>`). Ein `UiWindow` nimmt sie über `set_side_tabs` auf und hält Fenster plus Register im Bild.
  Bisher nur im Charakter-/Klassenfenster.
- Klassenfenster: Kopf in einer Zeile (Klasse · Lv. + XP-Strich · Ressource · Talentpunkte ·
  Stationsstatus mit Tooltip … Respec). Ergebnis-Meldungen unten links neben „Close“ (top level), damit
  nichts verrutscht.
- Talentseite: gemeinsame `TalentTierScale` plus drei `TalentTreeView`-Spalten auf denselben Zeilen.
  `TalentLayout.pick` füllt den freien Platz (normal mit Namen, Zeilen 78–118 px; kompakt ohne Namen ab
  150 %; erst darunter scrollt der Baumbereich). Knoten-Zustände auch ohne Farbe erkennbar (Maxed:
  Doppelrahmen und Raute, Available: „+“, Locked: Schloss).
- `TalentTooltip`: sofort bei Hover oder Fokus; Name, Art, Tier, Rang, aktueller und nächster Effekt,
  Voraussetzungen (erfüllt/fehlend), Sperrgrund, Kosten, Capstone-Regel. Neben dem Knoten, immer im
  Bild, nimmt keine Maus an. Nach dem Lernen erscheint er für denselben Knoten wieder.

## HUD-Layout
- Oben Mitte: Ziel-/Bossrahmen, darunter Hinweis. Breite nie größer als der Raum zwischen den Spalten.
- Oben links: aktive Effekte (`EffectBar`). Oben rechts: Minimap, darunter der Journey-Tracker. Unten links: die
  Menüleiste. Unten rechts: Loot-Feed über der Save-Anzeige.
- Unten Mitte (Combat HUD UX 2.0, `docs/COMBAT_HUD_UX_2_0.md`): die Kampfeinheit HP-Gefäß | 1 2 + Q E R F |
  Ressourcengefäß, darunter Level-Abzeichen | EXP-Balken | Pressure-Abzeichen; Dash-Segmente unter der Spielfigur.
- Unten Mitte: Spalte mit Toasts, Charge-Leiste, Interaktionshinweis und Skillleiste (Inhaltsbreite).
  Auf schmalen Canvases (150 %/200 %) rückt die Spalte nach rechts, bis sie den Spielerrahmen nicht mehr
  berührt. Passt die Skillleiste gar nicht daneben, steht sie zentriert über dem Rahmen
  (`GameHud._layout_bottom`); dann wandert der Loot-Feed (2 Zeilen) in die freie Ecke unten rechts und
  der Hinweis unter den Quest-Tracker (`_layout_hint`).
- Die Galerie prüft paarweise, dass sich diese HUD-Teile nicht überlappen.

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
