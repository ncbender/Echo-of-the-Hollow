# Talent UI Polish 1.2 – Book Tabs & Full Talent Tree Overview – Bericht

Branch `dev/talent-ui-polish-12` (Basis `13cbaad`, Ende von `dev/ui-ux-polish-11`), kein Push.
- `project.godot` hat weiterhin fremde uncommittete Änderungen; nicht angefasst, nicht committet.
- Keine Save-Dateien verändert; Tests schreiben nur nach `user://test_saves/`.
- Nur Darstellung geändert. Talentdaten, `TalentService`, Punkteschwellen, Voraussetzungen, Ränge,
  Klassenlevel, Combat, Dash, Inventar-Rechtsklick, Item-Hover, Forge, Save-System, Quests und
  Item-IDs sind unverändert.

## Abnahme: drei Bäume, sieben Tiers, 1920×1080 / 100 %, ohne Scrollen – **erfüllt**

**Nachweis:**
- **Test** `test_class_ui.gd::test_all_talents_visible_without_scrolling_for_every_class` prüft für
  Warrior, Arcanist und Shadowrunner bei 1920×1080 und 100 %:
  - keine sichtbare Scrollleiste im Baumbereich und im Fenster
  - drei Bäume, 39 Talente, sieben Tiers
  - jeder Knoten vollständig im sichtbaren Bereich und im Fenster
  - keine Überlappung zwischen Knoten
  - jede Tier-Zeile über alle drei Bäume auf derselben Höhe ausgerichtet
  - normales Layout mit Namen (nicht kompakt)
- **Screenshots:**
  - `1080p_100_talents.png` und `1080p_100_talents_full.png` (Warrior, volle Belegung mit Capstone-Tooltip)
  - `1080p_100_talents_arcanist.png` und `1080p_100_talents_shadowrunner.png`
  - geprüft von Tier 1 bis Tier 7 inklusive Capstones; Ranganzeigen und Linien vollständig.
- Die Bäume füllen den Raum: drei Spalten zu je etwa 537 px und Zeilen von etwa 111 px statt kleiner Bäume mit Leerfläche.

## A – Book Tabs (`scripts/ui/book_tabs.gd`)
- **Darstellung:**
  - Senkrechte Register Classes / Talents / Skills / Presets / Quests außen am linken Rand des Klassenfensters, 6 px unter den Rahmen geschoben.
  - Dunkles Leder, Bronze-Kante, Naht und Niete links vom Text; das aktive Register in entsättigtem Pergament und 10 px weiter herausragend.
  - Hover heller, Fokus mit Cyan-Rahmen.
- **Bedienung:**
  - Linksklick wechselt die Seite; es ist immer nur ein Register aktiv.
  - Tastatur: Fokus und Enter funktionieren.
  - Gleiche API wie `UiTabs` (Knoten `Tab<Id>`).
- **`UiWindow.set_side_tabs`:** Das Register ist ein Top-Level-Kind des Fensters. Das Fenster reserviert dessen Breite und zentriert Fenster und Register gemeinsam; beide bleiben auch bei 150/200 % im Bild (geprüft).
- Die horizontale Tab-Leiste des Klassenfensters ist entfernt. Andere Fenster (Inventar, Forge, Journal, Optionen) behalten ihre Reiter, wie gefordert.
- Ein Seitenwechsel ändert nichts an Talenten, Skill-Slots oder Presets (Test).

## B – Kompakter Kopf
- **Eine Zeile:** `Warrior · Lv. 56 (dünner XP-Strich) · Rage · 44 Talent Points · At Class Station / Away from Station … Reset talents`.
  - Die Stationsregeln stehen im Tooltip des Status, statt des langen Textes.
  - XP, Ressourcenwerte und Punkteherkunft ebenfalls als Tooltips.
  - Bei hoher Skalierung bricht der Kopf um (`HFlowContainer`).
- **Respec** steht nur auf der Talentseite; außerhalb der Station gesperrt, mit Begründung.
- Stationsregeln unverändert: Lernen überall, Klassenwechsel, Skills/Mods, Presets, Respec und Quests nur an der Station.
- **Ergebnismeldungen** („Learned …“) stehen jetzt unten links neben „Close“, außerhalb des Layouts. Vorher schoben sie die Seite: Nach jedem Lernklick sprang der Baum unter der Maus weg. Gefunden im Maus-Playtest, behoben, Test „no layout jump“.
- Entfernt: Infokarten-Chips, die doppelte Talent-Überschrift und der lange Regeltext (jetzt eine Legendenzeile unter den Bäumen).

