# NPC Quest Turn-ins 1.1 – M2: The Broken Cart / Mara Mixed Reward

Branch `dev/npc-quest-turnins-11-m2` von `dev/npc-quest-turnins-11-m1` @ `aae156c`. Save bleibt **v15**.
Grundlage: `docs/NPC_QUEST_TURNINS_1_1_AUDIT.md`, `_1_1_M1.md`, `_1_0_T2.md`, `_1_0_T3.md`.

Commits: `583ac26` (Daten + Code), `38a55a9` (Tests), dieses Dokument.

---

## 1. Reward-Daten

`data/story/the_broken_cart.tres` (M1-Format):

| Feld | Wert |
|---|---|
| `turn_in_gold` | 30 |
| `turn_in_npc_id` | `mara` |
| `turn_in_items` | `ItemCost(timber, 3)`, `ItemCost(stone, 2)` |

- Vorhandene Materialien `data/items/timber.tres` und `data/items/stone.tres` (je `max_stack` 50, `base_value` 0). Keine neuen
  Definitionen.
- Ziele, Schritte, `completion_flag = prologue.cart_done` und Nachfolger `shelter_among_the_trees` sind unverändert.
- Entitlement entsteht nur über den vorhandenen Hook `StoryService._settle` (`announce`) → `register_completion`, also beim
  Live-Ende von `mara_road_end` (`DialogueService.finish` → `notify(talk:mara_road_end)`). Kein Entitlement durch
  `DialogueService.pick` (Dialogbesuch), Service-Öffnen, `resettle`, Migration oder historisches `completed`.

## 2. Maras Servicezugang

- `NpcDefinition.service` von Mara bleibt `hearth_flask`. Haven-Knoten `home_base.tscn` „Mara“ (`offers_service = true`) unverändert.
- `FlaskPanel.rebuild` bekommt nach dem vorhandenen „Talk to Mara Veyne“-Knopf einen Knopf **„Quest Rewards“** (`name =
  QuestRewards`, Text `UI_QUEST_REWARDS`).
  - Sichtbar nur, wenn `QuestRewardPanel.has_rewards_for(character, npc_id)` gilt, d. h. Mara hat eine Reward-Quest im Zustand
    `pending` **oder** `claimed` (die erhaltene Karte bleibt einsehbar). Ohne Anspruch bleibt das Fenster wie vorher.
  - `FlaskPanel.open_quest_rewards()` → `hud.open_npc_service(&"quest_rewards", site)`: das unveränderte `QuestRewardPanel` mit
    Mara als `site`. Kein Multi-Service-System.
- Flask-Upgrades, Gold-Zeile, Talk-Knopf und Ergebniszeile bleiben unverändert.
- Dialogpriorität unverändert (`StoryNpc.interact`): ungehörter Storydialog (`mara_welcome`, `mara_return`) zuerst, danach öffnet
  G das Flask-Fenster. Das Reward-Fenster zeigt ebenfalls „Talk to Mara Veyne“ (vorhandenes T2-Verhalten).
- Old-Road-Mara (`CompanionNpc`, `offers_service = false`) unverändert: kein Service, kein Reward-Fenster, kein „?“.

## 3. QuestRewardPanel

- `quests()` → `quests_for(character, npc_id())`: Quests mit `QuestRewardService.has_reward` **und** `turn_in_npc_id ==` NPC
  des Fensters. Das Fenster listet und claimt damit nur Rewards seines NPCs (`pending_quest()` sucht nur in dieser Liste).
  Mara ↔ Edrin können einander nichts abholen (Tests in beide Richtungen).
- Karte: eine Zeile pro Reward-Teil (`reward_parts`): `Reward  30 Gold` (Knoten `Gold`, wie T2), `3 Timber` (`Item_timber`),
  `2 Stone` (`Item_stone`). Edrins Karte unverändert: `Reward  60 Gold`.
