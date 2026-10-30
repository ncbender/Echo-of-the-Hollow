# Menu UX Polish 1.1 – Navigation und Informationshierarchie

Umsetzung der Befunde aus der persönlichen Screenshot-Durchsicht. Die Grundstruktur der sieben Hauptmenüs bleibt; der
Batch reduziert Wiederholungen, vereinheitlicht die Außenreiter und verteilt Informationen gezielt auf Auswahl, Details
und Hilfe. Keine Spielregel-, Combat-, Balance-, Karten-, Weltgrafik- oder Save-Änderung (Save v15). Keine neuen oder
geänderten PNGs. `project.godot`, `settings.cfg`, `docs/Design/`, `docs/tasks/` und Spielstände unberührt.

## 1. Umgesetzte Änderungen und Navigationshierarchie

### Gemeinsame Außenreiter (`BookTabs`, `UiWindow`)
- Eine Implementierung für Klassenstation und Professions (keine zweite Tab-Art).
- Die Reiter liegen hinter dem Fenster (`z_index -1`) und reichen bis unter den Rahmen: kein sichtbarer Spalt, der
  Rahmen läuft neben inaktiven Reitern durch.
- Der gewählte Reiter liegt vor dem Rahmen (z 1) und reicht bis an die gravierte Seite (`UiWindow.tab_bridge()` =
  Panel-Innenrand − `PAGE_MARGIN`); sein Goldrand verbindet ihn optisch mit der Inhaltsfläche.
- Breiten: sichtbarer Teil inaktiv 106, gewählt 116 (unverändert); `BookTabs.bridge` ergänzt den Teil im Fenster.
  `reserved_width` (116), Rahmen 1120 × 760 und die gemeinsame Position sind unverändert, daher passt die Anordnung
  bei 75–150 % ohne Positionsänderung.
- Auswahl = Gold, Tastaturfokus = Cyan außen – beides zugleich sichtbar (geprüft mit echter Maus, `ui_art_check`).

### Professions – neue Hierarchie (ersetzt die Titelzeilen-Seiten aus Batch 1)
- Außen links: **Crafting · Gathering · Salvage** (BookTabs).
- Titelzeile rechts neben „PROFESSIONS“: die Berufe des Bereichs als `UiTabs` mit vollem Namen
  (Crafting 5, Gathering 4, Salvage 4). Level und Rang stehen im Tooltip des Tabs und im Seitenkopf.
- Salvage zeigt nur Berufe aus `SalvageService.SALVAGE_PROFESSIONS` (Regel des Service, keine neue Liste im UI);
  Alchemy erscheint dort nicht.
- Die vertikale Berufsliste ist entfernt; der Inhalt nutzt die volle Breite.
- Gemeinsamer Aufbau für alle fünf Crafting-Berufe und Salvage: Liste links (380 px, füllt die Höhe bis zur
  Aktionszone, min. 300), Karte rechts, Aktionszone im Footer – an derselben Position für jeden Beruf.

### Professions – Inhalte
- **Kopf:** Name · Rang · Level · XP in einer Zeile mit Balken; die Beschreibung (nannte die Werkstatt erneut) ist
  Tooltip des Namens.
- **Werkstatt:** genau einmal, in der Aktionszone: „Workshop: <Name> · you are here / go there to craft
  (· stash in reach)“. Die Werkstattzeile über der Liste und die Zeile „Workstation“ in der Karte sind entfernt.
  An der Werkstatt bleiben Ausbaustufe und Restore-Knopf.
- **Blockierungsgrund:** in der Aktionszone (Lock-Grund mit Freischaltweg, sonst `ProfessionService.craft_error`);
  abseits der Werkstatt ist die Werkstattzeile selbst der Grund.
- **Rezeptliste:** zweizeilige Zeilen (voller Name, darunter „Lv n · Not learned / Level too low / Not yet
  available“); „Processing“ steht nur noch in der Karte („Type“). Der Rezeptname steht nicht mehr in der Fußzeile.
- **Gathering:** Ertrag nur noch im Text („2 x Flax Fiber · 6 XP“), das Icon trägt keine Menge mehr.
- **Salvage:** gleiche Liste | Karte | Aktionszone; die allgemeinen Regeln stehen in einer Hilfe „?“.
  Leerzustand: „Nothing in your bag can be salvaged at <Werkstatt>.“

### Kompakte Hilfe `HelpButton` (neu, `scripts/ui/help_button.gd`)
- „?“-Knopf, öffnet ein Panel bei Maus-Hover **und** Tastaturfokus, schließt, wenn beides weg ist; nimmt keine
  Mauseingaben (nichts wird verdeckt bedienbar).
