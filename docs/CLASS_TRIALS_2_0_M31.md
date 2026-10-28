# Class Trials 2.0 – M3.1: Trial Polish & Boss Correction

Stand: 2026-10-28 · Branch `dev/class-trials-20-m31` (von M3 `c9010bb`) · Save **v14 (unverändert)**
Grundlage: `docs/CLASS_TRIALS_2_0_M3.md`, `docs/CLASS_TRIALS_2_0_TECH_AUDIT.md`.

## Sanctum Warden: Abweichung und Korrektur

**Vorher (M3):** `data/enemies/sanctum_warden.tres` kopierte die Werte von `grove_warden_config.tres` (Tempo 70,
Knockback-Resistenz 1,0, Bleed-Resistenz 0,5, Slow-Cap 0,25, Parry-Poise ×0,3, Parry unterbricht nicht; HP/Poise
90/35 aus `grunt.tscn`), und die Szene gab ihm die Grove-Warden-Klauen (`grove_warden_attacks.tres`, Slam weder block-
noch parierbar). Das wich vom freigegebenen Design ab.

**Nachher (M3.1):** `sanctum_warden` übernimmt jeden Kampfwert unverändert aus `data/enemies/hardened_husk.tres`
(160 HP / 70 Poise, Tempo 50, Aggro 240, Cooldown 1,2, Heavy jede 2. Attacke, Knockback-Resistenz 0,5, Körper/Farbe),
also dieselben Werte wie `bastion_guardian`. Die Angriffe sind die Grunt-Angriffe der Husk (`grunt_attacks`, `grunt_claws`;
Slam blockbar, parierbar, guard-breaking) – kein eigenes `attacks` am Spawn mehr (`scenes/maps/trial_arcanist.tscn`).
Erhalten: ID `sanctum_warden`, Rang 2 (Boss-Balken), keine Drops, Mastery-/Klassen-XP 0, Finale-Ziel
„Defeat the Sanctum Warden“ (Text ohne den nicht mehr zutreffenden Hinweis auf den unblockbaren Slam).

Der echte Grove Warden (`grove_warden_config.tres`, `grove_warden_attacks.tres`, Knoten `GroveWarden` in
`whisper_forest.tscn`) ist unverändert. `EncounterSpawn.attacks` / `GameMap.spawn_enemy(..., attacks)` bleiben als
optionale, derzeit ungenutzte Schnittstelle bestehen.

## Arcanist-Wolfsbegleiter – begrenzt offen

> **Erledigt in M3.1b** (Abschnitt „M3.1b – Arcanist-Finale in zwei Phasen“ unten). Ursprünglicher Stand:

Das Arcanist-Finale hatte schon in M3 **keine** Wölfe (nur der Boss; im Training 2× `rootbound_husk`). Eine
vorhandene, direkt passende Arcanist-Finale-Konfiguration mit Wölfen existiert nicht; die Wolfsgruppen im Projekt
(`veiled_passage` Finale: 2 Wölfe um den Alpha; `whispering_stone` `SideWolves`: 2 Wölfe) gehören zu anderen Zwecken.
Anzahl und Zusammensetzung wären eine eigene Festlegung → **nicht umgesetzt, Designentscheidung offen**
(z. B. „2 `hollowfang_wolf` wie im Veiled-Passage-Finale“).

## Passage Alpha – unverändert

`passage_alpha` = alle Kampfwerte von `hollowfang_wolf` (50 HP, 20 Poise, Tempo 100, Cooldown 1,2, kein Heavy,
Knockback-Resistenz −0,3), Rang 2, keine Drops/XP, im Finale mit zwei `hollowfang_wolf`. Keine Abweichung gegenüber M3.

## Trank- und Flask-Regeln (bestätigt, unverändert implementiert)

- Inventartränke: während eines laufenden Trials gesperrt (`ConsumableService.potion_error`, Bedingung
  `classes.in_trial()`); kein Verbrauch, Menge unverändert; die Ablehnung erscheint über den bestehenden Weg
  `PlayerProgressionBridge.try_use` → `message` (HUD-Meldung). Außerhalb eines Trials unverändert.
- Hearth Flask: im Trial nutzbar; Ladungen beim Trial-Start gemerkt (`PrologueState.trial_flask_charges`, transient),
  von `PrologueService.end_trial` bei Erfolg, Tod und Abbruch wiederhergestellt; `Character.to_dict` schreibt während
  eines Trials die Ladungen von vor dem Trial.

## Tests

Neue Suite `tests/integration/test_class_trials_m31.gd` (5 Tests, echte Kartenwechsel, Saves nur unter `user://test_saves/`):
- `test_sanctum_warden_follows_the_hardened_husk_reference`: ID, Rang, alle Kampfwerte == `hardened_husk`, keine Drops/XP,
  Finale nur der Warden ohne eigene Angriffe; Grove-Warden-Config und Whisper-Forest-Knoten unverändert. (1–4)
