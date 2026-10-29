# Combat HUD UX 2.0 – Batch 2

Kompakteres Kampf-HUD mit weniger Dauertext. Ausdrücklich geänderter Design-Lock: HP und Klassenressource stehen nicht
mehr oben links (`PlayerFrame` aus UI Layout Lock 1.0 entfällt). Sie stehen jetzt als Gefäße links und rechts der
Kampfleiste, Dash steht unter der Spielfigur. Alle übrigen HUD-Regeln gelten weiter.

Unverändert:
- Kampf-, Dash-, Parry-, Mastery- und Trankregeln;
- Eingaben;
- Save v15;
- `project.godot`, `docs/Design/`, `docs/tasks/`.

## 1. Umsetzung und Designmaße (Design-px, 1920 × 1080 bei 100 %)

| Teil | Komponente | Maß / Ort |
|---|---|---|
| Kampfeinheit | `GameHud._combat_unit` (HBox, Abstand 6) | HP-Spalte · `_combat_column` · Ressourcen-Spalte; Breite 52 + 6 + 426 + 6 + 52 = **542**, Höhe **84** |
| HP-Gefäß | `HudVessel` (Kind HEALTH), Art `hud/vessel_left` + Maske `hud/vessel_fill_left` | **52 × 66**, Außenseite links oben/unten 10 px abgeschrägt, 3-px-Rahmen Ink/Steel/Ink, Füllung `#9C3A32` (dunkelrot) |
| Ressourcen-Gefäß | `HudVessel` (Kind RESOURCE), `hud/vessel_right` + `hud/vessel_fill_right` (gespiegelt) | 52 × 66, Füllung = `ClassResourceDefinition.color` |
| Zahl im Gefäß | `HudFillArt.draw_number` | IBM Plex Mono 14, Parchment, 4 px dunkle Kontur, zentriert |
| Level-Abzeichen | `HudBadge` (LEVEL) unter dem HP-Gefäß | **52 × 14** in der EXP-Zeile, „Lv n“, 12 px, Rahmen = `bar/frame` |
| Pressure-Abzeichen | `HudBadge` (PRESSURE) unter dem Ressourcengefäß | 52 × 14, „x n“, nur bei Pressure > 0 |
| Kampfleiste | unverändert | 6 Slots 64 × 64, `1 2` + 18 + `Q E R F` = 426 |
| EXP-Balken | unverändert | genau einer, 426 × 14, 6 px unter der Kampfleiste, nur Prozent / `MAX` |
| Flaschen | `HudSlot` FLASK / POTION, Art `hud/flask(_fill)`, `hud/potion(_fill)` | 40 × 48 bei (12, 10) im 64er-Slot, 1:1 |
| Dash | `HudDashMeter` (direkt in `GameHud._root`) | Segmente 14 × 4, Abstand 3, Ink-Kontur; 22 Welt-px unter dem Spielerursprung (unter Schatten ≈ 10 und Zielmarke 18), am Canvasrand geklemmt |
| Menüleiste | `HudMenuBar` | Buttons **34 × 34** (vorher 40), Abstand 2 (vorher 4), Rand 4 (vorher 10): ≈ 256 × 42 statt 324 × 60; Icon-Art 32 × 32 1:1 |
| Journey | `ObjectivePanel` | Breite 340, Rand 8 / 6 (vorher 10), Titel 15, Ziel 14, Kopf Silkscreen 16 |

### Layout und Verhalten
- **Vertikale Ausrichtung:** Das Gefäß beginnt mit der Kampfleiste. Das Abzeichen steht mit 4 px Abstand in der
  EXP-Zeile (66 + 4 + 14 = 84 = 64 + 6 + 14).
- **Fenster:** Ist ein Fenster offen, treten Kampfleiste, EXP-Balken und Abzeichen zurück. HP- und Ressourcengefäß
  bleiben sichtbar.
- **Dialog:** Wie bisher tritt die ganze untere Mitte für das Dialogfeld zurück, jetzt einschließlich der Gefäße
  (siehe Einschränkungen).
- **Slots:**
  - keine Dauertexte;
  - der Cooldown erscheint als Abdunklung mit Sekunden, nur solange er läuft;
  - ein nicht bezahlbarer Skill wird abgedunkelt und zeigt unten einen 4-px-Balken in Ressourcenfarbe: vorhandene
    Ressource im Verhältnis zu den Kosten;
  - ein leerer Slot ist ein gedämpfter Rahmen; die Taste bleibt sichtbar, sie ist dann gedämpft;
  - Kosten, Gründe und Cooldown stehen im Tooltip.