- Wird nie automatisch fokussiert (`UiWindow._focus_first` überspringt ihn).
- Einsatz: Talent-Legende, Burden-Tabelle, Mastery-XP, Salvage-Regeln.

### Inventar – Details
- Stats gruppiert nach `InventoryPanel.DETAIL_GROUPS`: Defense, Attack, Elements and status, Skills and resource,
  Movement; nicht zugeordnete Stats aus `Stats.ALL` landen in „Other“ (nichts geht verloren).
- Filter „Only active bonuses“ (CheckBox) blendet Zusatzwerte mit 0 aus; `CORE_STATS` (u. a. Max Health, Armor)
  bleiben immer. Nur Ansicht, Fenster-Variable, nie im Save. Werte und Berechnung unverändert.

### Klassenstation – Kopfzeile
- Nur noch Klasse und Level (mit XP-Strich, Tooltip).
- Ressource entfällt (steht auf Classes); freie Talentpunkte nur auf Talents („n Talent Points free“).
- „At Class Station / Away from Station“ entfällt. Die Stationsbindung steht an den betroffenen Aktionen als
  sichtbarer Grund (Skills: Equip-Zeile, Presets: über Activate, Quests: über der Questaktion, Classes: über
  „Switch“). Lesende Seiten (Armor, Weapons) haben keinen Hinweis.

### Classes
- Karten: Name, Status-Badge, Level; die abgeschnittene Tagline ist Tooltip der Karte; gesperrte Karte ohne
  Levelzeile, Name lesbar (TEXT_SECONDARY statt MUTED).
- Details: ein Statuswort (Active / Unlocked / Locked) statt „· you are playing …“; aktive Klasse = ACTIVE-Badge
  in der Liste, gewählte = Gold.
- Spielstil: Sätze, die alle Spezialisierungsnamen aufzählen, werden ausgeblendet
  (`ClassStationPanel.playstyle_text`, datengetrieben über die Baumnamen; Daten unverändert).
- Fußzeile nur bei freigeschalteter, inaktiver Klasse: Grund (falls gesperrt) + „Switch to …“; die Erklärung
  des Wechsels ist Tooltip.

### Talents
- Neuer Knotenzustand **Open** (`TalentTreeView.OPEN`, angezeigt als „Requirements met“): Rang 0, alle
  Voraussetzungen erfüllt, aber kein freier Punkt. Ermittelt über `TalentService.validate_allocation` ohne die
  Punktsummen-Prüfung (`TalentTreeView.requirement_error`); keine Regeländerung.
- Locked wird einmal gesagt: Schloss + gedämpfte Kachel; Rangzeile nur „0/5“. Available „+“, Learned Bronze,
  Maxed Doppelrahmen – Zustände auch ohne Farbe unterscheidbar.
- Aktionszeile: Fakten zweizeilig (Art · Tier / Rang · Zustand), „Cost: 1 point per rank“, Grund umbrochen in
  330 px (behebt das seitliche Überlaufen der Seite bei langen Gründen). Bei 0 Punkten:
  „No free talent point - requirements are met“ statt eines Voraussetzungsgrundes.
- Die permanente Legende ist durch „?“ (TalentHelp) neben den Baum-Buttons ersetzt (inkl. Schwellen aus den Regeln).
- Klick wählt nur; Learn/Upgrade bleibt explizit; Schwellen 0/5/18/30 unverändert.

### Skills
- Je Mod-Kategorie: Dropdown + nur der Effekt der gewählten Mod bzw. „None chosen · n available“.
- Alle Mods (Zustand, Freischaltung, Effekt) über „All modifications (n)“ (eingeklappt, auch abseits der Station
  lesbar) und als Tooltips der Einträge im geöffneten Dropdown.
- Leere Q/E/R/F-Slots: nur „Empty“.
- Equip-Beschriftungen nach der echten Operation von `SkillBook.assign_slot`: **Equip** (leerer Slot), **Replace**
  (belegter Slot, Skill nicht ausgerüstet), **Swap** (beide Slots belegt), **Move** (in einen leeren Slot; der alte
  wird leer – vorher fälschlich „Swap“), **Equipped** (eigener Slot). Regeln unverändert.
- Unter der Equip-Zeile steht nur noch ein Grund (z. B. „Only at a class station.“).

### Presets
- Leere Slots: nur „Empty“.
- Aktivierung: Kosten auf dem Knopf („Activate preset n · free / n gold“), eine kurze Zeile, ob es als
  Talent-Reset zählt, darüber jeder konkrete Sperrgrund (auch „Only at a class station.“).

### Klassenquests
- Kontexttexte der drei spielbaren Klassenquests in `data/quests/unlock_*.tres` gekürzt (keine Zahlen mehr);
  Bedingungen, Kosten, Belohnungen unverändert.
