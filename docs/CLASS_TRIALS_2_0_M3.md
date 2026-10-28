# Class Trials 2.0 – M3: Spielbare Klassenprüfungen

Stand: 2026-10-28 · Branch `dev/class-trials-20-m3` (von M2 `13cef12`) · Save **v14 (unverändert, keine neuen Felder)**
Grundlage: `docs/CLASS_TRIALS_2_0_TECH_AUDIT.md`, `docs/CLASS_TRIALS_2_0_M1.md`, `docs/CLASS_TRIALS_2_0_M2.md`.

## 1. M2-Abnahme (visuell, echtes Fenster)

Mit einem Scratch-Skript (`SceneTree`, **mit Fenster**, Vulkan) wurden alle drei Karten geladen, der Spieler per
`InputFrame` nach Norden bewegt und Screenshots angesehen (Spawn, Übersicht mit eigener Kamera, Durchgang, Nordwand).
- In Ordnung: zwei klar getrennte Bereiche, Trennwand mit Durchgang, sichtbare Begrenzung, Ausgang im Süden erreichbar.
- Behoben: schwarzer Streifen im Durchgang (`TrialFloor` deckte y −48…−40 nicht ab → Fläche bis −32 verlängert);
  Spawn lag direkt am Ausgang, dessen Beschriftung den Spieler überdeckte (Spawn/Player 250 → 220).
- M3 im Fenster: laufende Prüfung je Klasse aufgenommen (Trainingswelle, HUD, Skillleiste der Trial-Klasse, nach dem
  Training offenes Gate, Boss-Balken). Die Trainingsziele wurden dabei per `PrologueService.record` gesetzt – **kein**
  manuelles Durchspielen mit echter Eingabe (siehe §10).

## 2. Session- und Klassenvertrag

| Schritt | Umsetzung |
|---|---|
| Start | `ClassChoicePanel.begin(class)` (Knopf **„Begin the trial“**) → `can_visit_grounds` (= `can_begin_trial` + Karte) → keine laufende Reise → `PrologueService.begin_trial` → `SessionState.travel(trial.map_id, entry_spawn_id)`; Reise abgelehnt ⇒ `end_trial(false)` sofort (kein verwaister Trial) |
| Vorschau | **„Visit the trial grounds (preview)“** (M2) bleibt: keine Session → `TrialGrounds` startet nichts, Gate zu, `record` zählt nichts |
| Temporäre Klasse | unverändert die bestehenden Schichten: `CharacterClasses.trial_class_id/level`, `ClassBuilds._trial`, `CharacterEquipment._trial_loadout` (Referenzkopie). Keine zweite Klassenlogik |
| Trial-Karten | `ProgressionRules.trial_map_ids = [broken_bastion, shattered_sanctum, veiled_passage, prologue]`; `GameDatabase` prüft, dass jede Trial-Karte darin steht |
| Grounds | neuer Knoten `TrialGrounds` (`scripts/world/trial_grounds.gd`) je Karte: Trainings-Encounter, Finale-Encounter, Gate, Rückkehr. Fremder Trial auf diesen Grounds → `end_trial(false)` + Rückkehr |

Permanente Klasse, Freischaltungen, Builds und Loadouts werden nie geschrieben; `prologue.chosen_class` nur in
`choose_starting_class` (unverändert).

## 3. Trainingsziele je Klasse (nur bestehende Objective-Arten und Mechaniken)

`TrialObjective.finale` (neu, Default `false`) trennt Training von Prüfung.

| Trial | Training (öffnet das Gate) | Finale (Prüfungsbereich) |
|---|---|---|
| Warrior – Broken Bastion | 50 Rage · 2 Furious-Strike-Treffer · **3 Rootbound Husks besiegen** (neu, KILLS mit Variante) | Poise-Break `bastion_guardian` · Kill `bastion_guardian` |
| Arcanist – Shattered Sanctum | 4 Zauber · 2 Arcane-Bolt-Treffer · 2 Arcane Marks · 2 Detonationen (bestehend) | Kill `sanctum_warden` |
| Shadowrunner – Veiled Passage | 40 Focus · Shadowstep · 2 Weak Points · 1 Execution (bestehend) | Kill `passage_alpha` |

Trainingsgegner (bestehende Varianten, Encounter `*_training`, nicht persistent): Warrior/Arcanist 2× `rootbound_husk`,
Shadowrunner `hollowfang_wolf` + `rootbound_husk`. Solange Trainingsziele offen sind, kommt nach jeder geräumten Welle eine neue.

Bewusst **nicht** umgesetzt: „Ausweichen“ als Ziel (kein Ereignis im Combat, Audit §F.3) und eine zeitlich begrenzte
Überlebensphase (kein Timer-Objective) – Warrior „hält die Bastion“ über drei Kills.

## 4. TrialGate

`TrialGate` (`scripts/world/trial_gate.gd`, erbt `WallBlock`) im Durchgang der Trennwand:
- offen genau dann, wenn `PrologueService.training_done(character, trial_id)` (laufender Trial **dieser** Karte, alle
  Nicht-Finale-Ziele erfüllt); sonst massive Wand (Kollision aktiv, pulsierender Rand).
