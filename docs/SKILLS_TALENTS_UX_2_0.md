# Skills & Talents UX 2.0

Redesign der sieben Tabs des Fensters „Skills & Talents“ (Klassenstation). **Phase 1: Weapons**, **Phase 2:
Talents**, **Phase 3: Skills**, **Phase 4: Presets**, **Phase 5: Quests**, **Phase 6: Classes** und **Phase 7: Armor** - umgesetzt (alle sieben Tabs). Fenster 1120 × 760
(Main Window Layout Lock 1.0), BookTabs, Tastenbelegung, Save v15 unverändert.

## Gemeinsame UX-Prinzipien (für alle Tabs)

A. Jeder Tab beantwortet eine zentrale Spielerfrage (Weapons: „Was kann meine Waffe?“).
B. Keine langen Erklärtexte; Daten statt Prosa.
C. Erst Übersicht, dann Details.
D. Auswahl links / oben, Details rechts.
E. Scrollen nur in Inhaltsbereichen, nie das ganze Fenster.
F. Gleiche Abstände (`UiTheme.GAP`), Typografie (Plex / Silkscreen), Interaktionen.
G. Ausgewähltes bleibt deutlich markiert (Gold: `CardButton` gedrückt = `panel/card_selected`).
H. Tastaturfokus getrennt sichtbar (Cyan-Kontur), Auswahl und Fokus gleichzeitig möglich.

## Weapons-Tab

Datenquelle der aktiven Familie: `CharacterEquipment.main_hand_family()` (aktives Loadout, bei einem Trial dessen
Loadout). Es gibt genau einen Waffen-Slot (Weapon Mastery 1.4: keine Waffe in der Nebenhand, kein Dual Wield,
kein Quick-Swap) - also nie zwei Familien zugleich. Ohne Waffe: Leerzustand „No weapon equipped“ mit Hinweis
auf das Inventar [I] und dem Fakt, dass unbewaffnet die Grundangriffe der Fallback-Familie
(`rules.fallback_weapon_family`, One-Handed Sword) laufen - deren Mastery wird nicht als aktiv gezeigt.
Gespeicherte Mastery anderer Familien bleibt erhalten, wird hier nicht gezeigt.

Aufbau (`ClassStationPanel._build_weapons`):
- oben `WeaponMastery`: Familienname, „Mastery x / max“ (`MasteryTrack.max_level`), XP-Leiste, „XP a / b ·
  next: <Combo> at <Lv>“ bzw. „Mastered · every combo unlocked“;
- Mitte links `Combos`: Raster 5 Spalten, je Combo eine Karte (Icon 2×, Name bis zwei Zeilen, „Base“ / „Lv n“);
  Reihenfolge: Grundangriffe L / H (Bogen L / P), dann die Pfade nach Freischaltlevel;
- Mitte rechts `ComboDetail`: Icon 3×, Name, Eingaben als Key-Chips (Flowing Draw: „Hold LMB“), Status
  („Unlocked“ / „Locked · mastery n (now m)“), Beschreibung nur wenn sie mehr sagt als „Eingaben: Name.“
  (z. B. Flowing Draw), Fakten aus dem Abschlussangriff: Final hit quick / heavy / precision, Ausfallschritt
  vorwärts / seitlich (px), Treffer pro Ziel, Projektilanzahl;
- unten eine Zeile Legende (L / H bzw. L / P).

Zustände: gewählt = Gold, Fokus = Cyan, gesperrt = Icon 45 % gedimmt + „Lv n“ in Warnfarbe (anklickbar),
Hover = Tooltip mit Name, Eingaben, Status. Klick zeigt nur Details - nie Änderung an Combo, Eingaben, Kampf.
Pfeiltasten bewegen den Fokus durch das Raster (Godot-Fokusnachbarn). Auswahl je Familie gemerkt.

## Combo-Icons

Combo-Pfade haben keine eigene ID: ein Pfad = Familie + Eingabefolge (= Angriffsknoten, z. B. `axe_llh`). 72 Pfade
(9 Familien × 8; Bogen 7 + Flowing Draw) plus 18 Grundangriffe. Die Familien teilen die Folgen, die Aktion je
Folge ist bis auf Werte gleich - daher ein Icon je Aktion: `combos/<Form>_<Folge>[_<Effekt>]` (44 Dateien,
40 × 40, Raster 2×, Details 3×, Nearest), abgeleitet nur aus Daten (`ComboIcons.icon_id`):
- Form aus dem Schnellangriff: `arrow` (Bogen), `bolt` (Projektil: Zauberstab), `thrust` (Trefferbogen < 60°:
  Speer), sonst `sweep` (Schwerter, Axt, Streitkolben, Dolch, Stab - Bogentreffer, kein Klingenbild);
- Effekt aus dem Abschlussangriff: `lunge` (vorwärts), `sidestep_r` / `sidestep_l` (Dolch LHL / HHL),
  `x3` (Dolch HHH), `twin` (Zauberstab LHL / HHL);
- Bild: oben die Eingabefolge als Pips (kleine Raute L, große Gold-Raute H, Goldring P), darunter der
  Abschlusstreffer der Form (leicht Stahl, schwer / Präzision Gold) und ggf. das Effektzeichen.

## Technische Grenzen

- Die Combo-Beschreibungen der Daten wiederholen fast nur den Namen; mehr Text gibt es nicht (keine erfundenen Werte).
- Unterschiede zwischen Familien bei gleicher Folge (Reichweite, Rückstoß, Schaden) zeigt das Icon nicht.
- Die Liste wird beim Seitenwechsel / Öffnen neu gebaut (Waffen- oder Klassenwechsel passieren nicht bei offenem Fenster).

## Phase 2: Talents (umgesetzt)

> **Menu UX Polish 1.0 (`MENU_UX_POLISH_1_0.md`):** Der feste Detailblock rechts entfällt. Der Baum nutzt die ganze
> Breite (Spalten bis 240 px); darunter eine kompakte Aktionszeile `TalentDetail` (Icon, Name, Art · Tier · Rang ·
> Zustand, Kosten / freie Punkte oder der konkrete Blockiergrund aus `TalentTooltip.block_reason`, Learn / Upgrade).
> Effekte, Ränge und Voraussetzungen nur im Tooltip. Die Abschnitte unten beschreiben den Stand davor.

Zentrale Frage: „Wie baue ich meine Klasse?“ Grundlage ist die verbindliche Struktur aus Talent Structure Rework
1.0 (`TALENT_STRUCTURE_REWORK_1_0.md`). In diesem Batch unverändert: Talentdaten, Schwellen (0 / 5 / 18 / 30 Punkte
in niedrigeren Tiers desselben Baums), die sechs Upgrade-Abhängigkeiten, Effekte, Kosten, Reset-Regeln und Save v15.

### 1. Neues Talentlayout

Statt drei kleiner Bäume nebeneinander gibt es jetzt **einen** großen Baum (`ClassStationPanel._build_talents`):

```
[ Berserker · 2 ][ Warbreaker · 1 ][ Bloodblade · 0 ]     Spezialisierungs-Buttons
Tier 1 | [Karte][Karte][Karte][Karte] | TalentDetail (fest, 310 px)
5 pts  |                              |   Icon  Name, Typ · Tier
...    | [Karte][Karte][Karte][Karte] |   Rang · Zustand
Tier 4 |          [Endtalent]         |   Wirkung / Anforderungen (scrollt)
       |                              |   1 point per rank · n free
       |                              |   [ Learn | Upgrade to rank n ]
Legende (Zustände, Arten)
```

- Tier-Skala links (`TalentTierScale`): je Tier „Tier n“, die Schwelle „x pts“ und der Stand des gezeigten Baums
  („Open“ grün bzw. „7/18“ gold).
- Baum (`TalentTreeView`): 4 Zeilen, je 4 Karten, das Endtalent allein in der Mitte. Eine Karte ist eine 72 px
  hohe Leiste. Links sitzt die Icon-Kachel (42 px), rechts der ganze Name (bis zwei Zeilen) und „Rang/Max Zustand“
  in Worten (z. B. „2/5 Learned“, „0/3 Locked“).
- Zustände: Locked (dunkle Kachel + Schloss, gedimmter Name), Available (grüner Rahmen + „+“), Learned
  (Bronze-Füllung), Maxed (Doppelrahmen + Raute). Das Endtalent hat einen inneren Rahmen. Gewählt ist die goldene
  Card-Art (`CardButton` gedrückt), Tastaturfokus die Cyan-Kontur des Themes.
- Maße (`TalentLayout`, Design-px): Kartenhöhe fest. Freier Platz geht in die Abstände zwischen den Tiers (14–56 px),
  dort laufen die Linien. Spalte = (Breite − Skala − 3 × 12) / 4, also 150 px bei 1120 × 760. Reicht die Höhe nicht,
  scrollt nur `TreeScroll`.

### 2. Baum-Navigation

- Drei `CardButton`-Toggles (`TreeTab_<id>`), Text „<Name>  ·  <Punkte im Baum>“ aus `TalentTreeDefinition`.
  Der aktive Baum ist gold, der Fokus cyan, der Text in der Baumfarbe.
- Ohne frühere Wahl wird der Baum mit den meisten Punkten gezeigt (bei Gleichstand der erste). Gemerkt werden
  der gewählte Baum je Klasse und der gewählte Knoten je Baum, solange das Fenster lebt (`show_tree`, `select_talent`).
- Ein Baumwechsel baut nur den Seiteninhalt neu: Fenstergröße, Position, BookTabs, Header und andere Tabs bleiben
  unverändert; der neue Baum startet oben. Investitionen werden nie berührt.