- Aufgaben als Fortschrittszeilen: „Defeat hollow creatures 5/8“ (mit Balken), „Hollow Essence 0/3“,
  „Gold Coin 0/20“ (have/need, „done“ wenn erfüllt).
- Erfüllte Voraussetzungen in einer Zeile („All met: …“), unerfüllte einzeln („Not met · …“).
- Belohnung: „Unlocks the <Klasse> class for good. Turning in uses up the deliveries.“
- Questaktion mit Grund darüber; was die Aktion tut, steht im Tooltip.

### Armor
- Burden oben: Wert, Stufe, aktuelle Auswirkung (+ Iron Discipline). Schwellentabelle, Gewicht der fünf Slots und
  Regeln in „?“ (BurdenHelp).
- Mastery-Karten: Name, WORN-Anteil, Level, Balken (84 px hoch, nicht mehr gestreckt).
- Details rechts: Fortschritt, Tragezustand, „Active now: …“, nächster Meilenstein, alle Meilensteine (spätere
  lesbar in TEXT_SECONDARY); XP-Erklärung in „?“ (MasteryHelp).

### Weapons
- Gesperrte Combos: Name in TEXT_SECONDARY (lesbar), Zustand „Locked · Lv n“ in Worten, Icon gedämpft.
  Eingabelegende und Details unverändert.

### Journal
- Listenkarten: Titel + Status („In progress“, „Completed“, ggf. „· reward waiting“); Kapitelname und
  Belohnungszeilen nur noch in den Details. Einträge heißen jetzt `Entry_<id>` (Detailkarten weiter `Story_<id>` /
  `Class_<id>`).
- Main Story: „Earlier chapters (n)“ standardmäßig eingeklappt (offen, wenn keine aktuelle Quest), zeigt
  „· reward waiting“, wenn dort eine Belohnung wartet; Wahl einer früheren Quest klappt auf. Completed-Tab bleibt.

### Lesbarkeit
- Gesperrte Namen (Rezepte, Klassen, Combos, Meilensteine) in TEXT_SECONDARY, Gründe in WARNING; gedämpft werden
  Icons und Aktionen. Keine globale Schriftänderung.

## 2. Geänderte Dateien

- **Neu:** `scripts/ui/help_button.gd` (+ `.uid`), dieses Dokument.
- **Code:** `scripts/ui/book_tabs.gd`, `ui_window.gd`, `professions_panel.gd` (neu aufgebaut), `class_station_panel.gd`,
  `talent_tree_view.gd`, `talent_tooltip.gd`, `journal_panel.gd`, `inventory_panel.gd`.
- **Daten:** `data/quests/unlock_arcanist.tres`, `unlock_warrior.tres`, `unlock_shadowrunner.tres` (nur
  `description`); `localization/ui.csv` (`UI_JOURNAL_EARLIER`, `UI_ONLY_ACTIVE_BONUSES`).
- **Tests angepasst:** `test_armor_ui`, `test_class_switch_ui`, `test_class_ui`, `test_preset_ui`, `test_quest_ui`,
  `test_skill_ui`, `test_talent_ui`, `test_professions_ui`, `test_ui_usability`, `test_main_window_layout`,
  `test_ui_window_foundation`, `test_quest_turnin_t3`, `test_quest_turnin_mara_ui`, `test_world_ui`.
- **Playtests:** `gallery_screens.gd` (14 neue Ansichten, `professions_salvage` mit eigenem Charakter – der alte
  Galerie-Charakter hatte eine volle Tasche und warf einen Skriptfehler), `ui_gallery.gd` (Register im Bild und von
  keinem HUD-Teil verdeckt), `ui_art_check.gd` (`booktabs_professions` wieder aktiv, Breiten mit `bridge`, z-Ordnung).
- **Assets:** keine. Der Asset-Validator lief daher nicht.
- **Doku:** `MENU_UX_POLISH_1_0.md`, `BOOKTABS_VISUAL_INTEGRATION_1_0.md` (Hinweise), `CLAUDE.md`.

## 3. Ausgeführte Tests (automatisiert)

- `./tools/check_project.ps1`: **Startup check OK**.
- `run_tests.ps1` mit `professions_ui, talent_ui, skill_ui, quest_ui, preset_ui, class_ui, class_switch_ui, armor_ui,
  weapon_mastery_ui, inventory_ui, main_window_layout, ui_window_foundation, ui_tab_geometry, ui_usability,
  ui_selection_polish, salvage, workshops, quest_turnin_t3, quest_turnin_mara_ui, gameplay_polish, world_ui,
  menus_ui, stash_ui, forge_ui, hud, combat_hud, ui_layout_lock, talents, presets, skills, professions`:
  **192 passed, 0 failed** (Endlauf). Vorherige Läufe zeigten 14 bzw. 7/5/1 Fehlschläge durch veraltete
  Testannahmen dieses Batches; die Tests wurden an das neue Verhalten angepasst.
