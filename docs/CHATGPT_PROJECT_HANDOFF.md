# Echoes of the Hollow – ChatGPT Project Handoff 1.0

Stand: 2026-10-29, Branch `dev/roots-remember-m4`, HEAD `16dd2fc`. Dieses Dokument ist eine Übergabe für ChatGPT
als Design- und Planungspartner. Es beschreibt den tatsächlichen Stand und ändert nichts am Projekt.

**Kennzeichnung**

| Marke | Bedeutung |
|---|---|
| [CODE] | im aktuellen Code / in den Daten bei der Erstellung dieses Dokuments geprüft |
| [DOC] | durch Projektdokumentation gestützt, nicht erneut verifiziert |
| [REPORT] | aus einem früheren Arbeitsbericht, im Code nicht erneut geprüft |
| [OPEN] | offen oder unklar |
| [DECISION] | festgelegte Designentscheidung |

---

## START HERE – CHATGPT

### Spielidentität
*Echoes of the Hollow* ist ein 2D-Pixel-Art-Action-RPG in schräger Top-Down-Perspektive.
- **Engine:** Godot 4.7.2, ausschließlich GDScript [CODE].
- **Kampf:** Echtzeit, mit Combo-Pfaden pro Waffenfamilie, Dash, Block und Parry sowie vier Klassenskills auf
  Q/E/R/F [CODE].
- **RPG:** ein Charakter mit mehreren Klassen. Jede Klasse hat eigenes Level, Talente, Skills und Ausrüstungs-Loadout;
  Inventar, Lager, Berufe und Mastery sind gemeinsam [CODE].
- **Welt:** Region 1 „Hollow Outskirts“ mit der Basis Haven (feste Ruinen, die restauriert werden) [CODE].
- **Sprache:** Spieltexte sind Englisch; Projektdoku und Arbeitsaufträge sind Deutsch [DECISION].

### Aktueller Entwicklungsstand
- **Spielbar** [CODE]:
  - Prolog: Old Road → Haven → Whispering Stone mit drei Trials und Klassenwahl.
  - Hauptquestkette bis „Beyond the Roots“ (offener Platzhalter: „Further story content is not yet available.“).
  - Drei Nebenquests.
  - Drei spielbare Klassen: Warrior, Arcanist, Shadowrunner.
  - Neun Waffenfamilien, Crafting/Schmiede, neun Berufe, Haven-Lager, Armor Mastery.
  - Save-Version **15**.
- **Grafik:**
  - Die UI hat echte Pixel-Art: 126 PNGs [CODE].
  - Die **Spielwelt ist vollständig prozedural/Platzhalter**: keine Sprites, keine Tilesets, keine Animationen
    [CODE].
  - **Item-Icons existieren noch nicht als Grafik**; überall werden prozedurale Glyphen gezeichnet [CODE].
- **UI:** Das UI-Designsystem ist festgelegt (Layout Lock, Hauptfenster, BookTabs, Leisten, Marker, Skill- und
  Combo-Icons). Die Klassenstation (Skills & Talents UX 2.0) ist in allen sieben Tabs neu gebaut [CODE].

### Wichtigste Design Locks [DECISION]
- **Auflösung:** Design-Raster 1920 × 1080 (Design-px). UI-Skalierung 75 / 100 / 125 / 150 %. Pixel-Art mit
  Nearest-Filter; Art-Pixel = Design-Pixel.
- **Farben und Schriften:** neutrale Palette Charcoal/Slate mit Bronze, Pergament und Resonanz-Cyan. Schriften nur
  IBM Plex Mono (Text) und Silkscreen (Überschriften).
- **Auswahl und Fokus:** Auswahl = Gold, Tastaturfokus = Cyan. Ein Klick wählt nur aus; Aktionen laufen nur über
  eindeutige Knöpfe.
- **HUD:**
  - oben links Spielerrahmen, oben rechts Minimap und Tracker;
  - unten links eine Menüleiste mit sieben Icons (I C T P J M O);
  - unten Mitte Kampfleiste `1 2 | Q E R F` mit 64-px-Slots, darunter die EXP-Leiste 426 × 14.
- **Hauptfenster:** die sieben Hauptmenüs haben einen festen Rahmen 1120 × 760 an derselben Position. Es scrollt nur
  innen.
- **Kampf:**
  - genau ein Waffen-Slot, kein Quick-Swap;
  - Mastery schaltet nur Combo-Pfade frei, nie Stats;
  - Burden wirkt nie auf Dash oder Parry.
- **Architektur:**
  - Daten sind Resources unter `data/` mit stabilen IDs; keine Sonderfall-Ketten im Code;
  - genau ein Autoload `GameSession`;
  - Saves nur über `SaveCoordinator`; Schemaänderung = neue Version + Migration.

### Zuletzt abgeschlossene Arbeit
1. Roots Remember M1–M4 (committet):
   - Chapel und Warden's Rest;
   - Rootbound Sentinel als einmaliger Gegner;
   - Abschluss von „The First Signs“ über Edrins Bericht;
   - offene Folgequest „Beyond the Roots“.
2. Whisper-Forest-Zielfix (committet).
3. **Nicht committet:**
   - Talent Structure Rework 1.0;
   - Skills & Talents UX 2.0, Phasen 1–7 (Weapons, Talents, Skills, Presets, Quests, Classes, Armor);
   - Preset Activation Atomicity Fix 1.0;
   - die gesamte UI-Paket- und Pixel-Art-Reihe ab UI Layout Lock 1.0.

### Nächster konkreter Schritt (bereits festgelegt)
**A. Persönliche Abnahme der Klassenstation** durch den Entwickler, danach Befundkorrekturen. Erst dann folgen der
Reihe nach:
- B: Regressionen;
- C: Item-Icons;
- D: Skill-/Talent-Icon-Lücken;
- E: Welt-Pixel-Art;
- F: Region 1;
- G: Systemvollständigkeit;
- H: voller Spieltest;
- I: Balancing;
- J: Kapitelabnahme.

Siehe Abschnitt 10.

### Wichtigste technische Risiken
1. **Große Mengen ungesicherter Arbeit:**
   - Der Ordner `assets/` ist **komplett untracked**. Darin liegen alle 126 UI-PNGs und beide Schriften.
   - Außerdem untracked: rund 30 Dokumente, rund 30 neue Testsuites und zentrale neue Skripte (`UiSkin`,
     `ComboIcons`, Minimap, Fog).
   - Dazu kommen 106 geänderte, nicht committete Dateien.
   - Ein Plattenschaden oder versehentliches `git clean` würde Monate an Arbeit kosten [CODE].
2. **Item-Icon-Größe ist uneinheitlich:**
   - Tasche/Paperdoll 34 × 34, sonst 30 × 30, HUD-Slot 40 × 40.
   - Der Katalog sagt „30 × 30“.
   - Muss vor der Item-Pixel-Art entschieden werden [CODE].
3. **Veraltete Tests und Playtests** erzeugen Fehlalarme: `rpg_playtest`, `test_prologue::test_migration_v3_to_v4`,
   `test_ui_layout` 150 % [REPORT/CODE].
4. **Welt-Grafik fehlt komplett.** Szenen bestehen aus `StaticBody2D`/`Node2D` mit `_draw()`-Optik. Der Umstieg auf
   Sprites und Tiles ist der größte offene Grafikblock [CODE].
5. **Plate-Rüstung fehlt in den Daten.** Dadurch sind Burden-Stufen Burdened/Heavy im Spiel unerreichbar.
   Magic Resistance und Spieler-Poise haben noch keine Spielwirkung [CODE/DOC].
6. **`project.godot` ist lokal verändert:**
   - die Zeile `stretch/aspect="keep"` entfernt;
   - der `[internationalization]`-Block verschoben;
   - unklar, ob beabsichtigt [CODE/OPEN].

### Wo weitere Informationen stehen
| Thema | Datei |
|---|---|
| Projektregeln für Claude Code (verbindliche Konventionen) | `CLAUDE.md` |
| Klassenstation, alle sieben Tabs | `docs/SKILLS_TALENTS_UX_2_0.md` |
| Talentstruktur | `docs/TALENT_STRUCTURE_REWORK_1_0.md`, `docs/TALENT_SYSTEM.md` |
| UI-Regeln | `docs/UI_DESIGN_SYSTEM.md`, `docs/UI_LAYOUT_LOCK_1_0.md`, `docs/MAIN_WINDOW_LAYOUT_LOCK_1_0.md`, `docs/DISPLAY_AND_UI_STANDARD.md` |
| Asset-Liste | `docs/UI_ASSET_CATALOG_1_0.md` |
| Save | `docs/SAVE_SYSTEM.md` |
| Tests | `docs/TEST_STRATEGY.md` |
| Kampf | `docs/COMBAT_DESIGN.md`, `docs/WEAPON_MASTERY_COMBAT_FLOW.md` |
| Story und Haven | `docs/PROLOGUE_AND_HAVEN.md`, `docs/SIDE_QUESTS_1_0.md`, `docs/ROOTS_REMEMBER_M1..M4.md` |
| Spezifikationen (nur lesen) | `docs/Design/`, `docs/tasks/` |

