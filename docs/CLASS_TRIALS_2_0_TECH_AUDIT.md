# Class Trials 2.0 – Technical Architecture Audit

Stand: 2026-10-28 · Branch `audit/class-trials-20` (von `audit/loot-quest-architecture-10`, `b1b2069`) · Save v14
**Nur Audit, keine Implementierung.** Keine Tests, Playtests oder echten Saves ausgeführt.
Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) unangetastet.

Bezug: `docs/CLASS_QUESTS.md`, `docs/PROLOGUE_AND_HAVEN.md`, `docs/SAVE_SYSTEM.md`,
`docs/LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` (§A Klassen-Magic-Waffe, §B Altar-Marker).

---

## 0. Kurzfazit

| Thema | Befund |
|---|---|
| Trial-Kern wiederverwendbar? | **Ja.** `PrologueService.begin_trial/end_trial/record` + die drei temporären Schichten (`CharacterClasses.trial_class_id`, `ClassBuilds._trial`, `CharacterEquipment._trial_loadout`) liegen am `Character` in der Session und überleben einen Szenenwechsel bereits heute. Nichts davon wird gespeichert. |
| Was ersetzt wird | `TrialStation` (Pedestal + unendliche Wellen), die drei Pedestale in `whispering_stone.tscn`, die Regel „alle drei Trials“ in `can_choose`, Story-Schritt „3× trial_complete“. |
| Zentraler Altar | `ClassChoiceStation` „Heart of the Stone“ + `ClassChoicePanel` (drei Karten, 2-Klick-Wahl, Meilenstein-Save) sind genau die richtige Stelle; Karten bekommen einen zweiten Knopf „Walk the echo“. „?“-Marker = `ClassChoiceStation._draw`. |
| Separate Karten | Technisch einfach (neue `GameMap`-Szenen + `MapDefinition`, `trial_map_ids`). **Hauptrisiko ist der Save-Ort**: ein Save im Trial-Map (periodisch oder kritisch durch den Story-Schritt beim ersten Trial-Abschluss) lädt später **ohne** Trial in die Trial-Karte. Lösbar mit einer generischen Regel „Trial-Karte wird nie gespeicherter Ort“. |
| Temporäre Klasse | **Sicher** für Klasse, Level, Talente, Skills, Ressource, Loadout, Stats. **Nicht** temporär: Inventar (Pickups, Gold), Hearth-Flask-Ladungen, Weapon-/Armor-Mastery-XP, Item-Evolution-XP, Story-Zähler. Kein Rollback empfohlen – stattdessen Quellen auf Trial-Karten abschalten. |
| Waffen für Trials | Nicht nötig: keine Klasse schränkt Waffenfamilien ein, Skills haben keine Waffenbedingung. Temporäre Waffen-Items wären ein Regelbruch (Items nur im besitzenden Inventar) → **nicht** empfohlen. |
| Mini-Bosse | Es gibt **genau eine** Gegner-KI (Nahkampf: Jagen → Telegraph → Angriff, `scripts/enemies/enemy.gd`) und 6 Varianten. Warrior: `hardened_husk` passt direkt. Shadowrunner: `hollowfang_wolf`-Rudel passt mit Kompromiss. Arcanist: **kein Fernkampfgegner** vorhanden → bester Ersatz Grove Warden (nicht block-/parierbarer Slam) + Wölfe. Echter Distanzdruck = neue KI = Blocker. |
| Assets | **Keine Tilesets, keine Sprites.** Alle Karten bestehen aus prozedural gezeichneten `ArenaFloor`- und `WallBlock`-Knoten; Gegner über `EnemyView`. „Bastion/Sanctum/Passage“ lassen sich nur über Farben, Wandanordnung und Requisiten (Steine, Bäume, Lagerfeuer, Readables) unterscheiden. |
| Save-Migration | Schema bleibt unverändert (`prologue.completed_trials` mit denselben IDs genügt). Offen ist nur ein **Nachziehen** des Story-Schritts für Altstände mit 1–2 Trials (siehe §E.4). |

---

## A – Bisherige Trials

### A.1 IDs, Trigger, Daten

| Trial-ID | Klasse | Datei | Level | Skills (Q/E/R/F) | Talente | Gegner (`enemy_configs`) |
|---|---|---|---|---|---|---|
| `trial_warrior` | warrior | `data/trials/trial_warrior.tres` | 12 (Default `trial_definition.gd:12`) | furious_strike, battle_cry, blade_rush, warbreaker | war_b_seething 2, war_wb_hands 1 | rootbound_husk ×2, hardened_husk |
| `trial_arcanist` | arcanist | `data/trials/trial_arcanist.tres` | 12 | arcane_bolt, mana_pulse, frostbind, rune_sigil | arc_ew_frostbite 1, arc_rm_inscribed 2 | rootbound_husk ×3 |
| `trial_shadowrunner` | shadowrunner | `data/trials/trial_shadowrunner.tres` | 12 | shadow_strike, expose_weakness, shadowstep, execution | sr_as_eye 1, sr_as_precision 2 | hollowfang_wolf, rootbound_husk, hollowfang_wolf |

Trigger / Orte:
- **Whispering Stone** (Story-Ort): Pedestale `TrialWarrior`, `TrialArcanist`, `TrialShadowrunner` mit je drei `Spawns/*`-Markern
  (`scenes/maps/whispering_stone.tscn:214-272`), Skript `scripts/world/trial_station.gd`.
- **Prologue Grounds** (Dev-Karte, `show_on_map = false`, `data/world/maps/prologue.tres`): dieselben drei Pedestale
  (`scenes/maps/prologue.tscn:76, 96, 116`) + Trainingsdummies. Wird von `class_playtest.gd` und `test_prologue.gd` benutzt.
- Erlaubte Trial-Karten: `ProgressionRules.trial_map_ids = [whispering_stone, prologue]`
  (`scripts/rpg/progression/progression_rules.gd:36`); jede andere Karte beendet einen laufenden Trial in
  `GameMap._ready` (`scripts/world/game_map.gd:60-61`).