- Erfolg: `UI_QUEST_REWARD_SUCCESS` = „Received %s.“ mit `reward_summary` → „Received 30 Gold, 3 Timber and 2 Stone.“ bzw. für
  Edrin weiterhin „Received 60 Gold.“
- Volle Tasche: `QuestRewardService.can_claim`/`claim` liefert `BAG_FULL`; `reason_text` zeigt dafür
  `UI_QUEST_REWARD_BAG_FULL` = „Not enough inventory space. Make room to claim the full reward.“ Der Knopf ist deaktiviert (Grund
  als Tooltip/Status, wie bei der Trial-Sperre). Das Fenster baut sich bei `Inventory.changed` neu auf (nur sichtbar; Verbindung
  wird beim nächsten `open` und in `_exit_tree` gelöst), eine alte Ablehnung weicht dem aktuellen Zustand → nach dem Platzschaffen
  ist „Claim Reward“ wieder aktiv, ohne das Fenster neu zu öffnen.
- Bereits abgeholt: „Reward received.“ (vorhanden).
- Gutschrift ausschließlich über `QuestRewardService.claim` (M1, unverändert).
- Neue Schlüssel in `localization/ui.csv`: `UI_QUEST_REWARD_ITEM` („%d %s“), `UI_QUEST_REWARD_AND` („%s and %s“),
  `UI_QUEST_REWARD_BAG_FULL`; geändert: `UI_QUEST_REWARD_SUCCESS` („Received %d Gold.“ → „Received %s.“, gleiche Ausgabe für Gold).

## 4. Reward-Erkennung

`turn_in_gold > 0` als „hat Reward“ ersetzt durch `QuestRewardService.has_reward` in:
- `QuestRewardPanel.quests_for`
- `StoryNpc.has_pending_reward`
- `JournalPanel.reward_text`
- `ObjectivePanel.reward_lines`

Texte von Journal und Tracker sind **nicht** geändert (M3). Das Journal nennt für Mara daher vorerst nur „(30 Gold)“.

## 5. Marker-Erreichbarkeit

`StoryNpc.has_pending_reward` verlangt jetzt zusätzlich, dass der Service des NPCs das Reward-Fenster erreicht:
`npc.service in QuestRewardPanel.REWARD_SERVICES` (`quest_rewards` = das Fenster selbst, `hearth_flask` = Knopf im Flask-Fenster).
Damit ist der T3-Befund behoben: ein NPC mit einem anderen Service bekäme kein irreführendes „?“.

| Situation | Marker |
|---|---|
| Old-Road-Mara, Reward pending | kein „?“ (`offers_service = false`) |
| Haven-Mara, `mara_welcome` ungehört | „!“ (Vorrang wie bisher) |
| Haven-Mara, pending, kein ungehörter Storydialog | „?“ |
| nach Claim | „“ |
| historisch completed ohne Entitlement | „“ |
| Edrin | unverändert (T3-Suite grün) |

## 6. Inventar-voll-Verhalten

Unverändert aus M1: Gesamtplatzprüfung vor jeder Gutschrift, kein Teilreward, kein Flag, kein Save, Anspruch bleibt pending;
Materialien zuerst, Gold zuletzt, Rollback nur der eigenen Deltas. Teilstapel werden aufgefüllt (48 Timber + 3 → 50 + 1).

## 7. R-B-Altstände

- Stände mit `the_broken_cart` completed vor M2 (auch über die v4→v5-Migration) haben kein `quest_reward_entitled.the_broken_cart`
  → kein Anspruch, kein Knopf, kein „?“.
- Stände, die die Quest nach M2 live abschließen, erhalten den Anspruch.
- Keine Migration, keine neuen Queststatus, `SaveSystem.VERSION` = 15.

## 8. Tests

Neue Suite `tests/integration/test_quest_turnin_mara.gd` (16 Tests; echter Story-Pfad, Haven- und Old-Road-Szene, echtes Panel):