---

## 1. Repo-Status [CODE]

| Punkt | Wert |
|---|---|
| Branch | `dev/roots-remember-m4` (Hauptbranch `main`) |
| HEAD | `16dd2fc` „docs: roots remember m4 - …“ |
| Arbeitsverzeichnis | 228 Einträge: **106 geändert**, **1 gelöscht**, **121 untracked** |
| Diff der getrackten Dateien | 107 Dateien, +10 850 / −2 683 Zeilen |
| Save-Version | `SaveSystem.VERSION := 15` (`scripts/rpg/save/save_system.gd:20`) |
| Engine | Godot 4.7.2 (`../tools/godot/Godot_v4.7.2-stable_win64_console.exe`) |

### Letzte Commits
- `16dd2fc`, `096fcf2`, `e1dedf1`: Roots Remember M4.
- `eab43bf`, `90a8f8b`, `72f1f8d`: Whisper-Forest-Zielfix.
- `2ff3a6b` … `0d702e2`: Roots Remember M2/M3.

### Uncommittete Änderungen nach System (gruppiert)

| System | Umfang | Beispiele |
|---|---|---|
| UI-Skripte | 23 geändert in `scripts/ui`, 3 in `scripts/ui/hud`, viele neue | `class_station_panel.gd`, `game_hud.gd`, `inventory_panel.gd`, `book_tabs.gd`; neu: `ui_skin.gd`, `combo_icons.gd`, `map_painter.gd`, `hud/area_minimap.gd`, `hud/menu_bar.gd`, `hud/xp_bar.gd`, `hud/bar_text.gd`, `hud/split_bar_text.gd`, `hud/hud_slot.gd` |
| Welt / Karte | 6 geändert in `scripts/world`, 4 neu | neu: `area_map.gd`, `map_fog.gd`, `map_landmark.gd`, `map_markers.gd`; 4 Map-Szenen geändert (chapel, tangled_wood, wardens_rest, whisper_forest) |
| Talente / Presets / Klasse | 9 Talentbäume, `talent_rules.tres`, 5 Skripte in `scripts/rpg/talents`, `character.gd`, `character_equipment.gd` | Talent Structure Rework, Preset-Atomarität, `class_switch_error` |
| Story / Quests | 3 neue Nebenquest-Daten (untracked), `story_service.gd`, `story_quest_definition.gd`, `mara.tres` | Side Quests 1.0 |
| Assets | **`assets/` komplett untracked** | 126 UI-PNGs, Fonts (IBM Plex Mono, Silkscreen, Kandidaten) |
| Werkzeuge | `tools/ui_art/` untracked | Generator und Validator der UI-Art |
| Tests | 24 Integrationssuites geändert, rund 30 neu (untracked), 4 Playtests geändert | z. B. `test_armor_ui`, `test_preset_atomicity`, `test_talent_structure`, `ui_art_check.gd` |
| Gelöscht | 1 | `tests/integration/test_grove_warden_reward.gd` (ersetzt durch `test_chapter_1_rare_reward.gd`) [CODE/DOC] |
| Doku | 7 geändert, rund 30 neu | alle `UI_*_1_0.md`, `SKILLS_TALENTS_UX_2_0.md`, `TALENT_STRUCTURE_REWORK_1_0.md` u. a. |
| Projekt | `project.godot`, `localization/ui.csv`, `CLAUDE.md` | in `project.godot` lokal: `window/stretch/aspect="keep"` entfernt (in Godot 4 ist „keep“ der Standardwert, die Wirkung ist also vermutlich gleich [OPEN]); `[internationalization]` verschoben |
| Schutzordner | `docs/Design/`, `docs/tasks/` untracked | Spezifikationen, nie verändern [DECISION] |

### Abgeschlossene Arbeitsbatches (jüngste zuerst)
- **[CODE] im Arbeitsverzeichnis, uncommittet:**
  - Skills & Talents UX 2.0 Phase 1–7;
  - Preset Activation Atomicity Fix 1.0;
  - Talent Structure Rework 1.0.
- **[DOC], uncommittet:**
  - UI Usability & Haven Crafting 1.0;
  - Skill Icons Pixel Art 1.0;
  - Map Markers Pixel Art 1.0;
  - HUD Bars / Resource Text;
  - BookTabs;
  - Main Window Layout Lock;
  - UI Secondary Controls, Scroll/Input, Selection, Panels, Core States, Visual Consistency, Font Integration;
  - HUD EXP Bar;
  - UI Window Foundation;
  - Map & Fog;
  - UI Layout Lock;
  - Gameplay Polish;
  - Side Quests;
  - World Expansion A/B.
- **Committet:** Roots Remember M1–M4 und der Whisper-Forest-Zielfix.
- **Auffällig:** Der Commit-Verlauf enthält Story-Arbeit, die *auf* einem großen uncommitteten UI-Stand entstanden
  ist. Die Commits allein bilden den spielbaren Stand also nicht ab.

---

## 2. Technische Architektur

### 2.1 Grundaufbau

| System | Zentrale Dateien | Verantwortung | Abhängigkeiten / Fallbacks |
|---|---|---|---|
| Engine / Projekt | `project.godot` | Viewport 1920 × 1080, Fenster 1600 × 900, `stretch/mode="canvas_items"`, Texturfilter Nearest (`default_texture_filter=0`) [CODE] | — |
| Session / Autoload | `scripts/rpg/session_state.gd` (`GameSession`, einziges Autoload) | hält `Character`, `GameDatabase`, `UserSettings`; Kind `SaveCoordinator`; Szenenwechsel `travel(map_id, spawn_id, fade)` [CODE] | Signal-Leck-Regel: Methoden-Callables statt Lambdas [DOC] |
| Hauptszenen | `scenes/ui/title_screen.tscn` (Start), `scenes/maps/home_base.tscn` (Haven), `scenes/arena/test_arena.tscn` | Titel → New Game → `old_road` [DOC] | — |
| Maps | `scripts/world/game_map.gd`, `data/world/maps/*.tres` (`MapDefinition`: `scene_path`, `region_id`, Nachbarn) | jede Map erbt `GameMap`, braucht `Player`, `GameHud`, `SpawnPoint` „default“ [DOC]; Übergänge nur `SessionState.travel()` | `GameMap.camera_bounds`; Fog über `GameMap._update_fog` [DOC] |
| WorldState | `character.world` | Map-ID, Spawn, Flags (Story `prologue.*`, `haven.*`, Zähler `count.<event>`, `defeated.<id>`, `boss_reward.<id>`, Quest-Reward-Flags), Gebäude, Wegsteine, Restaurierung, `map_states[map]["fog"]` [DOC] | — |
| Character | `scripts/rpg/character.gd`, `character_factory.gd` | Laufzeitinstanz: Klassen, Builds, Inventar, Lager, Equipment, Mastery, Armor Mastery, Berufe, Consumables, Welt; `switch_class` / `class_switch_error` [CODE] | Definitionen ≠ Instanzen ≠ Save-Dict [DECISION] |
| Stats | `scripts/rpg/stat_resolver.gd` | Stats immer neu berechnet, nie inkrementell [DECISION] | — |
| Combat ↔ RPG | `scripts/rpg/player_progression_bridge.gd` | einzige Brücke; `sync_weapon()` wählt die Familie der Hauptwaffe, sonst `rules.fallback_weapon_family` (`one_handed_sword`) [CODE] | Items wirken nur über `AttackModifier` [DECISION] |

### 2.2 Items, Inventar, Equipment

| System | Dateien | Verantwortung |
|---|---|---|
| Item-Definition | `scripts/rpg/items/item_definition.gd`, `data/items/*.tres` (69) | `Category` WEAPON/ARMOR/JEWELRY/TRINKET/MATERIAL/CONSUMABLE/QUEST (Standard MATERIAL); `Rarity` NORMAL…SET (7); `ArmorType` NONE/CLOTH/LEATHER/MAIL/PLATE; 17 `SlotKind`s [CODE] |
| Instanzen | `ItemInstance`, Erzeugung nur über `ItemCreation` / `ItemCreation.generate` | Rarity gehört der Instanz; Waffenbasis wird einmal gespeichert [DOC] |
| Inventory | `scripts/rpg/items/inventory.gd` | besitzender Container (Tasche bzw. `Character.stash`); `takes_slot`: ausgerüstete Items der aktiven Klasse belegen keinen Platz [DOC] |
| CharacterEquipment | `scripts/rpg/equipment/character_equipment.gd` | Loadouts pro Klasse (Instanz-IDs der Tasche), `apply_loadout`, `loadout_error` (Vorprüfung im Zielzustand), `class_switch_error`, `quick_slot` (Rechtsklick), `main_hand_family()` [CODE] |
| Stash | `StashService` | atomare Transfers, Kategorien nur als Ansicht (`docs/STASH.md`) [DOC] |
| Schutz / Salvage / Ökonomie | `ItemProtection`, `SalvageService`, `EconomyService` | Favorit/Sperre/Herkunft; Salvage atomar an der Werkbank des Rezepts; Verkaufswerte noch offen [DOC] |