- **SkillBar:** zeigt ihre vier Rahmen jetzt immer, auch ohne Skill (Basic Adventurer). Die Einheit bleibt dadurch
  geschlossen.
- **Entfallene Dauerinformationen:**
  - Klassenname und Waffenmastery: in Klassenstation und Charakterfenster;
  - „Shift: <Guard>“: in Charakter-Übersicht und Optionen;
  - Dash-Beschriftung.
- **Neue Plätze früherer PlayerFrame-Inhalte:**
  - Klassen-Buffs: in der `EffectBar` oben links (Raute, Ring, Restzeit, Name als Tooltip);
  - Pressure: als Abzeichen und im Tooltip des Ressourcengefäßes;
  - Trial-Hinweis: im Tooltip des Level-Abzeichens;
  - Konter-Fenster („Counter!“) und Parry-Abklingzeit („Parry 1.2s“): als kurzes Wort unter den Dash-Segmenten,
    nur solange relevant.

## 2. Füllstände

| Anzeige | Abbildung | Quelle |
|---|---|---|
| HP | `health / max_health`, Zahl `ceil(health)` | `HealthComponent` |
| Ressource | `pool.value / pool.max_value()`, Zahl `round(value)` | `ClassResourcePool` |
| Ohne Ressource | leeres, abgedunkeltes Gefäß ohne Zahl, Tooltip „<Klasse> uses no class resource.“ | `ClassDefinition.resource == null` |
| Hearth Flask | `charges / ConsumableService.max_charges` (exakt, kleine Ganzzahlen); eine Ladung ≥ 3 Pixelzeilen | `Character.consumables` |
| Trank | **Viertel eines Bag-Stacks** (`ItemDefinition.max_stack`, bei allen Tränken 10): 0 → leer; 1–2 → ¼; 3–5 → ½; 6–7 → ¾; ≥ 8 (auch mehrere Stacks) → voll | `Inventory.count`, `max_stack` |
| Kein Trank zugewiesen | leerer Slot (`Glyph.EMPTY`) | `potion_slot == ""` |
| Nicht nutzbar | Flasche dunkel (leer), Tooltip mit Grund (`ConsumableService.potion_error`, z. B. Trial) | – |

- **Nenner beim Trank:** Für Tränke gibt es keine Ladungsgrenze. Der einzige vorhandene Nenner ist die Stapelgröße
  der Daten. Viertelstufen behaupten keinen exakten Prozentwert, es gibt kein „größter je besessener Stapel“.
  Die genaue Zahl steht im Tooltip.
- **Cooldown beim Trank:** Der Schleier liegt hinter der Flasche, die Sekunden stehen oben rechts. Der Füllstand bleibt
  so lesbar.
- **Unterscheidbarkeit:** Flask und Trank haben verschiedene Silhouetten (Überlappung 0,33). Jeder Trank ist in seiner
  `PotionEffectDefinition.color` gefärbt.
- **Kein Blinken:** Es gibt keine blinkende Warnung.

## 3. Journey-Tracker und Questdaten

- **Eingeklappt:**
  - nur die Kopfzeile „JOURNEY“ mit „+“ (≈ 32 px hoch);
  - bei offener Questbelohnung ein „!“, dessen Tooltip die Belohnung nennt.
- **Ausgeklappt, je Eintrag Titel und konkretes Ziel:**
  - laufende Trial (Klasse, Ziele, Tor, Hinweis zum Verlassen);
  - Prolog-Hinweis;
  - Hauptquest;
  - bis zu 3 Nebenquests (voller Schritttext im Tooltip), danach „+N more in the Journal“;
  - Klassenquests;
  - offene Belohnungen.
- **Entfernt:**
  - Kapitelnamen („The Roots Remember: …“);
  - erzählerische Schritttexte;
  - `[J] Journal [M] Map`;
  - die 3-Zeilen-Kürzung `compact_main`.
- **Darstellung:** Ziele brechen um und werden nie abgeschnitten. Die Höhe folgt dem Inhalt; nur oberhalb von
  `max_height` scrollt der eine Bereich.
- **Ziele:**
  - `StoryService.tracker_entries(character, main)` liefert Titel und Ziel.
  - Das Ziel kommt aus `StoryService.short_goal`: die vorhandenen kurzen Ziel-Beschreibungen der `StoryObjective`
    mit Zählern.
  - Nur wenn kein Ziel eine Beschreibung hat, greift **neu** `StoryStep.hud_goal`. Diese optionale Anzeige-Eigenschaft
    liest keine Regel; der Fallback ist der Schritttext.