## C – Tooltip statt Detailleiste (`scripts/ui/talent_tooltip.gd`)
- Die permanente Detailleiste ist entfernt.
- **Der `TalentTooltip` erscheint sofort** bei Hover oder Tastaturfokus. Inhalt in dieser Reihenfolge:
  1. Name
  2. Art (Passive / Skill / Transformation), Tier, Rang
  3. aktueller Effekt
  4. nächster Rang bzw. Effekt auf Rang 1, ggf. freigeschalteter Skill
  5. Voraussetzungen, grün erfüllt / gelb fehlend, mit Zählern (z. B. „25 points in lower tiers of Bloodblade (0 / 25)“), Voraussetzungs-Talente, Klassenlevel
  6. Kosten mit freien Punkten
  7. Capstone-Regel aus den Daten („Only one capstone fits into a build (at most N points)“)
  8. Sperrgrund aus `TalentService.can_learn` bzw. „Click to learn a rank.“ / „Fully learned.“
- **Platzierung:** rechts vom Knoten, sonst links, sonst darunter/darüber; immer im Bild; verdeckt den Knoten nicht; nimmt keine Mauseingaben an; verschiebt kein Layout; verschwindet beim Verlassen.
- Die automatische Erstfokussierung beim Öffnen zeigt keinen Tooltip; echter Tastaturfokus schon.
- Hover gibt nie Punkte aus. Ein Klick lernt einen Rang wie bisher über `TalentService.learn`. Danach erscheint der Tooltip für denselben Knoten wieder.

## D/E – Talent-Layout (`talent_layout.gd`, `talent_tier_scale.gd`, `talent_tree_view.gd`)
- **Aufbau:**
  - Eine gemeinsame Tier-Skala links (T1…T7 mit Punkteschwelle; ob eine Schwelle im jeweiligen Baum erreicht ist, zeigt der Tooltip) plus drei Baumspalten auf denselben Zeilen.
  - Kopf je Baum: Name in Baumfarbe und investierte Punkte. Leichte Tier-Bänder im Hintergrund.
  - Knoten: Symbol nach Art, Zustandsrahmen, Markierung (Maxed Doppelrahmen und Raute, Available „+“, Locked Schloss), Rang-Badge immer im Knoten.
  - Kurzer Name darunter nur im normalen Layout.
  - Linien: dünn für den Weg nach unten, dick für explizite Voraussetzungen.
- **`TalentLayout.pick(room, trees)`** berechnet Spaltenbreite, Zeilenhöhe und Knotengröße aus dem freien Fensterraum, in ganzen Pixeln. Ein Bruchteil-Pixel hatte zuvor eine Scrollleiste ausgelöst; im Screenshot gefunden und behoben.
  - **Normal** (Zeile ≥ 78 px): mit Namen, Zeilen bis 118 px.
  - **Kompakt** (z. B. 150 %): nur Symbole, Namen im Tooltip, Zeilen ≥ 50 px, Bäume ab 190 px breit.
  - Erst darunter (200 %) scrollt der Baumbereich senkrecht, während Kopf, Register und Legende sichtbar bleiben.
- Das Layout wird bei Fenstergröße, Skalierung und Umbruch von Kopf oder Legende neu berechnet, nur bei echter Änderung.
- Rein datengetrieben (Tier, Spalte, Voraussetzungen der Knoten), keine festen Knotennamen; Guardian/Soulbinder bekommen dasselbe Layout, sobald sie Bäume haben. Geprüft mit Warrior, Arcanist und Shadowrunner.

## F – Prüfung nach Auflösung (echtes Fenster)

| Auflösung / Skalierung | Talentseite | Ergebnis |
|---|---|---|
| 1280×720 / 100 % | normal, kein Scrollen (gleicher Design-Canvas wie 1080p) | Galerie und Class-Playtest OK |
| 1920×1080 / 100 % | normal, kein Scrollen, alle 7 Tiers | OK (Abnahme) |
| 1920×1080 / 150 % | kompakt, alle 7 Tiers ohne Scrollen | OK |
| 2560×1440 / 100 % | normal, kein Scrollen | OK (Galerie + Class-Playtest) |
| 3840×2160 / 100 % | normal, kein Scrollen | OK |
| 3840×2160 / 150 % | kompakt, ohne Scrollen | OK |
| 1080p / 4K / 720p / 1440p bei 200 % | kompakt, Baumbereich scrollt senkrecht; Kopf bricht um | OK, gewolltes Verhalten |

**Echte Maus** (`class_playtest.gd`, OS-Cursor plus Eingabeereignisse, alle 6 Pässe):
- Hover in allen drei Bäumen: links (Hot Temper), rechter Rand oben (Open Veins), Mitte oben (Heavy Hands), unten/Capstone (Worldbreaker), rechts unten gesperrt (Blood Price).
- Geprüft: Tooltip zeigt den richtigen Knoten, liegt im Bild und verdeckt den Knoten nicht.
- Ein Klick lernt einen Rang; der Tooltip ist danach wieder da.
- Klick auf die Register Skills und Talents bei heruntergescrolltem Baumbereich.