- kein eigener Zustand, nie gespeichert; Vorschau/Abbruch/Fehlschlag/Neustart ⇒ automatisch zu.
- getestet: der Spieler läuft gegen das geschlossene Gate und bleibt davor; nach dem Training läuft er hindurch.

## 5. Mini-Bosse und Variantenkennungen

Drei neue `EnemyConfig`-Varianten mit **unveränderten** Kampfwerten bestehender Gegner, eigener ID, Rang „Boss“
(nur Anzeige: Boss-Balken), ohne Drops, Mastery- und Klassen-XP 0:

| ID | Werte von | Angriffe | Encounter |
|---|---|---|---|
| `bastion_guardian` | `hardened_husk` | Grunt (Guard-Break-Slam) | allein |
| `sanctum_warden` | `grove_warden_config` | `grove_warden_attacks` (Slam weder block- noch parierbar) | allein |
| `passage_alpha` | `hollowfang_wolf` | Grunt | + 2 `hollowfang_wolf` |

- Kill-Ereignisse melden jetzt die Variante: `PlayerProgressionBridge._on_hit_dispatched` → `KILLS` mit `config.id`
  (Ziele ohne `target_id` zählen weiter jeden Kill – Klassenquests unverändert kompatibel).
- `EncounterSpawn.attacks` (neu, optional) und `GameMap.spawn_enemy(at, config, attacks)` für die Warden-Klauen.
- Der Finale-Encounter startet erst bei offenem Gate und Spielernähe (`trigger_radius` 130); fällt der Boss, bevor alle
  Finale-Ziele erfüllt sind (z. B. Warrior ohne Poise-Break), erscheint er erneut.
- Grunt-Basis (`grunt.tscn`): 90 HP / 35 Poise. Korrektur zum Audit §F, dort stand 100/40.

## 6. Erfolg, Tod, Abbruch

| Fall | Ablauf |
|---|---|
| Erfolg | letztes Finale-Ziel → `PrologueService.record` → `end_trial(true)` (zentral, unverändert) → `trial_finished` → `TrialGrounds.return_to_altar` → `whispering_stone`/`heart`; danach `notify(trial_complete)` (Meilenstein-Save, geschrieben nach der Reise am Altar). Klasse wird **nicht** gewählt; `can_choose` nach M1 |
| Tod | bestehend: Bridge `_on_player_died` → `end_trial(false)` → Rückkehr (vor dem Respawn) |
| Abbruch | Ausgang „Heart of the Stone“ → Altar-Karte ist kein Trial-Map → `GameMap._ready` → `end_trial(false)` |
| Wiederholung | jederzeit am Altar; Fortschritt neu, Gate zu |

`return_to_altar` fordert höchstens eine Reise an (`returning`, `SessionState.travel` blockt Doppelanfragen).

## 7. XP, Loot, Flask, Loadouts

- **Eine** Regel: `PrologueService.rewards_blocked(character)` = laufender Trial **oder** physische Karte ist Trial-Grounds.
  Gefragt von: `GameMap._spawn_drops` (feste Drops + Equipment), `CombatRewardTracker._on_hit_landed`/`reward_kill`
  (Klassen-, Weapon-Mastery-, Armor-Mastery-XP), Bridge `_on_defended` (Armor-XP), `_grant_item_xp` (Evolution).
  Reguläre Kämpfe unverändert (getestet: Drop außerhalb eines Trials). Gilt auch für Pedestal-Trials der Dev-Karte.
- **Hearth Flask:** benutzbar; `PrologueState.trial_flask_charges` (transient) merkt die Ladungen bei Start, `end_trial`
  stellt sie wieder her (nie über das Maximum), ein Save während des Trials schreibt den Wert von vor dem Trial.
- **Tränke (Items):** während eines Trials gesperrt (`ConsumableService.potion_error`) – kein Item-Verbrauch.
- **Loadouts:** Ausrüsten im Trial ändert nur die Trial-Kopie; echte Loadouts und Inventar bleiben unverändert (getestet).

## 8. Save/Load

- Keine neuen Save-Felder, v14, Migrationen unverändert.
- Save auf Grounds ⇒ Ort `whispering_stone`/`heart` (M2-Resume); Trial-Klasse/Build/Loadout/Fortschritt nie im Save;
  Flask-Ladungen von vor dem Trial.
- Neustart (Laden aus Datei): kein Trial, Basic Adventurer, Altar, Trial erneut startbar (getestet).

## 9. Alte Pedestale, UI, Ortsanzeige

- `whispering_stone.tscn`: die drei `TrialStation`-Pedestale entfernt, `whispering_stone` aus `trial_map_ids`,
  `EchoHint` verweist auf das Heart of the Stone. Einziger Trial-Einstieg: der Altar.
- Dev-Karte `prologue.tscn`: Pedestale bleiben zum Ausprobieren der Klassen, können aber **nie** einen Trial bestehen
  (Finale-Ziele verlangen die Boss-Variante der Grounds; getestet), und geben keine Rewards.
