# Playtest Corrections 1.0

Der Entwickler hat den bisherigen Gesamtstand im gemeinsamen Playtest persönlich abgenommen. Offen waren nur die drei
folgenden Korrekturen; sie benötigen danach nur eine gezielte Nachprüfung. Kein weiterer Layout- oder Gameplay-Umbau.
Save v15, Statberechnung, Kampf, Karten, Quests und Balancing unverändert; keine Assets.

## 1. Inventar → Details: nur Wirksames

- **Ursache des Befunds:** Der Schalter „Only active bonuses“ verschonte alle `CORE_STATS` – das ist die Liste der
  Overview-Seite und enthält neben Max Health und Armor auch Physical Damage %, Crit Chance %, Attack Speed % und Poise
  Damage %. Deshalb blieben genau diese vier mit 0 sichtbar.
- **Jetzt:** kein Schalter; Details zeigt immer die gefilterte Ansicht (`InventoryPanel.shows_stat`):
  - immer sichtbar nur die Grundwerte `BASE_STATS` = Max Health, Armor;
  - jeder andere Wert nur, wenn er in der angezeigten Genauigkeit (0,1) nicht 0 ist – positiv wie negativ
    (negative Werte in Warnfarbe);
  - eine Gruppe ohne sichtbaren Wert entfällt ganz (Überschrift und Linie).
- Aktualisierung: die Seite baut bei jedem `Character.stats_changed` neu auf (Ausrüstung, Klassenwechsel, Talente,
  Buffs – unverändert).
- `UI_ONLY_ACTIVE_BONUSES` aus `localization/ui.csv` entfernt (ungenutzt).

## 2. Hauptmenüs ohne Close-Button

- `UiWindow.main_window` blendet den Close-Button aus und rechnet seine Zeile nicht mehr in den Rahmen (`_chrome_size`);
  der Platz gehört dem Inhalt. Rahmen 1120 × 760 und gemeinsame Position unverändert. Betroffen: Inventory, Character,
  Skills & Talents / Class Station, Professions, Journal, Map, Options.
- Schließen weiter über Esc, die jeweilige Menütaste und das Menüicon (unveränderte HUD-Logik, also auch dieselben
  Regeln bei Texteingaben und Unterdialogen). Die automatische Erstfokussierung fällt nicht mehr auf einen
  unsichtbaren Close-Button.
- Footer-Aktionen (Craft, Salvage) bleiben. Bestätigungsdialoge und kleine Fenster (Waystones, Belohnungen, Lager,
  Werkbänke …) behalten ihre Aktionen und ihren Close-Button – keine globale Änderung in `UiWindow`.
- Klassenstation: Ergebnismeldungen („Talents reset.“, Gründe) standen links neben Close; sie erscheinen jetzt in den
  vorhandenen HUD-Toasts unter dem Fenster (verschieben nie die Seite).
- Bei der Sichtprüfung gefunden und mit behoben: der Journal-Klappknopf „Earlier chapters (2) · reward waiting“
  verbreiterte die Liste (horizontale Scrollleiste). Der Hinweis steht jetzt in einer zweiten Zeile in Menügröße.

## 3. Talent-Tooltips im Fenster

- **Ursache:** `TalentTooltip._place` begrenzte nur auf den Bildschirm; rechts neben der zweiten Spalte von rechts war
  Platz auf dem Bildschirm, aber nicht im Fenster.
- **Jetzt:** Grenze = Rechteck des besitzenden Fensters (`bounds_rect`, 8 px Innenabstand), im selben Canvas wie die
  Talentkarte gemessen (UI-Skalierung und Fensterhöhe automatisch berücksichtigt). Rechts vom Talent, sonst links;
  Größe zuerst ermittelt, dann an allen Rändern begrenzt; überdeckt es das Talent, darunter bzw. darüber. Ist ein
  Tooltip höher als das Fenster, werden die Zeilen breiter (560 statt 400) statt abgeschnitten.
- Der Tooltip nimmt weiter keine Maus (kein Flackern), Inhalte und Tastaturfokus unverändert. Andere Tooltiptypen
  unverändert.

## Ausgeführte Tests

- `./tools/check_project.ps1`: **Startup check OK**.
- Neu `test_playtest_corrections` (3 Tests): Details (kein Schalter, jede Zeile = `shows_stat`, die vier Werte des
  Befunds bei 0 verborgen, positiver und negativer Bonus über eine echte Statquelle sichtbar, Gruppenüberschriften nur
  mit Werten, Entfernen der Quelle aktualisiert); sieben Hauptmenüs ohne Close-Button, gleicher Rahmen, keine leere
  Close-Zeile, eigene Taste und Esc schließen, Menüicon öffnet/schließt, Bestätigung behält ihre Knöpfe, ein kleines
  Fenster seinen Close-Button; jedes Talent aller drei Warrior-Bäume gehovert: Tooltip im Fenster, Talent frei, ohne
  Platz rechts links geöffnet (inkl. langem Capstone-Tooltip).
- `-Suite "playtest_corrections,ui_window_foundation,talent_ui,inventory_ui,main_window_layout"`: erster Lauf
  **25 passed, 2 failed** (zwei ältere Erwartungen: vollständige Statliste, Details-Scrollen) → angepasst.
- `-Suite "inventory_ui,main_window_layout,professions_ui,class_ui,preset_ui,skill_ui,quest_ui,armor_ui,class_switch_ui,
  world_ui,map_ux,menus_ui,ui_layout_lock"`: **66 passed, 0 failed**.
- Nach der Journal-Korrektur `-Suite "quest_turnin_mara_ui,ui_window_foundation,world_ui"`: **23 passed**.
- UI-Galerie 1080p/100 %: `inventory_details_active, inventory, character, talents_full, talents_locked,
  talents_tip_col3, talents_tip_col1, skills, professions, journal, map, options`: **OK (43 checks)**; danach
  `journal, inventory`: **OK**.
- Angepasst: `test_ui_window_foundation` (kein Close-Button, Schließen per Taste/Esc), `test_talent_ui` (Learn im
  Fenster statt „Learn und Close getrennt“), `test_inventory_ui` und `test_main_window_layout` (Details nur Wirksames).
- Keine Full-Suite, keine Gameplay-Loops, kein Asset-Validator.

## Selbst angesehene Screenshots (1920 × 1080, 100 %)

- `inventory_details_active`: Defense (Max Health, Armor), Attack (Attack Speed 4, Crit Chance 5, Poise Damage 8),
  Movement (Movement Speed −10 in Warnfarbe); Physical Damage 0 und alle leeren Gruppen verborgen.
- Sieben Hauptmenüs (Inventory, Character, Skills & Talents, Professions mit Craft-Footer, Journal, Map, Options mit
  „Reset to defaults“): kein Close-Button, keine leere Zeile.
- `talents_tip_col3`: Tooltip der zweiten Spalte von rechts öffnet links und liegt im Fenster; `talents_full`: langer
  Capstone-Tooltip ganz im Fenster; `talents_locked`, `talents_tip_col1`.
- `journal` vor und nach der Klappknopf-Korrektur.

## Commit

Siehe unten (nachgetragen).
