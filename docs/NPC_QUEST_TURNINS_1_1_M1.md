# NPC Quest Turn-ins 1.1 – M1: Mixed Reward Contract

Branch `dev/npc-quest-turnins-11-m1` von `audit/npc-turnins-11-mixed-rewards` @ `1166726` (T3-Code `2f44058` + Audit-Dokument).
Save bleibt **v15**. Grundlage: `docs/NPC_QUEST_TURNINS_1_1_AUDIT.md`, `_1_0_T1.md`–`_T3.md`.

Umfang: nur der Claim-Vertrag in `QuestRewardService`, das optionale Datenfeld und Tests. **Nicht** enthalten: Reward-Daten für
`the_broken_cart`, Maras Zugang (FlaskPanel), Marker, Journal-/Tracker-/Kartentexte, neue Dialoge oder Status.

---

## 1. Datenformat

`StoryQuestDefinition` (`scripts/rpg/quests/story_quest_definition.gd`):

| Feld | Typ | Bedeutung |
|---|---|---|
| `turn_in_gold` | `int` | wie T1 (0 = kein Gold) |
| `turn_in_npc_id` | `StringName` | wie T1 |
| `turn_in_items` | `Array[ItemCost]` | **neu**, optional; vorhandene stapelbare Materialien mit positiver Menge. Leer = Gold-only |

- `QuestRewardService.has_reward(quest)` = `turn_in_gold > 0 or not turn_in_items.is_empty()`. Ersetzt die Bedingung
  `turn_in_gold > 0` in `register_completion`, `can_claim` und `validate_quest`.
- `reward_items(quest)` fasst doppelte Item-IDs zusammen (Datenreihenfolge bleibt).
- `validate_quest` meldet: unbekannte Item-ID, nicht stapelbares Item, Währung als Material (Gold nur über `turn_in_gold`),
  Menge ≤ 0, leerer Eintrag; dazu wie bisher NPC unbekannt / open-ended – jetzt für jeden Reward, nicht nur Gold.
- Gold liegt nie in `turn_in_items`.

Beispiel (M2, noch **nicht** aktiv):
```
turn_in_gold = 30
turn_in_npc_id = &"mara"
turn_in_items = [ItemCost(timber, 3), ItemCost(stone, 2)]
```

## 2. Gesamtkapazität

`QuestRewardService.slots_needed(character, items) -> int` (nur lesend):
- pro Item-ID: Menge minus freier Rest aller vorhandenen Stapel derselben ID; der Rest braucht `ceil(rest / max_stack)` neue Slots
- Summe über alle Materialarten (also nicht wie `Inventory.room_for`, das jede Art gegen dieselben freien Slots rechnet)
- `-1` bei ungültigem Eintrag (unbekannt, nicht stapelbar, Währung, Menge ≤ 0)
- Gold braucht keinen Slot und wird nicht gezählt

`can_claim` vergleicht das Ergebnis vor jeder Gutschrift mit `Inventory.free_slots()`:
- `-1` → `HANDOVER_FAILED` („The reward could not be handed over.“)
- mehr Slots nötig als frei → `BAG_FULL` („Your bag is full. Make room for the reward first.“)

Gleiche Rechnung wie `SalvageService._room_after_removal`, ohne dessen `+1` (freigewordener Slot). Salvage bleibt unverändert.

Prüfreihenfolge in `can_claim`: Reward vorhanden → Zustand (claimed / none) → Trial → Daten gültig → Gesamtplatz.

## 3. Transaktion und Rollback

`claim(character, quest_id, session)`:
1. `can_claim` (alle Prüfungen oben, ohne Änderung)
2. `pay(character, gold, items)`:
   - je Material: Mengen aller Stapel dieser ID merken, dann `Inventory.add_item(id, n, ORIGIN_QUEST)` (pro Item alles-oder-nichts)
   - zuletzt Gold über `add_item(gold_coin, n)`
   - bei jedem Fehler `_undo` in umgekehrter Reihenfolge: berührte **vorhandene** Stapel → `set_quantity` auf den gemerkten Wert,
     **neue** Stapel dieses Claims → `remove_instance`