- Validierung: `GameDatabase` prüft Klasse ∈ `prologue_class_ids`, Skills der Klasse, Talent-Allokation
  (`scripts/rpg/game_database.gd:367-374`).

### A.2 Abschlussbedingungen (IST)

| Trial | Ziele (`TrialObjective`, ungeordnet, gleichzeitig gezählt) |
|---|---|
| Warrior | RESOURCE_AT_LEAST rage 50 · SKILL_HITS furious_strike 2 · POISE_BREAKS hardened_husk 1 |
| Arcanist | SKILL_CASTS (beliebig) 4 · SKILL_HITS arcane_bolt 2 · STATUS_APPLIED arcane_mark 2 · STATUS_CONSUMED arcane_mark 2 |
| Shadowrunner | RESOURCE_AT_LEAST focus 40 · SKILL_CASTS shadowstep 1 · STATUS_APPLIED weak_point 2 · STATUS_CONSUMED weak_point 1 |

Ablauf:
- Zählung über `PrologueService.record` (`scripts/rpg/prologue/prologue_service.gd:83-100`), gespeist aus
  `PlayerProgressionBridge` (`scripts/rpg/player_progression_bridge.gd:194-195, 304, 316-336`).
- Sind **alle** Ziele erfüllt → sofort `end_trial(true)` (`:99-100`) – noch im Kampf, unabhängig vom Ort.
- `KILLS` wird immer mit `target_id = &""` gemeldet (`player_progression_bridge.gd:322-323`) → „töte Gegner X“ ist heute
  **nicht** ausdrückbar. `POISE_BREAKS` kennt die Variante (`config.id`, `:324-325`).
- Kein Trial hat ein Kill-Ziel; Gegner sind nur Mittel. Fallen alle Gegner, spawnt `TrialStation._process` eine neue Welle
  (`trial_station.gd:72-73`) → unendlich.
- Abbruch: G am selben Pedestal (`:28-30`), Tod (`player_progression_bridge.gd:340-343`), Kartenwechsel (`game_map.gd:60-61`)
  → `end_trial(false)`, zählt nicht.

### A.3 Story- und Save-Abhängigkeiten

| Abhängigkeit | Ort | Wirkung |
|---|---|---|
| `prologue.completed_trials` | `scripts/rpg/prologue/prologue_state.gd:16, 35-49` | einzige persistente Trial-Information (+ `stage`, `chosen_class`) |
| `StoryService.notify("trial_complete")` | `prologue_service.gd:70-71`, nur beim **ersten** Abschluss | Zähler `count.trial_complete` in `WorldState.flags` |
| Quest `the_whispering_stone` Schritt 1 | `data/story/the_whispering_stone.tres` (`O_echoes`: `trial_complete`, `amount = 3`, `cumulative = true`) | Schritt „Walk the three echoes“; danach `class_chosen` → Flag `prologue.first_class_selected` |
| Wegstein-Erweckung | `whispering_stone.tscn` `C_after_choice` (Flag `prologue.first_class_selected`) | hängt **nur** an der Wahl, nicht an der Trial-Anzahl |
| `the_first_binding` | `data/story/the_first_binding.tres` | startet nach Wegstein (`next_quest_ids`), keine Trial-Abhängigkeit |
| `EchoHint` | `whispering_stone.tscn:194-200`, Bedingung `C_echoes` (Quest aktiv, Schritt 1) | Hinweistext „glowing stone … G“ |
| Migration v4→v5 | `scripts/rpg/save/save_migrations.gd:150-156` | setzt `count.trial_complete = 3` bei fertigem Prolog, sonst Anzahl `completed_trials` |
| Migration v3→v4 | `save_migrations.gd:93-113` | `completed_trials = []`, `chosen_class` heuristisch |
| Laufender Trial | `prologue_state.gd:3-5, 47-49` | `active_trial`, `trial_progress` werden nie gespeichert und beim Laden geleert |
| Sperren während Trial | `talent_service.gd:118`, `preset_service.gd:29, 143`, `waystone_service.gd:56`, `character.gd:78`, `game_map.gd:269`, `character_classes.gd:71` | Talente, Presets, Wegsteinreise, Klassenwechsel, Debug-Level |
| UI | `objective_panel.gd:44-55` („Try the three class trials (n/3)“), `pause_menu.gd:93-94`, `player_frame.gd:90`, `inventory_panel.gd:283`, `class_station_panel.gd:182-184` | reine Anzeige |

### A.4 Ersetzen vs. Weiterverwenden

| Baustein | Entscheidung |
|---|---|
| `PrologueService` begin/end/record/objectives_done | **weiterverwenden** (nur `can_choose` und ein Ziel-Kind ändern sich) |
| `PrologueState` + Save-Format | **unverändert** weiterverwenden; Trial-IDs `trial_warrior/arcanist/shadowrunner` **beibehalten** (Altstände bleiben gültig) |
| `TrialDefinition` | **erweitern** um Ziel-Karte/Spawn (Daten statt `match`), Gegnerfelder `enemy_count/enemy_configs` werden für die neuen Karten überflüssig (für Dev-Karte `prologue` vorerst lassen) |
| `TrialObjective` / `ObjectiveRules` | **weiterverwenden**; `KILLS` zusätzlich mit Varianten-ID melden (abwärtskompatibel, s. §F) |
| Temporäre Schichten in Classes/Builds/Equipment | **unverändert** weiterverwenden |
| `TrialStation` | auf `whispering_stone` **entfernen**; in der Dev-Karte `prologue` vorerst lassen (Tests/Playtest) oder in einem späteren Aufräumschritt ersetzen |
| `ClassChoiceStation` / `ClassChoicePanel` | **weiterverwenden** und erweitern (Trial-Auswahl + „?“) |
| `the_whispering_stone` Schritt 1 | **Daten anpassen** (`amount` 3 → 1, Texte) |
| `Encounter` / `EncounterSpawn` / `TrainingDummy` / `Checkpoint` / `StoryTrigger` | **weiterverwenden** für die Räume |