### 3. Sichtbarkeit der Namen

- Namen ohne Kürzel. Zeilenumbruch nur an Wortgrenzen (`AUTOWRAP_WORD_SMART`), höchstens zwei Zeilen, Textspalte
  ≥ 104 px. Das längste Wort aller 117 Talente ist 12 Zeichen lang („Worldbreaker“, „Exsanguinate“,
  „Nightstalker“) und passt.
- Erst Detail 330 / Skala 76 / Kachel 44 ließ diese drei Namen mitten im Wort brechen (Test). Jetzt gilt Detail 310,
  Skala 70, Kachel 42 mit Rand 4.

### 4. Detailbereich

`TalentDetail` (fest rechts, so hoch wie der Baum) zeigt:

- Icon (Skill-Art bzw. Arten-Glyphe), den vollständigen Namen in der Baumfarbe, Typ (Passive / Skill unlock /
  Transformation) · Tier · ggf. Capstone sowie „Rank a / b · Zustand“.
- Darunter in `DetailScroll` (scrollt nur dort): aktuelle Wirkung, nächster Rang, Skill-Beschreibung,
  Anforderungen (Tier-Schwelle mit Stand, „Requires <Parent>“, Klassenlevel; erfüllt grün, offen gold),
  Sperrgrund und Endtalent-Regel. Die Zeilen kommen aus `TalentTooltip.lines(..., for_details = true)`, eine
  Quelle für Tooltip und Details.
- Fuß: „1 point per rank · n free“ und der eine Button `LearnTalent`.
- Hover-Tooltips bleiben als Zusatz (Hinweistext jetzt „Click to select, then Learn in the details.“).

### 5. Auswahl und Investition

- Ein Klick oder Enter auf einen Knoten **wählt nur aus** und investiert nie.
- Gesperrte Knoten sind anwählbar, damit ihre Bedingungen lesbar sind.
- Lernen nur über `LearnTalent`. Der Button heißt „Learn“ (Rang 0) bzw. „Upgrade to rank n“ und ruft
  `TalentService.learn`: genau ein Rang, ein Punkt.
- Er ist deaktiviert (Tooltip = Grund aus `TalentService.can_learn`), wenn die Regeln Nein sagen, und zeigt „Maxed“
  bei vollem Rang. Nach dem Lernen bleiben Auswahl und Baum; der Fokus kehrt auf den Button zurück.
- Reset unverändert („Reset talents“ im Header, nur an der Klassenstation, Kosten wie bisher).
- Lernen ist wie bisher auch abseits der Station erlaubt (C).
- Icons: Skill-Art (`UiTheme.skill_icon`, 1:1) nur bei Knoten, die genau diesen Skill freischalten (Aktiv-Talente
  inkl. Aktiv-Endtalente). Passives und Transformationen behalten die gezeichnete Glyphe (Raute / Stern).
  Keine neuen PNGs, alle vorhandenen bleiben.

### 6. Echte Abhängigkeitslinien

- Linien nur für `prerequisites` (`TalentTreeView.links`). Keine Spalten- oder Nachbar-Tier-Linien mehr.
- Die Anzeige-Spalte (`shown_columns`, reine Position, Daten unverändert) ordnet so, dass Linien sich nicht
  kreuzen und nie hinter einer Karte laufen:
  - Ein Upgrade einen Tier tiefer rückt genau unter seinen Parent (tauscht mit dem Knoten dort) und bekommt eine
    gerade Linie: Cyclone, Lance of Stars, Fan of Knives, Choking Smoke.
  - Ein Upgrade zwei Tiers tiefer (Grand Rift, Piercing Blades) nimmt die Nachbarspalte. Seine Linie knickt in den
    Zeilenabstand, läuft durch die Spaltenlücke und knickt zurück (`link_path`).
- Bladestorm: Fan of Knives und Piercing Blades teilen den ersten Abschnitt unter Blade Fan (Gabel, keine Kreuzung).
- Farbe: Bronze, wenn der Parent gelernt ist, sonst gedämpft. Kleine Pfeilspitze ins Upgrade.

### 7. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/ui/class_station_panel.gd` | Talents-Abschnitt neu: Baum-Buttons, ein Baum, `TalentDetail`, `select_talent` / `show_tree` / `selected_talent` / `shown_tree`, Learn-Button; Legende eine Zeile |
| `scripts/ui/talent_tree_view.gd` | ein Baum, Karten-Knoten (`TalentButton` als `CardButton`), Anzeige-Spalten, Linien-Routing, Auswahl statt Lernen |
| `scripts/ui/talent_layout.gd` | Layout für einen Baum: Spaltenbreite, feste Kartenhöhe, variable Tier-Abstände |
| `scripts/ui/talent_tier_scale.gd` | Tier / Schwelle / Stand („Open“, „a/b“) |
| `scripts/ui/talent_tooltip.gd` | `lines(..., for_details)`, statisches `line_label`, neuer Hinweistext |
| `tests/integration/test_talent_ui.gd` | **neu** (6 Tests) |
| `tests/integration/test_class_ui.gd` | alte Talentseiten-Tests entfernt (jetzt in `test_talent_ui`) |
| `tests/playtest/gallery_screens.gd`, `tests/playtest/class_playtest.gd` | Galerie-/Playtest-Schritte für einen Baum, Klick = Auswahl, Learn-Button |
| `docs/SKILLS_TALENTS_UX_2_0.md`, `TALENT_SYSTEM.md`, `CLASS_DESIGN.md`, `CLAUDE.md` | Doku |

Nicht geändert: Talentdaten, Schwellen, Regeln (`TalentService`), Save (v15), Weapons-Tab, Skills, Presets, Quests,
Classes, Armor, Combat, Equipment, Inventory, Crafting, XP, `project.godot`, `settings.cfg`, `docs/Design/`,
`docs/tasks/`, Spielstände, PNGs. Keine Git-Schreibaktionen.

### 8. Gezielte Tests

`test_talent_ui` (neu):

- **Baum-Buttons und Auswahl:** Namen und Punkte aus den Daten, genau ein Baum, ein Klick wählt nur aus, Learn =
  genau ein Rang / ein Punkt, Upgrade-Text, Fenster scrollt nie. Gesperrter Tier: anwählbar, Grund und Stand
  („1 / 5“), Learn aus. Maxed, Tier-Freischaltung („Open“), Available; Fokus zeigt Tooltip, Enter wählt nur aus.
- **Baumwechsel:** Fenster und BookTabs unverändert, Investitionen und Zählung bleiben, Auswahl je Baum, Seitenwechsel
  behält den Baum.
- **Alle 9 Bäume bei 100 %:** 4/4/4/1, Zeilen bündig, alles im Fenster, keine Überlappung, kein Scrollen, ganze Namen
  (≤ 2 Zeilen, kein Wort zu breit), Ranglinie passt, Endtalent mittig, eine Linie je Voraussetzung, gerade zwischen
  Nachbar-Tiers, nie durch eine Karte.
- **Skill, Upgrade, Endtalent, Reset, Klassenwechsel:** Skill-Art nur bei Aktiv-Talenten; Cyclone wartet auf
  Whirlwind; Skill-Freischaltung über Learn; Endtalent gesperrt bzw. bei 30 Punkten lernbar; 32 Learn = 32 Punkte;
  Reset an der Station; Klassenwechsel zeigt die Arcanist-Bäume.
- **Echte Maus:** Klick wählt, Klick auf Learn lernt, der Knoten bleibt stehen, kein Tooltip über Learn, Reset nur an
  der Station, Rang übersteht Speichern/Laden.
- **150 %:** gleicher Rahmen, Fenster scrollt nie, Learn und Close getrennt.

Läufe:

- `talent_ui, class_ui, talents, talent_structure, main_window_layout, ui_tab_geometry, ui_window_foundation,
  weapon_mastery_ui`: **40 / 40 grün**.
- `tools/check_project.ps1`: OK.
- `class_playtest.gd` (Fenster, echte Maus, mehrere Auflösungen / Skalen): **460 / 460 OK**.
- Die zwei früher gemeldeten fremden Fehler wurden auf ihre Ursache geprüft. Beide stammen nicht aus diesem Batch
  und sind nicht angefasst:
  - `test_prologue::test_migration_v3_to_v4`: Die v14-Migration (Commit 3f4e92a, Loot Foundation 1.0) schreibt
    absichtlich `rarity` in Ausrüstungseinträge; die Erwartung „items otherwise untouched“ ist älter.
  - `test_ui_layout::test_inventory_scrolls_instead_of_overflowing_at_150_percent` (aus cd464a1, UI Scaling 1.1)
    erwartet, dass der Fensterkörper selbst scrollt. Seit Main Window Layout Lock 1.0 ist der Rahmen fest und es
    scrollen nur innere Bereiche. Inventar und `UiWindow` sind hier unverändert.

### 9. Visuell geprüfte Screenshots

`ui_gallery` mit `talents, talents_full, talents_locked, talents_arcanist, talents_shadowrunner` bei 1080p 75 %,
1080p 100 %, 1080p 150 %, 1440p 100 %, 4K 100 %: je 15 Checks OK. Angesehen wurden u. a.:

- `1080p_100_talents`: freie Punkte, Upgrade
- `1080p_100_talents_full`: Endtalent und Tooltip
- `1080p_100/150_talents_arcanist`: Runemaster, Grand-Rift-Linie
- `1080p_100_talents_shadowrunner`, `2160p_100_talents_shadowrunner`: Bladestorm, beide Upgrades
- `1080p_75_talents_locked`: gesperrter Tier mit Tooltip
- `1440p_100_talents_full`

