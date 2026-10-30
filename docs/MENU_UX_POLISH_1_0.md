# Menu UX Polish 1.0 – Batch 1

Umsetzung der Änderungswünsche aus dem persönlichen Spieltest für Inventar, Talents, Skills/Quests/Professions-
Typografie, Professions-Kopfzeile, Journal und die Hintergründe der sieben Hauptmenüs. Spielregeln, Services,
Talentstruktur (0 / 5 / 18 / 30) und Save v15 unverändert. Keine Änderungen an `project.godot`, `docs/Design/`,
`docs/tasks/` oder Spielständen; keine Git-Schreibaktionen.

## 1. Was geändert wurde

### Inventar (`scripts/ui/inventory_panel.gd`)
- Der Hilfetext „Hover: … Right-click: … Ctrl+click … Alt+click …“ unter der Tasche ist entfernt.
- Die Itemnamen neben den Paperdoll-Slots („Leather C…“, „Iron Sword“) sind entfernt. Slotname und Blockzustand
  („Two-hander“, „Dual wield“) bleiben.
- Name und alle Infos bleiben im `ItemTooltip` (Hover). Rechtsklick, Drag & Drop, Strg/Alt-Klick, Kapazität und
  Loadouts sind unverändert.

### Talents (`class_station_panel.gd`, `talent_tooltip.gd`, `talent_layout.gd`)
- Der feste Detailblock rechts (Effekt, nächster Rang, Voraussetzungen) entfällt.
- Effekte, Ränge und Voraussetzungen stehen nur noch im Talent-Tooltip (Hover / Tastaturfokus).
- Unter dem Baum steht eine kompakte Aktionszeile `TalentDetail` (InsetPanel, eine Zeile):
  - Icon, Name, „Art · Tier · (Capstone) · Rang n / m · Zustand“;
  - „1 point per rank · n free“ und, falls gesperrt, der konkrete Grund aus `TalentTooltip.block_reason`
    („Needs 5 points in lower tiers of Berserker (1 / 5)“, „Requires Whirlwind“, „Requires class level n“,
    sonst der Text von `TalentService.can_learn`);
  - der Button Learn / Upgrade to rank n / Maxed. Gesperrt ist er deaktiviert und nennt den Grund im Tooltip.
- Der Baum nutzt jetzt die ganze Breite und steht zentriert. `TalentLayout.MAX_COLUMN` wurde von 200 auf 240
  angehoben; bei 1120 px Rahmenbreite stehen die Namen damit einzeilig.
- Ein Klick wählt weiterhin nur aus, Punkte gibt nur `LearnTalent` aus (`TalentService.learn`).
- Baumwechsel, Auswahl je Baum, Reset, Legende und Upgrade-Linien sind unverändert.

### Typografie Skills / Quests / Professions / Journal
- Neue Theme-Variationen in `UiTheme`. Die globalen Werte bleiben unverändert, andere Fenster sind nicht
  betroffen.

| Variation | Größe | Rolle |
|---|---|---|
| `MenuHeadingLabel` | 16 (Silkscreen, Bronze) | Überschrift eines Journal-Details |
| `MenuTitleLabel` | 18 | Titel eines Eintrags (Skill, Quest, Rezept, Ruine) |
| `MenuTextLabel` | 15 | Fließtext, Beschreibungen, Aufgaben, Lieferungen, Listennamen |
| `MenuMetaLabel` | 14 (sekundär) | Status, Kosten, Hinweise, Metadaten |

- Helfer `UiTheme.menu_text(text, color, width, variation)` (umgebrochen).
- Fortschrittsbalken der Klassenquests und die Berufs-XP-Leiste sind jetzt 6 statt 8 px hoch
  (`BAR_HEIGHT_SMALL`).
- Die Stat-Zeilen der Berufe laufen über `ProfessionsPanel._compact` (15 statt 18).

**Schriftgrößen vorher → nachher** (Design-px):

| Ort | vorher | nachher |
|---|---|---|
| Skills: Name im Detail | 20 | 18 |
| Skills: Beschreibung | 18 | 15 |
| Skills: Status, Kosten, Regeln, Freischaltung, Mods, Mod-Name | 15 | 14 |
| Skills: Mod-Effekt | 14 | 14 |
| Quests (Klassenstation): Titel | 20 | 18 |
| Quests: Beschreibung | 18 | 15 |
| Quests: Ziele, Lieferungen, Anforderungen, Belohnung | 15 | 15 |
| Quests: Status / Aktionshinweis | 15 / 14 | 14 |
| Professions: Rang · Level im Kopf | 20 | 18 |
| Professions: Beschreibung | 18 | 15 |
| Professions: XP, Werkstatt, Sammelhinweis | 15 | 14 |
| Professions: Berufskarten, Rezeptzeilen, Material-, Stat-, Ressourcenzeilen | 18 | 15 |
| Professions: Rezept-/Itemtitel (Karte, Footer) | 20 | 18 |
| Professions: Ergebniszeile | 18 | 15 |
| Journal: Listeneintrag Titel / Status / Belohnung | 20 / 15 / 18 | 15 / 14 / 14 |
| Journal: Detailüberschrift | 24 (Silkscreen) | 16 (Silkscreen) |
| Journal: Beschreibung, Schritte | 18 | 15 |
| Journal: Ziele / Klassenquest-Ziele | 15 | 14 / 15 |
| Journal: Klassenquest- und Ruinentitel | 20 | 18 |
| Journal: Ruinenstatus, Haven-Hinweis | 15 / 18 | 14 |