---

## B – Zentraler Altar

### B.1 IST
- `ClassChoiceStation` (`scripts/world/class_choice_station.gd`) öffnet nur `GameHud.open_class_choice`
  (`scripts/ui/game_hud.gd:309-313`). Kein Zustandsmarker.
- `ClassChoicePanel` (`scripts/ui/class_choice_panel.gd`) baut pro Prolog-Klasse eine Karte (`_card`, `:127-157`):
  Name, `choice_text`, Ressource, „Echo walked / not walked yet“, Knopf „Choose/Confirm“ (deaktiviert über `can_choose`).
  2-Klick-Bestätigung (`choose`, `:61-86`), Meilenstein-Save mit Erfolgsanzeige nach `save_finished` (`:89-99`).
- Texte setzen „alle drei“ voraus: `INTRO` (`:9`), Status „Walk all three echoes first…“ (`:113`),
  Fehler `can_choose` „Walk all three echoes first.“ (`prologue_service.gd:114`).

### B.2 Vorschlag (kleinste Änderung)
1. **Trial-Auswahl im bestehenden Panel:** jede Karte erhält einen zweiten Knopf „Walk the echo“
   (`PrologueService.can_begin_trial` als Freigabe/Tooltip). Klick → neuer Service-Aufruf (z. B.
   `PrologueService.enter_trial(character, trial_id)` = `begin_trial` + Rückgabe Ziel-Karte/Spawn) und danach
   `SessionState.travel(trial.map_id, trial.spawn_id)` aus der UI/Station. Keine Regel in der UI.
   Kein zweites Fenster, kein neuer Eintrag in `GalleryScreens` nötig (bestehender Bildschirm), neue Knopftexte über
   `localization/ui.csv`.
2. **Wahl:** unverändert `choose` → `choose_starting_class`. Nur `can_choose` ändert sich (§E.1). Der Knopf ist pro Karte
   bereits einzeln über `can_choose(class_id)` gesperrt – mit der neuen Regel ergibt sich „nur Klassen mit eigenem Trial“
   automatisch.
3. **„?“-Marker:** in `ClassChoiceStation._draw` (`:22-32`), solange `not prologue.is_completed()` und für mindestens eine
   Prolog-Klasse `can_choose == ""`. Muster: `Readable` „?“ (`scripts/world/readable.gd:71-72`), Text über `WorldText`.
   Deckt sich mit Variante 1 aus `LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` §B.
4. **Nach der Wahl:** `can_begin_trial` lehnt ab (`prologue_service.gd:28-29`) → „Walk the echo“ deaktiviert;
   Karten zeigen wie heute „Chosen / Locked (learn later)“.
5. **Keine neuen Klassenrestriktionen:** `allowed_weapon_families` ist bei allen Klassen leer
   (`class_definition.gd:59-60` → alle Familien erlaubt); Schilde sind über `can_use_shields` schon heute für Arcanist/
   Shadowrunner/Basic gesperrt (`data/classes/*.tres`) – das ist Bestand und wird nicht angefasst.

Interaktionsabstand: `ClassChoicePanel._process` schließt das Fenster, wenn der Spieler die Station verlässt (`:51-53`).
Beim Reisen wird die Szene ohnehin gewechselt – unkritisch.

---

## C – Drei Trainingsgebiete

### C.1 Technischer Rahmen (Projektregeln)
- Neue Karten erben von `GameMap`, brauchen `Player`, `GameHud`, `SpawnPoint` „default“, `MapDefinition`
  (Muster `data/world/maps/prologue.tres`: `show_on_map = false`, eigene `map_cell`).
- Übergänge nur `SessionState.travel` (`scripts/rpg/session_state.gd:173-184`) bzw. `MapTransition`
  (`scripts/world/map_transition.gd`).
- Die drei Map-IDs in `ProgressionRules.trial_map_ids` aufnehmen, sonst beendet `GameMap._ready` den Trial beim Betreten.

### C.2 Eintritt, Rückkehr, Wiederholung

| Phase | Ablauf | Code |
|---|---|---|
| Eintritt | Altar-Panel → `begin_trial` → `travel(map_id, "default")` | `prologue_service.gd:37-50`, `session_state.gd:173` |
| Unterwegs | Character inkl. Trial-Schichten bleibt in `GameSession`; neue Karte bindet ihn (`bind_player`) und baut Klasse/Skills/Ressource aus `active_class_id` neu | `game_map.gd:42-66`, `session_state.gd:133-140` |
| Erfolg | letztes Ziel → `end_trial(true)` sofort; danach Rückkehr zum Altar (Spawn neben `TheStone`) | `prologue_service.gd:99-100` |
| Abbruch | Ausgang/Portal in der Karte → `end_trial(false)` + `travel` zurück; Pause-Menü-Option optional | – |
| Niederlage | Bridge beendet Trial bei Tod (`player_progression_bridge.gd:340-343`), Spieler respawnt **in der Trial-Karte** (`player.gd:494-502`) → Karte muss ohne aktiven Trial zurückschicken | – |
| Wiederholung | jederzeit vor der Wahl erneut über den Altar; neue Szene = frische Gegner (Encounters `persistent = false`) | `encounter.gd:6-8, 16` |

Empfehlung für Rückkehr: **eine generische Regel** statt Einzelfälle – „Steht der Spieler auf einer Trial-Karte und läuft
kein Trial (Erfolg, Abbruch, Tod, geladener Save), reist er zum Altar zurück.“ Datenquelle: Rückkehrziel am
`TrialDefinition` oder an den Regeln (`ProgressionRules`), nicht pro Karte im Code. Auslöser: `PrologueState.trial_finished`
und `GameMap._ready`. Damit sind Tod und Altstände mit abgedeckt.

