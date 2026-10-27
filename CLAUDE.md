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
  Presets referenzieren Instanz-IDs der Tasche (Shared-Item-Policy). Lagertransfers nur über `StashService`
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