- `test_arcanist_finale_only_by_a_real_warden_kill_and_flask_restored`: Kill eines Trainings-Husk und des Wardens mit
  **echten Arcane-Bolt-Würfen** (Skill → Projektil → Trefferpfad → Bridge); Fehlgegner schließt nichts ab, genau ein
  Abschlusssignal und ein `trial_complete`, Grunt-Klauen, 160/70; Flask nach Erfolg wiederhergestellt. (5, 7, 11, 12)
  Testvorbereitung: nur die aktuelle HP des Ziels wird auf 1 gesetzt, kein Ziel wird von Hand erfüllt.
- `test_passage_alpha_and_its_pack_unchanged`: 50 HP, Werte == Wolf, Alpha + 2 Wölfe, Encounter erst mit dem Alpha geräumt,
  Wölfe schließen den Trial nicht ab. (6, 8)
- `test_potions_sealed_only_inside_a_trial`: Trank im Trial abgelehnt (Menge gleich, Meldung), Flask nutzbar, nach Verlassen
  Trank normal getrunken. (9, 10, 11)
- `test_flask_restored_after_death_and_leaving_and_never_saved_spent`: Save während des Trials mit Ladungen von vorher,
  Wiederherstellung nach Tod und Abbruch. (12, 13)
- 14/15 (keine Trial-Drops/-XP, reguläre Drops): weiterhin `test_class_trials_m3::test_no_drops_or_xp_inside_but_outside_unchanged`.
- Angepasst: `test_class_trials_m3` erwartet für den Arcanist-Boss jetzt `grunt_claws`.

Lauf `class_trials_m31, class_trials_m3, class_trials_m2, class_trials_m1, shrine, prologue, story, world, consumables,
hollowwood_loot, enemy, evolution, mastery, pickup`: **114 bestanden, 1 fehlgeschlagen** –
`test_prologue.gd::test_migration_v3_to_v4` (bekannter Altfehler, Rarity-Fixture; nicht angefasst). Keine Zufallstests.

## Weiterhin ungeprüfte Spielbalance

- Sanctum Warden = Bastion Guardian in den Werten: zwei Klassen haben jetzt denselben Boss-Stat-Block; Wirkung gegen den
  Level-12-Arcanist ungespielt.
- Arcanist-Finale ohne Wolfsdruck (offene Designentscheidung, s. o.).
- Passage Alpha mit 50 HP vermutlich zu schwach für einen Mini-Boss (bewusst unverändert).
- Kein manuelles Durchspielen mit echter Eingabe gegen die KI.

## Ausdrücklich unverändert

`bastion_guardian`, `passage_alpha`, alle Trainingsziele, Gate, Erfolg/Abbruch/Tod, Klassenwahl, Rückkehr/Save-Ort,
temporäre Schichten, XP-/Loot-Sperre, Grunt-/Wolf-Drops, der echte Grove Warden, Story/Quests, Consumable-Code,
Save-Version/Migrationen, `project.godot`, `docs/Design/`, `docs/tasks/`.

## M3.1b – Arcanist-Finale in zwei Phasen

Stand: 2026-10-28 · Branch `dev/class-trials-20-m31b` (von `f941b87`) · Save **v14 (unverändert)**

### Beschlossener Ablauf (umgesetzt)

1. Training und Gate wie bisher (2× `rootbound_husk` je Welle, Ziele Mana/Arcane Bolt/Mark/Detonation) – unverändert.
2. **Phase 1:** Betritt der Spieler bei offenem Gate den Triggerradius (130 px um `Finale`), startet die Encounter
   `Vanguard` (`trial_arcanist_vanguard`): genau zwei `hollowfang_wolf` (`WolfA`/`WolfB`, ±70 px, wie im Veiled-
   Passage-Finale). Der `sanctum_warden` ist nicht gespawnt.
3. **Phase 2:** Fällt der zweite Wolf (echter `Enemy.defeated` → `Encounter._on_enemy_defeated` → `cleared`), startet
   `TrialGrounds._on_vanguard_cleared` die bestehende Encounter `Finale` genau einmal: der Warden allein, ohne weitere
   Wölfe (`Vanguard.done` verhindert jeden Neustart in diesem Besuch).
4. **Abschluss:** unverändert nur über das Finale-Ziel „Defeat the Sanctum Warden“ (`KILLS`/`sanctum_warden`) im
   Trefferpfad der Bridge → `PrologueService.record` → `end_trial(true)`. Wolfs-Kills treffen kein Ziel.

### Verwendete Mechanik (keine neue Architektur)

- Zwei gewöhnliche `Encounter`-Knoten (`Vanguard`, `Finale`, beide `persistent = false`) in
  `scenes/maps/trial_arcanist.tscn`; `Encounter` selbst ist unverändert.
- `TrialGrounds` (`scripts/world/trial_grounds.gd`) bekommt einen optionalen Export `vanguard: Encounter`:
  - im Triggerradius startet zuerst die Vanguard, solange sie in diesem Besuch nicht geräumt ist; das Finale wartet;
  - `vanguard.cleared` → `finale.start()` (nur bei aktivem Trial, ohne laufende Rückreise, Finale nicht schon aktiv);
  - danach gilt die bisherige Regel „Finale kommt zurück, falls es fällt, bevor das Ziel erfüllt ist“.
  Ohne `vanguard` (Warrior, Shadowrunner) ist der Ablauf Zeile für Zeile der alte. Keine allgemeine Phasen-Engine.