`whispering_stone` sollte danach aus `trial_map_ids` **entfernt** werden: dann bricht jede Rückkehr zum Altar einen
eventuell noch laufenden Trial automatisch ab (`game_map.gd:60-61`), und am Altar selbst kann kein Trial mehr laufen.
Die Dev-Karte `prologue` bleibt in der Liste, solange ihre Pedestale existieren.

### C.3 Zwei Räume pro Karte
- Eine Szene, zwei Bereiche, verbunden durch einen Durchgang (Muster: `SideFloor` + `SideNorth/SideSouth/SideEast` in
  `whispering_stone.tscn:73-79, 158-177`).
- **Raum 1 (Einführung + zwei Übungen):** `TrainingDummy` (`scenes/dummy/training_dummy.tscn`, Gruppe `training_target`)
  für Skill-/Status-Übungen – zählen für `SKILL_HITS/STATUS_*`, geben **keine** Kills, XP oder Drops
  (`combat_reward_tracker.gd:84`, `player_progression_bridge.gd:322`). Erklärtext über `StoryTrigger`-Hint
  (Muster `EchoHint`). Optional ein `Checkpoint` (Lagerfeuer) vor Raum 2 als Respawn.
- **Raum 2 (Mini-Boss):** `Encounter` mit `persistent = false`, `completion_loot = null`, `trigger_radius` am Eingang
  (`scripts/world/encounter.gd`). Startet erst beim Betreten.
- **Reihenfolge:** Trial-Ziele sind ungeordnet (`prologue_service.gd:74-79`). Damit der Trial nicht vor dem Boss endet,
  muss das Boss-Ziel ein Ziel sein, das nur in Raum 2 erfüllbar ist (Kill/Poise-Break einer Variante, §F). Eine harte
  Raum-Sperre ist **optional** (bräuchte einen kleinen Gate-Knoten, der `objectives_done` für Teilziele liest – neuer Code).
- Unendliche Wellen (`trial_station.gd:72-73`) entfallen.

### C.4 Vorhandene Bausteine (Assets)

| Kategorie | Vorhanden | Pfad |
|---|---|---|
| Boden | `ArenaFloor` (Karomuster, zwei Farben, Kachelgröße) | `scripts/arena/arena_floor.gd` |
| Wände/Requisiten | `WallBlock` (Block mit Ober-/Seitenfarbe) – Stehende Steine, Bäume, Mauern | `scripts/arena/wall_block.gd` |
| Rast/Respawn | `Checkpoint` (Lagerfeuer, heilt, füllt Flask) | `scripts/world/checkpoint.gd` |
| Texte | `Readable` (ohne `rewards`!), `StoryTrigger`-Hint | `scripts/world/readable.gd`, `scripts/world/story_trigger.gd` |
| Übungsziele | `TrainingDummy` | `scenes/dummy/training_dummy.tscn` |
| Kampf | `Encounter` + `EncounterSpawn`, `GameMap.spawn_enemy` | `scripts/world/encounter*.gd`, `game_map.gd:220-230` |
| Tilesets/Sprites | **keine** (keine `TileSet`/`TileMap`, keine Spiel-PNGs) | – |

### C.5 Konkrete Vorschläge (nur vorhandene Ressourcen, keine neuen Werte)

**Warrior – The Broken Bastion** (`trial_warrior_map`, Arbeitstitel)
- Optik: grau-steinerner `ArenaFloor` (Farbwerte wie `Clearing`), umgestürzte Mauerblöcke aus `WallBlock`.
- Raum 1: 2 Dummies. Übung 1 „Rage aufbauen“ (RESOURCE_AT_LEAST rage, bestehendes Ziel), Übung 2 „Furious Strike treffen“
  (SKILL_HITS furious_strike, bestehendes Ziel). Beide auf Dummies erfüllbar.
- Raum 2: `Encounter` mit **einem** `hardened_husk` (`data/enemies/hardened_husk.tres`) – Prüfung = bestehendes Ziel
  POISE_BREAKS hardened_husk 1 (+ optional Kill, §F).

**Arcanist – The Shattered Sanctum**
- Optik: violett/kühle Bodenfarben, verstreute Steinsplitter.
- Raum 1: Dummies. Übung 1 „Arcane Bolt aus Distanz“ (SKILL_HITS arcane_bolt), Übung 2 „Marks setzen + detonieren“
  (STATUS_APPLIED / STATUS_CONSUMED arcane_mark). Mana-Ressource ergibt sich nebenbei (SKILL_CASTS).
- Raum 2: Mini-Boss aus Bestand (§F.2): Grove-Warden-Konfiguration **oder** `hardened_husk` + `hollowfang_wolf`-Begleiter.

**Shadowrunner – The Veiled Passage**
- Optik: dunkler, enger Korridor (zwei schmale `ArenaFloor`-Bänder), Bäume/Steine als Sichtdeckung.
- Raum 1: Dummies. Übung 1 „Weak Point freilegen“ (STATUS_APPLIED weak_point), Übung 2 „Execution“
  (STATUS_CONSUMED weak_point). Shadowstep braucht ein Ziel (`GapCloserAction`, Prüfung vor Kosten) – Dummy genügt.
- Raum 2: Rudel `hollowfang_wolf` (§F.3).

Ob ein Dummy für Weak-Point/Execution/Arcane-Mark-Detonation tatsächlich reagiert wie ein Gegner (StatusComponent auf dem
Dummy) ist **im Playtest/Test zu bestätigen**; die heutigen Trials laufen nur gegen echte Gegner.

---

## D – Temporäre Klassenerprobung

### D.1 Was heute temporär ist (sicher)

