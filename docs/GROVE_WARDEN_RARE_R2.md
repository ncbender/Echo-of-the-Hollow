# Grove Warden Rare · R2: Boss Entitlement & Warden's Cache

Branch `dev/grove-warden-rare-r2` von `dev/grove-warden-rare-r11` @ `9d8e227`. Save bleibt **v15**: keine neuen Felder, keine
Migration, keine Neuwürfe. Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.
Grundlage: `docs/GROVE_WARDEN_RARE_REWARD_1_0_AUDIT.md`, `docs/GROVE_WARDEN_RARE_R1.md`, `docs/GROVE_WARDEN_RARE_R11.md`.

## 1. Flags und abgeleiteter Anspruch

| Fakt | Speicherung | Schreiber |
|---|---|---|
| Boss besiegt | `world.flags["defeated.whisper_forest_grove_warden"]` (vorhanden, bool) | nur `GameMap._on_persistent_enemy_defeated` (unverändert) |
| Rare erhalten | **neu:** `world.flags["boss_reward.whisper_forest_grove_warden"] = true` | nur `BossRewardService.hand_over`, direkt nach `Inventory.add_instance` |
| Anspruch offen | **abgeleitet**: besiegt ∧ nicht erhalten (`BossRewardService.has_claim`) | wird nie gespeichert |

- Das Claim-Flag ist `bool true`. Eine Instanz-ID als String-Wert war geplant (Audit §3.2), geht aber nicht:
  `WorldState.has_flag` vergleicht `flags[flag] != false`, und das wirft bei String-Werten in GDScript 4 einen Laufzeitfehler
  (im ersten Testlauf gefunden). `WorldState` bleibt unverändert.
- `world.flags` nimmt beliebige Keys auf. `WorldState.to_dict/from_dict` speichert das neue Flag mit der v15-Struktur, also
  braucht es **keine Save-Version**.
- Der Service ist generisch (`boss_id` + `EquipmentLootTable`). Die Werte stehen am Szenenknoten, es gibt keinen bossspezifischen
  Code.

## 2. Boss-Kill und Meilenstein-Save
- Der Kill-Pfad ist unverändert: `HealthComponent.died` (einmal pro Leben) → `Enemy.defeated` → `GameMap` setzt das Defeat-Flag.
- `WorldState.set_flag` sendet `flag_changed` nur bei einer echten Änderung. `BossRewardCache._on_flag_changed` fordert genau
  dann **einen** `request_critical_save("boss defeated …")` an. Das passiert erst **nach** dem Setzen des Flags, und der
  `SaveCoordinator` schreibt frühestens im nächsten Frame. Der Snapshot enthält das Flag also sicher (Test: Save-Datei neu
  geladen, Flag vorhanden).
- Ein wiederholtes `defeated`, ein weiterer tödlicher Treffer oder ein geladener Stand mit Flag ändert nichts mehr, also
  folgt auch kein zweiter Save.
- Nur Bosse mit einem Cache-Knoten lösen den Save aus, heute also nur der Grove Warden. Normale Gegner und andere persistente
  Gegner bleiben ohne Save.
- Die festen Drops (1 `hollow_essence`, 2 `iron_ore`, 25 `gold_coin`) sind unverändert. Sie bleiben transiente Pickups, werden
  weder eingesammelt noch als erhalten markiert und sind nicht Teil des Saves (wie bisher).
- **Spielende vor dem erfolgreichen Save:** Flag und Bodenbeute gehen gemeinsam verloren. Nach dem Laden lebt der Boss wieder,
  es gibt keinen Anspruch, und nichts dupliziert sich. Das Fenster ist jetzt nur noch ein Frame plus Schreibzeit. Schlägt das
  Schreiben fehl, wiederholt der Koordinator es nach 5 s (bestehendes Verhalten).

## 3. Warden's Cache
- Knoten `WardensCache` (`BossRewardCache`, `scripts/world/boss_reward_cache.gd`) in `scenes/maps/whisper_forest.tscn` bei
  (240, 100), neben dem Bossplatz (Warden bei (260, 120)). Exporte: `boss_id = whisper_forest_grove_warden`,
  `loot_table = data/loot/grove_warden_rare_reward.tres`, `label = "Warden's Cache"`.
- Muster wie `StoryPickup` (eine `Interactable`-Schwesterklasse): Sichtbarkeit live über `flag_changed`. Unsichtbar heißt
  nicht interagierbar (`Interactable.find_active` prüft `is_visible_in_tree`).
- **Sichtbar genau dann, wenn** `has_claim`. Das gilt auch vor der Klassenwahl, nach einem Kartenwechsel, nach Save/Load und in
  alten Ständen mit Defeat-Flag. Eine volle Tasche oder eine laufende Trial blendet ihn nicht aus.
- Platzhalter-Optik nur per `_draw`: eine dunkle Truhe mit Beschlägen in Rare-Gold, sanftem Puls und `WorldText`-Label. Es gibt
  keine neuen Assets, keine Mailbox, keinen NPC, keine Quest, und es entsteht kein World-Pickup.