**Integrationstests (Mausereignisse über `push_input`):**
- Hover gibt nichts aus; Klick lernt; kein Layoutsprung.
- Respec außerhalb der Station gesperrt.
- Save/Load nach der Talentänderung: ganzer Build identisch.

**Selbst gefundene und behobene Layoutprobleme:**
- Scrollleiste durch Bruchteil-Pixel
- zu niedrige Bäume, weil der Kopf beim ersten Layout umbrach
- Kopf und Bäume bei 200 % zu breit
- Statuszeile verschob die Bäume

## Tests
| Lauf | Ergebnis |
|---|---|
| `check_project.ps1` | OK |
| Volle Suite | **461 bestanden, 0 fehlgeschlagen** |
| `class_ui` (3 neue Tests, 1 umgeschrieben, 2 an Tooltip-API angepasst) | 7 / 7 |
| UI-Galerie 1080p / 4K / 720p / 1440p × 100 / 150 / 200 % (38 Bildschirme, darunter 6 Talent- und 2 Klassenansichten) | **1296 Prüfungen, 0 Fehler** |
| `class_playtest.gd` (6 Pässe, echte Maus) | 168, 0 Fehler, keine übersprungene Prüfung |
| `ui_playtest.gd` | 225, 0 Fehler |
| `prologue_playtest.gd --fixed-fps 60` | OK |

## Screenshots (`docs/screenshots/talent_ui_polish_12/`)
- **Talentübersicht 1080p/100 %:** `1080p_100_talents.png`, `1080p_100_talents_full.png` (alle drei Bäume; Capstone mit Tooltip)
- **Andere Klassen:** `1080p_100_talents_arcanist.png`, `1080p_100_talents_shadowrunner.png`
- **Hover am rechten Rand:** `mouse_1080p_100_war_bb_veins.png` (oben rechts, echte Maus), `1080p_100_talents_locked.png`
- **Tooltip eines gesperrten Talents:** `mouse_1080p_100_war_bb_price.png`, `1080p_100_talents_locked.png`
- **Höchstes Tier mit Capstone:** `1080p_100_talents_full.png`, `mouse_1080p_100_war_wb_worldbreaker.png`
- **Book Tabs:** `1080p_100_classes.png`, `1080p_100_classes_locked.png`, `1080p_100_skills.png`, `1080p_100_presets.png`, `1080p_150_skills.png`
- **150 %:** `1080p_150_talents*.png`, `1080p_150_talents_arcanist.png`, `1080p_150_talents_shadowrunner.png`, `mouse_1080p_150_war_bb_price.png`
- **Weitere Auflösungen:** `720p_100_*`, `1440p_100_*`, `2160p_100_*`, `2160p_150_*`, `mouse_2160p_150_war_wb_worldbreaker.png`, `1080p_200_talents*.png` (Scrollfall)
- `gallery_log.txt`

## Geänderte Dateien
- **Neu:** `scripts/ui/book_tabs.gd`, `talent_layout.gd`, `talent_tier_scale.gd`, `talent_tooltip.gd`
- **Geändert:** `scripts/ui/class_station_panel.gd` (Register, Kopf, Status, Talentseite, Tooltip-Steuerung), `talent_tree_view.gd` (neu aufgebaut), `ui_window.gd` (Seitenregister)
- **Tests:** `tests/integration/test_class_ui.gd`, `tests/playtest/class_playtest.gd` (Pässe 720p/1440p ergänzt, Maus-Abschnitt neu), `tests/playtest/gallery_screens.gd` (Bildschirme `talents_locked`, `talents_arcanist`, `talents_shadowrunner`)
- **Doku:** `docs/UI_DESIGN_SYSTEM.md`, `TEST_STRATEGY.md`, `DEVELOPMENT_ROADMAP.md`, `CLAUDE.md`, dieser Bericht

