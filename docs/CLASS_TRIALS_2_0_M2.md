# Class Trials 2.0 – M2: Trial Hub & Travel

Stand: 2026-10-28 · Branch `dev/class-trials-20-m2` (von M1 `7ef57dc`) · Save **v14 (unverändert)**
Grundlage: `docs/CLASS_TRIALS_2_0_TECH_AUDIT.md` (§B, §C, §D.4), `docs/CLASS_TRIALS_2_0_M1.md`.

M2 liefert nur Reise-Infrastruktur, drei Platzhalter-Karten und Save-Sicherheit. **Keine** Übungen, Bosse, Trial-Abschlüsse,
Belohnungen, Drop-/XP-Sperren oder temporären Loadouts.

## Phase A – Transition-Vertrag (Befund, kein Blocker)

- Karten: `MapDefinition` unter `data/world/maps/` (von `GameDatabase` geladen), Szene erbt von `GameMap`, `SpawnPoint` „default“.
- Reisen nur `SessionState.travel` – ignoriert Anfragen während einer laufenden Reise (eine Transition zur Zeit).
  `MapTransition` fragt pro Ankunft genau einmal an (`_used`).
- Der Character (inkl. Trial-Schichten) lebt in `GameSession` und überlebt den Szenenwechsel.
- Gespeicherter Ort = `world.map_id/spawn_id`, gesetzt **nur** in `GameMap._ready` (und `Checkpoint` für den Spawn).
  Laden reist zu diesem Ort (`SessionState.load_game`).
- Ein laufender Trial endet in `GameMap._ready` auf jeder Karte außerhalb `rules.trial_map_ids` – die neuen Karten stehen
  **nicht** in der Liste (Trial-Sessions dort erst in M3).

## Map-IDs, Szenen, Spawns

| Klasse | Trial-ID | Map-ID | Szene | Eintritt | Rückkehr |
|---|---|---|---|---|---|
| Warrior | `trial_warrior` | `broken_bastion` („The Broken Bastion“) | `scenes/maps/trial_warrior.tscn` | `default` | `whispering_stone` / `heart` |
| Arcanist | `trial_arcanist` | `shattered_sanctum` („The Shattered Sanctum“) | `scenes/maps/trial_arcanist.tscn` | `default` | `whispering_stone` / `heart` |
| Shadowrunner | `trial_shadowrunner` | `veiled_passage` („The Veiled Passage“) | `scenes/maps/trial_shadowrunner.tscn` | `default` | `whispering_stone` / `heart` |

- Neuer Spawn `heart` vor dem Altar in `scenes/maps/whispering_stone.tscn` (`SpawnHeart`, (0, −228)).
- `TrialDefinition.map_id` / `entry_spawn_id` (Daten, `data/trials/*.tres`); `GameDatabase` prüft, dass die Karte existiert.
- MapDefinitions: `show_on_map = false`, Region `hollow_outskirts` (Liste ergänzt).
- **Karteninhalt (Platzhalter, nur vorhandene Bausteine):** eine zusammenhängende Szene mit zwei `ArenaFloor`-Flächen
  (unten Trainingsbereich, oben Prüfungsbereich, Farbton je Klasse), `WallBlock`-Rand, Trennwand mit Durchgang,
  Marker `TrainingArea`, `TrialArea`, `TrialGate` (Platz für die M3-Sperre), ein `MapTransition` „Heart of the Stone“
  am Südrand, leerer `Enemies`-Knoten. Keine Gegner, Encounters, Sammelknoten, Readables, Pickups, Pedestale,
  Wegsteine oder Checkpoints. Keine Tilesets/Sprites (gibt es im Projekt nicht).

## Altar-Zugänge

- `ClassChoicePanel`: jede Karte hat zusätzlich **„Visit the trial grounds“** (`Visit_<class>`, `tr("UI_TRIAL_VISIT")`,
  Tooltip `UI_TRIAL_VISIT_HINT`: „This is not the final choice …“). Der Wahl-Knopf (`Choose_<class>`) und seine M1-Regeln
  bleiben unverändert.
- `ClassChoicePanel.visit(class_id)` → `PrologueService.can_visit_grounds` → `SessionState.travel(trial.map_id, entry_spawn_id)`,
  Panel schließt. Zweite Anfrage während der Reise wird abgelehnt.
- `PrologueService.can_visit_grounds` = gleiche Sperre wie `can_begin_trial` (unbekannter Trial, Prolog abgeschlossen,
  laufender Trial) + „Karte vorhanden“. Besuchen startet **keinen** Trial, setzt weder `chosen_class` noch
  `completed_trials`.
- Nach der Klassenwahl gibt es keine Visit-Knöpfe mehr.

## Rückkehr und Save-Sicherheit