Gefunden und behoben:

- Erste Fassung: senkrechte Karten waren zu hoch (Tier 4 abgeschnitten), die nicht umbrechende Typzeile verbreiterte
  das Fenster.
- „Upgrade to rank 3 (1 point)“ war breiter als der Detailbereich, das Fenster scrollte seitlich. Der Text ist jetzt
  kürzer, die Kosten stehen in der Punktzeile, der Button schneidet ab. Ein Test prüft das.

Ergebnis: vier Knoten pro Tier, Namen lesbar, Zustände in Worten und Zeichen, nur echte Linien ohne Kreuzung,
lesbarer Detailbereich, kein Fenstersprung.

### 10. Offene Probleme

- Bei 100 % ist die Ranglinie „0/3 Available“ knapp (passt, Test prüft die Breite). Längere Zustandswörter würden
  nicht mehr passen.
- Der Header bricht bei Shadowrunner (langer Klassenname) schon bei 100 % in zwei Zeilen um (Reset auf eigener
  Zeile). Das war schon vorher so und kostet etwas Baumhöhe; der Baum passt trotzdem.
- Der erste Tastaturfokus beim Öffnen liegt (wie bisher, `UiWindow._focus_first`) auf „Reset talents“ im Header,
  nicht auf dem gewählten Knoten. Nicht in diesem Batch geändert.
- Bladestorm: zwei Upgrades teilen sich den ersten Linienabschnitt (Gabel). Lesbar, aber nicht getrennt.
- Passive und Transformationen haben weiter nur Glyphen (Raute / Stern); eine eigene Icon-Serie ist bewusst nicht
  Teil dieses Batches.
- Ein „Rang zurücknehmen“ gibt es nicht (nur kompletter Reset), wie in den Regeln.

## Phase 3: Skills (umgesetzt)

Zentrale Frage: „Welche Skills nutze ich, und wie?“ Keine Gameplayänderung. `SkillBook`, Skill- und Mod-Definitionen,
Kosten, Cooldowns und Save v15 sind unverändert. Phase 1 (Weapons) und Phase 2 (Talents) bleiben, wie sie sind.

### 1. Bisheriger Skills-Tab

- Oben vier Slot-Karten (210 px) mit je einem Dropdown (alle verfügbaren Skills + „(empty)“).
- Darunter eine lange Liste mit **allen** Skills der Klasse als volle Karten: Icon, Name, Kosten / Cooldown oder
  „Locked: …“, zwei Mod-Dropdowns in der Zeile und die ganze Beschreibung.
- Probleme:
  - Das ganze Fenster scrollte; die Slots wanderten mit nach oben.
  - Mods standen für jeden Skill gleichzeitig da.
  - Ersetzen und Tauschen beim Slot-Dropdown war nicht sichtbar.
  - Leere Slots waren genauso groß wie volle.

Tatsächliche Regeln (`SkillBook`, unverändert):

- Ein Skill sitzt in höchstens **einem** Slot. Ihn in einen anderen Slot zu legen **tauscht** die beiden Slots.
- Ein belegter Slot wird ersetzt; dessen Skill geht zurück in die Liste.
- Jeder freigeschaltete Skill der Klasse darf in jeden Slot.
- Ändern von Slots und Mods geht nur an der Klassenstation (`assign_slot`, `set_mod`).
- Ein neu freigeschalteter Skill füllt nur **leere** Slots (`auto_fill`).
- Talent-Reset und Laden räumen nicht mehr verfügbare Skills und Mods aus den Slots (`sanitize`).
- Ein Klassenwechsel zeigt Build und Slots der anderen Klasse.
- Ein Preset setzt Slots und Mods aus seiner Speicherung (`PresetService.activate`).
- Mods: Form und Resonance je Skill, Freischaltung über Level, Talent oder Quelle, Unverträglichkeiten. Sie werden
  im Build gespeichert, auch für nicht ausgerüstete Skills.

### 2. Neue Slot-Anordnung

- Oben eine Leiste `SkillSlots` mit vier gleich breiten Karten, je 58 px hoch:
  - Taste (Key-Chip Q / E / R / F), Skill-Icon 40 × 40 (1:1), Name in der Skillfarbe, „Kosten · Cooldown“.
  - Leerer Slot: schlanke Inset-Fläche gleicher Höhe mit Taste, „Empty“ und „no skill“. Er ist nicht anklickbar.
- Ein Klick auf einen belegten Slot **wählt** dessen Skill aus.
- Die Leiste liegt über allen Scrollbereichen und verschiebt sich nie.

### 3. Skillliste links

- `SkillListScroll`, 340 px breit, scrollt nur selbst. Je Skill ein `CardButton` (`Skill_<id>`, 56 px hoch):
  - Icon (gesperrt gedimmt) und Name (gesperrt gedämpft).
  - Eine Kurzzeile „12 Rage · 6.0 s“ bzw. „Locked · Talent: Whirlwind“ / „Locked · Class level 8“ (gold).
  - Rechts der Key-Chip, wenn der Skill ausgerüstet ist.
- Reihenfolge: Level-Skills nach Freischaltlevel, dann Talent-Skills nach Name.
- Gewählt ist die goldene Card-Art, Fokus die Cyan-Kontur. Gesperrte Einträge sind anklickbar.
- Je Klasse 7 Skills, insgesamt 21; alle mit ihrem vorhandenen Icon (`UiTheme.skill_icon`).

### 4. Detailansicht rechts

`SkillDetail`, so hoch wie die Liste:

- **Kopf:** Icon, Name in der Skillfarbe, „Unlocked / Locked · Equipped on R / Not equipped“.
- **`SkillDetailScroll`** (scrollt nur selbst):
  - Beschreibung, „Kosten · Cooldown“ (mit Mods, über `ClassRuntime.params_for`) und die Wirkregeln (`SkillParams.describe`).
  - Freischaltung („Unlocked by: Class level 5“ grün bzw. „Unlock: Talent: Whirlwind“ gold).
  - Ggf. „Changed by talents: Shatterbolt“ (gelernte Transformationen).
  - Die Modifikationen.
- **Fester Fuß:** die Equip-Zeile. Sie ist die Hauptaktion und scrollt nie weg, auch bei 150 % (Screenshot-Befund,
  erst lag sie im Scrollbereich).
- Ausgewählt wird je Klasse: die letzte Wahl, sonst der Skill auf Q, sonst der erste der Liste.
- Die Wahl bleibt beim Schließen und erneuten Öffnen erhalten. Die Ansicht wird bei jedem Öffnen und nach jeder
  Aktion aus dem Charakterzustand neu gebaut.

### 5. Ausrüsten und Entfernen

- Vier Buttons `EquipSlot0..3`. Ihr Text nennt die Folge des Klicks: „Q · Equip“ (leer), „Q · Replace“ (belegt),
  „Q · Swap“ (der Skill sitzt schon woanders) und „Q · Equipped“ (eigener Slot, aus).
- Der Tooltip nennt den ganzen Satz, z. B. „Swap: Warbreaker moves to Q, Furious Strike goes to F.“ bzw. „Replaces
  Battle Cry on E (it goes back to the list).“ Darunter eine Zeile mit der Regel.
- „Remove from R“ (`UnequipSkill`) leert den eigenen Slot.
- Alles läuft über das unveränderte `SkillBook.assign_slot`. Es gibt keine versteckte automatische Ersetzung; die
  Auswahl allein rüstet nie aus.
- Gesperrter Skill: alle Buttons aus, Grund „Locked - unlock it first (Talent: Whirlwind).“
- Abseits der Station (C): alles lesbar, Buttons und Dropdowns aus, Grund `UI_ONLY_AT_STATION`.

### 6. Modifikationsbedienung

- Nur für den gewählten Skill: zwei Spalten, Form und Resonance.
- Je Spalte das bisherige Dropdown (`<skill>_form` / `<skill>_resonance`, gesperrte Einträge deaktiviert mit
  „(locked: …)“, Tooltip `SkillText.mod`, setzt über `SkillBook.set_mod`).
- Darunter jeder Mod des Slots mit Zustand und Wirkung: „Active“ (grün), „Available“ oder „Locked · Talent /
  Class level n / …“ (gedämpft).
- Skill gesperrt: Dropdowns aus („Unlock the skill first.“). Skill ohne Mods: „This skill takes no modifications.“

### 7. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/ui/class_station_panel.gd` | Skills-Abschnitt neu: `_skill_slot_bar`, `_skill_entry`, `_show_skill_detail`, `_skill_equip_row`, `_mod_column`, `select_skill` / `selected_skill` / `class_skills` / `layout_skills`; `_mod_choice` übernommen (ohne Schließen-Tooltip abseits der Station) |
| `localization/ui.csv` | `UI_SKILL_EMPTY_SLOT`, `UI_SKILL_EQUIP`, `UI_SKILL_MODIFICATIONS` |
| `tests/integration/test_skill_ui.gd` | **neu** (7 Tests) |
| `tests/integration/test_class_ui.gd` | Stationstest nutzt Liste + Equip-Button statt Slot-Dropdown |
| `tests/playtest/gallery_screens.gd` | neue Bildschirme `skills_locked`, `skills_arcanist`, `skills_shadowrunner` |
| `docs/SKILLS_TALENTS_UX_2_0.md`, `CLAUDE.md` | Doku |

### 8. Unveränderte Assets