### Professions-Kopfzeile (`professions_panel.gd`, `ui_window.gd`)
> **Abgelöst durch Menu UX Polish 1.1** (`docs/MENU_UX_POLISH_1_1.md`): Bereiche wieder als Außenreiter, die Berufe
> des Bereichs als Tabs in der Titelzeile, keine Berufsliste mehr.

- Die Book-Register links sind ersetzt. Die drei Seiten stehen als `UiTabs` (TabButton-Stil: Auswahl Gold, Fokus
  Cyan) rechts neben „PROFESSIONS“ in der Titelzeile.
- Dafür bietet `UiWindow` jetzt die Titelzeile `_title_row` mit `set_title_tabs(control)` an, ohne neue
  Skin-Architektur.
- Der Rahmen bleibt gleich: Hauptfenster reservieren die Registerbreite weiterhin, die Position ist unverändert.
- Crafting-, Gathering- und Salvage-Regeln sind unverändert.

### Journal („Journey“)
- Das als „Journey“ bezeichnete Fenster ist das Journal (Taste J).
- Der Close-Button zeigt nur „Close“ (`UI_CLOSE` in `localization/ui.csv`). J und Esc schließen weiterhin.
- Die Listeneinträge sind kompakter: Innenabstand 8 statt 10, die Höhe folgt dem echten Umbruch.
- Die Texte nutzen die Hierarchie oben.
- Der Rahmen bleibt 1120 × 760.

### Gemeinsame Menühintergründe (`ui_window.gd`, `ui_skin.gd`, Generator, Validator)
- `window/backdrop` (32 × 32, gekachelt 1:1 innerhalb des Rahmens):
  - Fenstergrundton `#1D1F24` mit geordnetem Korn: ein heller Pixel `#23262C` auf einem Diagonalraster jede vierte
    Zeile und sein dunkler Schatten `#191B20` rechts darunter;
  - 3,1 % der Pixel; kein Rauschen.
- `window/page` (16 × 16, Nine-Patch 6):
  - die ruhige Seite hinter dem Inhalt (Body und gezeigter Footer, 6 px Rand);
  - gravierte Doppellinie (dunkle Rille über heller Lippe), flaches Charcoal, kleine Old-Gold-Eckticks.
  - Text steht nie auf dem Korn. Die Gravur ersetzt bei diesen Fenstern die Titelregel.
- Gezeichnet wird in `UiWindow._draw_main_ground`, nur für `main_window` und nur wenn die Art vorhanden ist. Ohne
  PNG bleibt der bisherige Look (Fallback).
- Cards (Slate) heben sich ab, Insets (Charcoal mit Lippe) wirken vertieft.
- Popups und Tooltips sind unverändert.

## 2. Geänderte Dateien
- **Code:**
  - `scripts/ui/ui_theme.gd`, `ui_window.gd`, `ui_skin.gd`;
  - `inventory_panel.gd`, `class_station_panel.gd`, `talent_tooltip.gd`, `talent_layout.gd`;
  - `professions_panel.gd`, `journal_panel.gd`.
- **Daten:** `localization/ui.csv` (`UI_CLOSE`).
- **Werkzeuge:** `tools/ui_art/generate_core_ui_assets.py` (+ `window_backdrop`, `window_page`, Palette
  `WINDOW_GROUND`/`WINDOW_GRAIN`), `tools/ui_art/validate_ui_assets.py` (SPEC + Korn-/Seitenprüfungen).
- **Neue Assets:** `assets/ui/window/backdrop.png`, `assets/ui/window/page.png` (128 PNGs). Die 126 alten PNGs sind
  byte-identisch (md5 vorher/nachher verglichen).
- **Tests:** `test_talent_ui.gd`, `test_professions_ui.gd`, `test_ui_window_foundation.gd`, `test_inventory_ui.gd`;
  `tests/playtest/ui_art_check.gd` ohne `booktabs_professions`, da dort keine Register mehr existieren.
- **Doku:** dieses Dokument, `UI_DESIGN_SYSTEM.md` (Typografie), `SKILLS_TALENTS_UX_2_0.md` (Hinweis Phase 2),
  `CLAUDE.md`.