| Zustand | Mechanik | Zurückgesetzt durch | Save |
|---|---|---|---|
| Klasse | `CharacterClasses.trial_class_id` überlagert `active_class_id` (`character_classes.gd:12-19`) | `end_trial` (`:163-168`) | nie (`to_dict` schreibt `_active_class_id`, `:117-121`) |
| Level | `trial_level` (`get_level`, `:79-82`) | `end_trial` | nie |
| Talente + Skills | temporärer `ClassBuild` aus `TrialDefinition.make_build` (`class_builds.gd:45-60`) | `end_trial_build` | nie |
| Loadout | Kopie der Referenzen der echten Klasse, nur erlaubte Items (`character_equipment.gd:285-299`) | `end_trial` | nie |
| Stats | `StatResolver` aus aktueller Klasse/Level/Build/Loadout – kein inkrementeller Zustand | automatisch (`stats_changed`) | – |
| Ressource, Cooldowns, Status | Laufzeit in `class_runtime` / Komponenten, Neuaufbau bei `active_class_changed` | automatisch | nie |
| Ziele | `prologue.active_trial`, `trial_progress` | `end_trial` / `from_dict` | nie |
| Klassen-XP | `add_xp` nur für freigeschaltete Klassen (`character_classes.gd:94-97`) → Trial-Klasse erhält keine | – | – |

Fazit: **Klasse, Skills, Talente, Ressource und Waffenkit lassen sich für einen Trial sicher bereitstellen – das existiert
bereits und funktioniert auch über einen Kartenwechsel**, weil alle drei Schichten am `Character` in `GameSession` hängen.
Keine permanente Freischaltung (`classes.unlock` wird nur in `choose_starting_class` aufgerufen).

### D.2 Was heute **nicht** temporär ist (Risiko bei längeren Trials)

| Zustand | Ursache | Bewertung |
|---|---|---|
| Inventar: feste Gegnerdrops (Gold, Essenz) | `GameMap._spawn_drops` für jeden registrierten Gegner (`game_map.gd:86-87, 130-138`); `hardened_husk` droppt Essenz + 4 Gold, Wolf 1 Gold, Husk 2 Gold | **Widerspricht „keine separaten Trial-Lootdrops“.** Heute schon mit unendlichen Wellen farmbar. |
| Inventar: Equipment-Drops | nur über `Enemy.equipment_loot` / `Encounter.completion_loot` | auf Trial-Karten einfach leer lassen |
| Hearth-Flask-Ladungen | `Player.begin_use` / `ConsumableService` (persistiert in `Character.consumables`) | Verbrauch bleibt; Design: erlauben + am Altar/Checkpoint auffüllen oder sperren |
| Weapon-Mastery-XP, Armor-Mastery-XP | `CombatRewardTracker.reward_kill` (`combat_reward_tracker.gd:82-96`), Defense-XP (`player_progression_bridge.gd:394-410`) | bleibt erhalten (auch heute). Design-Entscheidung |
| Item-Evolution-XP | `_grant_item_xp` (`player_progression_bridge.gd:238-248`) | bleibt erhalten |
| Equip-Änderungen im Trial | gehen in `_trial_loadout` → werden verworfen; Items selbst bleiben im Inventar | sicher |
| Story-Zähler | `count.*`, Encounter-Events (`encounter.gd:105-117`) | harmlos, aber Encounter-IDs eindeutig wählen |

**Empfehlung: kein Snapshot/Rollback des Inventars.** Ein Rollback würde Instanzen außerhalb von `Inventory`/`StashService`
verwalten und gegen die Item-Regeln verstoßen. Stattdessen Quellen auf Trial-Karten abschalten:
- **Minimal:** ein Kartenflag „keine Drops“ (z. B. `MapDefinition`- oder `GameMap`-Export), das `GameMap._spawn_drops`
  überspringt. Eine Stelle, datengetrieben, keine trialspezifischen Gegner-Kopien.
- Keine `ResourceNode`s, keine `Readable` mit `rewards`, keine Stash/Werkbank auf Trial-Karten.
- Mastery-/Armor-XP: Entscheidung offen (B3). Technisch wäre „keine Kill-Belohnung auf Drop-freien Karten“ an derselben Stelle
  abschaltbar, berührt aber Combat ↔ RPG nur über `CombatRewardTracker` – kein Eingriff in Combat-Daten.

### D.3 Waffen
- Keine Klasse schränkt Waffenfamilien ein (`allowed_weapon_families` leer in allen `data/classes/*.tres`).
- `SkillDefinition` hat keine Waffenbedingung (`scripts/rpg/skills/skill_definition.gd`: Kosten, Cooldown, Aktionen).
- Der Spieler trägt seine Startwaffe (`iron_sword`/`steel_greatsword`, `progression_rules.tres`); die Trial-Loadout-Kopie
  übernimmt sie. Ein Arcanist-Trial mit Schwert ist technisch voll funktionsfähig.
- Temporär erzeugte Trial-Waffen (z. B. Leih-Stab) würden Items außerhalb eines besitzenden Inventars oder nachträgliches
  Löschen verlangen → **nicht empfohlen**. Falls gewünscht, wäre der einzige regelkonforme Weg eine nicht-item
  Combat-Waffe (nur `WeaponFamily` im `CombatComponent`), die aber die „ein Waffen-Slot“-/Bridge-Regeln umgeht → Blocker,
  nicht im Umfang.

### D.4 Save/Load während eines Trials
- `Character.to_dict` schreibt nur den echten Zustand (Klasse, Builds, Loadouts ohne Trial-Schicht); Laden leert den Trial.
- **Neues Risiko durch separate Karten:** `GameMap._ready` setzt `character.world.map_id = map_id` (`game_map.gd:52-53`).
  Ein Save auf der Trial-Karte (periodisch `save_coordinator.gd:83-89`, manuell über Pause-Menü, oder **kritisch**: mit
  `amount = 1` schließt der erste Trial-Abschluss Story-Schritt 1 ab → `SessionState._on_story_progressed` fordert einen
  Meilenstein-Save an, während der Spieler noch auf der Trial-Karte steht) lädt später auf die Trial-Karte **ohne** Trial.