- `ui_layout`: **1 passed, 1 failed** – der bekannte veraltete Test
  `test_inventory_scrolls_instead_of_overflowing_at_150_percent` (Handoff §7 Nr. 6), nicht angepasst.
- UI-Galerie (Layoutprüfungen inkl. neuer Registerprüfung, keine Scriptfehler in den gewerteten Läufen):
  - 1080p × 75/100/125/150 %, 32 Ansichten: **488 Checks OK**;
  - 1440p und 4K × 100/150 %, 15 Ansichten: **224 Checks OK**.
- `ui_art_check.gd` (Fenster, echte Maus) 1080p × 75/100/150 % für `booktabs_class`, `booktabs_professions`,
  `skills_mods`, `professions_search`, `weapons_tab`, `hud_combat`: **486 Checks OK**.
- Galerie-Scriptfehler: Die Ausgangsaufnahme vor dem Batch hatte `Out of bounds get index '0'` in
  `GalleryScreens` (`professions_salvage`, volle Tasche; die Aufnahme fehlte). Behoben. Der bekannte Fehler in der
  Ansicht `inventory` (Stormcaller Fang) wurde nicht erneut ausgelöst, da `inventory` nicht im gewerteten Satz war.
- Keine Full-Suite, keine vollständigen Gameplay-Loops.

## 4. Selbst angesehene Screenshots

- Vorher (1080p 100 %): professions, talents, talents_locked, classes_switch, skills_arcanist, presets_saved,
  quests_warrior, armor_mixed, character_weapons, journal, inventory_details, professions_gathering.
- Nachher 1080p 100 %: professions (Leatherworking an der Werkstatt), professions_alchemy (abseits),
  professions_salvage (mit offener Hilfe), professions_gathering, talents_locked, talents_full, talents_no_points,
  talents_help (Hilfe per Tastaturfokus), skills_arcanist, skills_away, skills_mods_open, classes_switch,
  quests_warrior, quests_away, presets_invalid, armor_mixed, armor_help, journal, inventory_details.
- 1080p 150 %: professions_alchemy (fünf Berufstabs in einer Zeile, volle Namen), talents_no_points.
- 1080p 125 %: professions_salvage. 1080p 75 %: skills_arcanist.
- 1440p 100 %: quests_warrior. 4K 150 %: professions_woodworking.
- Vergrößerte Ausschnitte der Register (vorher/nachher, Hover + Fokus aus `ui_art_check`).
- Befunde, die im Batch behoben wurden: seitliches Überlaufen der Talentseite bei langen Gründen (Batch-1-Zustand
  und Zwischenstand), Hilfe öffnete sich beim automatischen Fensterfokus, leere gestreckte Armor-Karten.

## 5. Offene Punkte für die gemeinsame Endabnahme (menschlich)

1. **Register hinter dem Rahmen:** Wirkt das „eingesteckte“ Aussehen der inaktiven Reiter und die Brücke des aktiven
   zur Seite stimmig, auch bei 75 %?
2. **Menüleiste bei 150 %:** Das Hauptfenster verdeckt die rechten Icons der Menüleiste unten links (bestehendes
   Verhalten; das Fenster nimmt die Klicks, verdeckte Icons sind nicht bedienbar). Mit dem Kampf-HUD gemeinsam prüfen.
3. **„Move“ als vierte Equip-Beschriftung** (Verschieben in einen leeren Slot) – passend benannt?
4. **Hilfe „?“:** Reicht Hover/Fokus, oder soll sie per Klick dauerhaft offen bleiben?
5. **Journal:** Eingeklappte frühere Kapitel als Standard; „reward waiting“ am Klappknopf ausreichend sichtbar?
6. **Professions-Kopf:** Die Berufsbeschreibung ist nur Tooltip des Namens – fehlt sie?
7. **Skills:** Die aufgeklappte Mod-Liste liegt im scrollenden Detailbereich (bei vielen Mods muss gescrollt werden).
8. Menü-/HUD-Überlappungen insgesamt (ausdrücklich für die Endabnahme vorgemerkt).

Unterscheidung: Abschnitt 3 = automatisierte Prüfung, Abschnitt 4 = Screenshot-Sichtprüfung durch Claude,
Abschnitt 5 = menschliche Abnahme (steht aus).

## 6. Commit

Siehe Abschnitt „Commit“ unten (nachgetragen).