3. nur bei Erfolg: `quest_reward_claimed.<id>` setzen
4. danach `session.request_critical_save` (Meilenstein)

Garantien:
- Kein pauschales `remove_quantity` über eine Item-ID: andere Stapel derselben ID werden nie berührt, Instanz-IDs und Aufteilung
  der vorhandenen Stapel bleiben exakt erhalten (Test `rollback_only_takes_back_this_claims_quantities`).
- Gold scheitert → Materialien zurück; Gold selbst ist alles-oder-nichts, es bleibt kein Teilbetrag.
- Fehler: kein Flag, kein Save-Request, Rückgabe des Grundes, Anspruch bleibt `pending`.
- `pay` ist (wie `SalvageService.apply`) öffentlich, damit Tests nicht addierbare Einträge erzwingen können. Es setzt keine Flags.

Verwendete vorhandene APIs: `add_item`, `set_quantity`, `remove_instance`, `items`, `free_slots`. Keine neue Inventory-Engine.

## 4. Edrin / Gold-only

- `the_first_binding`: `turn_in_gold = 60`, `turn_in_items` leer, `turn_in_npc_id = edrin` – Daten unverändert.
- Gold-only-Pfad: `slots_needed({}) = 0`, die Platzprüfung ist immer erfüllt; `pay` fügt nur Gold hinzu. Fehlertexte und
  Erfolgsverhalten sind dieselben wie in T1 (`quest_turnin_t1` unverändert grün, inkl. `failed_credit_sets_no_flag…`).
- Gold-only mit voller Tasche bleibt abholbar (Währung braucht keinen Slot).

## 5. Entitlement und Save

- Unverändert: Entitlement nur bei Live-Abschluss (`StoryService._settle` mit `announce`), nie durch `resettle`, Migrationen oder
  historische `completed`-Einträge (R-B). Trial blockiert. Claimed gewinnt, Wiederholung zahlt nichts.
- Materialien, Gold und Claimed-Flag ändern sich im selben synchronen Aufruf → jeder Snapshot enthält alles oder nichts
  (Test `claimed_mixed_reward_is_one_snapshot_and_survives_load`).
- Keine Schemaänderung: `turn_in_items` ist Definitionsdatum (Resource), nicht Spielstand. Flags bleiben freie `world.flags`.
  **Save v15 bleibt**, keine Migration.

## 6. Tests

Neue Suite `tests/integration/test_quest_turnin_mixed_rewards.gd` (22 Tests). Synthetische Reward-Daten auf `the_first_binding`
(in `after_each` zurückgesetzt), synthetische Taschen (Füller `iron_sword`), echter Story-Pfad bis zum Abschluss und echter
`QuestRewardService.claim`. Saves nur als Dictionaries bzw. `user://test_saves/quest_turnin_mixed_rewards/`.

| Auftrag # | Test |
|---|---|
| 1 | `edrin_reward_is_still_exactly_60_gold_and_no_materials` |
| 2 | `gold_only_reward_needs_no_bag_slot` |
| 3, 4, 17, 18 | `mixed_claim_pays_every_material_and_the_gold_once` |
| 5, 9 | `one_free_slot_is_not_enough_for_two_materials` |
| 6 | `full_bag_gives_no_partial_reward` |
| 7 | `partial_timber_stack_is_topped_up_without_a_new_slot`, `stack_overflow_needs_one_new_slot` |
| 8 | `two_materials_need_two_new_slots` |
| 10 | `refusal_keeps_existing_material_stacks_unchanged` |
| 11 | `first_material_failure_pays_nothing` (über `pay` mit nicht addierbarem erstem Eintrag + Claim mit voller Tasche) |
| 12 | `second_material_failure_rolls_the_first_back` (echter `claim`; ein `Inventory.changed`-Listener füllt die Tasche nach der ersten Gutschrift) |
| 13 | `gold_failure_rolls_the_materials_back` (echter `claim`, Gold > `CURRENCY_ROOM`) |
| 14 | `rollback_only_takes_back_this_claims_quantities` |
| 15, 16 | in allen Fehler-/Ablehnungstests über `_check_unchanged` (Tasche, Flag, Save-Requests, Pending) |
| 19 | `pending_mixed_reward_survives_save_and_load` |
| 20 | `claimed_mixed_reward_is_one_snapshot_and_survives_load` |
| 21 | `historical_completion_gives_no_mixed_reward` |
| 22 | `resettle_creates_no_retroactive_claim` |
| 23 | `trial_blocks_the_mixed_claim` |
| 24 | `invalid_material_data_never_pays_partially` |
| 25 | `story_contract_is_unchanged_with_a_mixed_reward` |
| – | `items_only_reward_registers_an_entitlement`, `shipped_data_have_no_material_rewards_yet` |