- Meilensteine dürfen nicht unterdrückt werden (CLAUDE.md). Zwei regelkonforme Varianten:
  1. **Gespeicherter Ort = Altar:** Trial-Karten schreiben als `world.map_id/spawn_id` das Rückkehrziel statt sich selbst
     (Datenfeld an `MapDefinition`, generisch). Jeder Save zeigt automatisch auf den Altar. **Empfohlen.**
  2. Rückkehrregel aus §C.2 (Karte ohne laufenden Trial → reist zum Altar) – deckt Laden zusätzlich ab.
  Beide zusammen sind robust; Variante 2 allein lässt einen kurzen Ladeumweg über die Trial-Karte zu.

---

## E – Trial-Status und Story

### E.1 Regeländerung (nur `PrologueService`)
- `can_choose(class_id)`: statt Schleife über alle drei Trials (`prologue_service.gd:111-115`) nur
  `prologue.has_completed_trial(trial_for_class(class_id).id)`. Fehlertext entsprechend.
- `choose_starting_class` unverändert (einmalig, `stage = COMPLETED`, `notify("class_chosen")`).
- Andere Klassen bleiben gesperrt (Karte deaktiviert), andere Trials bleiben bis zur Wahl startbar (`can_begin_trial`
  prüft nur `is_completed()` und „kein Trial läuft“).
- `prologue.chosen_class` bleibt die feste Klassenidentität (einziger Schreiber `choose_starting_class`).

### E.2 Abbruch, Niederlage, Wiederholung
- Abbruch/Tod/Kartenwechsel: `end_trial(false)` – kein Eintrag, kein Story-Event, alle Schichten weg. Sofort wiederholbar.
- Erneuter Erfolg desselben Trials: kein zweites `trial_complete` (`first_completion`, `prologue_service.gd:62-64`).
- Erfolg eines zweiten Trials vor der Wahl: `trial_complete` zählt hoch; Schritt 1 ist dann bereits erledigt → kein Effekt.

### E.3 Story-Auswirkungen

| Element | Änderung |
|---|---|
| `the_whispering_stone` Schritt 1 | `O_echoes.amount` 3 → 1, Beschreibung/Schritttext („Walk an echo within the stone“) – **reine Daten** |
| Schritt 2 (`class_chosen`) | unverändert |
| Wegstein-Erweckung | unverändert (Flag `prologue.first_class_selected`) |
| `the_first_binding` | unverändert |
| `EchoHint` | Text anpassen („Listen at the Heart of the Stone …“), Bedingung bleibt |
| `MemoryFragment` „Three stood here …“ | bleibt (Lore) |
| HUD `objective_panel.gd:54-55` | „n/3“-Text anpassen (Anzeige) |
| `ClassChoicePanel.INTRO` / Status | Texte anpassen |
| Klassen-Magic-Belohnung | Hook bleibt wie in `LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` §A: abgeleiteter Anspruch nach `prologue.is_completed()` + `chosen_class`, Claim mit Platzprüfung, Flag in `WorldState`; **nicht** an Trial-Abschluss koppeln (kein Magic für Ausprobieren) |

### E.4 Alte Saves und alte Trial-Flags

| Altstand | Verhalten nach 2.0 | Handlungsbedarf |
|---|---|---|
| Prolog fertig (`stage = completed`) | unverändert; Trials gesperrt | keiner |
| 3/3 Trials, keine Wahl | Wahl sofort möglich (alle drei Klassen) | keiner |
| 1–2 Trials, Quest auf Schritt 1 | Zähler `count.trial_complete ≥ 1` erfüllt das neue Ziel, **aber** `StoryService._settle` läuft nur bei `start` oder wenn ein Event ein Ziel des **aktuellen** Schritts berührt (`story_service.gd:25-32, 73-91`) → Schritt 1 bleibt „hängen“. `can_choose` erlaubt die Wahl trotzdem (eigener Trial bestanden). `class_chosen` berührt Schritt 1 nicht → kein `_settle`, kein Fortschritt für Schritt 2. Danach ist kein weiterer Trial mehr möglich (`can_begin_trial` nach `is_completed()` gesperrt) → Schritt 1 wird nie erledigt, Schritt 2 (nicht kumulativ) nie gezählt, Flag `prologue.first_class_selected` fehlt, **Wegstein bleibt gesperrt: Soft-Lock.** | **Ja, Pflicht:** generisches Nachziehen aktiver Story-Quests nach dem Laden (`_settle` für alle aktiven Quests, kein questspezifischer Code) **oder** Migrationsschritt v14→v15 ohne Schemaänderung. Hier **nicht** implementiert; vor Freigabe mit `story`/`shrine`-Tests absichern. |
| v3→v4/v4→v5 migriert | `completed_trials` leer/Zähler gesetzt; fertige Prologe unverändert | keiner |
| Save im laufenden Trial (vor 2.0) | lädt ohne Trial auf `whispering_stone` | keiner |
| Save auf Trial-Karte (nach 2.0) | siehe §D.4 | Rückkehrregel |

Derselbe Mechanismus betrifft **neue** Spielstände nicht: Dort erhöht der erste `trial_complete` den Zähler, während
Schritt 1 aktiv ist → `_settle` läuft sofort. Das Nachziehen gehört deshalb in M1, vor jeder Freigabe der Regeländerung.

Alte Trial-IDs: beibehalten. Ein unter alten Regeln bestandener Trial gilt als bestanden (Entscheidung B4).

---

## F – Mini-Boss-Konzept

Gegnerbestand (`data/enemies/`, alle auf `scenes/enemies/grunt.tscn` + `scripts/enemies/enemy.gd`, eine Nahkampf-KI):