### 2.3 Klassen, Skills, Talente, Presets

| System | Dateien / Daten | Verantwortung |
|---|---|---|
| Klassen | `data/classes/*.tres` (6), `ClassDefinition` (`playable` Standard true, `starts_unlocked`) | Basic Adventurer (Start), Warrior, Arcanist, Shadowrunner spielbar; Guardian, Soulbinder `playable = false` [CODE] |
| Talente | `TalentService`, `data/talents/*.tres` (9 Bäume, 3 je Klasse), `data/progression/talent_rules.tres` | `tier_points = (0, 5, 18, 30)`, `first_point_level = 5`, `skill_slots = 4`, `preset_slots = 5`, Respec in `gold_coin` (10 + 2/Level, erster frei) [CODE] |
| Skills | `SkillBook`, `data/skills` (21), `data/skill_mods` (25) | 4 Slots Q/E/R/F, `assign_slot`; Treffer nur über `SkillCast.deliver` [DOC] |
| Presets | `scripts/rpg/talents/preset_service.gd` | 5 Presets; `validate` prüft vorab auch den Loadout-Wechsel; `activate` = alles oder nichts [CODE/DOC] |
| Prolog / Trials | `PrologueService`, `data/trials` (3) | Trials sind temporär und werden nicht gespeichert [DOC] |
| Klassenquests | `QuestService`, `data/quests` (5) | Freischaltung charakterweit [DOC] |

### 2.4 Story und Quests
- **`StoryService`:**
  - Fortschritt nur über `notify(event)`.
  - Quests, Dialoge, NPCs, Ruinen und Wegsteine sind Daten unter `data/story`, `data/npcs`, `data/haven/ruins`
    und `data/world/waystones`.
  - Platzierung nur über `StoryCondition` [DOC].
- **Hauptquests vs. Nebenquests:**
  - Hauptquests sind die Kette ab FIRST_QUEST über `next_quest_ids`; die Einteilung macht nur
    `StoryService.is_main_story`.
  - Nebenquests starten nur über `start_event_id` [CODE/DOC].
- **Belohnungen:** NPC-Turn-ins und Belohnungsflags laufen über `quest_reward_entitled/claimed.<id>`; Boss-Caches
  über `BossRewardService` [DOC].

### 2.5 Crafting, Berufe, Haven

| System | Dateien | Kern |
|---|---|---|
| Crafting (Schmiede) | `CraftingService`, `ItemStats`, `AffixRoller`, `data/crafting` (41) | Transaktion mit Revision; gewürfelte Werte nie neu berechnet; max. 5 Affixe und 2 Essenzen [DOC] |
| Berufe | `ProfessionService`, `data/professions` (9 Berufe, 19 Rezepte) | Herstellen = Transaktion mit einem Materialplan; an Haven-Werkbänken Tasche + Lager [DOC/CODE] |
| Haven | `RestorationService`, `data/haven/ruins` (10 Ruinen) | feste Ruinen, Stufen ruined/restored/revitalized; 5 Ruinen sind Werkbänke (alchemy, blacksmithing, leatherworking, tailoring, woodworking) [CODE] |
| Sammeln | `ResourceGathering`, `data/world/resource_nodes` (11) | Schritte bei gehaltenem G, feste Budgets [DOC] |

### 2.6 Save/Load
- **Speichern:**
  - `SaveSystem` (Format, Prüfsumme SHA-256 über exakten Payload-Text, Temp-/Backup-Datei);
  - `SaveMigrations` (schrittweise bis v15);
  - `SaveCoordinator` (manuell, periodisch alle 300 s aktiver Spielzeit, Meilenstein).
  - [CODE: Version; DOC: Rest]
- **Slots:** 5 manuelle Slots und 3 rotierende Autosaves unter `user://saves/`. Tests nutzen nur
  `user://test_saves/` [DOC].
- **Nicht gespeichert:** HP, Ressource, Cooldowns, Buffs, Combat-Waffe, laufende Trials. Alles wird beim Laden neu
  aufgebaut [DOC].
- **Doku-Abweichung:** Das JSON-Beispiel in `SAVE_SYSTEM.md` zeigt `"version": 10`, die Überschrift „Version 15“.
  Die Payload-Tabelle nennt `armor_mastery`, `consumables` und Gathering-Teilzustand nicht, obwohl die
  Migrationen 8→9 und 9→10 sie anlegen [CODE/DOC].

### 2.7 UI-Architektur
- **Theme:**
  - `UiTheme` (`scripts/ui/ui_theme.gd`) ist die einzige Quelle für Farben, Schriften, Maße und Komponenten.
  - `UiSkin` lädt optionale Art `res://assets/ui/<id>.png`; fehlt eine Datei, bleibt der prozedurale Fallback
    [CODE].
- **Fenster:**
  - Alle Fenster erben `UiWindow`; Hauptmenüs nutzen `UiWindow.main_window` und `body_room()`.
  - Primäraktionen stehen in `UiWindow.footer`.
  - Bestätigungen laufen nur über `UiConfirmDialog` [DOC].
- **HUD:** `GameHud` mit `PlayerFrame`, `TargetFrame`, `AreaMinimap`, `QuestTracker`, `HudMenuBar`, `QuickUseBar`
  + `SkillBar`, `HudXpBar`, `LootFeed`, `SaveIndicator` [CODE/DOC].
- **Klassenstation:** `ClassStationPanel` (rund 2 600 Zeilen) mit BookTabs-Seiten Classes, Talents, Skills, Presets,
  Quests, Armor, Weapons [CODE].
- **Texte:**
  - Item-Texte nur über `ItemDescriber`; Tooltips `ItemTooltip`, `TalentTooltip`.
  - UI-Chrome-Texte über `localization/ui.csv` (`tr("UI_…")`) [DOC].
- **Galerie:** Jeder neue Bildschirm wird in `tests/playtest/gallery_screens.gd` eingetragen [DECISION].

### 2.8 Render- und Grafikarchitektur [CODE]
- **Welt:**
  - Die Map-Szenen enthalten nur `StaticBody2D`, `Node2D`, `Area2D`, `CollisionShape2D` und `Marker2D`.
  - **Kein `Sprite2D`, kein `AnimatedSprite2D`, kein `TileMap`/`TileMapLayer`** in `scenes/` oder `scripts/`.
  - Die Optik entsteht prozedural über `_draw()`: rund 26 Skripte in Welt, Spieler, Gegner, Basis und Arena.
- **Effekte und Audio:** `CombatFx` / `SkillFxSpec` sind prozedural; `CombatAudio` nutzt `SynthSounds` als
  Platzhalter [DOC].
- **Karte:**
  - `MapPainter` zeichnet das Kartenbild: 1 px = 8 Welt-px; Klassen FLOOR/WALL sind zugleich `is_solid`.
  - Marker sind 1:1 16 × 16; Fog wird pro Zelle gezeichnet [DOC].
- **UI-Art:** Nine-Patch über `StyleBoxTexture` (`UiTheme.SKINNED`), Theme-Icons über `UiTheme.SKINNED_ICONS`.

---

## 3. Aktueller Content-Stand

### 3.1 Weltkarten (Region `hollow_outskirts`) [CODE]

| Map-ID | Name | Szene | Status |
|---|---|---|---|
| `old_road` | The Old Road | `old_road.tscn` | IMPLEMENTIERT (Start) |
| `home_base` | Haven | `home_base.tscn` | IMPLEMENTIERT |
| `whispering_stone` | The Whispering Stone | `whispering_stone.tscn` | IMPLEMENTIERT |
| `whisper_forest` | Whisper Forest | `whisper_forest.tscn` | IMPLEMENTIERT (groß, World Expansion A) |
| `tangled_wood` | The Tangled Wood | `tangled_wood.tscn` | IMPLEMENTIERT |
| `chapel` | The Chapel | `chapel.tscn` | IMPLEMENTIERT |
| `wardens_rest` | Warden's Rest | `wardens_rest.tscn` | IMPLEMENTIERT |
| `broken_bastion` / `shattered_sanctum` / `veiled_passage` | Trials Warrior / Arcanist / Shadowrunner | `trial_*.tscn` | IMPLEMENTIERT (temporär, Prolog) |
| `prologue` | Prologue Grounds | `prologue.tscn` | VORBEREITET / Legacy: als Trial-Map in `progression_rules` geführt, erreichbar aus der Testarena [OPEN: Rolle im echten Ablauf] |
| `test_arena` | Proving Arena | `scenes/arena/test_arena.tscn` | Entwicklerwerkzeug |