### Werte

- Wölfe: `data/enemies/hollowfang_wolf.tres` unverändert (50 HP, 20 Poise, Tempo 100, Cooldown 1,2, kein Heavy,
  Knockback-Resistenz −0,3; reguläre Wolf-Drops/-XP werden auf Trial-Grounds über `PrologueService.rewards_blocked`
  wie bisher gesperrt).
- Warden: wie M3.1 (= `hardened_husk`: 160 HP / 70 Poise, Tempo 50, Grunt-Angriffe), keine Drops/XP.

### Cleanup, Neustart, Save

- Abbruch (Ausgang `ToHeart`) und Tod (Rückkehr zum Altar) wechseln die Karte; alle Gegner sind Kinder der Karte und
  verschwinden mit ihr – in Phase 1 und Phase 2. Kein eigener Cleanup-Code.
- Jeder neue Start lädt die Karte neu: frische Encounter (`done = false`), Training offen, Gate zu, Phase 1 von vorn.
- Nichts der beiden Encounter wird gespeichert (nicht persistent: kein `encounter.<id>`-Flag). Ein Save während
  des Trials enthält keinen laufenden Trial (Ladepunkt Altar, M2/M3-Regel). Hinweis: `StoryService.notify` zählt wie
  bei jeder Encounter (auch den Trainingswellen) das Ereignis `count.encounter:trial_arcanist_vanguard` im
  `WorldState` – ein reiner Zähler ohne Wirkung auf den Ablauf, kein Finale-Zustand.

### Tests (gezielt)

`tests/integration/test_class_trials_m31.gd`:
- `test_sanctum_warden_follows_the_hardened_husk_reference` (erweitert): Vanguard = genau 2× `hollowfang_wolf`
  ohne eigene Angriffe, `TrialGrounds.vanguard` gesetzt; Warrior/Shadowrunner ohne Vanguard. (13)
- `test_arcanist_finale_only_by_a_real_warden_kill_and_flask_restored` (angepasst): erst beide Wölfe per Arcane Bolt.
- neu `test_arcanist_finale_wolves_first_then_the_warden_alone`: 2 Wölfe mit Wolfswerten, kein Warden, Finale nicht
  gestartet; erster Wolf (Arcane Bolt) → kein Warden; zweiter → genau ein Warden, `Finale.started` genau 1×; 90 Frames
  im Radius: weiter ein Warden, keine Wölfe, keine weiteren Starts; Wolfs-Kills schließen nichts ab; Warden-Kill per
  Arcane Bolt → genau ein Abschluss, ein `trial_complete`, keine Pickups, keine Klassen-/Mastery-XP, Inventar gleich,
  keine Klassenwahl. (1–7, 12)
- neu `test_arcanist_finale_leaving_death_and_saving_mid_fight`: Save in Phase 1 und Phase 2 (nur `user://test_saves/`)
  ohne laufenden Trial und ohne Cleared-Flags; Abbruch in Phase 1 und 2 → Gegnerinstanzen ungültig; Neustart: Training
  offen, keine Finale-Gegner vor dem Gate, wieder Phase 1 mit 2 Wölfen; Tod in Phase 2 → kein Abschluss. (8–11)
- `test_class_trials_m3::test_each_trial_runs_on_its_grounds` (angepasst): bei einer Vanguard erst kein Boss, dann die
  zwei Vanguard-Gegner über den echten Todespfad töten, danach der Boss wie bisher.

Lauf `class_trials_m31, class_trials_m3, class_trials_m2, shrine, prologue`: **36 bestanden, 1 fehlgeschlagen** –
`test_prologue.gd::test_migration_v3_to_v4` (bekannter Altfehler, Rarity-Fixture; nicht angefasst).
`tools/check_project.ps1`: OK (keine Fehler/Warnungen).

### Weiterhin ungeprüfte Balance

- Zwei Wölfe (Tempo 100, Nahkampfdruck) gegen den Level-12-Arcanist mit Fernkampf-Kit, danach 160-HP-Warden ohne Pause:
  Gesamtlänge und Flask-Verbrauch ungespielt.
- Der Warden erscheint sofort beim Tod des zweiten Wolfs an seinem festen Punkt (0, −60 relativ zu `Finale`) –
  keine Atempause, kein Telegraf; Feel offen.
- Kein manuelles Durchspielen mit echter Eingabe gegen die KI.

### Ausdrücklich unverändert (M3.1b)

`Encounter`, `EncounterSpawn`, `GameMap.spawn_enemy`, `hollowfang_wolf`, `sanctum_warden`, `bastion_guardian`,
`passage_alpha` (50 HP), Warrior-/Shadowrunner-Karten, Trainingswellen und -ziele, Gate, `PrologueService`
(Erfolg/Abbruch/Tod, Klassenwahl, Flask-Wiederherstellung, Trank-Sperre, Reward-Sperre), Save-Version v14,
Grove Warden, Hollowwood-Loot, Story/Quests, `project.godot`, `docs/Design/`, `docs/tasks/`.