| Auftrag # | Test |
|---|---|
| 1, 5, 26 | `the_broken_cart_carries_the_mixed_reward` |
| 2, 5 | `live_completion_registers_the_claim_and_keeps_the_story` |
| 3, 4 | `historical_completion_and_resettle_give_no_claim` |
| 8, 9 | `road_mara_is_no_turn_in_place` |
| 10, 11, 12 | `haven_mara_story_first_then_question_mark_until_the_claim` |
| 6, 7 | `flask_window_keeps_its_service_and_reaches_the_rewards`, `flask_without_a_reward_has_no_button` |
| 13, 14, 18 | `maras_card_and_one_full_claim` |
| 15 | `full_bag_pays_nothing_then_claims_after_making_room` |
| 16, 17 | `partial_stacks_are_topped_up_and_a_failed_claim_keeps_them` |
| 19, 20 | `pending_and_claimed_survive_save_and_load` |
| 21, 22 | `mara_and_edrin_never_claim_each_others_reward` |
| 23 | `edrin_claims_only_his_reward_while_maras_is_pending` |
| 24 | `trial_blocks_maras_claim` |
| 25 | `material_only_rewards_count_as_rewards_in_the_ui_paths` |
| 27 | `other_reward_systems_are_untouched` (Warden's Cache); keine Änderung an Trials, Loot, Boss-Reward im Diff |

Angepasste Bestandstests (sie schrieben „nur Edrin hat einen Reward“ fest, das ist mit der Designfreigabe überholt):
- `quest_turnin_t1::reward_data_is_validated`: `the_broken_cart` ausgenommen.
- `quest_turnin_mixed_rewards::shipped_data_have_materials_only_at_the_broken_cart` (vorher `…no_material_rewards_yet`).
- `quest_turnin_t3`: der Prolog-Helfer schließt jetzt auch `the_broken_cart` live ab; er holt Maras Reward direkt ab, damit die
  Edrin-Prüfungen (Tracker genau eine Zeile) unverändert gelten. Die Mara-Prüfung lautet „kein ? nach ihrem Claim“.

Lauf (headless, `run_tests.ps1`): `quest_turnin_mara, quest_turnin_mixed_rewards, quest_turnin_t1, quest_turnin_t2,
quest_turnin_t3, consumables, haven, old_road, shrine, economy, inventory` → **111 passed, 0 failed**. `check_project.ps1`: OK.
Vor der Anpassung schlugen genau die fünf oben genannten Bestandsprüfungen fehl (erwartet). Nicht gelaufen: Full-Suite, Galerie,
Playtests, `prologue` (enthält den bekannten Altfehler `test_migration_v3_to_v4`).

## 9. Offene M3-Aufgaben

- Journal (`UI_QUEST_REWARD_JOURNAL_PENDING/CLAIMED`): nennt nur Gold, für Mara „(30 Gold)“; Formulierung mit Materialien. Bei
  einem Material-only-Reward stünde „(0 Gold)“.
- Tracker (`UI_QUEST_REWARD_TRACKER`): „Return to Mara Veyne for your reward.“ erscheint schon ab der Old Road, obwohl erst die
  Haven-Mara auszahlt (Audit D6, Designfrage).
- Galerie-Bildschirme: Flask-Fenster mit „Quest Rewards“, Maras Reward-Fenster pending/claimed/Tasche voll (`GalleryScreens`).
- Visuelle Abnahme der Kartenzeilen ohne Label („3 Timber“, „2 Stone“) bei 1080p und 720p/150 %.
- Optional: Rückweg vom Reward-Fenster zum Flask-Fenster (heute: schließen und erneut G).

## 10. Unverändert

`QuestRewardService` (M1-Vertrag), `StoryService`/`resettle`, Story-Nachfolger, Dialoge, `NpcDefinition`-Daten, `home_base.tscn`,
`old_road.tscn`, `GameHud.open_npc_service`, `ConsumableService`/Flask-Upgrades, Edrins Daten und 60 Gold, Class Trials,
Grove-Warden-Cache, Loot/Affixe/Dropchancen, Readable, `SaveSystem.VERSION`.