- Rückweg und freiwilliger Abbruch: derselbe `MapTransition` → `whispering_stone` / `heart`. Wiederbetreten über den Altar.
- `MapDefinition.resume_map_id` / `resume_spawn_id` (neu, generisch): Karten mit Resume-Ziel werden **nie** gespeicherter Ort.
  - `GameMap._ready` schreibt nach dem Betreten das Resume-Ziel als `world.map_id/spawn_id`
    (`MapDefinition.resolve_saved_location`) → jeder Save (periodisch, Meilenstein, manuell) auf einer Trial-Karte zeigt auf
    den Altar.
  - `Character.from_dict` löst einen geladenen Ort auf einer Resume-Karte ebenfalls zum Altar auf (synthetische/ältere Saves).
- Kein laufender Trial kann auf eine Trial-Karte mitgenommen werden (Karte nicht in `trial_map_ids` → `end_trial(false)`);
  Laden stellt nie einen Trial her (unverändert). Keine Trial-Klasse, kein Loadout-Eingriff beim Reisen.
- Keine neuen Save-Felder, keine Migration. M1-`resettle` unverändert aktiv.
- Nebenwirkung: Pause-Menü/Weltkarte zeigen auf einer Trial-Karte den Ort „The Whispering Stone“ (der gespeicherte Ort).

## Alte Pedestale (Übergangslösung)

Die drei Pedestale in `whispering_stone.tscn` und in der Dev-Karte `prologue.tscn` bleiben **voll funktionsfähig** und sind
bis M3 der **einzige Weg, einen Trial zu bestehen**. Die neue Altar-Reise ist eine **Vorschau** der Trial-Karten. Erst wenn
M3 Trial-Sessions und Abschlüsse auf den neuen Karten liefert, werden die regulären Pedestale deaktiviert; die Dev-Karte
bleibt bis zu einer getesteten Ablösung unverändert.

## Tests (gezielt)

Neue Suite `tests/integration/test_class_trials_m2.gd` (echte Kartenwechsel, Saves nur `user://test_saves/class_trials_m2/`):
- `test_trial_grounds_data`: drei Map-IDs registriert, Szene/ID, Eintritts-Spawn, genau ein Rückweg zum Spawn `heart`,
  Resume-Ziel, Platzhalter-Marker, keine Gegner/Loot-/Fortschrittsquellen.
- `test_each_path_travels_and_returns_without_progress`: alle drei Zugänge, richtige Map-ID, Eintritt am Spawn, doppelte Anfrage
  ignoriert, kein Trial, gespeicherter Ort = Altar, Rückkehr an `heart`, Wiedereintritt; Prolog/Klassen/Builds/Loadouts/Inventar/
  Lager/Mastery/Armor/Flask/Quests unverändert, Story-Schritt unverändert.
- `test_save_on_trial_grounds_loads_at_the_altar`: Save auf Trial-Karte (Testpfad) und synthetischer Save mit Trial-Map-ID →
  Laden am Altar, Basic Adventurer, kein Trial.
- `test_paths_closed_during_a_pedestal_trial_and_after_the_choice`: Zugänge während eines Pedestal-Trials gesperrt, Trial endet
  beim Betreten einer Trial-Karte ohne Abschluss, nach der Wahl keine Zugänge.
- `test_old_pedestals_and_m1_rules_unchanged`: Pedestale vorhanden, M1-Eligibility, kein Soft-Lock/kein doppeltes Settle.

Lauf `class_trials_m1,class_trials_m2,shrine,prologue,story,world,world_ui`: **52 bestanden, 1 fehlgeschlagen** –
`test_prologue.gd::test_migration_v3_to_v4` (vorbestehend seit vor M1, Rarity-Fixture; nicht angefasst).
`tools/check_project.ps1`: OK (Import + 300 Frames, keine Fehler/Warnungen).

## Offene M3-Abhängigkeiten

1. Trial-Session auf den neuen Karten: `begin_trial` beim Betreten bzw. Verlassen, Karten in `trial_map_ids`, Rückkehr bei
   Erfolg/Tod/Abbruch (Rückkehrregel aus Audit §C.2); `whispering_stone` danach aus `trial_map_ids` entfernen.
2. Übungen im Trainingsbereich, Mini-Boss-Encounter im Prüfungsbereich, Sperre am `TrialGate`.
3. Trial-Ziele mit Varianten-Kill (Audit §F), Drop-/XP-Politik, Flask, Loadout-Entscheidungen.
4. Ablösung der regulären Pedestale, danach Dev-Karte.
5. Ortsanzeige auf Trial-Karten (zeigt den Resume-Ort).

## Ausdrücklich unverändert

M1-Regeln (`can_choose`, `choose_starting_class`, `resettle`), Pedestale/`TrialStation`, `trial_map_ids`, Trial-Ziele,
Gegner/KI, Drops/Mastery/Evolution, Hearth Flask, Loadouts/Builds, Magic-Belohnung, Grove-Warden-Rare, NPC-Abgaben,
Quest-Gold, Waffenfamilien-/Schildrechte, Story-Daten, `SaveSystem.VERSION`/Migrationen, `project.godot`.