- `WorldState.current_map_id` (transient) = physische Karte; `WorldState.here()` für Pause-Menü und Weltkarte. Der
  gespeicherte Ort (`map_id`) bleibt das Resume-Ziel.
- HUD (`ObjectivePanel`): Trial-Klasse, Trainingsziele, Gate-Status, Finale-Ziele, Abbruch-Hinweis (neue Texte in
  `localization/ui.csv`). Altar-Karten: „Begin the trial“, „Visit the trial grounds (preview)“, „Choose …“.

## 10. Tests

Neue Suite `tests/integration/test_class_trials_m3.gd` (9 Tests, echte Kartenwechsel, Saves nur
`user://test_saves/class_trials_m3/`):

| Test | Abgedeckte Anforderungen |
|---|---|
| `test_each_trial_runs_on_its_grounds` | 1, 2, 3, 5, 6, 7, 8, 9, 10, 17 (alle drei Klassen: Start, Klasse/Level/Skills, permanente Klasse, Gate zu + blockiert, Wellen, kein Boss vor dem Gate, Gate offen + passierbar, Boss-Variante, falsche Gegner, Abschluss, Rückkehr `heart`, Wahl möglich, Snapshot unverändert) |
| `test_preview_starts_nothing` | 4 |
| `test_death_and_leaving_fail_and_allow_a_retry` | 11, 12, 13 |
| `test_no_double_sessions_or_transitions` | 14, 15 |
| `test_no_drops_or_xp_inside_but_outside_unchanged` | 16 |
| `test_flask_potions_inventory_and_loadout_safety` | 17, 18 |
| `test_save_during_a_trial_and_load_after_a_restart` | 19, 20, 21 |
| `test_no_pedestal_shortcut` | 22 |
| `test_location_display_on_the_grounds` | 24 |
| M1-/M2-Suites | 23 |

Kampfereignisse in den Tests: Treffer über `Hurtbox.receive_hit` und `PlayerProgressionBridge._on_hit_dispatched`
(derselbe Pfad wie echte Treffer, wie bisher in `test_shrine`); Trainingsziele über `PrologueService.record`.
Realer Kampf mit Skills ist für den Arcanist in `test_prologue.gd::test_trial_objectives_from_real_combat` abgedeckt.

Ergebnisse:
- `class_trials_m3, class_trials_m1, class_trials_m2, shrine, prologue, story, world, world_ui`: **61 bestanden, 1 fehlgeschlagen**
  (`test_prologue.gd::test_migration_v3_to_v4`, vorbestehendes Rarity-Fixture, unverändert rot seit vor M1).
- direkte Abhängigkeiten der Reward-/Drop-/Trank-Änderungen `consumables, armor_mastery, evolution, hollowwood_loot, mastery, enemy, pickup`:
  **61 bestanden, 0 fehlgeschlagen**.
- `tools/check_project.ps1`: OK (Import + 300 Frames).

Angepasste bestehende Tests (Vertragsänderung M3): `test_class_trials_m2` (Grounds haben jetzt Encounters; fremder Trial endet
auf Grounds mit Rückkehr; Pedestale weg), `test_shrine` (Pedestal-Test ersetzt durch „Trials beginnen nur am Heart of the Stone“),
`test_prologue::test_trial_objectives_from_real_combat` (Training allein besteht nicht mehr, Finale nötig).

## 11. Offene Punkte und Restrisiken

1. **Balancing nicht gespielt:** Boss-Werte sind 1:1 kopiert; `passage_alpha` (50 HP) ist als Boss vermutlich zu schwach,
   `sanctum_warden` (90 HP, Grunt-Basis) gegen Level-12-Arcanist ungetestet. Feel-Test nötig (keine Werte erfunden).
2. **Kein manuelles Durchspielen** mit echter Eingabe gegen die KI; Ziel-Erreichbarkeit mit echten Skills nur für den
   Arcanist (Dummy-Test) und aus den bisherigen Pedestal-Trials belegt.
3. Trainingswellen erzeugen bei jedem Räumen ein Story-Zählerereignis `encounter:<map>_training` (gespeicherter Zähler,
   ohne Wirkung) und die Karten zählen `visits` in `map_states` – harmlos, aber persistente Nebenspuren.
4. Tränke im Trial gesperrt ist eine **neue Regel** (Ressourcenmodell E2) – bitte bestätigen.
5. Ausweich-Ziel (Shadowrunner) und Zeitlimit (Warrior) existieren nicht als Mechanik.
6. Dev-Karte `prologue.tscn`: Pedestal-Trials laufen weiter, ohne Abschluss/Rewards; eine Umstellung auf die Grounds ist offen.

## 12. Ausdrücklich unverändert

M1-Klassenregeln (`can_choose`, `choose_starting_class`), `StoryService.resettle`, Story-Daten (`data/story`),
Waffenfamilien-/Schildrechte, Gegner-KI (`enemy.gd`), globale Drop-/XP-Regeln außerhalb von Trials, Magic-Belohnung,
Grove-Warden-Rare (Original-Warden in `whisper_forest` unverändert), NPC-Abgaben, Quest-Gold, Save-Version und Migrationen,
`project.godot`, `docs/Design/`, `docs/tasks/`.