- **Datenänderung:** genau eine – `beyond_the_roots.tres` (offener Platzhalter ohne Ziele) erhält
  `hud_goal = "Further story is not yet available."`.
  - Alle anderen 35 Schritte haben bereits kurze Ziel-Texte (geprüft).
  - Keine Questlogik- und keine Save-Änderung; `StoryStep` ist eine Definition, nicht Teil des Saves.

## 4. Geänderte Dateien und neue Assets

- **Neu:**
  - `scripts/ui/hud/hud_vessel.gd`, `hud_badge.gd`, `dash_meter.gd`, `hud_fill_art.gd` (+ `.uid`);
  - `tests/integration/test_combat_hud.gd`;
  - dieses Dokument.
- **Geändert:**
  - `scripts/ui/game_hud.gd`, `hud/hud_slot.gd`, `hud/quick_use_bar.gd`, `skill_bar.gd`, `hud/menu_bar.gd`,
    `hud/effect_bar.gd`, `objective_panel.gd`;
  - `ui_theme.gd` (`MENU_ICON_SIZE` 34);
  - `scripts/rpg/quests/story_step.gd` (`hud_goal`), `story_service.gd` (`tracker_entries`, Fallback in
    `short_goal`);
  - `data/story/beyond_the_roots.tres`.
- **Entfernt:** `scripts/ui/hud/player_frame.gd` (+ `.uid`).
- **Werkzeuge:**
  - `tools/ui_art/generate_core_ui_assets.py`: `hud_vessel`, `hud_vessel_fill`, `hud_bottle`, `hud_bottle_fill`;
    Masken wie `bar/fill`;
  - `validate_ui_assets.py`: Maske = offenes Inneres des Rahmens, geschlossener Rand, nur Maskentöne, gespiegelte
    Gefäße, verschiedene Flaschensilhouetten.
- **Neue Assets:** 8 PNGs, insgesamt 136.
  - `hud/vessel_left`, `hud/vessel_right`, `hud/vessel_fill_left`, `hud/vessel_fill_right` (52 × 66);
  - `hud/flask`, `hud/flask_fill`, `hud/potion`, `hud/potion_fill` (40 × 48).
  - Die 128 bisherigen PNGs sind byte-identisch (md5 vorher/nachher).
  - Ohne PNG zeichnen Gefäße und Flaschen einen prozeduralen Ersatz.
- **Tests/Playtests angepasst:**
  - `test_hud`, `test_hud_xp_bar`, `test_ui_layout_lock`, `test_ui_usability`, `test_ui_window_foundation`,
    `test_quest_turnin_mara_ui`;
  - `ui_gallery.gd` (Überlappungsprüfung mit Gefäßen, Abzeichen, Menüleiste, Minimap);
  - `gallery_screens.gd` (9 neue Ansichten, Rücksetzung über `_restore`);
  - `ui_art_check.gd`: Gefäße statt PlayerFrame; der Fall `resource_geometry` der alten Leiste ist entfernt.
- **Doku:**
  - `UI_LAYOUT_LOCK_1_0.md`, `UI_DESIGN_SYSTEM.md`, `HUD_EXP_BAR_1_0.md`, `HUD_RESOURCE_TEXT_READABILITY_1_0.md`:
    Hinweis auf die Ablösung;
  - `CLAUDE.md`.

## 5. Ausgeführte Tests (automatisiert)

- `py -3 tools/ui_art/validate_ui_assets.py`: **RESULT: OK** (136 PNGs).
- `./tools/check_project.ps1`: **Startup check OK**.
- `run_tests.ps1 -Suite combat_hud` (neu, 7 Tests): **7 passed**. Abgedeckt:
  - Schaden, Heilung, Verbrauch, Focus-Regeneration;
  - Klassenwechsel Warrior / Arcanist / Shadowrunner / Basic Adventurer;
  - leere HP;
  - Slots ohne Dauertexte, Cooldown, Ressourcenmangel, leerer Slot;
  - Flask und Trank voll / teilweise / leer / Cooldown, Füllstufen;
  - Dash: Verbrauch, Position, Aufladen, Ausblenden, Konter;
  - Menüleiste bei 75 %;
  - Tracker ein- und ausgeklappt, Nebenquests, `hud_goal`;
  - Layout bei 75/100/125/150 % ohne Überlappung mit Menüleiste, Loot-Feed und Save-Status;
  - Gefäße bleiben bei offenem Fenster sichtbar.
