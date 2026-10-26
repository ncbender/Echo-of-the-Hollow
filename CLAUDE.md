# Echoes of the Hollow – Projektregeln

2D-Pixel-Art-Action-RPG, schräge Top-Down-Perspektive. **Godot 4.7.2, ausschließlich GDScript.**
Stand: Combat-Prototyp + RPG-Fundament + Welt/Basis-Loop (Overnight 3) + Combat Polish 0.2 + UI Foundation 0.1
+ Crafting Foundation 0.1 (Resonanzschmieden) + Class Foundation 0.2 (Klassen, Talente, Skills, Prolog).
Roadmap: `docs/DEVELOPMENT_ROADMAP.md`.
Hauptszene: `scenes/maps/home_base.tscn`; Combat-Testarena: `scenes/arena/test_arena.tscn`.

## Werkzeuge
- Godot: `../tools/godot/Godot_v4.7.2-stable_win64_console.exe` (oder `$env:GODOT`)
- Startprüfung (Import + Parse + 300 Frames, Fehler UND Warnungen): `./tools/check_project.ps1`
- Tests gezielt: `./tools/run_tests.ps1 -Suite dash,combo` (Suite = `tests/**/test_<name>.gd`)
- Playtests (Fenster): `-s res://tests/playtest/visual_playtest.gd` (Combat), `rpg_playtest.gd` (RPG),
  `loop_playtest.gd` (Gameplay-Loop), `ui_playtest.gd` (Auflösungen/UI-Skalierung),
  `crafting_playtest.gd` (Forge), `class_playtest.gd` (Klassen-UI; `-- --prologue`: Prolog mit allen drei Klassen)
- Neue `class_name`-Skripte brauchen vorher `--import` (macht `run_tests.ps1` automatisch).

## Feste Regeln
- Combat-Design in `docs/COMBAT_DESIGN.md` ist verbindlich. Timings/Tempo/Balance nicht ohne Playtest
  ändern; Vorschläge dort unter „Vorschläge für den Feel-Test“ sammeln.
- Spieldaten sind Resources unter `data/` mit stabilen `StringName`-IDs. Keine `match`/`if`-Ketten
  für einzelne Waffen, Angriffe, Items oder Klassen.
- Definitionen (Resources) ≠ Laufzeitinstanzen (`Character`, `ItemInstance`, …) ≠ Spielstand (Dict/JSON).
- Knockback ist eine Distanz in px und läuft nur über `KnockbackMotion` (eine Skalierung beim Empfänger).
  Dash geht immer in Blickrichtung (Maus), nie nach WASD.
- Combat ↔ RPG nur über `PlayerProgressionBridge`; Items wirken über `AttackModifier`, nie über
  geänderte `AttackDefinition`-Daten oder eigene Schadenslogik.
- Items existieren nur im `Inventory`; Loadouts referenzieren Instanz-IDs (Shared-Item-Policy).
- Stats immer über `StatResolver` neu berechnen, nie inkrementell addieren.
- Einziges Autoload: `GameSession` (hält den Character über Szenenwechsel). Keine weiteren ohne Begründung.
- Signale langlebiger RefCounted-Objekte: Methoden-Callables statt Lambdas mit `self` (sonst Leck).
- Schemaänderung am Save → `SaveSystem.VERSION` + Migration + `save`-Tests (`docs/SAVE_SYSTEM.md`).
- Tests nutzen nie `user://saves/`, nur `user://test_saves/`.
- UI: Maße nur in Design-Px (1920×1080) über `UiTheme`-Konstanten; Fenster erben von `UiWindow`;
  nie `Control.scale` für UI; Welttexte über `WorldText`. Display-Einstellungen nur in `UserSettings`
  (`user://settings.cfg`, nie im Save). Standard: `docs/DISPLAY_AND_UI_STANDARD.md`.
- Crafting: Item-Beiträge nur über `ItemStats`, Änderungen nur über `CraftingService` (Transaktion,
  Revision); gewürfelte Werte nie neu berechnen; Uniques nur über `CraftingProfile.allowed_operations`;
  Combat-Wirkung nur als `ItemEffect`/`AttackModifier`. Design: `docs/CRAFTING_DESIGN.md`.
- Klassen (`docs/CLASS_DESIGN.md`, `TALENT_SYSTEM.md`, `SKILL_SYSTEM.md`, `CLASS_QUESTS.md`): Talent-/Skill-/
  Preset-/Prolog-/Quest-Regeln nur in `TalentService`, `SkillBook`, `PresetService`, `PrologueService`,
  `QuestService`; Inhalte sind Daten (`data/skills`, `skill_mods`, `talents`, `trials`, `quests`, `status`).
  Skill-Treffer nur über `SkillCast.deliver`, alle Treffer des Charakters über `ItemEffectRunner.dispatch_hit`
  (Quelle/Tiefe in `HitData`). Skills nutzen Player-Hooks (`ability_handler`, `begin_skill`,
  `start_skill_motion`) - nie den Dash. Trials sind temporär (nie speichern, nie freischalten).
  Spielerseitige Texte Englisch; neue UI-Chrome-Texte über `localization/ui.csv` (`tr("UI_...")`).
- Neue Maps erben von `GameMap`, brauchen `Player`, `GameHud`, `SpawnPoint` "default" und eine `MapDefinition`.
  Übergänge nur über `SessionState.travel()`. Weltzustand nur in `WorldState`.

## Tests (selektiv, siehe `docs/TEST_STRATEGY.md`)
- Nur Suites des geänderten Systems + direkte Abhängigkeiten. Grüne, unveränderte Suites nicht wiederholen.
- Nie behaupten, ein Test/Playtest sei gelaufen, wenn er nicht lief. Ergebnisse in den Overnight-Reports.

## Git
- Arbeitsbranch der jeweiligen Sitzung (zuletzt `dev/class-foundation`); kleine Commits pro Phase. Kein Push, kein Force.