## 4. Claim-Ablauf (`BossRewardService.claim`)
1. Defeat-Flag fehlt → „The cache is sealed.“
2. Bereits erhalten → „The cache is empty.“
3. `character.classes.in_trial()` → „Finish or leave the current trial first.“
4. Kapazität: `room_for(model) ≥ 1` für **jedes** der zwölf Modelle. Das Modell steht vor dem Wurf noch nicht fest, alle sind
   1-Slot-Items. Sonst → „Your bag is full. Make room to open the cache.“
5. Erst jetzt **ein** `EquipmentLoot.roll(grove_warden_rare_reward)`: Modell, Rare, ilvl 20, Herkunft `found`. Es gibt keinen
   neuen Roller.
6. `hand_over`: `Inventory.add_instance(item)`, **danach** das Claim-Flag.
7. Der Cache fordert einen Meilenstein-Save an (`boss reward …`) und blendet sich aus.

**Zeitpunkt des RNG-Wurfs:** nur beim erfolgreichen Claim, nie beim Kill. Bei einer Ablehnung wird der RNG nicht angefasst
(Test: `rng.state` unverändert). Der Cache hat ein eigenes, zufällig geseedetes `rng`.

**Volle Tasche:** kein Wurf, keine Instanz, kein Flag, keine Weltbeute. Es kommt die Meldung über `hud.notify`, der Cache bleibt.
Ist wieder Platz in der Tasche, klappt genau ein Claim.

**Fehlerpfad `add_instance`:** Er ist praktisch unerreichbar, weil die Kapazität vorher geprüft wird und die ID frisch aus dem
CSPRNG kommt. Trotzdem ist er abgesichert: Ohne Flag wird die Instanz verworfen (sie existierte nur im Speicher), der Anspruch
bleibt offen. Getestet mit einer doppelten und einer leeren Instanz-ID.

**Wiederholsicherheit:** Tasche und Flag ändern sich im selben synchronen Aufruf ohne Code dazwischen. Der `SaveCoordinator`
macht den Snapshot in einem eigenen Frame und sieht also beides oder keines. Weder ein zweites Interagieren, ein Kartenwechsel,
Save/Load noch ein Doppel-Callback erzeugen ein zweites Item.

**Restrisiko:** Bei einem Absturz zwischen Claim und Meilenstein-Save gehen Item und Flag gemeinsam verloren. Der Anspruch ist
dann wieder offen, und der nächste Claim würfelt **neu**. Ein Duplikat entsteht nicht. Wer gezielt einen älteren Slot lädt,
kann vor dem Claim neu würfeln (systembedingt, wie bei M4).

## 5. Altstände (Rückwirkung)
- Hat ein v1–v15-Stand `defeated.whisper_forest_grove_warden` und kein Claim-Flag, ist der Anspruch automatisch offen. Das gilt
  auch vor der Klassenwahl. Das Defeat-Flag ist authentisch: Es hat einen einzigen Schreiber, und keine Migration setzt es.
- Kein Anspruch ohne Flag, bei einem Flag mit Wert `false` und nach einem Claim.
- Es gibt keine Heuristik aus Quests, Klasse, Kartenbesuchen oder Inventar und keine Migration. Alte Rares werden nie neu
  gewürfelt. Echte Saves wurden nicht geöffnet.
- Auch Entwicklungsstände mit besiegtem Warden bekommen einen offenen Anspruch (bewusst, Audit E5/R1).

## 6. Loot-Feed und Instanz-Rarity
- Der zentrale Fehler: `PlayerProgressionBridge.item_received` trug nur `item_id`/`quantity`, deshalb zeigte `LootFeed` die
  **Definitions**-Rarity. Ein Rare-`wanderer_coat` erschien so als „Magic“. Dasselbe galt schon für reguläre Equipment-Drops,
  deren Instanz-Rarity von der Definition abweicht.
- Korrektur: Das Signal hat jetzt einen dritten Parameter `item: ItemInstance`, der für einfache Pickups `null` ist.
  - `ItemPickup` übergibt seine Instanz.
  - `LootFeed.push(item_id, quantity, item = null)` liest `item.effective_rarity(definition)` für Farbe, Rarity-Wort und
    Icon-Pips (`ItemIcon.rarity`).
  - Ohne Instanz bleibt es wie bisher bei der Definitions-Rarity (Galerie-Aufrufe mit zwei Argumenten funktionieren
    unverändert).
- Der Cache meldet Erfolg auf zwei Wegen:
  - Feed-Zeile über `item_received` mit der Instanz
  - Toast „Warden's Cache: <Name> (Rare)“ über `hud.notify`

  Es gibt keine neue Notification-Engine.
- Unverändert: Verkauf und Salvage lesen weiter die Definitions-Rarity (offener Punkt der Loot Foundation, nicht Teil von R2).

