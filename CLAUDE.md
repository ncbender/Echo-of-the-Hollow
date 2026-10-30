# Echoes of the Hollow – Projektregeln

2D-Pixel-Art-Action-RPG, schräge Top-Down-Perspektive. **Godot 4.7.2, ausschließlich GDScript.**
Stand: Combat-Prototyp + RPG-Fundament + Welt/Basis-Loop (Overnight 3) + Combat Polish 0.2 + UI Foundation 0.1
+ Crafting Foundation 0.1 (Resonanzschmieden) + Class Foundation 0.2 (Klassen, Talente, Skills, Prolog)
+ Klassen/Combat 0.3–0.4 + Prologue & Haven Vertical Slice 0.1 (Save 1.1, Story-Prolog, Haven, Wegsteine)
+ UI/UX Redesign 1.0 (Designsystem „The Forgotten Chronicle“, neues HUD) + UI/UX Polish 1.1 + Talent UI Polish 1.2
+ Inventory & Haven Stash 1.0 (Haven-Lager, Save v6) + Professions Foundation 1.0 (neun Berufe, Artisan Quarter, Save v7)
+ Overnight Artisan Crafting 01 (Werkstätten Ruined/Restored/Revitalized, Hollowwood-Sammeln, Restaurierung aus dem Lager).
+ Overnight Systems 02 (Item Integrity + Salvaging, Hearth Flask + Tränke, Armor Mastery, Loot-Economy-Grundlage; Save v10).
+ Combat Rework / Weapon Mastery 1.4–1.5 (Combat Flow für Spielerwaffen, neun Familien, Pfad-Mastery, ein Waffen-Slot; Save v10).
+ Gathering Rework 1.1 (Sammeln in Schritten mit gehaltenem G, feste Budgets, Teilzustand im Save).
+ Pre-Alpha Item Foundation 1.0 (max. 5 reguläre Affixe, Affix-Kategorien, Fünf-Tier-Modell, Local/Global, Quality 0,5 %; Save v11).
+ Weapon Base Damage 1.0–1.2 (Instanz-Basis bei Erzeugung, Angriffsmultiplikatoren, Forged V3, Spezialwaffen V2, Local-Affixe; Save v13).
+ Loot Foundation 1.0 (Instanz-Rarity, Fünf-Tier-Affixe, gemeinsamer Affix-Kern `AffixRoller`, `ItemCreation.generate`; Save v14).
+ Hollowwood Loot Integration 1.0 (Grunt-/Wolf-Equipment-Drops über `EquipmentLootTable`/`EquipmentLoot`, Instanz-Pickups).
+ Region 1 World Expansion A 1.0 (große Whisper Forest/Tangled Wood, `GameMap.camera_bounds`; `docs/WORLD_EXPANSION_A_1_0.md`)
  + World Expansion B 1.0 (große Chapel/Warden's Rest; `docs/WORLD_EXPANSION_B_1_0.md`)
  + Side Quests 1.0 (The Lost Hunter, What the Roots Keep, Embers of Shelter; `docs/SIDE_QUESTS_1_0.md`).
  Nebenquests starten nur über `StoryQuestDefinition.start_event_id` (nie Schritt 0, nie in `next_quest_ids`);
  `ProfessionService.craft` meldet nach Erfolg `craft:<recipe_id>`.
  + Gameplay Polish 1.0 (kompakter Tracker für Nebenquests, Roots-Keep-Hinweise, drei optionale Funde;
  `docs/GAMEPLAY_POLISH_1_0.md`).
  + UI Layout Lock 1.0 / UI-Paket 1 (HUD-Zonen, eine Icon-Menüleiste I C T P J M O, Kampfleiste 1 2 | Q E R F,
  Minimap-Platzhalter; `docs/UI_LAYOUT_LOCK_1_0.md`). Gehaltene Maus-Angriffe zählen nur vom Spielfeld aus.
  + Map & Fog of War 1.0 / UI-Paket 2 (Minimap, Karte M mit Area/Region, Fog pro Karte in
  `WorldState.map_states[map]["fog"]`, Save v15 unverändert; `docs/MAP_AND_FOG_OF_WAR_1_0.md`). Aufdecken nur
  über `GameMap._update_fog` (echte Bewegung), Marker nur über `MapMarkers` (nur erkundete Zellen, nie Gegner/Loot).
  + UI Window Foundation 1.0 / UI-Paket 3 (Journal: Main Story/Side/Class/Completed/Haven, Einteilung nur über
  `StoryService.is_main_story` = Kette ab FIRST_QUEST; HUD tritt hinter Fenstern zurück; optionale UI-Art nur über
  `UiSkin` (`res://assets/ui/<id>.png`, sonst prozeduraler Fallback); `docs/UI_WINDOW_FOUNDATION_1_0.md`,
  Asset-Liste `docs/UI_ASSET_CATALOG_1_0.md`).
  + HUD EXP Bar 1.0 (genau ein `HudXpBar` 426 × 14, 6 px unter der Kampfleiste in `GameHud._combat_column`;
  nur Prozent der aktiven Klasse bzw. „MAX“, Daten nur aus `CharacterClasses`; `docs/HUD_EXP_BAR_1_0.md`).
  + UI Font Integration 1.0: genau zwei Schriften - IBM Plex Mono (`UiTheme.body_font()`, alle Texte, auch
  Zeichen-Code statt `ThemeDB.fallback_font`) und Silkscreen (`UiTheme.display_font()`, nur Titel/Überschriften,
  8-px-Raster); `docs/UI_FONT_INTEGRATION_1_0.md`.
  + UI Visual Consistency 1.0: neutrale UiTheme-Flächen nach den Art-Ankern (Charcoal/Slate, kein Grünstich),
  ein Theme für alles; semantische Farben unverändert; `docs/UI_VISUAL_CONSISTENCY_1_0.md`.
  + UI Core States & Map Palette 1.0 (Button-/Slot-/Tab-Zustände, HUD-Slot disabled, neutrale Karten-
  töne FLOOR/WALL = zugleich `is_solid`-Klassen, Abstand > 0,01 halten; `docs/UI_CORE_STATES_1_0.md`).
  + UI Panels & Primary Controls 1.0 (Primary-Buttons inkl. Disabled-Hook, HUD-/Card-/Inset-/Tooltip-Panels;
  `docs/UI_PANELS_PRIMARY_1_0.md`).
  + UI Selection & Surface Polish 1.0 (Auswahl = Gold über Card-Art auch für `CardButton`, Fokus bleibt eigene
  Resonanz-Kontur; harter Pixel-Schatten außerhalb skinned Fenster über `UiTheme.draw_hard_shadow`;
  `docs/UI_SELECTION_POLISH_1_0.md`).
  + UI Scrollbars & Input Fields 1.0 (`scroll/track`, `scroll/grabber` 10 × 10, Rand 3, diagonal-symmetrisch für H und V;
  `input/normal|focus|disabled` 24 × 24, Rand 4 → LineEdit normal/focus/read_only; Fokus = Resonanz, nie Gold;
  35 PNGs, alte byte-identisch; `docs/UI_SCROLL_INPUT_1_0.md`).
  + UI Secondary Controls 1.0 (Dropdown-Pfeil/-Radio, Check-Icons, Slider-Füllung/-Griff, Key-Chip; Theme-Icons nur
  über `UiTheme.SKINNED_ICONS`; Gold = an/gewählt, Cyan = Fokus; 48 PNGs; `docs/UI_SECONDARY_CONTROLS_1_0.md`).
  + Main Window Layout Lock 1.0 (die sieben Hauptmenüs I C T P J M O: ein Rahmen `UiTheme.MAIN_WINDOW_SIZE` 1120 × 760,
  gleiche Position über `UiWindow.main_window`, Inhalte über `body_room()`; innere Scrollbereiche;
  `docs/MAIN_WINDOW_LAYOUT_LOCK_1_0.md`).
  + BookTabs Visual Integration 1.0 (`booktab/normal|hover|selected` 24 × 24, Rand 4, rechts offen; Auswahl Gold,
  Fokus Cyan außen; alle inaktiven Register 112 px; 51 PNGs; `docs/BOOKTABS_VISUAL_INTEGRATION_1_0.md`).
  + HUD Bars Visual Integration 1.0 (alle Leisten: `bar/frame` + Tönungsmaske `bar/fill` ohne Seitenränder, Farbe per
  `UiTheme.fill_box`, Füllung 1 px eingerückt; `UiSkin.PATCH` darf `Vector4i` sein; 53 PNGs;
  `docs/HUD_BARS_VISUAL_INTEGRATION_1_0.md`).
  + HUD Resource Text Readability 1.0 (Ressourcenwert = `SplitBarText`: dunkel über heller Füllung (< 3:1), hell über
  der Rinne, pixelgenau an der Füllkante geteilt; Resource Bar Height Final Fix 1.0: Leiste 14 px, Text 12 px,
  Glyphen in der Rinne, nur die Kontur unter Unterlängen auf der Rahmenzeile (16 px nötig);
  `docs/HUD_RESOURCE_TEXT_READABILITY_1_0.md`).
  + Map Markers Pixel Art 1.0 (`map/player|exit|waystone|waystone_silent|rest|npc|landmark|quest` 16 × 16, 1:1 über
  `MapPainter.marker_rect` im Bild, Spielerpfeil in 90°-Schritten; Sichtbarkeit nur `MapMarkers`; 61 PNGs;
  `docs/MAP_MARKERS_PIXEL_ART_1_0.md`).
  + Skill Icons Pixel Art 1.0 (`skills/<skill id>` 40 × 40 für alle 21 aktiven Skills der spielbaren Klassen,
  1:1 in Kampfleiste und Klassenstation über `UiTheme.skill_icon`; Validator gleicht die IDs mit `data/` ab; 82 PNGs;
  `docs/SKILL_ICONS_PIXEL_ART_1_0.md`).
  + Skills & Talents UX 2.0 Phase 1 - Weapons (nur die Familie der Hauptwaffe, Combo-Raster + Details; Icons
  `combos/<Form>_<Folge>[_<Effekt>]` nur über `ComboIcons` aus den Daten; Auswahl ändert nie Kampf/Eingaben; 126 PNGs;
  `docs/SKILLS_TALENTS_UX_2_0.md`). Phase 2 - Talents: drei Baum-Buttons (Name · Punkte), ein Baum, fester
  Detailbereich; Klick wählt nur, Lernen nur über `LearnTalent` (`TalentService.learn`); Linien nur für echte
  Voraussetzungen; Skill-Art nur bei Aktiv-Talenten. Phase 3 - Skills: Q/E/R/F-Leiste oben, kompakte Liste,
  Details mit fester Equip-Zeile (Equip / Replace / Swap über `SkillBook.assign_slot`) und Mods nur des gewählten
  Skills; Auswahl rüstet nie aus. Phase 4 - Presets: fünf kompakte Zeilen (Save/Overwrite), Name/Rename/Delete des
  gewählten, Build-Details (Punkte je Baum, Q/E/R/F + Mods, Item-Referenzen mit Zustand) mit Activate-Fuß; alles über
  das unveränderte `PresetService`. Phase 5 - Quests: Klassen-Freischaltquests (charakterweit) als kompakte Liste mit
  echtem Status (Locked/Available/Active/Ready to Turn In/Completed/Class unlocked), Details mit Zielen, Lieferungen,
  Anforderungen, Belohnung und einer Aktion (Take quest / Turn in über `QuestService`). Phase 6 - Classes: kompakte
  Karten (ACTIVE/UNLOCKED/LOCKED, Level, Tagline), Details mit Ressource, Spielstil, Spezialisierungen, Gear bzw.
  Freischaltung; Karte wählt nur, „Switch to <Klasse>“ nur wenn `Character.class_switch_error` (= Prüfungen von
  `switch_class`) leer ist, sonst der Grund; die Startklasse nur solange sie aktiv ist. Phase 7 - Armor: Burden
  oben (Werte aus `ArmorMasteryService`/`ArmorMasteryRules`), 2×2 Mastery-Karten (WORN n% getrennt von Gold-Auswahl),
  Details mit Meilensteinen; nur Anzeige. Alle sieben Tabs umgesetzt.
  + UI Usability & Haven Crafting 1.0 (Balkenzahlen nur über `BarText` - auf die Ziffern zentriert, passend
  verkleinert; Tab-Fenster mit fester Außengröße über `UiWindow.stable_size`; Berufe: begrenzte Rezeptliste mit
  Suche, Mausrad nur über der Liste; an jeder Haven-Werkbank und der Schmiede immer Tasche + Lager (Tasche zuerst,
  ein Materialplan, atomar), außerhalb nie; Save v15 unverändert; `docs/UI_USABILITY_HAVEN_CRAFTING_1_0.md`).
  + Talent Structure Rework 1.0 (4 Tiers je Baum: Tier 1–3 je vier frei wählbare Talente, Tier 4 Endtalent; Schwellen
  0 / 5 / 18 / 30 Punkte in niedrigeren Tiers desselben Baums; Prereqs nur für direkte Skill-Upgrades; alte Verteilungen
  bleiben gültig, Save v15 unverändert; `docs/TALENT_STRUCTURE_REWORK_1_0.md`).
  + Menu UX Polish 1.0 Batch 1 (Inventar ohne Hilfetext/Slot-Itemnamen - Name nur im Tooltip; Talents: Baum volle
  Breite + kompakte Aktionszeile `TalentDetail`, Effekte nur im Tooltip, Blockiergrund `TalentTooltip.block_reason`;
  dichte Menütexte nur über `MenuHeading/Title/Text/MetaLabel` (16/18/15/14), globale Größen unverändert; Professions-
  Seiten als Tabs in der Titelzeile über `UiWindow.set_title_tabs`; Journal-Close ohne Tastenhinweis; Hauptmenüs:
  Korn `window/backdrop` + ruhige gravierte Seite `window/page` über `UiWindow._draw_main_ground`; 128 PNGs;
  `docs/MENU_UX_POLISH_1_0.md`).
  + Combat HUD UX 2.0 Batch 2 (ersetzt den PlayerFrame oben links: `HudVessel` HP links / Klassenressource rechts der
  Kampfleiste, 52 × 66, Zahl innen, Name/Max im Tooltip, ohne Ressource leer + Tooltip; Level/Pressure als `HudBadge`
  in der EXP-Zeile; Slots ohne Dauertexte, Flask/Trank als Flüssigkeitsstand (Flask = Ladungen/Max, Trank = Viertel
  eines `max_stack`); Dash-Segmente unter dem Helden (`HudDashMeter`, nur während Aufladung); Klassen-Buffs in der
  `EffectBar`; Menüleiste 34 px; Journey-Tracker mit Titel + Ziel aus `StoryService.tracker_entries`/`short_goal`,
  optional `StoryStep.hud_goal`; Art nur über `HudFillArt`; 136 PNGs; `docs/COMBAT_HUD_UX_2_0.md`).
  + Menu UX Polish 1.1 (gemeinsame Außenreiter `BookTabs` hinter dem Rahmen, gewählter verbindet zur Seite; Professions:
  Bereiche außen, Berufe als Titelzeilen-Tabs, Salvage nur `SalvageService.SALVAGE_PROFESSIONS`, Werkstatt + Grund nur
  in der Aktionszone; Hilfe nur über `HelpButton` (Hover + Fokus); Talent-Zustand „Open“ = Voraussetzungen erfüllt,
  kein Punkt (`TalentTreeView.node_state`); Equip/Replace/Swap/Move/Equipped nach `assign_slot`; Journal-Liste nur
  Titel + Status, frühere Kapitel eingeklappt; Inventar-Details gruppiert + „Only active bonuses“; `docs/MENU_UX_POLISH_1_1.md`).
  + Loot & Progress Feedback 1.0 (ein Loot-Feed `LootFeed` für Items, Gold, Berufs-XP – nur nach echter Vergabe über
  `bridge.item_received` / `bridge.profession_xp`, gebündelt, max. 5 Zeilen + Warteschlange; Level-ups nur über
  `bridge.progress` → `ProgressNotice` + `LevelUpFx`, zusammengefasst, Hero vor Mastery; keine Gathering-Schrittzähler,
  keine Parry-Texte im HUD; `docs/LOOT_PROGRESS_FEEDBACK_1_0.md`).
  + Combat Telegraphs 1.0 (Flags nur über `AttackDefinition.is_parryable/is_blockable/breaks_guard/block_holds/
  telegraph_kind` – auch in `DefenseComponent.resolve`; `EnemyView` zeigt im Startup Kegel + ein Symbol: Kreuzfunke =
  parierbar, Schild = nur blockbar, roter gebrochener Ring = weder noch; kein Blinken, kein „!!“/„PARRY“-Text;
  `docs/COMBAT_TELEGRAPHS_1_0.md`).
  + Map UX 2.0 (Karte M: Area im ganzzahligen Maßstab, beim Öffnen auf den Spieler zentriert, Ziehen/Pfeiltasten/
  Zentrierknopf über `WorldMapPanel.PanCanvas`; Region als kompaktes Ortsnetz mit Waystone-Zustand am Knoten und
  Detailzone; Reisen nur über „Travel“ an einem wachen Waystone, gemeinsam mit `WaystonePanel.start_travel`;
  `docs/MAP_UX_2_0.md`).
  + Playtest Corrections 1.0 (Gesamtstand vom Entwickler abgenommen; Inventar-Details nur Wirksames, immer Max Health/
  Armor (`InventoryPanel.shows_stat`); Hauptmenüs ohne Close-Button – `UiWindow.main_window` blendet ihn aus, andere
  Fenster behalten ihn; Talent-Tooltips im Fenster (`TalentTooltip.bounds_rect`); `docs/PLAYTEST_CORRECTIONS_1_0.md`).
  + Parry Timing Cue 1.0 (ersetzt die Telegraph-Symbole: nur Elites/Bosse (`EnemyConfig.rank`) mit parierbarem Angriff
  zeigen einen kurzen Kreuzblitz REACTION + Fenster/2 vor dem Treffer – `ParryCue`, `EnemyView`; Kegel und rote Fläche
  bleiben; `docs/PARRY_TIMING_CUE_1_0.md`).
Roadmap: `docs/DEVELOPMENT_ROADMAP.md`.
Hauptszene: `scenes/ui/title_screen.tscn` (New Game → `old_road`); Haven: `scenes/maps/home_base.tscn`;
Combat-Testarena: `scenes/arena/test_arena.tscn`.

## Werkzeuge
- Godot: `../tools/godot/Godot_v4.7.2-stable_win64_console.exe` (oder `$env:GODOT`)
- Startprüfung (Import + Parse + 300 Frames, Fehler UND Warnungen): `./tools/check_project.ps1`
- Tests gezielt: `./tools/run_tests.ps1 -Suite dash,combo` (Suite = `tests/**/test_<name>.gd`)
- Playtests (Fenster): `-s res://tests/playtest/visual_playtest.gd` (Combat), `rpg_playtest.gd` (RPG),
  `loop_playtest.gd` (Gameplay-Loop), `ui_playtest.gd` (Auflösungen/UI-Skalierung),
  `prologue_playtest.gd` (kompletter Prolog ab Titel, `--fixed-fps 60`),
  `class_playtest.gd` (Klassen-UI; `-- --prologue`: Prolog mit allen drei Klassen), `prologue_playtest.gd`
  (`--fixed-fps 60`), `ui_gallery.gd` (alle Bildschirme, `-- --res=... --scale=... --only=...`).
  `stash_playtest.gd` (Haven-Lager, echte Maus, 720p/1080p/4K × 100/125/150 %).
  `loop_playtest.gd`/`crafting_playtest.gd` erreichen die Schmiede über die Ruine Old Smithy.
- Neue `class_name`-Skripte brauchen vorher `--import` (macht `run_tests.ps1` automatisch).

## Feste Regeln
- Combat-Design in `docs/COMBAT_DESIGN.md` ist verbindlich. Timings/Tempo/Balance nicht ohne Playtest
  ändern; Vorschläge dort unter „Vorschläge für den Feel-Test“ sammeln.
- Combat Flow 1.5 / Weapon Mastery 1.4 (`docs/WEAPON_MASTERY_COMBAT_FLOW.md`, Spezifikation `docs/Design/`): Spielerwaffen
  sind Combo-Pfad-Bäume (`AttackDefinition.combo_input`, `WeaponFamily.combo_paths`), Familien nur über
  `tools/generate_weapon_families.gd` erzeugen. Eingaben/Fenster/Puffer nur im Flow-Modus von `CombatComponent`
  (Werte `CombatFlowRules`); Gegner nutzen den Legacy-Baum. Mastery schaltet nur Pfade frei (nie Stats), XP nur
  beim Kill nach Beitrag (`CombatRewardTracker`). Genau ein Waffen-Slot, kein Quick-Swap; Skills/Tränke nur neutral;
  Dash/Parry/Block vor dem Cancel-Fenster ablehnen, nie speichern. „Voll aufgeladen“ = `HitData.is_full_power`.
- Spieldaten sind Resources unter `data/` mit stabilen `StringName`-IDs. Keine `match`/`if`-Ketten
  für einzelne Waffen, Angriffe, Items oder Klassen.
- Definitionen (Resources) ≠ Laufzeitinstanzen (`Character`, `ItemInstance`, …) ≠ Spielstand (Dict/JSON).
- Knockback ist eine Distanz in px und läuft nur über `KnockbackMotion` (eine Skalierung beim Empfänger).
  Dash: mit WASD in Bewegungsrichtung, ohne WASD in Blickrichtung (Maus) - nur über `DashComponent.direction_for`.
- Combat ↔ RPG nur über `PlayerProgressionBridge`; Items wirken über `AttackModifier`, nie über
  geänderte `AttackDefinition`-Daten oder eigene Schadenslogik.
- Items existieren nur in einem besitzenden `Inventory` (Tasche oder Haven-Lager `Character.stash`); Loadouts und
  Presets referenzieren Instanz-IDs der Tasche (Shared-Item-Policy). Equipment Inventory Separation 1.0: Items im
  Loadout der aktiven Klasse liegen im Slot und belegen keinen Taschenplatz (`Inventory.takes_slot`); Anlegen/
  Ablegen/Presets/Klassenwechsel lehnen ohne Platz atomar ab (`docs/EQUIPMENT_SYSTEM.md`). Preset-Aktivierung ist
  alles oder nichts: `PresetService.validate` prüft vorab auch den Loadout-Wechsel (`CharacterEquipment.loadout_error`,
  Tasche im Zielzustand), `activate` übernimmt nur Talente/Slots/Mods (Respec-Zähler, Freischaltungen bleiben). Lagertransfers nur über `StashService`
  (atomar, Kategorien sind Ansichten; `docs/STASH.md`).
- Stats immer über `StatResolver` neu berechnen, nie inkrementell addieren.
- Einziges Autoload: `GameSession` (hält den Character über Szenenwechsel). Keine weiteren ohne Begründung.
- Signale langlebiger RefCounted-Objekte: Methoden-Callables statt Lambdas mit `self` (sonst Leck).
- Schemaänderung am Save → `SaveSystem.VERSION` + Migration + `save`-Tests (`docs/SAVE_SYSTEM.md`).
- Tests nutzen nie `user://saves/`, nur `user://test_saves/`.
- UI: Maße nur in Design-Px (1920×1080) über `UiTheme`-Konstanten; Fenster erben von `UiWindow`;
  nie `Control.scale` für UI; Welttexte über `WorldText`. Display-Einstellungen nur in `UserSettings`
  (`user://settings.cfg`, nie im Save). Standard: `docs/DISPLAY_AND_UI_STANDARD.md`.
  Farben/Schriften/Komponenten nur aus `UiTheme` (Designsystem: `docs/UI_DESIGN_SYSTEM.md`); Item-Texte nur
  über `ItemDescriber`; Bestätigungen nur über `UiConfirmDialog`; neue Bildschirme in `GalleryScreens` eintragen.
  Primäre Aktion eines scrollenden Fensters (Craft, Restore) in `UiWindow.footer` (scrollt nie weg).
  Inventar: Hover = `ItemTooltip`, Rechtsklick = `CharacterEquipment.quick_slot`, keine Aktions-/Discard-Knöpfe;
  Währung (`is_currency`) ist ein Zähler, kein Taschenplatz.
- Crafting: Item-Beiträge nur über `ItemStats`, Änderungen nur über `CraftingService` (Transaktion,
  Revision); gewürfelte Werte nie neu berechnen; Uniques nur über `CraftingProfile.allowed_operations`;
  Combat-Wirkung nur als `ItemEffect`/`AttackModifier`. Design: `docs/CRAFTING_DESIGN.md`.
  Weapon Base Damage 1.0–1.2 (`docs/WEAPON_BASE_DAMAGE_1_2.md`): neue Instanzen nur über `ItemCreation` (Item-Level
  explizit oder freigegebene Quelle, Waffenbasis einmalig gespeichert, nie neu berechnet); Waffenschaden nur über `WeaponDamage` (D_weapon) ×
  `AttackDefinition.weapon_damage_multiplier` (Generator); Waffen ohne `base_weapon_damage` = Familienreferenz (Kompatibilität);
  LOCAL-Affixe nie in `StatResolver`; Quality bei Modellwaffen nur auf die Basis.
  Item Foundation 1.0 (`docs/ITEM_FOUNDATION_1_0.md`): max. `CraftingProfile.MAX_AFFIX_SLOTS` (5) reguläre Affixe, Essenzen
  getrennt (max. 2); Tier-Schwellen nur aus `AffixTiers`, Tier-Nummern nur im eigenen `tier_model` lesen (`tier_of`);
  Ringe/Amulette nur GLOBAL; Quality nur über `ItemStats.quality_factor`.
  Loot Foundation 1.0 (`docs/LOOT_FOUNDATION_1_0.md`): Rarity gehört der Instanz (`ItemInstance.rarity`, Anzeige über
  `effective_rarity`); Affix-Eligibility und -Rolls nur über `AffixRoller` (Identität, Tier, Wert getrennt); Tier-Gewichte nur als
  explizite `AffixTierWeights`-Eingabe, nie Standardverteilung; neue Loot-Items nur über `ItemCreation.generate`.
  Equipment-Drops nur über `EquipmentLoot.roll` mit einer `EquipmentLootTable` (`docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md`):
  ein Wurf pro Ereignis, erzeugte Instanz unverändert über `GameMap.spawn_item_pickup` / `ItemPickup.item`.
  Kapitel-1-Rare (`docs/CHAPTER_1_RARE_REWARD_1_0.md`): nur Sentinel's Cache in Warden's Rest (`BossRewardService`);
  Warden's Cache = einmalige Materialien. `boss_reward.whisper_forest_grove_warden` ist eingefrorener Legacy-Beleg
  (nie mehr setzen) und schließt beide Caches (`BossRewardCache.taken_flags`).
- Klassen (`docs/CLASS_DESIGN.md`, `TALENT_SYSTEM.md`, `SKILL_SYSTEM.md`, `CLASS_QUESTS.md`): Talent-/Skill-/
  Preset-/Prolog-/Quest-Regeln nur in `TalentService`, `SkillBook`, `PresetService`, `PrologueService`,
  `QuestService`; Inhalte sind Daten (`data/skills`, `skill_mods`, `talents`, `trials`, `quests`, `status`).
  Skill-Treffer nur über `SkillCast.deliver`, alle Treffer des Charakters über `ItemEffectRunner.dispatch_hit`
  (Quelle/Tiefe in `HitData`). Skills nutzen Player-Hooks (`ability_handler`, `begin_skill`,
  `start_skill_motion`) - nie den Dash. Freie Skill-Bewegung nur als kurze Angriffs-Lunge (`MoveAction`, ≤ 40 px);
  längere Bewegung nur zielgebunden (`GapCloserAction`, Prüfung vor Kosten). Trials sind temporär.
  Block/Parry nur über `DefenseComponent` + `DefenseProfile` (Auflösung in `Hurtbox.hit_filter`, Angriffs-
  `defense_flags`). Visuelles Feedback nur über `CombatFx`/`SkillFxSpec`, Sounds nur über `CombatAudio.play` (keine
  Gameplay-Logik in Effekten).
  Spielerseitige Texte Englisch; neue UI-Chrome-Texte über `localization/ui.csv` (`tr("UI_...")`).
- Neue Maps erben von `GameMap`, brauchen `Player`, `GameHud`, `SpawnPoint` "default" und eine `MapDefinition`.
  Übergänge nur über `SessionState.travel()`. Weltzustand nur in `WorldState`.
- Story: Fortschritt nur über `StoryService.notify(event)`; Quests, Dialoge, NPCs, Ruinen, Wegsteine sind
  Daten (`data/story`, `data/npcs`, `data/haven/ruins`, `data/world/waystones`); Platzierung/Sichtbarkeit
  über `StoryCondition`, nie über questspezifischen Code. Haven hat feste Ruinen (`RestorationService`,
  atomar), keine freien Bauplätze. Stufenwechsel nur über `RestorationService.advance` mit Zielstufe
  (Kosten über denselben Materialplan wie die Werkbänke); Werkstätten öffnen zuerst die Werkbank.
  Design: `docs/PROLOGUE_AND_HAVEN.md`.
- Berufe (`docs/PROFESSIONS.md`): Regeln nur in `ProfessionService` (Lernen, XP, Herstellen als Transaktion mit  einem Materialplan für Zählen und Verbrauchen), Zustand in `Character.professions`; Berufe, Rezepte, Sammelknoten  sind Daten (`data/professions`, `data/world/resource_nodes`); Werkbänke sind Haven-Ruinen mit `profession_id`.
- Sammeln (`docs/GATHERING.md`): nur in Schritten über `ResourceGathering.complete_step` (eine Transaktion pro Schritt,
  Plan pro Zyklus fest, nie neu würfeln); Start nur auf der G-Druck-Flanke über `Player.begin_gather`, Halten über
  `InputFrame.interact_held`, Unterbrechungen nur in `Player`. Werkzeuge sind reine Optik (kein Item/Slot).
- Item Integrity (`docs/ITEM_SYSTEM.md`): Favorit/Sperre/Herkunft nur über `ItemProtection` (nur Einzelitems);
  Herkunft beim Entstehen setzen (`Inventory.add_item(..., origin)`), nie raten. Zerstören/Verkaufen nur nach
  `ItemProtection.destroy_block`. Salvaging nur über `SalvageService` (Werkbank des Herstellungsrezepts, atomar,
  keine XP); Verkaufswerte nur über `EconomyService` (`docs/ECONOMY.md`, Basiswerte noch offen).
- Hearth Flask & Tränke (`docs/CONSUMABLES.md`): Regeln nur in `ConsumableService`, Zustand `Character.consumables`;
  Trinken nur über `Player.begin_use` (Wirkung erst bei Abschluss); Trankwirkungen sind `PotionEffectDefinition`-Daten;
  Tasten 1/2 als Laufzeitaktionen. HUD-Effektleiste nur Anzeige.
- Armor Mastery (`docs/ARMOR_MASTERY.md`): Regeln nur in `ArmorMasteryService`, Werte in `ArmorMasteryRules`;
  Burden wirkt nur über `Player.move_speed_multiplier` und `CombatComponent.recovery_multiplier` - nie Dash/Parry.
- Saves nur über `SaveCoordinator` (manuell/periodisch/Meilenstein); Meilensteine nie unterdrücken,
  Erfolg erst nach erfolgreichem Schreiben anzeigen. Tod/Respawn speichert nie.

## Tests (selektiv, siehe `docs/TEST_STRATEGY.md`)
- Nur Suites des geänderten Systems + direkte Abhängigkeiten. Grüne, unveränderte Suites nicht wiederholen.
- Nie behaupten, ein Test/Playtest sei gelaufen, wenn er nicht lief. Ergebnisse in den Overnight-Reports.

## Git
- Arbeitsbranch der jeweiligen Sitzung (zuletzt `dev/class-foundation`); kleine Commits pro Phase. Kein Push, kein Force.