## 3. Ausgeführte Prüfungen

### Automatisiert
- `py -3 tools/ui_art/validate_ui_assets.py`: **RESULT: OK** (128 PNGs).
- `./tools/check_project.ps1`: **Startup check OK**.
- `run_tests.ps1 -Suite "talent_ui,professions_ui,ui_window_foundation,inventory_ui"`: **28 passed, 0 failed**.
- `run_tests.ps1 -Suite "skill_ui,quest_ui,main_window_layout,ui_tab_geometry,ui_usability,salvage,workshops,quest_turnin_mara_ui,class_ui"`:
  **52 passed, 0 failed**.
- `run_tests.ps1 -Suite "ui_layout,menus_ui,stash_ui,forge_ui"`: **20 passed, 1 failed**.
  - Der Fehler ist der bekannte veraltete Test
    `test_ui_layout::test_inventory_scrolls_instead_of_overflowing_at_150_percent` („body scrolls vertically“,
    Handoff §7 Nr. 6).
  - Er ist nicht durch diesen Batch verursacht und wurde nicht angepasst.
- UI-Galerie (Layout-Checks):
  - 1080p × 75/100/125/150 % für inventory, talents, talents_locked, skills, quests_warrior, professions,
    professions_gathering, professions_salvage, journal, journal_haven, map, options, character: **144 Checks OK**;
  - 1440p und 4K × 100/150 % für talents, professions, journal, skills, inventory: **60 Checks OK**.
  - In der Galerie meldet der Bildschirm `inventory` einen Skriptfehler (`Out of bounds get index '0'` in
    `GalleryScreens`: Stormcaller Fang fehlt im Galerie-Charakter). Der Fehler trat schon vor diesem Batch in der
    Ausgangsaufnahme auf und liegt im Galerie-Skript, nicht im Spielcode.
- Neue Testprüfungen:
  - Talents: kein `DetailScroll`, Effekt und Voraussetzungen im Tooltip, konkreter Blockiergrund in der
    Aktionszeile.
  - Professions: Tabs rechts neben dem Titel in einer Zeile, im Fenster, über dem Inhalt, auf allen vier Skalierungen.
  - Inventar: kein Itemname am Slot, kein Hilfetext, Hover-Tooltip nennt das Item.
  - Journal: Close-Text ohne Taste.

### Screenshot-Sichtprüfung (von Claude angesehen)
- 1080p 100 %: `inventory`, `talents`, `skills`, `quests_warrior`, `professions`, `journal`. Vorher-Aufnahmen
  derselben Bildschirme liegen zum Vergleich im Scratchpad.
- 1080p 150 %: `talents`, `professions`, `journal_haven`.
- 1080p 125 %: `professions_gathering`.
- 1080p 75 %: `skills`.
- 1440p 150 %: `professions`.
- 4K 100 %: `talents`.
- Befund:
  - keine Überlappung der Professions-Tabs mit Titel oder Inhalt;
  - Talent-Aktionszeile vollständig, Learn-Button und Close getrennt;
  - Korn sehr dezent, Seite ruhig hinter dem Text, Gravur und Eckticks sichtbar, aber zurückhaltend.

### Menschliche Abnahme
- Steht aus.

## 4. Offene Punkte für den persönlichen Spieltest
1. **Lesbarkeit von 15/14 px bei 75 %** (≈ 11/10,5 physische px bei 1080p): Ist Fließtext in Skills, Quests,
   Professions und Journal gut lesbar oder jetzt zu klein?
2. **Korn bei 75 %:** Das Nearest-Raster kann einzelne Kornpixel auslassen. Wirkt das ruhig oder unregelmäßig?
3. **Talent-Tooltip als einzige Quelle** für Effekte: Reicht Hover/Fokus, oder fehlt ein dauerhafter Effekt-Text
   beim Planen?
4. **Close-Buttons:**
   - Nur das Journal zeigt „Close“ ohne Tastenhinweis, die anderen sechs Hauptmenüs zeigen weiter „Close [X / Esc]“.
   - Die Vereinheitlichung ist eine Designentscheidung für einen späteren Batch.
5. **Journal „zu groß“:**
   - Der Inhalt ist kompakter, der Rahmen bleibt 1120 × 760 (Main Window Layout Lock).
   - Falls der Eindruck bleibt, ist eine kleinere äußere Geometrie ein offener Designpunkt und keine Ausnahme in
     diesem Batch.
6. **Leere Fläche im Journal:**
   - Bei wenigen Quests bleibt unter Liste und Details freie Fläche (fester Rahmen).
   - Prüfen, ob das stört.
7. **Professions-Tabs:** Die Seitenwahl liegt jetzt oben statt in den Registern. Ist die Bedienung intuitiv?