| Variante | HP / Poise | Tempo | Besonderheit | Angriffe |
|---|---|---|---|---|
| `rootbound_husk` | 70 / 30 | 58 | nie Heavy | `grunt_attacks` |
| `hardened_husk` | 160 / 70 | 50 | Elite (rank 1), Heavy jede 2., KB-Resistenz 0,5 | `grunt_attacks` (Slam: block/parier/guard-break, `defense_flags = 7`) |
| `hollowfang_wolf` | 50 / 20 | 100 | nie Heavy, KB-Resistenz −0,3 | `grunt_attacks` |
| `grove_warden` | 90 / 35 | 70 | Boss (rank 2), Parry unterbricht nicht, Parry-Poise ×0,3, Bleed-Res. 0,5, Slow-Cap 0,25 | `grove_warden_attacks`: Swipe nur blockbar (`1`), Slam weder block- noch parierbar (`0`) |
| Basis-Grunt | 100 / 40 | 70 | Heavy jede 3. | `grunt_attacks` |

Einschränkung: `EncounterSpawn` und `GameMap.spawn_enemy` setzen nur `config`, **nicht** `attacks`
(`encounter_spawn.gd`, `game_map.gd:220-230`). Der Grove Warden ist nur als in der Szene platzierter Knoten möglich
(`whisper_forest.tscn:233-238`) – oder `EncounterSpawn` bekommt ein optionales `attacks`-Feld (kleinste Erweiterung).

Für alle drei gilt eine gemeinsame minimale Erweiterung: **`KILLS` mit Varianten-ID melden**
(`player_progression_bridge.gd:322-323`: `(hit.target as Enemy).config.id` statt `&""`). `ObjectiveRules.matches` behandelt
`target_id = &""` als „beliebig“ (`objective_rules.gd:5-6`) → bestehende Kill-Ziele (Klassenquests `unlock_*.tres`) bleiben
kompatibel. Damit ist „besiege den Boss“ als Abschlussziel ausdrückbar.

### F.1 Warrior – The Broken Bastion
- **Grundlage:** `hardened_husk` (bereits Trial-Gegner, bereits Ziel `POISE_BREAKS hardened_husk`).
- **Lernziel:** schwere/aufgeladene Angriffe brechen Poise; Guard-Break-Slam nicht blocken, sondern ausweichen/parieren.
- **Minimale Erweiterung:** keine KI-Änderung. Optional Kill-Ziel per Varianten-ID. Encounter mit einer Spawn-Markierung.
- **Risiken:** Poise regeneriert nach 1,5 s mit 25/s (`health_component.gd:15-16`) – Poise-Break hängt an Spieler-DPS mit
  Startwaffe + Trial-Level 12; heute im Feel-Test bereits so gespielt, aber gegen 1 statt mehrere Gegner neu zu bewerten.
  Keine Werte ändern ohne Playtest.
- **Abschluss:** klar – „Break the guard“ (+ optional „Defeat“).

### F.2 Arcanist – The Shattered Sanctum
- **Kein Fernkampfgegner im Projekt.** `Enemy` ist explizit Nahkampf (`enemy.gd:1-6`); Projektile gibt es nur für Spieler
  (`CombatComponent.projectile_fired`). „Distanzdruck“ im Sinne von gegnerischen Projektilen = neue KI → **nicht im Umfang**.
- **Bester Ersatz aus Bestand:**
  - Variante A: **Grove Warden** – unblock-/unparierbarer Slam (`grove_warden_attacks.tres`, `defense_flags = 0`) erzwingt
    Abstand halten und Positionierung → passt zum Lernziel „Reichweite + Positionierung“. Braucht `attacks` am Spawn oder
    platzierten Knoten ohne `persistent_id`. Gegen: Er ist der Regionsboss von Hollowwood (`whisper_forest`) – Doppelverwendung
    entwertet ihn (Entscheidung B5). Seine Werte (90 HP) liegen unter `hardened_husk`.
  - Variante B: `hardened_husk` + 1–2 `hollowfang_wolf` als „Bewegungsdruck“ (schnelle Wölfe zwingen zum Umpositionieren,
    Husk ist das Mark-Ziel). Keine Erweiterung außer Kill-Ziel.
- **Lernziel:** Abstand halten, Marks setzen und detonieren unter Druck, Mana haushalten.
- **Risiken:** Arcanist mit Startwaffe im Nahkampf ist schwach – Wolf-Tempo 100 vs. Spielerbewegung ungetestet in Solo-Arena;
  Frostbind-Slow gegen Warden gekappt (`max_slow = 0.25`).
- **Abschluss:** „Detonate N marks on the guardian“ ist mit `STATUS_CONSUMED arcane_mark` **nicht** variantengebunden →
  Abschluss über Kill-Ziel der Bossvariante.

### F.3 Shadowrunner – The Veiled Passage
- **Grundlage:** `hollowfang_wolf` (schnell, kurze Fenster, Cooldown 1,2 s, nie Heavy) – passt zum Lernziel; als Einzelgegner
  aber zu schwach für einen „Mini-Boss“ (50 HP).
- **Vorschlag ohne neue Werte:** Rudel (2–3 Wölfe) als Prüfung, Abschluss „Kill N hollowfang_wolf“ (Varianten-ID) **oder**
  Wolfrudel + ein `hardened_husk` als Execution-Ziel.
- **Ein echter „Alpha“-Wolf** bräuchte eine neue `EnemyConfig` mit neuen Werten → **nicht festgelegt**, Designfreigabe nötig.
- **Lernziel:** Ausweichen (Dash-I-Frames, `dash_component.gd:29-30`), Shadowstep zum Ziel, Weak Point → Execution.
- **Lücke:** „Ausweichen“ ist kein Trial-Ziel – es gibt kein Ereignis „Angriff ausgewichen“ (nur `dash_started`,
  `DefenseComponent.parried/blocked`). Ein Ziel „N Angriffe ausgewichen“ bräuchte ein neues `TrialObjective.Kind` + Erkennung
  im Hurtbox-/Dash-Pfad → Risiko für Combat-Timing; **nicht empfohlen** im ersten Schritt.
- **Risiken:** Rudel-Druck + kein Block für Shadowrunner-Build schwer einschätzbar; Execution-Kosten 40 Focus.

---

## G – Umsetzungsplan (max. vier Meilensteine)