- Alle UI-PNGs unverändert, auch die 21 Skill-Icons `skills/<id>`. Keine neuen Grafiken, keine neuen Fonts.
- Leere Slots, Zustände und Fokus kommen aus vorhandenen Theme-Varianten (`CardButton`, `InsetPanel`, `KeyChip`,
  Fokus-Kontur).

### 9. Gezielte Testergebnisse

`test_skill_ui` (neu):

- **Klassen und Icons:** Alle 21 Skills, jede Klasse genau ihre 7, je eigenes Icon, Name, Locked / Unlocked; keine
  fremden Skills.
- **Level 1:** nur Q belegt, drei schlanke leere Slots. Gesperrter Skill anwählbar, Bedingung lesbar, Equip aus;
  Auswahl ändert nichts.
- **Ausrüsten:** Equip auf leeren Slot, Replace, Swap (nie doppelt), Remove; die Buttons nennen die Folge vorher.
- **Mods:** nur für den gewählten Skill, gesperrte Mods mit Freischaltung. Das Dropdown setzt genau den Mod; Slots,
  Talente und der andere Mod-Slot bleiben unberührt; Talent-Mod (Concussive Rush → Piercing Lunge) wird „Available“.
- **Freischaltung bis Klassenwechsel:** Talent schaltet Whirlwind frei; Preset-Aktivierung setzt R zurück;
  Talent-Reset sperrt Whirlwind und leert seinen Slot; Klassenwechsel zeigt die Arcanist-Skills.
- **Abseits der Station, Tastatur, Wiederöffnen:** Enter wählt nur aus; alle Änderungsknöpfe aus; die Wahl bleibt
  nach Schließen und Öffnen; ein extern geleerter Slot wird gezeigt.
- **Geometrie (100 / 150 %):** gleicher Rahmen wie Talents, das Fenster scrollt nie, Slots über Liste und Details,
  beide nebeneinander und im Fenster, Slottexte in ihren Karten.

Läufe:

- `skill_ui, class_ui, talent_ui, skills, presets, main_window_layout, ui_tab_geometry, ui_window_foundation,
  weapon_mastery_ui`: **42 / 42 grün**.
- `tools/check_project.ps1`: OK.
- `ui_art_check --only=skills_mods` (Mod-Dropdown im echten Fenster geöffnet): OK.

### 10. Visuell geprüfte Screenshots

`ui_gallery` mit `skills, skills_locked, skills_arcanist, skills_shadowrunner` bei 1080p 75 %, 1080p 100 %,
1080p 150 %, 1440p 100 %, 4K 100 %: je 12 Checks OK. Angesehen wurden:

- `1080p_100_skills`: vier belegte Slots, verfügbare und gesperrte Mods
- `1080p_100/150_skills_locked`: leerer F-Slot, gesperrter Whirlwind gewählt, gesperrte Mods
- `1080p_100/75_skills_arcanist`: Talent-Mod Double Mark verfügbar, „Changed by talents“
- `1080p_150_skills_shadowrunner`, `1440p_100_skills_shadowrunner`: Tastaturfokus (cyan) und Auswahl (gold)
  gleichzeitig, lange Beschreibung, nicht ausgerüsteter Talent-Skill Death Mark, Liste scrollt bei 150 %
- `2160p_100_skills`

Gefunden und behoben:

- Equip-Buttons mit Skillnamen waren abgeschnitten („E · Battle…“); jetzt steht dort die Aktion.
- Leere Slots waren höher als volle; jetzt gleiche Höhe.
- Bei 150 % lag die Equip-Zeile unter dem Scrollrand; jetzt ist sie der feste Fuß.

### 11. Noch offene Probleme

- Lange Mod-Zeilen umbrechen in den Spalten (z. B. „Wide Spin · Locked · Class level 8“, die Zahl in Zeile 2).
  Lesbar, aber nicht kompakt.
- Der erste Tastaturfokus beim Öffnen liegt (wie überall, `UiWindow._focus_first`) auf dem ersten Slot, nicht auf
  dem gewählten Listeneintrag.
- Kosten und Cooldown sind Werte der aktuellen Mods und Talente (wie im Kampf). Eine Aufschlüsselung „Basis +
  Mod“ gibt es nicht.
- Andere Texte des Panels (Statusmeldungen, Button-Texte) sind weiterhin direkt englisch statt über `ui.csv`; neu
  lokalisiert sind nur die drei Überschriften.

## Phase 4: Presets (umgesetzt)

Zentrale Frage: „Welche Builds habe ich gespeichert, und was passiert beim Laden?“

Unverändert: `PresetService` (Speichern, Umbenennen, Löschen, Validieren, Aktivieren), das Preset-Format
(`name`, `talents`, `slots`, `mods`, `equipment`, `extra`), Equipment-Ownership, Taschenkapazität und Save v15.
Phase 1–3 bleiben, wie sie sind.

### 1. Bisherige Preset-Funktionen

- Fünf Plätze je Klasse (`TalentRules.preset_slots`). Ein Preset speichert nur **Referenzen**: Talentränge,
  Q/E/R/F, Mods je Skill, Instanz-IDs des Klassen-Loadouts.
- Aktionen:
  - **Speichern / Überschreiben**: kostenlos, überall, auch abseits der Station.
  - **Umbenennen**: kostenlos, nur ein gespeichertes Preset, Name nicht leer.
  - **Löschen**: fragt per `UiConfirmDialog`.
  - **Aktivieren**: nur an der Klassenstation, nicht in einer Trial.
- `PresetService.validate` prüft vor dem Aktivieren:
  - die Talentverteilung (`TalentService.validate_allocation`),
  - Skills und Mods gegen einen Probe-Build,
  - jede Item-Referenz (in der Tasche / im Lager / fehlt / nicht anlegbar),
  - das Gold für den Reset.
- Gleiche Talente: kostenlos. Andere Talente: die normale Reset-Kosten (zählt als Respec).
- Danach legt `CharacterEquipment.apply_loadout` die Ausrüstung an (atomar; ohne Platz in der Tasche abgelehnt).
- Bisherige UI: fünf große Karten mit Erklärungstext, Namensfeld, vier Knöpfen und einer Zusammenfassungszeile
  („n talent points · Skills: … · n equipment references“). Was genau im Preset steckt, war nicht zu sehen.

### 2. Neue Preset-Liste

Links (`PresetColumn`, 360 px):

- Fünf kompakte Zeilen `Preset<n>` (52 px). Jede enthält:
  - einen `CardButton` (`PresetEntry`): Nummer als Key-Chip, Name (zu lang = „…“) bzw. „Empty“, darunter
    „Saved · 7 pts“ (grün) bzw. „Empty slot“;
  - daneben den kompakten Speicherknopf `Save` („Save“ bzw. „Overwrite“, gleiche Breite).
- Gewählt: goldene Card-Art. Tastaturfokus: Cyan-Kontur. Ein Klick wählt nur aus.
- Darunter für das gewählte Preset: Abschnitt „Preset n“, Namensfeld `PresetNameEdit`, „Rename“ und „Delete“
  (beide aus, solange das Preset leer ist).
- Save nimmt den Namen aus dem Feld, wenn es zum gespeicherten Slot gehört, sonst den gespeicherten Namen bzw.
  „Preset n“ (Service-Standard).
- Wahl je Klasse: die letzte, sonst das erste gespeicherte Preset, sonst Platz 1.

### 3. Neue Build-Detailansicht

Rechts `PresetDetail`, so hoch wie der freie Platz:

