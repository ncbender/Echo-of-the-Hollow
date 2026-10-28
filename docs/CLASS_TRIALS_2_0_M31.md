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