- `-Suite "hud,hud_xp_bar,ui_layout_lock,ui_window_foundation,ui_usability"`: **35 passed** (letzter Lauf).
- `-Suite "...,consumables,class_trials_m3,quest_turnin_t3,quest_turnin_mara_ui,prologue"`: **73 passed, 5 failed**
  im ersten Lauf.
  - 4 Fehler waren veraltete Annahmen dieses Batches (Trackertitel, Kapitelzeile, Dialog, Stapelreihenfolge). Sie
    wurden angepasst und im Nachlauf bestanden (`ui_layout_lock,quest_turnin_mara_ui`: **18 passed**).
  - 1 ist der bekannte veraltete Test `test_prologue::test_migration_v3_to_v4` (Handoff §7 Nr. 5). Er wurde nicht
    angepasst.
- `-Suite "gameplay_polish,roots_remember_m4,side_quests,story"`: **34 passed**.
- `ui_art_check.gd` (1080p, 100 %): **RESULT: OK (339 checks)**.
- UI-Galerie, keine Scriptfehler in den gewerteten Läufen:
  - 1080p × 75/100/125/150 % für 14 HUD-Ansichten: **112 Checks OK**;
  - 1440p und 4K × 100/150 % für `hud_low`, `hud_full`, `hud_basic`, `hud_tracker_many`, `hud_dash`:
    **40 Checks OK**;
  - ein Zwischenlauf hatte einen Scriptfehler in der Rücksetzung der Galerie (Spieler einer alten Map). Er ist
    behoben; die Aufnahmen dieses Laufs zählen nicht.
- Keine Full-Suite, keine vollständigen Gameplay-Loops.

## 6. Screenshot-Sichtprüfung (von Claude angesehen)

- 1080p 100 %:
  - `hud_combat` und Ausschnitt der Kampfeinheit;
  - Übersicht `hud_full`, `hud_low`, `hud_empty`, `hud_arcanist`, `hud_shadowrunner`, `hud_basic`, `hud_dash`;
  - `hud_low` (Dash-Segmente unter dem Helden);
  - `hud_tracker_many` und `hud_tracker_collapsed`.
- 1080p 75 %: `hud_low`.
- 1080p 150 %: `hud_combat` (Abstand zu Loot-Feed und Menüleiste).
- 4K 100 %: `hud_basic`.
- 4K 150 %: `hud_dash`.
- Befunde:
  - Gefäße, Flaschen und Segmente pixelgenau;
  - Füllstände lesbar;
  - keine Überlappung;
  - Basic Adventurer zeigt ein leeres Ressourcengefäß und vier leere Rahmen. Der Fehler davor, eine fehlende SkillBar,
    ist behoben.

**Menschliche Abnahme:** steht aus. Sie erfolgt gesammelt nach allen Batches.

## 7. Bekannte Einschränkungen und offene Punkte

1. **Menüleiste:** Die Icons bleiben bei 32 px Art (1:1). Verkleinert wurden Rahmen, Abstände und Rand, nicht das
   Icon. Kleinere sichtbare Icons brauchen eigene 24-px-Art; nichtganzzahlig skalierte Pixel-Art wäre unsauber. Bei
   75 % sind die Icons physisch 24 px groß.
2. **Lesbarkeit bei 75 %:** Gefäßzahl (14) und Abzeichen (12) sind physisch ≈ 10,5 / 9 px groß. Zu prüfen im
   Spieltest.
3. **Rage-Rot und HP-Rot:** Beide sind rot (HP dunkler `#9C3A32`, Rage `#DB4033`). Die Unterscheidung läuft über die
   Position (links / rechts).
4. **Dialog:** Gefäße treten im Dialog mit der unteren Mitte zurück, wie zuvor die Kampfleiste. Oben links gibt es
   keine HP-Anzeige mehr.
5. **Dauer der Klassen-Buffs:** Die Gesamtdauer ist der Restwert beim ersten Sehen (ClassRuntime speichert nur das
   Ablaufdatum). Beim Laden einer laufenden Wirkung ist der Ring dann voll.
6. **Dash-Anzeige:** Sie liegt in der HUD-Ebene über der Welt. Steht die Spielfigur am unteren Kartenrand, wird sie
   geklemmt und kann über der Kampfeinheit liegen.
7. **Commit:** siehe unten. Gemischte Dateien mit fremden uncommitteten Änderungen bleiben uncommittet.

## 8. Commit

Siehe Abschnitt Commit im Abschlussbericht (wird nach dem Commit ergänzt).