## 7. Beispiel-Rolls (`BossRewardService.claim`, feste Seeds)
| Seed | Item | Affixe |
|---|---|---|
| 7 | iron_mace, Rare, ilvl 20, Basis 18,420, found | Swift T4 +3 Attack Speed · Vital T5 +4 Max Health · Bloodthirsty T5 +1 Life on Hit |
| 21 | oak_staff, Rare, ilvl 20, Basis 15,964, found | Keen T5 +0,5 Crit · Cruel T5 +4 Crit Dmg · Executioner T5 +5 Finisher · Furious T5 +4 Resource Gain |

## 8. Tests
Neue Suite `tests/integration/test_grove_warden_reward.gd` mit 12 Tests. Sie nutzt synthetische Charaktere und feste Seeds.
Dateien entstehen nur unter `user://test_saves/grove_warden_r2/` und werden danach gelöscht.

| Auftrag # | Test |
|---|---|
| 1 | `test_no_claim_before_the_kill` (auch Flag `false`); Kartentest: Cache unsichtbar, `open` abgelehnt |
| 2, 3, 4, 5, 25 | `test_kill_saves_once_and_opens_the_cache`: echter tödlicher Treffer in `whisper_forest`, Flag, genau 1 Meilenstein-Save (Datei enthält das Flag), Cache sichtbar, Bodenbeute = feste Drops ohne Equipment, erneutes `defeated` + Treffer → kein zweiter Save, kein Claim-Flag |
| 6, 24, 23 (Feed) | `test_cache_survives_map_changes_and_claims_once_with_a_rare_feed_row`: zwei Kartenwechsel mit offenem Anspruch (nichts verloren), Claim über `interact`, Feed-Zeile Rare (Farbe, Wort, Pips), einfache Zeile weiter Definitions-Rarity, nach dem Neuladen kein Cache, kein Warden, kein zweiter Claim |
| 7, 16, 27, 28 | `test_claim_before_class_choice_gives_one_rare_found_level_20` (basic_adventurer, M4-Zustand und Klasse unverändert) |
| 8, 9, 10 | `test_full_bag_rolls_nothing_and_keeps_the_claim` (RNG-Zustand unverändert) · `test_full_bag_keeps_the_cache_in_the_world` (keine Weltbeute) |
| 11, 12, 30 | `test_item_and_claim_flag_share_one_snapshot_through_save_and_load` |
| 13, 14 | `test_old_saves_get_the_claim_only_with_a_real_defeat_flag` (v14-Payload über `SaveMigrations`, keine Heuristik) |
| 15 | `test_trial_blocks_the_claim` |
| 17–22 | `test_reward_rolls_follow_the_existing_table_and_roller`: 60 Seeds, Gleichheit mit `EquipmentLoot.roll`, nur Pool-Affixe, T4/T5, 3 und 4 Affixe erreicht, kein Thundering auf Waffen, Keen auf Rüstung, keine Essenzen |
| 23 | `test_wanderer_coat_is_a_rare_instance_and_the_feed_says_rare` |
| 29 | `test_failed_hand_over_keeps_the_claim_and_duplicates_nothing` |

| Suite | Ergebnis |
|---|---|
| grove_warden_reward (neu) | 12/12 grün |
| grove_warden_rare_pool, hollowwood_loot, loot_foundation, save, hud, economy, class_trials_m4, world | 86/86 grün |
| `check_project.ps1` | OK |

Der bekannte Altfehler `test_migration_v3_to_v4` (Suite `prologue`) ist nicht aufgetreten, weil die Suite nicht lief.
Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-/Haven-/Crafting-/Klassen-Playtests, Arena, Galerie.

## 9. Restrisiken und offene Abnahme
- **Visuelle Abnahme:** Die Cache-Optik (Platzhalter-Truhe, Label, Puls) und die Feed-Zeile wurden nur headless geprüft, nicht im
  Fenster.
- Der Claim nach einem Absturz vor dem Meilenstein-Save würfelt neu (§4). Das ist kein Duplikat.
- `oak_shield` können Klassen ohne `can_use_shields` nicht tragen (akzeptiert). `furious` wirkt erst nach der Klassenwahl.
- Der Kill-Save hängt am Cache-Knoten. Ein künftiger Boss ohne Cache bekommt keinen Kill-Save, was beabsichtigt ist.
- Ein manuell editierter Save kann das Defeat-Flag fälschen. Für ein Einzelspielerspiel ist das akzeptabel.

## 10. Unverändert
Bosswerte, Bossphasen und feste Bossdrops, `GameMap`, `Enemy`, `WorldState`, `SaveSystem`/`SaveCoordinator` (nur benutzt),
Save-Version 15, Migrationen, `EquipmentLoot`, `ItemCreation`, `AffixRoller`, Affixe, Tiers, Reward- und Tier-Tabelle, alle
regulären Loot-Tabellen, Class Trials und M4-Klassenbelohnung, Quests, NPCs, `StoryPickup`.