Es gibt nur eine Region. Eine Region 2: NICHT VORHANDEN.

### 3.2 Hauptquest-Verlauf [CODE]
1. **A Road Forgotten:** Old Road, erste Kämpfe.
2. **The Broken Cart:** Wagen verteidigen, Kisten bergen, Mara.
3. **Shelter Among the Trees:** Haven erreichen, Mara, Old Smithy restaurieren, Edrin Vale.
4. **The Whispering Stone:** Echos (Trials), Klassenwahl, Wegstein wecken.
5. **The First Binding:** zurück nach Haven, Mara, Edrin.
6. **The First Signs:** Whisper Forest nach Osten, Wurzeln im Tangled Wood, Wegstein der Kapelle, Weg nach Osten,
   gespaltener Wachstein in Warden's Rest, Bericht an Edrin.
7. **Beyond the Roots:** offene Folgequest. Ihr Text lautet „Further story content is not yet available.“ Das ist
   die GEPLANTE Fortsetzung, ohne Inhalt.

### 3.3 Nebenquests [CODE]

| Quest | Start-Event | Schritte (Kurz) |
|---|---|---|
| The Lost Hunter | `talk:mara_lost_hunter` | Tobins Lager auf dem Hunter's Trail, Spuren, Höhle räumen, Horn bergen, zu Mara |
| What the Roots Keep | `interact:roots_keep_marker` | Zeichen im Tangled Wood finden, Sunken Grove durchsuchen |
| Embers of Shelter | `interact:shelter_ledger` | Kapellen-Schutzräume, Ember Draught brauen (Alchemist's Cottage), Mara berichten |

### 3.4 Klassen und Klassenquests [CODE]

| Klasse | Status | Talentbäume | Freischaltquest |
|---|---|---|---|
| Basic Adventurer | Startklasse (`starts_unlocked`), spielbar; in der Klassenstation nur sichtbar, solange sie aktiv ist | — | — |
| Warrior | IMPLEMENTIERT | Berserker, Warbreaker, Bloodblade | Path of Steel |
| Arcanist | IMPLEMENTIERT | Weaver, Runemaster, Astral | Path of the Arcane |
| Shadowrunner | IMPLEMENTIERT | Assassin, Bladestorm, Nighthunter | Path of Shadows |
| Guardian | VORBEREITET (`playable = false`; Daten „Prepared: oaths, Resolve“) | — | Oath of the Guardian (Daten vorhanden) |
| Soulbinder | VORBEREITET (`playable = false`; „Soul Energy, echo summons“) | — | Bond of Souls (Daten vorhanden) |

### 3.5 Aktive Skills (21) [CODE]
- **Warrior:** `battle_cry`, `blade_rush`, `blood_frenzy`, `furious_strike`, `unbound_fury`, `warbreaker`,
  `whirlwind`.
- **Arcanist:** `arcane_bolt`, `arcane_rift`, `astral_ascension`, `astral_lance`, `frostbind`, `mana_pulse`,
  `rune_sigil`.
- **Shadowrunner:** `blade_fan`, `death_mark`, `execution`, `expose_weakness`, `shadow_strike`, `shadowstep`,
  `smoke_veil`.
- **Skill-Mods:** 25 Dateien in `data/skill_mods`.
- **Kapazität:** Die Roadmap nennt „restliche Skills (8 pro Klasse)“. Derzeit sind es 7 pro Klasse, der achte ist
  GEPLANT [DOC].

### 3.6 Talentstruktur [CODE]
- 9 Bäume. In den Daten hat jeder Baum 4 Talente in Tier 2, 4 in Tier 3 und 1 in Tier 4. Tier 1 ist der
  Standardwert in der Datei; laut Doku sind es 4 Talente je Baum [DOC].
- Ränge: 4 Talente mit max. Rang 5, 4–5 mit max. Rang 3, der Rest Rang 1 bzw. Standard.
- Tier-Schwellen 0 / 5 / 18 / 30 Punkte in niedrigeren Tiers desselben Baums.
- Prereqs gibt es nur für direkte Skill-Upgrades [DOC].
- Alte Verteilungen bleiben gültig [DOC].

### 3.7 Waffenfamilien und Combo-Pfade [CODE]
- **Familien (9):** One-Handed Sword, Two-Handed Sword, Axe, Dagger, Mace/Hammer, Spear, Staff, Scepter/Wand, Bow.
  Erzeugt nur über `tools/generate_weapon_families.gd` [DECISION].
- **Nahkampf und Stäbe:** je 14 Combo-Pfade (Grundangriffe + Pfade). Die Roadmap nennt 64 Nahkampf-Pfade und
  8 Bogen-Freischaltungen [DOC].
- **Bogen:** 10 Pfadeinträge, Endstufe „Flowing Draw“.
- **Combo-Icons:** 44 PNGs, gemeinsam über die Familien (`ComboIcons.icon_id`).
- **Animationen:** Waffen-Animationen sind Platzhalter (prozedural) [DOC].

### 3.8 Rüstung und Items [CODE]
- **Armor-Kategorien:** CLOTH, LEATHER, MAIL, PLATE.
- **Items mit Typ:**
  - Cloth 1 (`linen_trousers`);
  - Leather 3 (`leather_cap`, `leather_gloves`, `worn_boots`);
  - Mail 3 (`warden_helm`, `warden_mail`, `warden_greaves`);
  - **Plate 0**.
- **Rüstungsteile ohne Typ:** 8, z. B. `wanderer_coat`, `traveler_cloak`, `oak_shield`, `rope_belt`,
  `warlord_helm`. Sie zählen weder für Burden noch für Mastery.

| Kategorie | Anzahl | Beispiele |
|---|---|---|
| WEAPON | 15 | `iron_sword`, `forged_blade`, `echo_blade`, `steel_greatsword`, `hunting_bow`, `oak_staff`, `oak_wand`, `stormcaller_fang`, `crushing_oath` |
| ARMOR | 15 | siehe oben |
| JEWELRY | 3 | `copper_ring`, `silver_ring`, `bone_amulet` |
| TRINKET | 1 | `hollow_charm` |
| MATERIAL | 26 | Rohstoffe (`iron_ore`, `iron_ingot`, `timber`, `oak_plank`, `raw_hide`, `cured_leather`, `flax_fiber`, `linen_cloth`, `duskleaf`, `stone`, `hollow_essence`, `gold_coin` als Währung) und 14 Crafting-Materialien (`forge_crystal`, `transmute_core`, `socket_chisel`, `imprint_shard`, Essenzen `storm_wolf_essence` / `stone_golem_essence`, `storm_ore`, `frost_glass`, `garnet`, `impact_rune` u. a.) |
| CONSUMABLE | 8 | `minor_potion`, `barkskin_tonic`, `ember_draught`, `quickstep_tincture`, `resonance_elixir`, `stoneskin_draught`, `whisperbloom_concentrate`, `pattern_leather_bracers` (Schnittmuster) |
| QUEST | 2 | `old_key`, `supply_crate` |

### 3.9 Crafting-Stationen [CODE]
- **Schmiede (Resonanzschmieden):** die Old Smithy in Haven.
- **Berufe (9):**
  - Herstellen: Blacksmithing, Leatherworking, Tailoring, Woodworking, Alchemy;
  - Sammeln: Mining, Herbalism, Skinning, Woodcutting.
- **Werkbänke** (Haven-Ruinen mit `profession_id`): Old Smithy (Schmied), Tanner's Lodge, Weaver's House,
  Woodwright's Workshop, Alchemist's Cottage. Die Zuordnung der Dateien ist wahrscheinlich, aber nicht einzeln
  geprüft [OPEN].
- **Weitere Ruinen:** Common Hall, Fallen Barracks, Forgotten Study, Old Storehouse (Lager), Trading House.
- **Sammelknoten (11):** `iron_vein`, `rich_iron_vein`, `ancient_deposit`, `forest_rock`, `oak_tree`, `old_oak`,
  `duskleaf_patch`, `duskleaf_cluster`, `wild_flax`, `elk_remains`, `stag_remains`.

### 3.10 Gegner, Bosse, Begegnungen [CODE]

| Gegner | HP | Vorkommen |
|---|---|---|
| Rootbound Husk | 70 | fast alle Maps |
| Hollowfang Wolf | 50 | Old Road, Forest, Tangled Wood, Chapel, Warden's Rest, Whispering Stone, Trials |
| Hardened Husk | 160 | Old Road, Whisper Forest, Tangled Wood |
| Grunt (Basisgegner) | — | `scenes/enemies/grunt.tscn` |
| **Grove Warden** (Boss) | — | Whisper Forest; Warden's Cache (einmalige Materialien) |
| **Rootbound Sentinel** (einmaliger Boss) | 200 | Warden's Rest; Sentinel's Cache = einziger Kapitel-1-Rare (`BossRewardService`) |
| Bastion Guardian / Sanctum Warden / Passage Alpha | 160 / 160 / 50 | Trial-Bosse (Warrior / Arcanist / Shadowrunner) |

- **Legacy-Flag:** `boss_reward.whisper_forest_grove_warden` ist ein eingefrorener Legacy-Beleg und wird nie mehr
  gesetzt [DECISION/DOC].
- **Gegner-KI:** Gegnervielfalt, Gruppen-KI und Elite-Modifikatoren sind GEPLANT [DOC].

### 3.11 Übersicht

| Status | Inhalt |
|---|---|
| IMPLEMENTIERT | Prolog + 6 Hauptquests, 3 Nebenquests, 3 Klassen, 21 Skills, 9 Talentbäume, 9 Waffenfamilien, Crafting, 9 Berufe, Haven-Restaurierung, Lager, Hearth Flask + Tränke, Armor Mastery, Karte/Fog, Save v15, Loot-Drops (Grunt/Wolf), Kapitel-1-Rare |
| VORBEREITET | Guardian, Soulbinder (Daten + Quests, nicht spielbar); `prologue`-Map; Asset-IDs ohne Hook (`hud/cooldown`, `status/<id>`, `feedback/*`, `category/*`, `hud/minimap_frame`) |
| GEPLANT | „Beyond the Roots“-Fortsetzung, 8. Skill je Klasse, Plate-Items, Item-Icons, Welt-Sprites/Tiles/Animationen, echte Audio/VFX, Gamepad, Tastenbelegung, Verkaufs-Basiswerte |
| NICHT VORHANDEN | Region 2, Dungeons über Region 1 hinaus, Sprites/Tilesets, Item-PNGs, Status-Icons, Spieler-Poise-Bruch, magischer Gegnerschaden |

---

## 4. UI Design Lock (technisch)

### 4.1 Palette und Schrift [CODE] (`UiTheme`)
- **Flächen:**
  - `PANEL #23262c`;
  - `PANEL_ELEVATED #30343b` (Slate);
  - `PANEL_INSET #191b20` (Charcoal);
  - Fenster `#1d1f24` bei 99 % Deckkraft.
- **Akzente:**
  - Bronze `#c5ad85`, `#7d6c52`, `#4a4134`;
  - Pergament `#eadcb8`;
  - Text `#e9ddc5`, `#b3aea4`, `#85827b`;
  - Resonanz `#78b8c5` (Fokus);
  - Erfolg `#9cbf7e`, Warnung `#d9b46a`, Gefahr `#d27461`;
  - HP `#b4493f`, Poise `#c9a95c`;
  - EXP-Füllung = Bronze dim.
- **Schriften:**
  - Text: IBM Plex Mono Regular (`assets/fonts/ibm_plex_mono/`), Größen 14 / 15 / 18 / 20.
  - Überschriften: Silkscreen (`assets/fonts/silkscreen/`), 8-px-Raster, 16 / 24 / 32 / 64.
- **Abstände:** Bildschirmrand 16, Panel-Innenabstand 14, Gap 8, Rahmen 2.

### 4.2 HUD [DOC: `UI_LAYOUT_LOCK_1_0.md`; Maße teils CODE]

| Zone | Inhalt | Maß |
|---|---|---|
| oben links | `PlayerFrame` (Breite 360), `EffectBar` | (16, 16) |
| oben Mitte | `TargetFrame` 420, Boss 640 (512 bei 150 %) | zentriert |
| oben rechts | Minimap 200 × 200 (168 bei 150 %), darunter `QuestTracker` 340 | (−356, 16) |
| unten links | Menüleiste: 7 Icons, Rahmen 40 × 40 (`MENU_ICON_SIZE`), Art 32 × 32, Abstand 4 | (16, −16) |
| unten Mitte | Kampfleiste `1 2` + 18 px + `Q E R F`, Slots 64 × 64 (`HUD_SLOT_SIZE`), Breite 426; EXP-Leiste 426 × 14, 6 px darunter (`XP_BAR_SIZE`, `XP_BAR_GAP`) [CODE] | unten −16 |
| unten rechts | `SaveIndicator` (46), darüber `LootFeed` 340 | — |

- **Menüleiste:** I Inventory, C Character, T Skills & Talents, P Professions, J Journal, M Map, O Options. Klick =
  Taste.
- **Ressourcenleisten:**
  - Rahmen `bar/frame` + Tönungsmaske `bar/fill`;
  - Leiste 14 px, Text 12 px als `SplitBarText` (dunkel über heller Füllung, hell über der Rinne, pixelgenau
    geteilt);
  - Zahlen über `BarText` [DOC].
- **Doku-Abweichung:** `UI_LAYOUT_LOCK_1_0.md` nennt oben rechts noch „Platzhalter ‚Map unavailable‘“. Seit
  Map & Fog 1.0 gibt es eine echte Minimap (`scripts/ui/hud/area_minimap.gd`) [CODE].

### 4.3 Hauptfenster und BookTabs
- **Rahmen:** `MAIN_WINDOW_SIZE = 1120 × 760` [CODE] für alle sieben Hauptmenüs.
  - Gleiche Position über `UiWindow.main_window`.
  - Bei 150 % (Canvas 1280 × 720) wird die Höhe einheitlich auf 688 geklemmt [CODE-Kommentar].
  - Inhalte über `body_room()`; Scrollen nur in inneren Bereichen.
- **BookTabs:** `booktab/normal|hover|selected` 24 × 24, Rand 4, rechts offen. Alle inaktiven Register sind
  112 px breit. Auswahl Gold, Fokus Cyan außen [DOC].
- **Tab-Fenster:** feste Außengröße über `UiWindow.stable_size` [DOC].

### 4.4 UI-Skalierung [CODE]
- **Stufen:** `UserSettings.UI_SCALES = [0.75, 1.0, 1.25, 1.5]`. Nur diese Werte sind gültig.
- **Speicherort:** `user://settings.cfg`, nie im Save.
- **Canvas:** 100 % = 1920 × 1080, 125 % = 1536 × 864, 150 % = 1280 × 720, gleich für 1080p, 1440p und 4K [DOC].
- **Regel:** nie `Control.scale` [DECISION].
- **Abweichung:** Der Bericht zum Talent Structure Rework nennt einen Fall „class_ui bei 200 %“. 200 % ist kein
  Spielerwert, das betrifft nur einen Testpfad [REPORT/OPEN].

### 4.5 Minimap, Fog, Marker [DOC/CODE]
- **Fog:**
  - pro Map in `WorldState.map_states[map]["fog"]`;
  - aufgedeckt nur über echte Bewegung (`GameMap._update_fog`);
  - unerkundet `MapFog.DARK`, erkundet = Bild unter 32 % Schwarz.
- **Marker:**
  - nur über `MapMarkers.collect`, nur auf erkundeten Zellen, nie Gegner oder Loot;
  - Arten: player, exit, waystone (wach/still), rest, npc, landmark, quest;
  - 16 × 16, 1:1 über `MapPainter.marker_rect`;
  - der Spielerpfeil dreht in 90°-Schritten;
  - der Goldring um Quest-Marker ist Code.
- **Kartenfenster M:** Tabs Area und Region; die Regionskarte hat eigene Ortskästchen.

---

## 5. Asset-Inventar [CODE, gezählt und gemessen]

### 5.1 `assets/ui/` – 126 PNGs (alle untracked!)

| Gruppe | Dateien | Quellgröße | Zweck |
|---|---|---|---|
| `combos/` | 44 | 40 × 40 | Combo-Icons, Weapons-Tab (Raster 2×, Details 3×) |
| `skills/` | 21 | 40 × 40 | 21 aktive Skills, 1:1 in Kampfleiste und Klassenstation |
| `map/` | 8 | 16 × 16 | Kartenmarker |
| `button/` | 8 | 24 × 24 | normal, hover, pressed, disabled + primary × 3 (+1) |
| `menu/` | 7 | 32 × 32 | Menüleisten-Icons |
| `panel/` | 4 | 24 × 24 (3), 16 × 16 (inset) | hud, card, card_selected, inset |
| `slot/` | 4 | 24 × 24 | Inventar-Slotzustände |
| `check/` | 4 | 16 × 16 | Checkbox-Zustände |
| `dropdown/` | 4 | 12 × 12 (Pfeil), 16 × 16 (3 Radio) | — |
| `slider/` | 4 | 10 × 10 (fill), 16 × 16 (3 grabber) | — |
| `booktab/` | 3 | 24 × 24 | — |
| `tab/` | 3 | 24 × 24 | — |
| `input/` | 3 | 24 × 24 | — |
| `hud/` | 2 | 64 × 64 | `slot_frame`, `slot_frame_disabled` |
| `scroll/` | 2 | 10 × 10 | track, grabber |
| `bar/` | 2 | 3 × 3 (frame), 4 × 6 (fill) | — |
| `window/` | 1 | 48 × 48 | Fensterrahmen, 9P 12 |
| `tooltip/` | 1 | 24 × 24 | — |
| `chip/` | 1 | 12 × 12 | Tasten-Chip |

- **`assets/ui/items/` existiert nicht:** 0 Item-Icons.
- **Fonts:**
  - `assets/fonts/ibm_plex_mono` und `assets/fonts/silkscreen`, je 2 Dateien (Schrift + Lizenz o. ä. [OPEN]);
  - `assets/fonts/candidates/` mit 36 Kandidaten-Dateien (gohufont, Pixelify Sans, Press Start 2P u. a.).
    Nicht im Spiel genutzt.
- **Welt:** `assets/` enthält **keine** Welt-Sprites, Tilesets oder Animationen. Im ganzen Projekt gibt es außer
  `icon.svg` und Test-/Doku-Screenshots keine weiteren Bilddateien.

### 5.2 Generator, Validator, Fallbacks
- **Generator:** `tools/ui_art/generate_core_ui_assets.py` (1 427 Zeilen, Python + PIL). Erzeugt die UI-PNGs
  regelbasiert aus einer festen Palette, inkl. `SKILL_ICONS` und `COMBO_ICONS`.
- **Validator:** `py -3 tools/ui_art/validate_ui_assets.py [--render DIR]`. Er prüft:
  - Pfad und Größe;
  - RGBA mit hartem Alpha (0/255);
  - nur Palettenfarben;
  - Nine-Patch-Kanten;
  - identische Geometrie der Zustandsvarianten;
  - Icons ohne Hintergrundplatte, mit Kontur.
  - **Bei dieser Übergabe ausgeführt: `RESULT: OK`.**
- **Fallback:** `UiSkin.texture(id)` gibt `null` zurück, wenn die Datei fehlt. Jede Komponente zeichnet dann ihren
  prozeduralen Fallback (z. B. Skill = farbiger Kreis + Buchstabe, Item = Glyphe nach Slot-Art).
- **Platzhalter heute:**
  - alle Items (`ItemIcon._draw_glyph`);
  - Hearth Flask und Tränke im HUD;
  - Status-Icons (Text-Chips);
  - Feedback-Akzente;
  - Kategorie-Tabs;
  - Cooldown-Abdunklung (flaches Schwarz);
  - die gesamte Welt;
  - Combat-VFX und Audio.

### 5.3 Icon-Größenproblematik bei Items [CODE]
Die Item-Art (`items/<id>`) wird je nach Ort in unterschiedlichen Größen gezeichnet:

| Ort | Komponente | Zelle | gezeichnete Art |
|---|---|---|---|
| Tasche / Paperdoll / Lager | `ItemCell` (56 × 56, `ItemIcon` mit 6 px Einzug = 44 × 44) | 44 × 44 | `rect.grow(-5)` = **34 × 34** |
| Crafting, Berufe, Loot-Feed, Bauplan | `ItemIcon` mit `ICON_SIZE` 40 × 40 | 40 × 40 | **30 × 30** |
| HUD Quick-Use (Flask, Trank) | `HudSlot` 64 × 64 | — | **40 × 40** (`draw_texture_rect` mittig) |
| Katalog (`UI_ASSET_CATALOG_1_0.md` D) | — | — | „30 × 30 visible (drawn into the 40 × 40 cell inset 5 px)“ |

**Folge:** Eine 30 × 30-Quelle würde in der Tasche um den Faktor 1,13 und im HUD um 1,33 verzerrt
(Nearest-Neighbour, ungleichmäßige Pixel). Eine einheitliche Quellgröße mit ganzzahliger Darstellung an allen Orten
fehlt noch. Das muss **vor** der Item-Pixel-Art entschieden werden (Phase C).

---

## 6. Skills & Talents UX 2.0 – Stand aller sieben Tabs
Klassenstation `scripts/ui/class_station_panel.gd`. Gemeinsame Muster [CODE/DOC]:
- fester Rahmen 1120 × 760;
- Liste oder Raster plus feste Details;
- Auswahl Gold, Fokus Cyan;
- ein Klick wählt nur; Aktionen nur über eindeutige Knöpfe, gesperrt mit sichtbarem Grund;
- Regeln nur über die Services.

Kein weiteres Redesign geplant [DECISION].

| Tab | UI-Struktur | Datenquelle | Aktionen | Regeln / Einschränkungen | Tests |
|---|---|---|---|---|---|
| **Weapons** | Kopf mit Mastery (Level, XP, nächster Combo); Combo-Raster mit 5 Spalten (Icon 2×) und Details (Icon 3×) | `CharacterEquipment.main_hand_family()`, `MasteryTrack`, `ComboIcons` | keine (nur Anzeige) | nur die Familie der Hauptwaffe; ohne Waffe Leerzustand „No weapon equipped“ (Fallback-Familie wird nicht als aktiv gezeigt); Mastery anderer Familien wird nicht angezeigt | `test_weapon_mastery_ui` |
| **Talents** | drei Baum-Buttons (Name · Punkte), ein Baum, fester Detailbereich | `TalentService`, `talent_rules.tres` | `LearnTalent` → `TalentService.learn` | 4 Tiers, Schwellen 0/5/18/30; Linien nur für echte Voraussetzungen; Skill-Art nur bei Aktiv-Talenten | `test_talent_ui`, `test_talent_structure` (unit), `test_talents`, `test_class_ui` |
| **Skills** | Q/E/R/F-Leiste oben, kompakte Liste, Details mit fester Equip-Zeile und Mods des gewählten Skills | `SkillBook` | Equip / Replace / Swap → `SkillBook.assign_slot`; Mods | Auswahl rüstet nie aus | `test_skill_ui`, `test_skills` |
| **Presets** | 5 kompakte Zeilen (Save/Overwrite); Name/Rename/Delete; Build-Details (Punkte je Baum, Q/E/R/F + Mods, Items mit Zustand), Fuß Activate | `PresetService` | Save, Overwrite, Rename, Delete, Activate | **atomar:** `validate` prüft vorab Talente, Slots, Mods und den Loadout-Wechsel (`CharacterEquipment.loadout_error`, Tasche im Zielzustand); `activate` übernimmt nur Talente/Slots/Mods; Respec-Zähler und Freischaltungen bleiben | `test_preset_ui`, `test_preset_atomicity`, `test_presets` |
| **Quests** | Liste der Klassen-Freischaltquests mit Status Locked / Available / Active / Ready to Turn In / Completed / Class unlocked; Details (Ziele, Lieferungen, Anforderungen, Belohnung) | `QuestService` | Take quest / Turn in | charakterweit | `test_quest_ui` |
| **Classes** | Karten (ACTIVE/UNLOCKED/LOCKED, Level, Tagline), Details (Ressource, Spielstil, Spezialisierungen, Gear bzw. Freischaltung) | `CharacterClasses`, `ClassDefinition` | „Switch to <Klasse>“ (`Activate_<id>`) | **zentrale Vorprüfung** `Character.class_switch_error` = dieselben Prüfungen wie `switch_class` (Station, keine Trial, nicht aktiv, freigeschaltet/spielbar, Tasche im Zielzustand); Knopf nur bei leerem Fehler, sonst Grund; Startklasse nur solange aktiv; Guardian/Soulbinder verborgen | `test_class_switch_ui`, `test_class_ui` |
| **Armor** | Burden-Status oben (Punkte, Stufe, Strafen, Stufenbereiche aus den Regeln, 5 Slots), 2 × 2 Mastery-Karten (WORN n %, Level, XP, Boni, nächster Meilenstein), Details mit 4 Meilensteinen | `ArmorMasteryService`, `ArmorMasteryRules` | keine (nur Anzeige) | Slots Head 15 / Chest 40 / Hands 10 / Legs 25 / Feet 10 %; Stufen ab 15/26/38 (Light/Balanced/Burdened/Heavy), Strafen 0/2/5/8 % auf Gehtempo und Attack Recovery, nie Dash/Parry; Mastery Stufe 1–20, Meilensteine 5/10/15/20, skaliert mit getragener Abdeckung | `test_armor_ui`, `test_armor_mastery` |

**Bekannte Einschränkungen** [REPORT, Phasen 6/7]:
- Burdened und Heavy sind mit echten Items unerreichbar (keine Plate-Items).
- Magic Resistance und Poise werden als Boni angezeigt, haben aber keine Spielwirkung.
- Typlose Rüstungsteile zählen nicht und zeigen z. B. „Chest – 0“.
- Taglines werden bei 360 px gekürzt.
- Playstyle-Texte wiederholen die Bäume („Trees: …“).
- Geteilte Item-Instanzen zwischen Klassen-Loadouts werden nicht erklärt.
- Nach der Prolog-Wahl gibt es in der Station keinen Weg zurück zum Basic Adventurer (die Regel selbst erlaubt ihn).

**Letzte Läufe** [REPORT, Phase 7]:
- Station-Suites 28/28 und 48/48 grün.
- `check_project.ps1` OK.
- `class_playtest.gd` 460/460 OK.
- Galerie bei 1080p 75/100/150 %, 1440p und 4K je 18 Checks OK.

---

## 7. Offene technische Probleme
Priorisiert nach Risiko für Save, Itemdaten, Gameplay und Spieler-UX.

| # | Punkt | Status | Risiko | Befund |
|---|---|---|---|---|
| 1 | Ungesicherte Arbeit: `assets/`, `tools/ui_art/`, rund 30 Doku- und 30 Testdateien untracked; 106 Dateien geändert | BESTÄTIGT [CODE] | sehr hoch (Datenverlust) | reine Git-/Backup-Frage; keine Code-Ursache |
| 2 | Trial-/Prolog-Grenzfälle bei der Taschenkapazität: `PrologueService.choose_starting_class` und das Trial-Ende werden nicht abgelehnt und können die Tasche überfüllen | BESTÄTIGT als bewusst offen [DOC: `EQUIPMENT_SYSTEM.md`] | mittel (Itemdaten: laut Doku kein Verlust, nur kein neues Item) | im Code nicht erneut nachgestellt |
| 3 | Inventar-Schnappschuss nach Save/Load in `rpg_playtest` weicht ab (nur Schlüssel `inventory`) | UNGEPRÜFT [REPORT] | mittel bis hoch, falls echt (Save/Itemdaten) | Ursache unbekannt; kann Testartefakt oder echter Unterschied sein (z. B. Reihenfolge, `rarity`-Feld). **Vor Phase B klären.** |
| 4 | `rpg_playtest.gd` klickt einen Inventar-Knopf „Equip“, den es nicht mehr gibt (Zeilen 98/102); 4 Folgechecks fallen | BESTÄTIGT, VERALTETER TEST [CODE] | niedrig | Inventarregel: Rechtsklick = `quick_slot`, keine Aktionsknöpfe |
| 5 | `test_prologue::test_migration_v3_to_v4` erwartet „items otherwise untouched“, die v14-Migration schreibt absichtlich `rarity` | VERALTETER TEST [REPORT, Ursache im Bericht geprüft] | niedrig | Testerwartung ist älter als Loot Foundation 1.0 |
| 6 | `test_ui_layout::test_inventory_scrolls_instead_of_overflowing_at_150_percent` erwartet, dass der Fensterkörper scrollt | VERALTETER TEST [CODE: Test vorhanden, Zeile 104] | niedrig | Seit Main Window Layout Lock scrollen nur innere Bereiche |
| 7 | Magic Resistance / Poise des Spielers ohne Spielwirkung (Gegner nur physisch, kein Poise-Bruch beim Spieler) | BESTÄTIGT [DOC: `ARMOR_MASTERY.md`] | mittel (UX: angezeigte Boni wirken nicht) | Design-Entscheidung nötig |
| 8 | Plate-Items fehlen: Burdened/Heavy und Iron Discipline unerreichbar | BESTÄTIGT [CODE] | mittel (Systemvollständigkeit) | nur Testitems decken die Stufen ab |
| 9 | Unbewaffneter Sonderfall der Weapon Mastery: ohne Waffe läuft `one_handed_sword` als Fallback-Familie (`PlayerProgressionBridge.sync_weapon`); die Weapons-Seite zeigt deren Mastery nicht als aktiv | UNGEPRÜFT [CODE: Fallback bestätigt] | niedrig bis mittel | Ob Kills ohne Waffe One-Handed-Sword-XP vergeben (Kill-XP folgt `hit.attack.weapon_family_id`), ist nicht verifiziert. `WEAPON_BASE_DAMAGE_1_2.md` §6.3: Die Kompatibilitätsgrenze „Waffe ohne Basis“ wird nur noch vom unbewaffneten Fallback genutzt; Entscheidung offen |
| 10 | Map-Marker-Gedränge (eng beieinander liegende Marker überdecken sich) | UNGEPRÜFT | niedrig (UX) | In den Dokumenten nicht als Befund gefunden. `MapMarkers`/`MapPainter` haben keine sichtbare Abstands- oder Bündellogik [CODE, oberflächlich] |
| 11 | RID-Leck-Meldungen, wenn bestimmte Suites zusammen laufen | UNGEPRÜFT [REPORT] | niedrig | Testartefakt vermutet, nicht belegt |
| 12 | `crafting_loop` „bekannter Altfehler“; `test_loop` nutzt das alte `ResourceNode.gather()` | UNGEPRÜFT [DOC: `WEAPON_BASE_DAMAGE_1_2.md`, `TEST_STRATEGY.md`] | niedrig | — |
| 13 | Doku-Abweichungen: `SAVE_SYSTEM.md` (Beispiel v10, fehlende Schlüssel), `UI_LAYOUT_LOCK_1_0.md` (Minimap-Platzhalter), `DEVELOPMENT_ROADMAP.md` endet bei Gathering 1.1 (alles danach fehlt dort) | BESTÄTIGT [CODE/DOC] | niedrig (Planungsrisiko) | — |
| 14 | `project.godot` lokal verändert (`stretch/aspect` entfernt) | BESTÄTIGT [CODE] | niedrig bis mittel | ob beabsichtigt [OPEN]; Schutzdatei, nicht anfassen |

---

## 8. Testinfrastruktur

### 8.1 Werkzeuge und Befehle [CODE]

| Zweck | Befehl / Datei |
|---|---|
| Startprüfung (Import, Parse, Hauptszene headless 300 Frames; Fehler **und** Warnungen) | `./tools/check_project.ps1` |
| Gezielte Suites | `./tools/run_tests.ps1 -Suite "armor_ui,class_ui"` (Suite = `tests/**/test_<name>.gd`; in PowerShell die Liste quoten). Der Runner importiert vorher (`--import`) – nötig für neue `class_name`-Skripte |
| Alles | `./tools/run_tests.ps1` ohne `-Suite` – nur bei Änderungen an mehreren Kernsystemen |
| Runner / Framework | `tests/run_tests.gd`, `tests/framework/test_case.gd`, `error_counter.gd` (Engine-/Skriptfehler lassen Tests scheitern); headless `--fixed-fps 60` |
| Godot-Pfad | `../tools/godot/Godot_v4.7.2-stable_win64_console.exe` oder `$env:GODOT` |
| UI-Galerie (Screenshots) | `godot --path . -s res://tests/playtest/ui_gallery.gd -- --res=1920x1080,2560x1440,3840x2160 --scale=0.75,1.0,1.5 --only=a,b` → `tests/output/gallery/<res>_<scale>_<screen>.png`; Bildschirme in `tests/playtest/gallery_screens.gd` |
| UI-Art-Check (nicht headless, echte Maus) | `-s res://tests/playtest/ui_art_check.gd -- --res=… --scale=…` → `tests/output/ui_art/`; 24 Szenen (inventory, hud_combat, states, booktabs_*, bars, map_markers, skill_icons, weapons_tab …) |
| Asset-Validator | `py -3 tools/ui_art/validate_ui_assets.py` (bei dieser Übergabe: OK) |
| Fenster-Playtests | `class_playtest.gd` (Klassen-UI; `-- --prologue`), `rpg_playtest.gd`, `loop_playtest.gd`, `prologue_playtest.gd` (`--fixed-fps 60`), `stash_playtest.gd`, `crafting_playtest.gd`, `ui_playtest.gd`, `visual_playtest.gd`, `feedback_playtest.gd`, `roots_m1..m4_visual_check.gd`, `forest_target_visual_check.gd`, `gathering_visual_check.gd`, `combat_feel_test.gd` |

**Bestand:** 112 Integrations- und 13 Unit-Suites sowie 1 Framework-Datei. Ausgaben liegen unter `tests/output/`.

### 8.2 Efficient Testing 1.1 [DECISION]
- Nur Suites des geänderten Systems plus direkte Abhängigkeiten. Die Abhängigkeitstabelle steht in
  `docs/TEST_STRATEGY.md`.
- Grüne, unveränderte Suites nicht wiederholen.
- Keine Full-Suite und keine vollständigen Prolog-, Haven-, Trial-, Arena- oder Gameplay-Loops ohne ausdrückliche
  Freigabe.
- Nie behaupten, ein Test sei gelaufen, wenn er nicht lief. Ergebnisse gehören in den Batch-Bericht.

### 8.3 Drei Prüfarten
| Art | Was | Grenzen |
|---|---|---|
| Automatisiert | Unit-/Integrationssuites, `check_project.ps1`, Asset-Validator, Layout-Checks in Galerie und UI-Art-Check | prüfen Regeln und Geometrie, nicht Lesbarkeit oder Spielgefühl |
| Screenshot-Sichtprüfung | Galerie- und UI-Art-Bilder, von Claude angesehen | KI-Sicht; Feinheiten wie Kontrast oder Pixel-Treue bei 1440p brauchen ein menschliches Auge |
| Menschlicher Playtest | Spielgefühl, Combat-Timing, Balance, UX | **steht für die Klassenstation noch aus (Phase A)**; für Combat-Feel ebenfalls offen (`COMBAT_FEEL_TEST.md`) |

### 8.4 Bekannte Testfallen
- In PowerShell muss die Suite-Liste gequotet werden: `-Suite "a,b"`.
- Neue `class_name`-Skripte brauchen `--import`; `run_tests.ps1` macht das automatisch, ein direkter Godot-Aufruf
  nicht.
- Galerie-Bildschirme übernehmen Zustand vom vorherigen Bildschirm, z. B. eine Auswahl. Jeder Bildschirm muss
  seinen Zustand explizit setzen.
- Mehrere Suites zusammen erzeugen gelegentlich RID-Leck-Meldungen [REPORT].
- Die veralteten Tests aus Abschnitt 7 (#4–6) schlagen erwartbar fehl und sind kein Regressionssignal.
- Tests schreiben nur nach `user://test_saves/` und räumen `.bak`/`.tmp` auf.

---

## 9. Geplante nächste Arbeit – technische Einschätzung
Die Reihenfolge A–J ist festgelegt [DECISION]. Hier stehen nur Voraussetzungen, Abhängigkeiten und Risiken.

| Phase | Voraussetzungen | Abhängigkeiten | Risiken |
|---|---|---|---|
| **A. Persönliche Abnahme der Klassenstation, Befundkorrekturen** | Spielstand mit allen drei Klassen; Galerie-Bildschirme (`classes_*`, `armor_*`, `talents_*`, `skills_*`, `presets_*`, `quests_*`, `weapons_tab`) als Referenz | Befunde dürfen nur die UI betreffen; Regeln bleiben in den Services | Befunde, die Regeln berühren (z. B. Rückweg zum Basic Adventurer, Anzeige wirkungsloser Stats), sind Design-Entscheidungen, keine UI-Fixes |
| **B. Bekannte Regressionen** | Abschnitt 7 #3–6, #11–12 | #3 (Inventar-Snapshot) zuerst klären, da Save/Itemdaten; dann veraltete Tests auf die aktuellen Regeln anpassen | Ein veralteter Test darf nicht durch Lockern der Erwartung „grün gemacht“ werden, wenn eine echte Abweichung dahintersteckt |
| **C. Item-Icon-Größen und Item-Pixel-Art** | **Entscheidung über eine Quellgröße**, die in Tasche (heute 34), Listen (30) und HUD (40) ganzzahlig dargestellt wird; Katalog D anpassen; 69 Item-IDs (Prio: Startausrüstung, Tränke, Region-1-Materialien) | `ItemIcon` und `ItemCell` (Einzug 6 + 5), `HudSlot`; der Validator braucht eine `items/`-Spezifikation; Generatorstil wie bei Skills/Combos | Freie Größenänderung der Zellen verschiebt das Inventarraster im festen 1120 × 760-Rahmen; Rarity-Pips (unten 6 px) und Marker (oben rechts 10 × 10) müssen frei bleiben |
| **D. Skill-/Talent-Icon-Lücken** | Liste der Talente, die heute ohne Art sind (Talentknoten nutzen Skill-Art nur bei Aktiv-Talenten); ggf. 8. Skill je Klasse | `UiTheme.skill_icon`, `SKILL_ICONS` im Generator; Validator gleicht IDs mit `data/` ab | 117 Talente (9 × 13) als einzelne Icons wären ein großer Block; Umfang vorher festlegen |
| **E. Welt-Sprites und Umwelt-Pixel-Art** | Entscheidung über das Weltraster (Tile-Größe, Perspektive „schräg Top-Down“), Animationsumfang für Spieler, Gegner, Waffen; Import-Pipeline | Die heutige Optik ist `_draw()` in rund 26 Skripten, Kollision über `StaticBody2D`; `MapPainter` leitet das Kartenbild aus Kollisionsklassen ab; Angriffsphasen (`AttackDefinition`) müssen an Animationen gekoppelt werden | größter Block; Gefahr, Gameplay-Geometrie (Hitboxen, Kollision, Kamera-Grenzen) zu verändern; Minimap/Fog hängen an FLOOR/WALL-Klassen |
| **F. Region-1-Vervollständigung** | Inhalt für „Beyond the Roots“; Plate-Items; ggf. weitere Gegnertypen | `StoryService` (Events, `next_quest_ids`), `StoryCondition`, `MapDefinition`, Fog/Marker; Kapitel-1-Rare-Regel (nur Sentinel's Cache) | neue Story-Flags ohne Versionswechsel sind erlaubt, Schemaänderungen nicht ohne Migration |
| **G. Systemvollständigkeit** | Entscheidungen zu: Magic Resistance / Spieler-Poise, Verkaufs-Basiswerte (`EconomyService`), unbewaffneter Fallback, Trial-/Prolog-Kapazität, Guardian/Soulbinder (bleiben vorbereitet?) | jeweils das zuständige Service; Save-Regel | jede Schemaänderung → `SaveSystem.VERSION` 16 + Migration + `save`-Tests |
| **H. Vollständiger Spieltest** | A–G abgeschlossen; Freigabe für Full-Suite und volle Loops (laut Efficient Testing sonst ausgeschlossen) | `prologue_playtest`, `loop_playtest`, `class_playtest -- --prologue`; menschlicher Durchlauf | lange Laufzeiten; veraltete Playtests (z. B. `rpg_playtest`) vorher reparieren, sonst unklare Fehler |
| **I. Gameplay-Balancing (zuletzt)** | Spieltest-Daten; `COMBAT_DESIGN.md` („Vorschläge für den Feel-Test“) | Timings/Balance nur nach Playtest ändern [DECISION]; Werte in Daten (`CombatFlowRules`, `ArmorMasteryRules`, `talent_rules`, Item-Daten) | Rückwirkungen auf Tests mit festen Zahlen (z. B. Burden „39 · Heavy“, Schadenswerte) |
| **J. Finale Kapitelabnahme** | alles oben; Doku-Abgleich (Roadmap, Save-Doku) | — | — |

---

## 10. Wichtige Abweichungen zwischen Code und älterer Doku

| Doku | Aussage | Tatsächlich [CODE] |
|---|---|---|
| `DEVELOPMENT_ROADMAP.md` | endet bei Gathering Rework 1.1; Talent-Engine „7 Tiers“ (Class Foundation 0.2) | seither rund 30 Batches; Talente jetzt 4 Tiers |
| `UI_LAYOUT_LOCK_1_0.md` | Minimap = Platzhalter „Map unavailable“ | echte Minimap (`area_minimap.gd`) |
| `UI_ASSET_CATALOG_1_0.md` D | Item-Art 30 × 30 sichtbar | 34 (Tasche), 30 (Listen), 40 (HUD) |
| `SAVE_SYSTEM.md` | JSON-Beispiel `"version": 10`; Payload-Tabelle ohne `armor_mastery` / `consumables` | `VERSION := 15`; die Migrationen legen beide an |
| `TEST_STRATEGY.md` „Visueller Playtest“ / Ebenen | Fokus auf Combat-Prototyp | heute zusätzlich Galerie, UI-Art-Check, Python-Validator |
| Phase-6-Bericht | Basic Adventurer als vierte Klassenkarte | seit Phase 7 nur sichtbar, solange aktiv |

---

## 11. Fragen, die ChatGPT gezielt anfordern sollte

Diese Informationen fehlen hier und sollten bei Bedarf als Dateiauszug angefordert werden:

1. **Combat-Zahlen:** Timings, Schaden, Gegnerwerte. Quelle: `docs/COMBAT_DESIGN.md`,
   `docs/WEAPON_MASTERY_COMBAT_FLOW.md`, `data/combat`, `data/enemies`.
2. **Talentinhalte:** Namen und Effekte je Baum. Quelle: `docs/TALENT_SYSTEM.md` oder die `.tres`.
3. **Haven-Ruinen:** Kosten und Stufen. Quelle: `data/haven/ruins`, `docs/PROLOGUE_AND_HAVEN.md`.
4. **Rezepte:** Rezeptliste der Berufe. Quelle: `data/professions/recipes`, `docs/PROFESSIONS.md`.
5. **Loot:** Loot-Tabellen und Drop-Raten. Quelle: `data/loot`, `docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md`.
6. **Original-Spezifikationen:** `docs/Design/` (nur lesen).
7. **Aktuelles Aussehen:** Screenshots aus `tests/output/gallery/` und `tests/output/ui_art/`. ChatGPT kann ohne Bilder
   keine visuelle Abnahme leisten.
8. **Ergebnis der persönlichen Abnahme (Phase A):** die Befundliste des Entwicklers.
9. **Commit- und Backup-Strategie** für den großen uncommitteten Stand: Entscheidung des Entwicklers.