Lauf (headless, `run_tests.ps1`): `quest_turnin_mixed_rewards, quest_turnin_t1, quest_turnin_t2, quest_turnin_t3, economy,
inventory, save` → **74 passed, 0 failed**. `check_project.ps1`: OK (keine Fehler/Warnungen).
Ein Testfehler im ersten Lauf lag am Fixture (Stein-Stapel mit Restplatz), nicht am Service; korrigiert.
Altfehler `test_migration_v3_to_v4` liegt in der Suite `prologue`, die hier nicht lief (nicht betroffen).

## 7. M2-Integrationspunkte

- **Daten:** `data/story/the_broken_cart.tres`: `turn_in_gold = 30`, `turn_in_npc_id = &"mara"`,
  `turn_in_items = [timber ×3, stone ×2]` (IDs `timber`, `stone`, beide `max_stack` 50). Danach greift `register_completion`
  automatisch beim Live-Ende von `mara_road_end`; Altstände ohne Flag bleiben ohne Anspruch.
- **UI-Bedingungen noch auf `turn_in_gold > 0`** – in M2/M3 auf `QuestRewardService.has_reward` umstellen, sonst übersehen sie
  einen Items-only-Reward (für 30 Gold + Material funktionieren sie zufällig):
  - `scripts/world/story_npc.gd:80` (Marker; zusätzlich Erreichbarkeitsregel D4 aus dem Audit)
  - `scripts/ui/quest_reward_panel.gd:72` (Quest-Liste), `:128` (Kartenzeile nur Gold), `:149` (Erfolgstext nur Gold)
  - `scripts/ui/journal_panel.gd:118-125`, `scripts/ui/objective_panel.gd:101`
- **Maras Zugang:** „Quest Rewards“-Knopf im `FlaskPanel` → `hud.open_npc_service(&"quest_rewards", site)` (Audit §5.1).
- **Volle Tasche im Fenster:** `can_claim` liefert `BAG_FULL`; das Panel zeigt Gründe bereits als deaktivierten Knopf.
  `slots_needed` kann für einen Hinweis „needs N free slots“ genutzt werden.

## 8. Restrisiken

- Fehler „mitten im Claim“ sind in der Praxis kaum erreichbar (Platz vorab geprüft, synchron); der Rollback ist über Tests mit
  erzwungenen Fehlern abgesichert, nicht über reale Fälle.
- `_undo` setzt einen berührten vorhandenen Stapel auf den alten Wert zurück. Ein fremder Listener, der während des Claims
  denselben Stapel ändert, würde dabei überschrieben (kein solcher Listener existiert; nur der Testfall füllt mit anderen Items).
- Materialstapel tragen keine Herkunft (`origin` nur bei Einzelitems) – wie im Audit, bewusst.
- Die Meldung `BAG_FULL` ist ein neuer spielerseitiger Text im Service (Englisch, wie die übrigen Claim-Gründe); Lokalisierung der
  Claim-Gründe ist wie in T1 nicht über `ui.csv` geregelt.