- **Kopf:** voller Name (umbrechend) und „Warrior · Preset 2“.
- **`PresetDetailScroll`** (scrollt nur selbst):
  - **Talents · n points:** Punkte je Baum aus den Klassendaten („Berserker 0 · Warbreaker 7 · Bloodblade 0“, in
    der Baumfarbe, 0 gedämpft).
  - **Skills:** Q/E/R/F mit Key-Chip, vorhandenem Skill-Icon, Name und den Mods des Skills
    („Form: Wide Arc · Resonance: …“). Leere Slots heißen „Empty“. Mods nicht belegter Skills stehen in einer
    Zeile darunter.
  - **Equipment:** je Referenz Slot und Item (Name in Seltenheitsfarbe) bzw. der Zustand:
    - „In the Haven stash“ (gold),
    - „Missing - no longer in the bag“ (rot),
    - „Cannot be equipped“ (rot),
    - ohne Referenzen: „No equipment stored (activating unequips this class's gear).“
- **Fester Fuß:**
  - Was beim Aktivieren passiert: „Same talents as now: activating is free …“ bzw. „Talents differ: activating
    counts as a talent reset (25 gold / free - first reset).“
  - Jede Sperrmeldung aus `PresetService.validate` („! …“, rot).
  - Der Knopf `Activate` „Activate preset 2 (free | 25 gold)“: deaktiviert mit allen Gründen im Tooltip, abseits
    der Station mit `UI_ONLY_AT_STATION`.
- Leeres Preset: nur „Preset n is empty“ und eine Zeile, was Save speichert. Keine große Tafel.
- Die Teile des Presets liest ein temporärer `ClassBuild` (`from_dict`), so wie es auch `PresetService.validate`
  tut. Das Format wird nicht neu interpretiert.

### 4. Speicher- und Aktivierungslogik

- Alle Aktionen laufen wie bisher über `PresetService.save_preset`, `rename_preset`, `delete_preset` (nach
  Bestätigung) und `activate`. Es gibt keine neue Regel und keine neue Prüfung.
- Ergebnis und Fehler stehen in der Statuszeile unten, dann wird die Seite aus dem Charakterzustand neu gebaut.
- Die Auswahl eines Presets ändert nichts (Test).

### 5. Equipment-Referenzbehandlung

- Nur Anzeige. Gesucht wird in `character.inventory.find`, sonst in `character.stash.find`; anlegbar über
  `CharacterEquipment.can_equip`. Dieselben Quellen nutzt `PresetService.validate`.
- Nichts wird erzeugt, verschoben oder ersetzt. Fehlende Items bleiben fehlend und sperren Activate.
- Unbekannte Item-IDs heißen „unknown item“.

### 6. Gezielte Tests

`test_preset_ui` (neu, 5 Tests):

- **Alle fünf leer:** kompakt, Leerzustand ohne Activate, Rename / Delete aus. Speichern über die Zeile mit dem
  Namen aus dem Feld; Eintrag zeigt „Saved“ und „Overwrite“; kein Item bewegt.
- **Mehrere Presets:** Talente je Baum, Skills mit Icon und Mod, eine Zeile je Item-Referenz. Ein langer Name ist
  in der Liste gekürzt und in den Details ganz; das Fenster scrollt nie. Der Wechsel zwischen Presets ändert weder
  Build noch Items noch Ausrüstung.
- **Aktivierung:**
  - abseits der Station gesperrt mit Grund, Speichern bleibt frei;
  - Reset-Kosten werden vorher genannt; ohne Gold gesperrt;
  - mit Gold aktiviert: genau die Kosten gezahlt, Item-Menge identisch, Ownership konsistent;
  - fehlende Referenz: „Missing“, Activate gesperrt, nichts erzeugt;
  - volle Tasche bei einem Preset ohne Ausrüstung: abgelehnt, Ausrüstung bleibt angelegt, kein Item verloren
    oder doppelt.
- **Umbenennen, Löschen, Klassenwechsel, Save/Load:** Umbenennen; Löschen fragt (Abbrechen behält, Bestätigen
  leert nur diesen Platz, keine Items betroffen); Save v15 mit identischen Presets nach dem Laden; der Arcanist
  hat eigene, leere Presets, die Warrior-Presets bleiben.
- **Geometrie (100 / 150 %):** gleicher Rahmen wie Skills, das Fenster scrollt nie, Liste und Details
  nebeneinander im Fenster, Activate sichtbar.

Außerdem `test_class_ui` (Stationstest: Name über `PresetNameEdit`, Activate im Detail).

Läufe:

- `preset_ui, presets, skill_ui, talent_ui, equipment_separation, main_window_layout, ui_tab_geometry,
  ui_window_foundation, weapon_mastery_ui`: **44 / 44 grün**.
- `preset_ui, class_ui`: 9 / 9 grün (vor dem Lösch-Test).
- `tools/check_project.ps1`: OK.
- `class_playtest.gd` (echte Maus, Presets-Seite mit Kostenanzeige): **460 / 460 OK**.

### 7. Visuell geprüfte Screenshots

`ui_gallery` mit `presets`, `presets_saved` und `presets_invalid` (neu) bei 1080p 75 %, 1080p 100 %, 1080p 150 %,
1440p 100 % und 4K 100 %: je 9 Checks OK.

- **`presets_saved`:** drei gespeicherte Presets, langer Name, gleiche Talente (frei).
- **`presets_invalid`:** Preset 3 mit verschwundener Item-Referenz („Missing“ rot, Activate gesperrt mit Grund).

Angesehen: `1080p_100_presets(_saved|_invalid)`, `1080p_150_presets_invalid`, `1080p_75_presets_saved`,
`2160p_100_presets_saved`, `1440p_100_presets`.

Behoben nach der ersten Sicht:

- Die Speicherknöpfe waren unterschiedlich breit, die Zeilen dadurch ungleich.
- Die Zusammenfassung „· Baumname“ wurde abgeschnitten. Jetzt steht dort „Saved · n pts“; die Bäume zeigt das
  Detail.

### 8. Verbleibende Probleme

- ~~Teil-Aktivierung bei voller Tasche~~ - **behoben** durch Preset Activation Atomicity Fix 1.0
  (`TALENT_SYSTEM.md`): Die Prüfung umfasst den Ausrüstungswechsel; die Seite zeigt „Your bag is full - make room
  first.“ und sperrt Activate; eine Aktivierung ist alles oder nichts.
- **Speichern ohne Rückfrage:** „Overwrite“ ersetzt ein Preset ohne Bestätigung (wie vorher).
- **Gemeinsames Namensfeld:** Es gehört zum gewählten Platz. Wer einen anderen Platz direkt speichert, bekommt
  dessen bisherigen Namen (bzw. „Preset n“) und benennt danach um.
- **Detailbereich bei 150 %:** Die Ausrüstungszeilen liegen bei 150 % im Scrollbereich; Fehler und Activate
  bleiben im festen Fuß sichtbar.

## Phase 5: Class Quests (umgesetzt)

Zentrale Frage: „Wie schalte ich eine weitere Klasse frei?“

Unverändert: `QuestService`, `QuestLog`, Questdaten (`data/quests`), Trials, `StoryService`, Hauptjournal, Hauptquest,
Nebenquests und Save v15. Phase 1–4 und die atomare Preset-Aktivierung bleiben, wie sie sind.

### 1. Tatsächliche bisherige Class-Quest-Funktionen

- Klassenquests sind **Freischaltquests, charakterweit**: je Klasse eine (`ClassQuestDefinition.class_id`).
  - Das Abgeben schaltet die Klasse dauerhaft frei; die Lieferungen werden verbraucht.
  - Spielbar sind „Path of Steel“ (Warrior), „Path of the Arcane“ (Arcanist) und „Path of Shadows“
    (Shadowrunner): je 8 Hollow-Kreaturen (`KILLS`, beliebiges Ziel), 3 Hollow Essence und 20 Gold.
  - Guardian- und Soulbinder-Quests sind vorbereitet (`available = false`) und bleiben verborgen.
- Es gibt **keine** Quests „der aktuellen Klasse“. Die Liste ist für jede aktive Klasse dieselbe; die aktive
  Klasse ändert nur, welche Quest schon erledigt bzw. unnötig ist.
- Zustände (`QuestLog.state`): nicht angenommen (`""`), `active`, `completed`. Fortschritt je Ziel in `progress`.
- Aktionen, nur an einer Klassenstation:
  - **Take quest** (`QuestService.start`): `can_start` verlangt den abgeschlossenen Prolog und eine noch nicht
    freigeschaltete Klasse;
  - **Turn in** (`QuestService.turn_in`): `can_turn_in` verlangt die Station, erfüllte Ziele und die Lieferungen
    in der Tasche.
- Fortschritt zählt `QuestService.record` (Kampfereignisse). Es gibt **keine** Trial-, Dialog- oder
  Navigationsaktion in diesem Tab; die Klassen-Trials gehören zum Prolog (Heart of the Stone).
- Bisherige UI: ein Erklärsatz, dann je Quest eine große Karte mit Titel, Badge (NOT TAKEN / ACTIVE / COMPLETED),
  Beschreibung, Zielzeilen, Lieferzeilen und Knopf. Status „bereit zur Abgabe“ und „Klasse schon freigeschaltet“
  waren nicht sichtbar.

### 2. Neue Questliste

- Links `QuestListScroll` (360 px, scrollt nur selbst). Je Quest ein `CardButton` `Quest_<id>` (52 px):
  - Name;
  - „Status · Kurzinfo“ in der Statusfarbe.
- Status aus dem echten Zustand (`ClassStationPanel.quest_status`):

  | Status | wann | Farbe | Kurzinfo |
  |---|---|---|---|
  | Locked | nicht angenommen, `can_start` lehnt ab | gedämpft | der Grund („Complete the prologue first“) |
  | Available | nicht angenommen, annehmbar | Pergament | „Unlocks <Klasse>“ |
  | Active | angenommen, Ziele oder Lieferungen offen | Resonanz | „5/8 · 0/2 items“ |
  | Ready to Turn In | angenommen, Ziele erfüllt, Lieferungen in der Tasche | Gold | „8/8 · 2/2 items“ |
  | Completed | abgegeben | Grün | „Unlocks <Klasse>“ |
  | Class unlocked | nicht angenommen, Klasse schon frei (z. B. Prolog-Wahl) | gedämpft | „Unlocks <Klasse>“ |

- Gewählt: goldene Card-Art. Tastaturfokus: Cyan. Gesperrte Einträge sind anwählbar. Klick und Enter wählen nur.
- Auswahl: die letzte, sonst die erste bereite, dann aktive, dann verfügbare Quest, sonst die erste.

### 3. Neue Detailansicht

Rechts `QuestDetail`, so hoch wie die Liste:

- **Kopf:** voller Titel, „Status · Class quest: <Klasse>“.
- **`QuestDetailScroll`** (scrollt nur selbst):
  - Beschreibung;
  - **Objectives**: Zieltext mit Zähler (`ObjectiveRules.text`) und Fortschrittsbalken, erfüllt grün. Vor der
    Annahme 0, denn erst ab der Annahme wird gezählt;
  - **Deliver at a class station**: „3 x Hollow Essence · you have n“, genug = grün;
  - **Requirements** (was `can_start` prüft): „Met / Open · Prologue completed“ und „Met / Open · <Klasse> not
    unlocked yet“;
  - **Reward**: „The <Klasse> class, unlocked for good (the deliveries are used up).“ Andere Belohnungen gibt es
    nicht.
- **Fuß:**
  - die eine zulässige Aktion als Primärknopf (`Start` „Take quest“ bzw. `TurnIn` „Turn in“);
  - darüber eine Zeile mit dem Grund, falls gesperrt (Text aus `QuestService`, abseits der Station
    `UI_ONLY_AT_STATION`), bzw. was der Knopf tut;
  - abgeschlossen: kein Knopf, „Completed - <Klasse> is unlocked.“;
  - „Class unlocked“: kein Knopf, „<Klasse> is already unlocked - this quest is not needed.“
- Kein großer Erklärtext. Ein Leerzustand („No class quests right now.“) erscheint nur ohne Quests.

### 4. Questaktionen und Status

- Annehmen und Abgeben laufen wie bisher über `_station_button` → `QuestService.start` / `turn_in`; danach baut
  sich die Seite aus dem Zustand neu.
- Die Auswahl ändert nie `QuestLog` (Test). Es gibt keine neue Mechanik und keinen neuen Status; „Ready to Turn
  In“ ist `can_turn_in(..., at_station = true) == ""`.

### 5. Verhalten je Klasse

- **Warrior** (Prolog: Warrior): Path of Steel „Class unlocked“, die anderen beiden annehmbar bzw. aktiv.
- **Arcanist / Shadowrunner:** entsprechend mit der eigenen Klasse als „Class unlocked“.
- **Klassenwechsel:** gleiche, charakterweite Liste. Status und Fortschritt kommen aus demselben `QuestLog`; neu
  freigeschaltete Klassen erscheinen als „Class unlocked“ bzw. „Completed“. Es gibt keine fremden aktiven
  Klassenquests, weil Klassenquests keiner aktiven Klasse gehören.
- Ohne abgeschlossenen Prolog: alle „Locked“ mit dem Grund, die eigene Klasse „Class unlocked“.

### 6. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/ui/class_station_panel.gd` | Quests-Abschnitt neu: `class_quests`, `selected_quest` / `select_quest`, `quest_status`, `_quest_entry`, `_show_quest_detail`, `layout_quests` |
| `tests/integration/test_quest_ui.gd` | **neu** (4 Tests, Fälle A–M) |
| `tests/integration/test_class_ui.gd` | Stationstest: Quest in der Liste wählen, `Start` im Detail |
| `tests/playtest/gallery_screens.gd` | neue Bildschirme `quests_warrior`, `quests_arcanist`, `quests_shadowrunner` |
| `docs/SKILLS_TALENTS_UX_2_0.md`, `CLAUDE.md` | Doku |

Keine PNGs, Fonts, Questdaten oder Services geändert.

### 7. Gezielte Testergebnisse

`test_quest_ui` (neu):

- **A, B, J:** vor dem Prolog ist nichts annehmbar. Alle Quests sind anwählbar und lesbar; Locked mit Grund;
  Take quest gesperrt; „Open · Prologue completed“. Die eigene Klasse ohne Aktion. Guardian und Soulbinder
  verborgen. Die Auswahl ändert `QuestLog` nicht.
- **C, K, D, E, F, G:** Available; Annehmen über den Knopf (`QuestService`); Active 0/8; 5/8 in Liste, Detail und
  Balken; Turn in gesperrt („Objectives not complete yet.“); Ready to Turn In mit Lieferungen gegen die Tasche;
  Abgeben schaltet die Klasse frei und verbraucht genau 3 Essence und 20 Gold; Completed ohne Aktion.
- **H, I, L:** nach dem Klassenwechsel dieselbe Quest mit 2/8; freigeschaltete Klassen als „Class unlocked“;
  abseits der Station Turn in gesperrt mit Grund; Save v15, `QuestLog` nach dem Laden identisch.
- **M + Tastatur:** gleicher Rahmen wie Presets bei 100 / 150 %, das Fenster scrollt nie, Liste und Details
  nebeneinander; Enter wählt nur.

Läufe:

- `quest_ui, class_ui, shrine`: **14 / 14 grün**. `shrine` prüft u. a., dass Guardian und Soulbinder auch im
  Quests-Tab fehlen.
- `preset_ui, preset_atomicity, skill_ui, talent_ui, main_window_layout, ui_tab_geometry, ui_window_foundation,
  weapon_mastery_ui`: **38 / 38 grün**.
- `tools/check_project.ps1`: OK.
- `class_playtest.gd` (echte Maus, alle Seiten): **460 / 460 OK**.

### 8. Visuell geprüfte Screenshots

`ui_gallery` mit `quests_warrior` (Arcane aktiv 5/8, Shadows verfügbar), `quests_arcanist` (Steel bereit zur
Abgabe, Shadows abgeschlossen) und `quests_shadowrunner` (Prolog offen: alles gesperrt, eigene Klasse
freigeschaltet, Tastaturfokus auf einem Eintrag) bei 1080p 75 %, 1080p 100 %, 1080p 150 %, 1440p 100 % und 4K 100 %:
je 9 Checks OK.

Angesehen: `1080p_100_quests_*` (alle drei), `1080p_150_quests_warrior`, `1080p_75_quests_arcanist`,
`1440p_100_quests_shadowrunner` und `2160p_100_quests_warrior`. Bei 150 % scrollt der Detailbereich, Grund und
Knopf bleiben im festen Fuß.

Nach der ersten Sicht behoben: Die Quest der eigenen, schon freigeschalteten Klasse zeigte einen gesperrten „Take
quest“ mit dem Prolog-Grund. Jetzt gibt es dort keinen Knopf, nur „already unlocked - this quest is not needed“.

### 9. Verbleibende Probleme

- Die Liste hat nur drei Einträge und viel freie Fläche darunter; bei mehr Klassen (Guardian, Soulbinder) füllt
  sie sich.
- Die Beschreibungen nennen Ziele und Lieferungen schon im Fließtext; Ziele und Lieferungen stehen darunter noch
  einmal mit Stand. Das sind Daten, die Texte wurden nicht geändert.
- Die Anforderung „<Klasse> not unlocked yet“ steht bei „Class unlocked“ auf „Open“. Das ist korrekt, aber
  doppelt zum Hinweis im Fuß.
- Statuswörter, Abschnittsnamen und Hinweise sind direkt englisch, nicht in `ui.csv`, wie die übrigen
  Panel-Texte.

## Phase 6: Classes (umgesetzt)

Zentrale Frage: „Welche Klasse spiele ich, und kann ich wechseln?“

Unverändert: Klassenregeln und -werte, XP, Talentpunkte, Freischaltungen, Equipment-Separation, Lager und Save v15.
Phase 1–5, die atomare Preset-Aktivierung und die Class-Quest-Freischaltung bleiben, wie sie sind.

### 1. Bisheriges Classes-Layout

- Ein Einleitungssatz über geteilte Systeme („Shared: mastery, inventory, materials, Haven. Per class: …“).
- Ein 2-spaltiges Raster großer Karten (300 × 104: Emblem, Name, Status, Level, Tagline).
- Rechts ein Detailpanel (420 px) mit Ressource, Playstyle, Talentbäumen, Anforderungen und dem Knopf „Activate“.
- „Activate“ war an der Station immer aktiv; ein Grund (volle Tasche, Trial) kam erst nach dem Klick in der
  Statuszeile.
- Sichtbarkeit: alle Klassen mit `playable = true`, also Warrior, Arcanist, Shadowrunner **und** die Startklasse
  Basic Adventurer. Guardian und Soulbinder (`playable = false`) waren und bleiben verborgen.

### 2. Neue Klassenkarten

- Links `ClassListScroll` (360 px, scrollt nur selbst) mit einheitlichen `CardButton`-Karten `Class_<id>`
  (60 px):
  - Emblem 40 px (`ClassEmblem`, gesperrt grau);
  - Name;
  - Status rechts („ACTIVE“ Resonanz, „UNLOCKED“ grün, „LOCKED“ gedämpft);
  - darunter „Lv n · <Tagline>“; gesperrt nur die Tagline.
- Reihenfolge wie bisher: aktiv, freigeschaltet, gesperrt (`class_order`).
- Gewählt: goldene Card-Art. Tastaturfokus: Cyan. Die aktive Klasse trägt zusätzlich den Text „ACTIVE“; gewählte
  und aktive Karte sind getrennt erkennbar (Gold-Rahmen und Text).
- Ein Klick oder Enter **wählt nur**, der Fokus bleibt auf der Karte (`select_class`).
- Der Einleitungssatz über geteilte Systeme ist entfallen.

### 3. Neue Detailansicht

`ClassDetails`, rechts, so hoch wie die Liste:

- **Kopf:** Emblem 56 px, Name (Silkscreen), Status mit Bezug zur aktiven Klasse („Active · you are playing it“ /
  „Unlocked · you are playing Warrior“ / „Locked · you are playing Warrior“). Bei freigeschalteten Klassen
  „Level n / max · XP“ und eine XP-Leiste.
- **`ClassDetailScroll`** (scrollt nur selbst):
  - **Resource:** `resource_text` in der Ressourcenfarbe;
  - **Playstyle:** die Datenbeschreibung;
  - **Specializations:** die drei Bäume in Baumfarbe mit den investierten Punkten (gesperrt: nur Namen);
  - **Gear of this class:** das Loadout der Klasse mit Zustand je Item (Name in Seltenheitsfarbe; „In the Haven
    stash“ / „Missing“ / „Cannot be equipped“ - dieselbe Anzeige wie bei Presets) oder „Nothing equipped.“;
  - gesperrt stattdessen **Unlock**: die bisherigen `requirements` (Prolog-Regel, Stand der Klassenquest).
- **Fuß:** siehe 5.

### 4. Aktiv / ausgewählt / gesperrt

| Zustand | Karte | Detail-Fuß |
|---|---|---|
| aktiv (und gewählt) | Gold-Rahmen + „ACTIVE“ | „You are playing Warrior.“, kein Knopf |
| freigeschaltet, gewählt | Gold-Rahmen + „UNLOCKED“ | „Switch to <Klasse>“ + was der Wechsel tut, oder der Grund |
| gesperrt, gewählt | Gold-Rahmen + „LOCKED“, gedämpft | „Unlock it first - its class quest is on the Quests page.“, kein Knopf |
| aktiv, nicht gewählt | „ACTIVE“ ohne Gold | - |

Es gibt keine Freischaltaktion hier; die Klassenquests bleiben im Quests-Tab.

### 5. Klassenwechsel und Blockierungsgründe

- Neu: `Character.class_switch_error(class_id, in_safe_zone)`. Das sind **dieselben Prüfungen in derselben
  Reihenfolge** wie bisher in `switch_class`, das sie jetzt selbst aufruft (eine Regelstelle, nichts geändert):
  1. Station;
  2. keine Trial;
  3. nicht schon aktiv;
  4. `CharacterClasses.activation_error` (freigeschaltet, spielbar);
  5. `CharacterEquipment.class_switch_error` (die Tasche im Zielzustand: das Gear der alten Klasse kehrt zurück).
- Der Knopf „Switch to <Klasse>“ (`Activate_<id>`) ist nur aktiv, wenn diese Prüfung leer ist. Sonst steht der Grund
  darüber und im Tooltip, z. B.:
  - „Classes can only be changed at a class station.“
  - „Your bag is too full to change class - free 3 slots first.“
- Ohne Sperre steht dort, was passiert: „Switching makes Arcanist's level, talents, skills and gear active;
  Warrior's stay saved.“
- Der Wechsel selbst ist das unveränderte, atomare `Character.switch_class`: nach allen Prüfungen nur
  `set_active`. Ein Teilwechsel ist unmöglich; Loadouts und Items bleiben unverändert (Test).

### 6. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/rpg/character.gd` | `class_switch_error` (die Prüfungen von `switch_class`, herausgezogen; `switch_class` nutzt sie) |
| `scripts/ui/class_station_panel.gd` | Classes-Abschnitt neu: Kartenliste, Detail mit Scroll und Fuß, `layout_classes`; Konstanten `CLASS_LIST_WIDTH`, `CLASS_CARD_HEIGHT` |
| `tests/integration/test_class_switch_ui.gd` | **neu** (5 Tests) |
| `tests/playtest/gallery_screens.gd` | neue Bildschirme `classes_active`, `classes_switch`, `classes_blocked`, `classes_shadowrunner` |
| `tests/playtest/rpg_playtest.gd` | Klassenwechsel: Karte wählen, dann „Switch to Warrior“ |
| `docs/SKILLS_TALENTS_UX_2_0.md`, `CLAUDE.md` | Doku |

Keine PNGs, Fonts, Klassendaten oder Save-Formate geändert.

### 7. Gezielte Testergebnisse

`test_class_switch_ui` (neu):

- **Liste:** nur spielbare Klassen (Warrior, Arcanist, Basic Adventurer, Shadowrunner - in dieser Reihenfolge),
  Guardian und Soulbinder verborgen; Zustände; Level auf der Karte; gesperrt nur die Tagline; aktiv ist
  standardmäßig gewählt. Arcanist wählen: getrennte Gold- und ACTIVE-Markierung, nichts gewechselt; gesperrte
  Klasse lesbar, ohne Knopf.
- **Erlaubter Wechsel** über den Knopf: beide Loadouts, Tasche und Ownership unverändert, Karte jetzt ACTIVE.
- **Blockiert:** abseits der Station und bei voller Tasche jeweils mit Grund und gesperrtem Knopf; auch ein
  erzwungener Druck ändert nichts (voller Zustandsvergleich).
- **Pre-Check = Regel:** `class_switch_error` und `switch_class` geben in vier Fällen denselben Grund; der erlaubte
  Fall wechselt.
- **Save/Load, Geometrie, Tastatur:** Save v15 (aktive Klasse und Loadouts nach dem Laden); gleicher Rahmen bei
  100 / 150 % auch beim Kartenwechsel; das Fenster scrollt nie; Enter wählt nur, der Fokus bleibt.

Läufe:

- `class_switch_ui, class_ui, shrine, equipment_separation`: **24 / 24 grün**.
- `preset_atomicity, preset_ui, quest_ui, skill_ui, talent_ui, main_window_layout, ui_tab_geometry,
  ui_window_foundation, weapon_mastery_ui, class_combat_polish, shadowrunner, equipment`: **70 / 70 grün** (inkl.
  Suites, die `switch_class` direkt nutzen).
- `tools/check_project.ps1`: OK.
- `class_playtest.gd` (echte Maus): **460 / 460 OK**.
- `rpg_playtest.gd`: Der Klassenwechsel über „Switch to Warrior“ ist OK („warrior active“). 6 andere Checks
  schlagen fehl:
  - Der Playtest klickt im Inventar einen „Equip“-Knopf, den es nach der Inventarregel (keine Aktionsknöpfe,
    Rechtsklick = Schnellslot) nicht mehr gibt; vier Folgechecks hängen daran.
  - Nach dem Laden unterscheidet sich der Inventar-Schnappschuss (Diagnose: nur der Schlüssel `inventory`, nicht
    Klassen, Builds oder Loadouts).
  - Beides liegt außerhalb dieses Batches. Ob es schon vorher so war, ist nicht gegen den alten Stand geprüft.

### 8. Visuell geprüfte Screenshots

`ui_gallery` mit `classes`, `classes_locked`, `classes_active` (A), `classes_switch` (B, D, F), `classes_blocked` (E)
und `classes_shadowrunner` (C, Tastaturfokus auf der Arcanist-Karte) bei 1080p 75 %, 1080p 100 %, 1080p 150 %,
1440p 100 % und 4K 100 %: je 18 Checks OK.

Angesehen: `1080p_100_classes(_active|_switch|_blocked|_shadowrunner)`, `1080p_150_classes_blocked`,
`1080p_75_classes_switch`, `1440p_100_classes_shadowrunner` und `2160p_100_classes_active`.

Behoben nach der ersten Sicht:

- Die Blockade-Ansicht zeigte zunächst einen möglichen Wechsel. Das war richtig: Das Arcanist-Loadout teilte sich
  die Instanzen mit dem Warrior, also kehrte nichts in die Tasche zurück. Die Galerie leert dort jetzt das
  Arcanist-Loadout.
- Ein doppelter Punkt am Ende des Grunds („first..“).

### 9. Verbleibende Probleme

- **Basic Adventurer** erscheint als vierte Karte, weil die Daten ihn als spielbar führen (bestehende
  Sichtbarkeitsregel). Ob die Startklasse in der Klassenstation bleiben soll, ist eine Design-Entscheidung.
- **Playstyle-Texte** enden in den Daten mit „Trees: …“; die Spezialisierungen stehen direkt darunter noch einmal
  (Datentext unverändert).
- **Taglines** sind in der Karte bei 360 px gekürzt („…“); voll stehen sie im Tooltip, die Beschreibung im Detail.
- **Geteilte Item-Instanzen:** Nach einer Freischaltung teilen sich Klassen-Loadouts oft dieselben Instanzen
  (Kopie beim Freischalten). Das Detail zeigt das ehrlich (gleiche Items), erklärt es aber nicht eigens.
- **`rpg_playtest`** ist in den Inventar-Schritten veraltet (siehe 7).

## Phase 7: Armor (umgesetzt) - letzte Phase

Zentrale Frage: „Was trage ich, was kostet es mich, und was habe ich gemeistert?“ Nur Anzeige über
`ArmorMasteryService`. Rüstungs- und Kampflogik, Burden-Grenzen, Mastery-XP, Balance, Equipment und Save v15 sind
unverändert; Phase 1–6 bleiben.

### 1. Tatsächliche Armor-Regeln

Quelle: `ARMOR_MASTERY.md`, `ArmorMasteryService`, `ArmorMasteryRules`.

- **Typen:** vier - Cloth, Leather, Mail, Plate (`ItemDefinition.armor_type`). Gezählt werden fünf Slots: Head
  15 %, Chest 40 %, Hands 10 %, Legs 25 %, Feet 10 %.
- **Burden:** Punkte je Slot und Typ, summiert.
  - Stufen ab `tier_starts` 15 / 26 / 38: Light / Balanced / Burdened / Heavy.
  - Strafen 0 / 2 / 5 / 8 % Gehtempo und Attack-Recovery-Dauer.
  - Iron Discipline (Plate-Meilenstein) senkt die Gehstrafe.
  - Dash und Parry sind nie betroffen.
- **Mastery:** vier charakterweite Tracks, Stufe 1–20. XP aus Kills und Block / Parry, verteilt nach der
  getragenen Abdeckung.
- **Meilensteine:** Stufe 5 / 10 / 15 / 20 je Typ, ein Stat-Bonus, skaliert mit der getragenen Abdeckung
  (nicht getragen = 0). Es gibt **keine weiteren Freischaltungen** und keine Voraussetzungen außer der Stufe.
- **Mit den echten Items erreichbar:** Light und Balanced. Burdened und Heavy verlangen Plate, und Plate-Items
  gibt es in den Daten noch nicht. Die Tests von `test_armor_mastery` nutzen Testitems; die Seite zeigt dort
  „39 · Heavy“.

### 2. Alte Armor-Ansicht

- Eine Burden-Karte mit fest im Code stehenden Stufenbereichen („Light 0-14 …“) und einer Zeile mit den fünf
  Slots.
- Darunter vier gleichwertige Track-Karten: Stufe, XP-Leiste, Abdeckung, alle vier Meilensteine als Textzeilen.
- Keine Auswahl, keine Details, „nächster Meilenstein“ nicht hervorgehoben.

### 3. Neue Statusübersicht (oben, `Burden`)

- **Links:**
  - „Armor Burden · what you wear now“;
  - groß „21 · Balanced“ (`Tier`, Stufenfarbe);
  - die Strafen jetzt (`BurdenEffects`: „-2% movement · +2% attack recovery time“ bzw. „No penalty.“);
  - ggf. Iron Discipline;
  - die Stufenbereiche **aus den Regeln** (`TierRanges`, aktuelle farbig);
  - „Dash and parry are never affected.“
- **Rechts (`BurdenSlots`):** die fünf gezählten Slots mit Typ und Punkten („Head Mail 3“, „Chest - 0“).
- Burden ist klar die Ausrüstung von jetzt. Mastery steht darunter getrennt.

### 4. Mastery-Karten (2 × 2, `Tracks`)

- Je Typ ein `CardButton` `Track_<type>`, auf die Höhe der Detailansicht gestreckt. Inhalt:
  - Name;
  - „WORN 35%“ (Resonanz) bzw. „not worn“;
  - „Lv n / 20“ mit XP-Leiste;
  - die jetzt wirkenden Boni je Stat summiert (`Bonus`: „+4.8% Poise, +3.2% Block Efficiency“, „Bonuses inactive -
    not worn“ bzw. „No bonus yet“);
  - der nächste Meilenstein (`Next`: „Next: Lv 10 +2% Attack Recovery Speed“ bzw. „Mastered - every milestone
    reached“).
- **Gewählt** ist die goldene Card-Art, **Tastaturfokus** Cyan, **getragen** der Text „WORN n%“. Das sind drei
  getrennte Zeichen; eine gewählte Karte ist nicht „getragen“.
- Vorwahl: der am meisten getragene Typ. Klick und Enter wählen nur; der Fokus bleibt.

### 5. Detailbereich (`ArmorDetail`)

- „<Typ> Mastery“, „Level n / 20 · XP a / b to level n+1“ bzw. „Mastered“ und eine XP-Leiste.
- „Worn now: 35% (Head, Hands, Feet) - bonuses count at that share.“ bzw. „Not worn now - its bonuses are
  inactive.“
- **`ArmorDetailScroll`:** die vier Meilensteine:
  - erreicht und getragen: „now +0.4%“ (grün);
  - erreicht, nicht getragen: „reached - inactive, not worn“;
  - der nächste: „next“ (gold);
  - offen: gedämpft.
- Ein Satz, wie Mastery wächst und dass sie nie die Ausrüstung ändert. Burden kommt nur vom Gear.
- Keine erfundenen Freischaltungen oder Voraussetzungen.

### 6. Basic-Adventurer-UI-Sonderfall (Classes)

- `class_order` zeigt nach der regulären Klassenwahl nur noch Warrior, Arcanist und Shadowrunner.
- Die Startklasse (`starts_unlocked`, Basic Adventurer) erscheint **nur, solange sie die aktive Klasse ist**
  (vor der Prolog-Wahl), dann als ACTIVE-Karte vor den drei gesperrten.
- Daten, `playable`, Freischaltung, Prolog, Trials und Saves sind unverändert. Es ist nur ein Filter der Karten.

### 7. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/ui/class_station_panel.gd` | Armor-Abschnitt neu (`_armor_status`, `_armor_track`, `_show_armor_detail`, `select_armor_type` / `selected_armor_type`, `layout_armor`); `class_order` filtert die Startklasse |
| `tests/integration/test_armor_ui.gd` | **neu** (5 Tests) |
| `tests/integration/test_class_ui.gd`, `test_class_switch_ui.gd` | Klassenliste ohne Startklasse; Wechseltest mit dem Arcanist |
| `tests/playtest/gallery_screens.gd` | neue Bildschirme `armor_none`, `armor_mixed`, `armor_mail`, `classes_start` |
| `docs/SKILLS_TALENTS_UX_2_0.md`, `ARMOR_MASTERY.md`, `CLAUDE.md` | Doku |

Keine PNGs, Fonts, Daten oder Regeln geändert.

### 8. Gezielte Testergebnisse

`test_armor_ui` (neu):

- **Keine Rüstung:** „0 · Light“, „No penalty.“; vier Karten „not worn“, Lv 1; 2 × 2-Raster; Stufenbereiche aus
  den Regeln.
- **Gemischt (Leather + Cloth):**
  - Burden und Stufe aus dem Charakter, getragene Anteile;
  - Stufe und XP-Leiste aus `CharacterArmorMastery`;
  - jeder aktive Bonus auf der Karte, nächster Meilenstein;
  - Mail wählen: Gold, aber „not worn“; die Details sagen „Not worn now“;
  - Mastery, Equipment und Tasche unverändert.
- **Mail (Balanced, gemeistert):** Strafen aus dem Service, „Mastered“ in Detail und Karte, alle vier Meilensteine
  „now +“, jeder Stat einmal und summiert.
- **Klassenwechsel, Save/Load, Geometrie, Tastatur:**
  - Mastery bleibt beim Wechsel unverändert (charakterweit), Burden folgt dem neuen Loadout;
  - Save v15 mit gleicher Mastery;
  - gleicher Rahmen wie Classes bei 100 / 150 %; das Fenster scrollt nie; Burden oben, Karten und Details
    nebeneinander;
  - Enter wählt nur.
- **Classes-Korrektur:** genau Warrior, Arcanist und Shadowrunner. Die Startklasse ist in den Daten weiter
  spielbar und freigeschaltet. Neuer Charakter vor der Wahl: Basic Adventurer ACTIVE vorn plus die drei; der
  Prolog-Zustand bleibt unverändert.

Läufe:

- `armor_ui, armor_mastery, class_ui, class_switch_ui, shrine`: **28 / 28 grün**. `test_armor_mastery::
  test_armor_page` prüft weiter „39 · Heavy“ mit Plate-Testitems.
- `shrine, quest_ui, preset_ui, preset_atomicity, skill_ui, talent_ui, main_window_layout, ui_tab_geometry,
  ui_window_foundation, weapon_mastery_ui`: **48 / 48 grün**.
- `tools/check_project.ps1`: OK.
- `class_playtest.gd` (echte Maus, alle Seiten): **460 / 460 OK**.

### 9. Visuell geprüfte Screenshots

`ui_gallery` mit `character_armor` (Galerie-Charakter, abseits der Station), `armor_none`, `armor_mixed`,
`armor_mail`, `classes` und `classes_start` bei 1080p 75 %, 1080p 100 %, 1080p 150 %, 1440p 100 % und 4K 100 %: je
18 Checks OK.

Angesehen: `1080p_100_armor_(none|mixed|mail)`, `1080p_100_character_armor`, `1080p_150_armor_mixed`,
`1440p_100_armor_mail`, `2160p_100_armor_none`, `1080p_100_classes_start` und `1080p_75_classes`.

Behoben nach der ersten Sicht:

- Leere Fläche unter dem 2 × 2-Raster: Die Karten sind jetzt gestreckt und zeigen den nächsten Meilenstein.
- Der Bonus auf der Karte war abgeschnitten: Er bricht jetzt um.
- Doppelte Stats bei einem gemeisterten Track: Sie sind jetzt je Stat summiert.

### 10. Verbleibende Probleme

- **Burdened und Heavy** sind mit den echten Items unerreichbar (keine Plate-Daten); die Ansicht ist mit Testitems
  geprüft.
- **Magic Resistance und Poise** zeigt die Seite als Bonus an, laut `ARMOR_MASTERY.md` haben sie derzeit keine
  sichtbare Spielwirkung (Gegner machen nur physischen Schaden, kein Poise-Bruch beim Spieler). Die Seite erklärt
  das nicht.
- **Typlose Teile** (Wanderer's Coat) zählen weder für Burden noch für Mastery („Chest - 0“). Richtig, aber für
  Spieler überraschend.
- **Startklasse vor der Prolog-Wahl:** Die Karte zeigt auch das Gear des Basic Adventurer; ein Wechsel zurück zur
  Startklasse ist danach über die Seite nicht mehr möglich (Regel unverändert, `switch_class` erlaubt es
  weiterhin).

## Abschluss Skills & Talents UX 2.0

Alle sieben Tabs sind umgesetzt: Weapons, Talents, Skills, Presets, Quests, Classes und Armor. Gemeinsame Muster:

- fester Rahmen 1120 × 760;
- Liste oder Raster links bzw. oben, feste Details rechts, Scrollen nur in Inhaltsbereichen;
- Auswahl Gold, Fokus Cyan;
- Klick wählt nur; Aktionen nur über eindeutige Knöpfe mit sichtbarem Grund, wenn gesperrt;
- Regeln nur über die bestehenden Services.

## Prüfung

`test_weapon_mastery_ui` (Icon je Combo aller Familien, nur getragene Familie, Mastery / gesperrt / frei, Auswahl
ändert nichts, Waffenwechsel, Leerzustand, gleiche Fenstergeometrie, Pfeiltasten), `ui_art_check` Szene
`weapons_tab` (sechs Familien, gesperrte Combo per Klick, Pfeiltasten, leerer Slot) bei 1080p 75 / 100 / 150 %,
1440p, 4K; Validator (126 PNGs, 44 Combo-Bilder alle verschieden).