## Bekannte Einschränkungen und Abweichungen
- **Kompaktes Layout ab 150 %:** Talentnamen stehen dann nur im Tooltip. Das ist bewusst so, damit nichts unlesbar klein wird.
- **200 %:** Der Baumbereich scrollt senkrecht, wie für den Platzmangel vorgesehen.
- **Lange Voraussetzungslinien:** Explizite Voraussetzungen über mehrere Tiers (z. B. Runemaster: Arcane Rift → Grand Rift) laufen senkrecht hinter Namen dazwischenliegender Knoten. Die Namen bleiben lesbar, die Linie liegt dahinter.
- **Tooltip bei 4K/150 %:** Er kann den unteren Rand und den Close-Knopf vorübergehend überdecken, solange die Maus auf dem Knoten bleibt.
- **Vorbereitete Klassen:** Guardian/Soulbinder haben keine Talentbäume; das Layout ist dafür vorbereitet, aber nicht mit echten Daten geprüft.
- **Grafik provisorisch:** Register und Knotensymbole sind prozedural gezeichnet (keine Pixel-Art-Sprites).
- **Abweichung bei den Tests:** Der Class-Playtest prüft „Tooltip nach dem Lernen wieder da“ nur, wenn Godots Mausposition wirklich auf dem Knoten liegt. Der OS-Cursor (`warp_mouse`) und synthetische Ereignisse liefen im ersten Fensterpass auseinander; dann wird protokolliert statt bewertet. Im letzten Lauf wurde nichts übersprungen. Deterministisch prüft das der Integrationstest.

## Lokale Commits
| Commit | Inhalt |
|---|---|
| `96f6730` | A: BookTabs und UiWindow-Seitenregister |
| `70b6570` | B–E: Kopf, Status, Talentseite, TalentTooltip, Layout, Tests |
| (dieser Commit) | G: Doku, Screenshots, Bericht |

---

## Phase A2 – Book Tabs Stability Fix 1.3

**Ursache des Springens:** Zwei Effekte wirkten zusammen.
- **Das Klassenfenster passte sich dem Inhalt jeder Seite an.** `UiWindow.fit()` nimmt die bevorzugte Größe des Inhalts und zentriert das Fenster. Die Register hängen mit festem Versatz am linken Fensterrand und wanderten deshalb mit. Gemessen bei 1080p/100 % vor dem Fix: Classes → Talents, das Fenster wächst von 1196×625 auf 1763×1040, die Register springen um 284 px nach links und 207 px nach oben.
- **Die Registerspalte war bei der ersten Platzierung 10 px schmaler.** Das herausragende aktive Register verbreiterte sie erst danach.

**Fix:**
- `ClassStationPanel.preferred_body_size` liefert für alle fünf Seiten denselben Rahmen: den vollen verfügbaren Platz abzüglich Register und Rand. Das Fenster ändert Größe und Lage beim Seitenwechsel nicht mehr. Kleinere Seiten stehen oben links in diesem Rahmen; größere scrollen innen (z. B. Classes bei 200 % waagerecht).
- `BookTabs` hat eine feste Breite (Register plus Überstand). Das aktive Register ragt nur optisch nach links heraus, ohne Layout zu verschieben.
- **Bei der Prüfung gefunden:** Bei 200 % setzte das Lernen eines Talents die Scrollposition des Baumbereichs auf 0 zurück, der Knoten sprang unter der Maus weg. Die Scrollposition bleibt jetzt beim Neuaufbau nach dem Lernen erhalten; ein Seitenwechsel beginnt oben.
- Unverändert: Talente, Klassenwechselregeln, Save-Daten. Die Talentseite bei 1920×1080/100 % zeigt weiter alle drei Bäume mit allen sieben Tiers ohne Scrollen (Abnahmetest grün, zusätzlich im Stabilitätstest geprüft).

**Tests:**

| Test | Ergebnis |
|---|---|
| `class_ui::test_book_tabs_never_move_when_switching_pages`: alle fünf Seiten zweimal (Klick und Tastatur Enter) bei 100/150/200 %; Fenster-Rect, Spalten-Rect sowie Lage und Seitenkante jedes Registers exakt gleich; Rahmen und Register im Viewport; danach Talentseite komplett ohne Scrollen | grün. Mit zurückgenommenem Fix schlägt er genau mit dem beschriebenen Sprung fehl (gegengeprüft) |
| `class_ui::test_learning_keeps_the_scrolled_tree_view_at_200_percent` | grün |
| `class_playtest.gd`, echtes Fenster, 720p, 1080p und 4K × 100/150/200 % plus 1440p/100 %: zwei Runden über alle Register, erst echte Mausklicks, dann echte Tastenereignisse (Pfeil runter + Enter), Koordinatenvergleich nach jedem Wechsel | 400 Prüfungen, 0 Fehler, keine übersprungene Prüfung |
| UI-Galerie Klassenseiten 720p/1080p/4K × 100/150/200 % | 243 Prüfungen, 0 Fehler |
| Volle Suite / Startprüfung | 463 bestanden, 0 fehlgeschlagen / OK |

**Bekannt:** Auf kleinen Seiten (Presets, Quests) bleibt bei 1080p/100 % unten Leerfläche, weil der Rahmen absichtlich fest ist. Bei 200 % scrollt die Klassenseite waagerecht innerhalb des Rahmens.