### M1 – Regel und Story „ein Trial genügt“
- **Dateien:** `scripts/rpg/prologue/prologue_service.gd` (`can_choose`), `data/story/the_whispering_stone.tres`
  (`amount`, Texte), generisches Nachziehen aktiver Story-Quests nach dem Laden in `StoryService` (oder Migration v15 ohne
  Schema – Entscheidung), `scripts/ui/class_choice_panel.gd` (Texte), `scripts/ui/objective_panel.gd` (Anzeige),
  `class_choice_station.gd` („?“), `localization/ui.csv`.
- **Ziel:** Wahl pro Klasse nach eigenem Trial, „?“ am Altar, Altstände ohne Soft-Lock. Pedestale bleiben vorerst.
- **Risiken:** Soft-Lock bei 1–2 Trials (§E.4); doppelter Meilenstein-Save bei Wahl (bestehend).
- **Tests:** `prologue`, `shrine`, `story`, `save` (nur Prolog-/Migrationsfälle).
- **Ausgeschlossen:** neue Karten, Trial-Inhalte, Klassen-Magic-Belohnung, Save-Schema.

### M2 – Trial-Reise-Infrastruktur
- **Dateien:** `trial_definition.gd` (Ziel-Karte/Spawn, Rückkehrziel), `progression_rules.gd`/`.tres` (`trial_map_ids`,
  `whispering_stone` raus), `game_map.gd` (Rückkehrregel, Drop-frei-Flag in `_spawn_drops`), `map_definition.gd`
  (gespeicherter Ort = Rückkehrziel), `prologue_service.gd` (Eintritt), `class_choice_panel.gd` („Walk the echo“),
  Entfernen der Pedestale aus `whispering_stone.tscn`, drei **leere** Platzhalter-Karten + `MapDefinition`s.
- **Ziel:** Altar → Karte → Erfolg/Abbruch/Tod/Laden → Altar, ohne Drops, Save immer auf Altar.
- **Risiken:** Save-Ort (§D.4), Respawn auf Trial-Karte, Reise während Fenster offen, Dev-Karte `prologue` weiter
  funktionsfähig halten.
- **Tests:** `prologue`, `shrine`, `save` (Save auf Trial-Karte → Laden am Altar), `map`/`world`-Suite der Übergänge.
- **Ausgeschlossen:** Rauminhalte, Bosse, neue Gegner, Kill-Varianten-ID.

### M3 – Drei Karten mit Raum 1 + Raum 2 aus Bestand
- **Dateien:** drei neue `scenes/maps/trial_*.tscn` (ArenaFloor/WallBlock/Dummies/StoryTrigger/Checkpoint/Encounter),
  `data/trials/*.tres` (neue Ziele aus bestehenden Kinds), `player_progression_bridge.gd` (KILLS mit Varianten-ID),
  ggf. `encounter_spawn.gd` (optionales `attacks`, nur bei Warden-Variante).
- **Ziel:** spielbare 4–5-Minuten-Prototypen mit vorhandenen Gegnern und Werten.
- **Risiken:** Dummy-Status-Verhalten (Marks/Weak Points), Trial endet vor Raum 2 (Zielreihenfolge), Warden-Doppelnutzung.
- **Tests:** `prologue` (Ziele, Abschluss nur nach Bossziel), `enemy`/`encounter` gezielt, Daten-Validierung `GameDatabase`.
- **Ausgeschlossen:** neue Gegner-KI, neue `EnemyConfig`-Werte, neue Skills, Balanceänderungen, Ausweich-Ziel.

### M4 – Klassen-Magic-Belohnung nach endgültiger Wahl
- Wie `LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` §G M1 (abgeleiteter Anspruch, Claim mit Platzprüfung, `ItemCreation.generate`
  Magic ilvl 5 aus `hollowwood_early_tiers`, Flag, Mapping als Daten-Resource). Hängt **nur** an `prologue.is_completed()`
  + `chosen_class`, nie an Trials.
- **Tests:** neue Reward-Suite, `prologue`, `inventory`, `save`.
- **Ausgeschlossen:** Änderungen an Trials, `choose_starting_class`-Regeln, Save-Version.

Durchgehend ausgeschlossen: Full-Suite, Prolog-/Haven-Gesamtloops, Klassen-Playtests, Arena, Galerie.

---

## H – Echte technische Blocker und offene Entscheidungen

**Technische Blocker (nur falls gewünscht):**
1. **Gegnerischer Fernkampf** (Arcanist „Distanzdruck“): existiert nicht; braucht neue KI-Logik in `Enemy` → eigenes Feature.
2. **Ausweich-Ziel** (Shadowrunner): kein Ereignis „ausgewichen“; neue Erkennung im Combat-Pfad.
3. **Temporäre Trial-Waffen als Items**: nicht regelkonform; nicht empfohlen.

**Kein Blocker, aber Pflicht vor Freigabe:** Story-Nachziehen für Altstände (§E.4) und Save-Ort auf Trial-Karten (§D.4).

**Offene Entscheidungen:**
- B1 Arcanist-Boss: Grove Warden wiederverwenden (Regionsboss doppelt) oder Husk + Wölfe?
- B2 Shadowrunner-Boss: Wolfrudel aus Bestand akzeptieren oder neue Alpha-Werte freigeben?
- B3 Persistente Nebenprodukte im Trial: Weapon-/Armor-Mastery-XP, Item-Evolution-XP und Flask-Verbrauch erlauben oder
  abschalten? (Drops: abschalten laut Design.)
- B4 Altstände: zählen unter alten Regeln bestandene Trials als bestanden? (Empfehlung: ja, gleiche IDs.)
- B5 Dev-Karte `prologue` mit alten Pedestalen: behalten (Tests/Playtest) oder in M2/M3 auf die neue Infrastruktur umstellen?
- B6 Harte Raumsperre zwischen Raum 1 und 2 nötig, oder reicht die Zielstruktur?
