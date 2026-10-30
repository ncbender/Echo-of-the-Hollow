# HUD Resource Text Readability 1.0

> **Abgelöst durch Combat HUD UX 2.0 (`COMBAT_HUD_UX_2_0.md`):** Die Ressourcenleiste im PlayerFrame gibt es nicht
> mehr. Der Wert steht als Zahl mit dunkler Kontur im Ressourcengefäß. `SplitBarText` bleibt als Komponente erhalten.

Der Wert in der 12-px-Klassenressourcenleiste (PlayerFrame) ist auf jeder Ressourcenfarbe lesbar. HUD-Layout,
Leistenhöhe, Ressourcenfarben und -werte, die Balken-Art (53 PNGs) und der EXP-Balken bleiben unverändert.

## Gemessene Ursache

Kontrast (WCAG) des hellen Texts (Parchment) bzw. dunklen Texts (Ink #0E0F12) auf der Füllung:

| Ressource (Klasse) | hell / Füllung | dunkel / Füllung | spielbar |
|---|---|---|---|
| Rage (Warrior) | 3,2 | 4,4 | ja |
| Mana (Arcanist) | 2,0 | 7,1 | ja |
| Focus (Shadowrunner) | 1,0 | 14,0 | ja |
| Resolve (Guardian) | 1,1 | 15,4 | nein |
| Soul Energy (Soulbinder) | 1,0 | 14,3 | nein |

Heller Text auf der leeren Rinne: 13,8. Auf Gelb / Türkis / Hellgelb war heller Text praktisch unsichtbar (1:1),
nur die Kontur trug ihn.

Geometrie: Leiste 12 px, Rinne innen 10 px. IBM Plex Mono: Ziffern ~9-10 px hoch, `/`, `g`, `y` reichen 3 px
unter die Grundlinie - die ganze Zeile (Versal bis Unterlänge) ist schon bei 9 px Schrift 11 px hoch. **Für Text
mit Unterlängen ist die Leiste objektiv zu niedrig**: Ziffern bleiben in der Leiste, Schrägstrich und Unterlängen
berühren die untere Rahmenlinie. Kleinste Korrektur: Ressourcenleiste 12 → 14 px (wie der EXP-Balken).

## Resource Bar Height Final Fix 1.0 (umgesetzt)

`PlayerFrame.RESOURCE_BAR_HEIGHT = 14` (war 12), Text weiter 12 px (`RESOURCE_FONT_SIZE`; die Größenanpassung hätte
in 14 px auf 13 px vergrößert und den Gewinn aufgezehrt), SplitBarText, Farben, Füllstände und Zentrierung unverändert.
PlayerFrame wird dadurch 2 px höher; Reihenfolge (Titel, HP, Ressource, Dash, Buffs, Mastery) und Anker gleich.

Gemessen an den echten Pixeln (BarText einzeln in einem transparenten SubViewport, `ui_art_check` Szene
`resource_geometry`, alle Texte mit `/` und Unterlängen; bei jeder UI-Skalierung gleich):

| Leiste | Glyphen | Glyphen + Kontur 2 | Rahmenzeilen |
|---|---|---|---|
| 12 px | - | 1..12 (über den Rand) | 0, 11 |
| **14 px** | **3..12 (in der Rinne 1..12)** | 2..13 | 0, 13 |
| 15 px | - | 3..14 | 0, 14 |
| 16 px | - | 3..14 (in der Rinne) | 0, 15 |

Ziffern, Schrägstriche und Unterlängen berühren den Rahmen nicht mehr. Nur die 1-px-Kontur unter einer Unterlänge
(„g“, „y“, „/“) liegt auf der unteren Rahmenzeile (dunkel auf Stahl-dunkel). Ursache: Der Textblock ist mit Kontur
12 Zeilen hoch = die Rinne; die Zentrierung auf die Ziffern setzt ihn 1 Zeile tief (unten 3 px Unterlänge, oben
keine). Mindesthöhe für Glyphen **und** Kontur in der Rinne bei unveränderter Zentrierung: **16 px**.

## Verglichene Varianten (echte Daten, alle Ressourcen, 0-100)

- **A** heller Text auf einer dunklen Platte hinter dem Text: lesbar, aber die Platte zerschneidet die Füllung
  (75 % sah wie zwei Segmente aus, die Füllkante unter dem Text war verdeckt).
- **B** adaptiv: über dem gefüllten Teil einer hellen Füllung dunkler Text, über der leeren Rinne (und auf dunklen
  Füllungen wie Rage) heller Text mit Kontur - genau an der Füllkante geteilt. **Gewählt.**

## Lösung

`SplitBarText` (`scripts/ui/hud/split_bar_text.gd`): zwei `BarText` mit gleichem Text, gleicher Größe und Lage,
je in einem Clip-Bereich links / rechts der Füllkante (ein Glyph, der die Kante kreuzt, wechselt pixelgenau die
Farbe). Dunkel auf der Füllung, wenn heller Text dort < 3:1 erreicht (`MIN_CONTRAST`) - Mana, Focus, Resolve,
Soul Energy; Rage bleibt hell (3,2:1 + Kontur). Füllkante = `round(ratio × Breite) − 1` (Rahmen). Schrift wie
bisher über `BarText` (12 px bei 75-150 %, Kontur 2), auf die Ziffern zentriert.

## Prüfung

`test_ui_usability` (Kontrast aller fünf Farben, Teilung an der Kante, beide Hälften deckungsgleich, leere Leiste
nur hell, Zentrierung inkl. „Mana 1 / 100“, „Focus 8 / 100“, „Focus 9 / 100“, „Soul Energy 100 / 100“, 75 %
lesbare Größe); `tests/playtest/ui_art_check.gd` Szene `resource_text` (Rage, Mana, Focus bei 0, 1, 5, 8, 9, 25,
50, 75, 100 → Sammelbild pro Auflösung).
