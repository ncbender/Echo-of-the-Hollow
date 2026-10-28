# NPC Quest Turn-ins 1.0 · T1: Quest Reward Contract

Branch `dev/npc-quest-turnins-10-t1` von `audit/npc-quest-turnins-10` @ `849192c` (= R2 `21fdde5` + Audit). Save bleibt
**v15**, keine Migration. Grundlage: `docs/NPC_QUEST_TURNINS_1_0_AUDIT.md` (Option 1, R-B).

Nicht umgesetzt (T2/T3):
- Edrins Service/Fenster
- Dialogaktionen
- „?“-Marker
- Journal-/HUD-Anzeige

Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.

## 1. Phase A – Befunde vor der Umsetzung

| # | Frage | Befund |
|---|---|---|
| 1 | Welcher Codepfad schließt `the_first_binding` ab? | `DialogueService.finish(edrin_threat)` → `StoryService.notify(talk:edrin_threat)` → `_settle(announce = true)` setzt `completed`, `prologue.completed`, startet `the_first_signs` (`scripts/rpg/quests/story_service.gd`) |
| 2 | Wo wird der Anspruch genau einmal registriert? | In `_settle` am Übergang `finished`, **nur mit `announce`**. `announce = false` kommt ausschließlich aus `resettle` (Aufruf in `Character.from_dict`), also aus der Rekonstruktion beim Laden. `completed` wird nie zweimal erreicht, weil `_settle` nur aktive Quests bearbeitet |
| 3 | Wie unterscheiden sich die drei Zustände? | Zwei Weltflags (§2) |
| 4 | Reichen `WorldState`-Flags? | Ja. `world.flags` speichert freie Keys mit v15. Werte sind `bool`, weil `has_flag` String-Werte nicht verträgt (Befund R2) |
| 5 | Welche Currency-API? | `Inventory.add_item(EconomyService.GOLD, n)`, derselbe Weg wie beim Verkauf (`EconomyService`). `gold_coin` ist Währung, braucht keinen Slot (`room_for` = `CURRENCY_ROOM`). Pro Aufruf alles-oder-nichts, wird im `inventory`-Payload gespeichert |
| 6 | Rückmeldung? | `claim` gibt `""` (Erfolg) oder den Grund zurück. `state` liefert `none`/`pending`/`claimed` |
| 7 | Woran erkennt man eine echte Trial? | `character.classes.in_trial()`, dieselbe Prüfung wie M4 und R2 |

Kein Blocker: Ein echter neuer Abschluss ist eindeutig von der Rekonstruktion unterscheidbar (über `announce`). Migrationen
schreiben Quest-Einträge direkt und laufen nie über `_settle`.

## 2. Persistenter Vertrag

| Zustand | `quest_reward_entitled.the_first_binding` | `quest_reward_claimed.the_first_binding` | Quest |
|---|---|---|---|
| kein Anspruch (`none`) | fehlt | fehlt | beliebig |
| offen (`pending`) | `true` | fehlt | `completed` |
| abgeholt (`claimed`) | beliebig | `true` | beliebig |

- Ein fehlendes Claimed-Flag allein ist **kein** Anspruch.
- Widersprüchliche Flags werden defensiv behandelt:
  - Claimed ohne Entitled ergibt `claimed` (keine Zahlung).
  - Entitled ohne `completed` ergibt `none` (keine Zahlung).
- Daten: `StoryQuestDefinition.turn_in_gold` (60) und `turn_in_npc_id` (`edrin`), gesetzt nur in
  `data/story/the_first_binding.tres`. Andere Quests haben 0.
- `StoryService.validate_data` prüft, dass das NPC existiert, der Wert nicht negativ ist und die Quest nicht `open_ended` ist.
- Es gibt kein allgemeines Reward-Framework: nur Gold und nur Story-Quests.

## 3. Entitlement-Zeitpunkt und `resettle`
- Der Anspruch entsteht in `StoryService._settle` im selben Aufruf, der die Quest live auf `completed` setzt, direkt nach dem
  `completion_flag`. Danach folgen wie bisher `story_progressed` (Meilenstein-Save) und der Start der Nachfolger.
- Unverändert und nicht verzögert: Abschluss, Ziele, Schrittfolge, `prologue.completed`, `the_first_signs`.
- **`resettle`** ruft `_settle(announce = false)`. Der M1-Fix schließt historische Schritte und Quests weiter nach und startet
  Nachfolger, setzt aber **kein** Entitlement.
  - Test: Ein Stand mit erfülltem, aber nie abgeschlossenem letzten Schritt wird beim Laden `completed`, ohne Anspruch.
  - Gegenprobe: Ohne den `announce`-Schutz wird dieser Test rot.
- Wiederholungen ändern nichts: weder Dialog, Event noch `resettle`. Die Quest ist nicht mehr aktiv, `set_flag` ist
  idempotent.

## 4. Altstände (R-B)

| Fall | Ergebnis |
|---|---|
| vor T1 `completed` (auch v4→v5-Migration, die `completed` + `prologue.completed` schreibt) | kein Entitled-Flag → kein Anspruch, kein Gold |
| aktiv, Ziele unvollständig | Abschluss später live → Anspruch |
| aktiv, Ziele erfüllt (Rekonstruktion durch `resettle`) | `completed` ohne Anspruch |
| `pending` gespeichert | bleibt nach Save/Load `pending` |
| `claimed` gespeichert | bleibt `claimed`, kein zweiter Claim |

Keine Heuristik aus `prologue.completed`, Dialogflags, Zählern, NPC-Besuchen oder Trials. Keine Migration.

## 5. Claim-API für T2

```gdscript
QuestRewardService.state(character, &"the_first_binding")   # &"none" | &"pending" | &"claimed"
QuestRewardService.can_claim(character, quest_id)            # "" or the reason (UI text)
QuestRewardService.claim(character, quest_id, session)       # "" or the reason; session -> milestone save
```

`claim` läuft so ab:
1. `can_claim` prüft:
   - Reward-Daten vorhanden
   - nicht `claimed`
   - `pending` (Entitled ∧ `completed`)
   - keine Trial
2. Exakt `turn_in_gold` (60) Gold über `add_item` gutschreiben.
3. Das Claimed-Flag setzen.
4. Mit `session` **einen** `request_critical_save("quest reward <id>")` anfordern.

| Ergebnis | Meldung |
|---|---|
| kein Anspruch | „There is no reward waiting for you.“ |
| bereits abgeholt | „You were already rewarded.“ |
| Trial läuft | „Finish or leave the current trial first.“ |
| Gutschrift gescheitert | „The reward could not be handed over.“ |

Scheitert die Gutschrift, wird kein Flag gesetzt, kein Gold behalten (`add_item` ist alles-oder-nichts) und kein Save
angefordert. Gold und Flag ändern sich im selben synchronen Aufruf, also enthält jeder Save-Snapshot beides oder keines.

T2 ruft `claim(character, quest_id, session)` aus Edrins Service-Fenster auf. Es gibt keinen Inventarplatz-Check, weil Gold
keinen Slot braucht.

## 6. Tests
Neue Suite `tests/integration/test_quest_turnin_t1.gd`, 10 Tests mit synthetischen Saves. Milestone-Anfragen gehen an
`user://test_saves/quest_turnin_t1/`; nichts wird geschrieben, weil keine Map läuft.

| Auftrag # | Test |
|---|---|
| 1–5, 18, 19 | `test_live_completion_registers_the_claim_and_keeps_the_story_contract`: echte Kette (Story-Events, Trial, Klassenwahl, Wegstein), Abschluss über `DialogueService.finish(edrin_threat)`, Quest `completed`, `prologue.completed`, Nachfolger, Ziele/Reihenfolge unverändert, vorher kein Claim, Abschluss/Dialog-Wiederholung/Tracker ohne Gold |
| 10, 11, 22 | `test_claim_gives_exactly_60_gold_once_and_one_milestone_save` |
| 16, 17 | `test_trial_blocks_the_claim` |
| 21 | `test_failed_credit_sets_no_flag_and_keeps_no_gold` |
| 9, 13, 14, 15 | `test_pending_and_claimed_survive_save_and_load_in_one_snapshot` |
| 6, 12 | `test_historical_completion_gives_no_claim` (inkl. widersprüchlicher Flags) |
| 7 | `test_v4_migrated_completion_gives_no_claim` |
| 8, 9, 23 | `test_resettle_reconstructing_a_completion_registers_no_claim` |
| 20 | `test_other_rewards_never_touch_the_quest_reward` (M4-Claim, Warden's Cache) |
| – | `test_reward_data_is_validated` |

| Suite | Ergebnis |
|---|---|
| quest_turnin_t1 (neu) | 10/10 grün |
| story, save, economy, class_trials_m1, class_trials_m4, grove_warden_reward, prologue | 70/71. Rot ist nur der **bekannte Altfehler** `test_prologue::test_migration_v3_to_v4` (Fixture ohne `"rarity": 0`); auf dem Ausgangscommit `849192c` identisch rot (geprüft in einem separaten Worktree) |
| `check_project.ps1` | OK |

Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-, Haven-, Klassen-, Crafting-, Arena- und Galerie-Loops.

## 7. Risiken
- Absturz zwischen Claim und Meilenstein-Save: Gold und Flag gehen gemeinsam verloren, der Anspruch bleibt `pending`. Kein
  Duplikat.
- `announce` trägt jetzt zwei Bedeutungen: Signale und Live-Abschluss. Einziger Aufrufer mit `false` ist `resettle`. Ein
  künftiger stiller Aufrufer, der einen echten Abschluss meldet, müsste das berücksichtigen (Kommentar am Hook).
- Ein manuell editierter Save kann das Entitled-Flag setzen. Für ein Einzelspielerspiel ist das akzeptabel.

## 8. Offen für T2/T3
- **T2:**
  - Edrin bekommt einen Service (`offers_service`, `NpcDefinition.service`).
  - Neuer Typ in `GameHud.open_npc_service`, Fenster mit Footer-Aktion, Aufruf `QuestRewardService.claim(..., session)`.
  - Ein ungehörter Storydialog hat weiter Vorrang.
- **T3:**
  - „?“-Marker bei `pending`
  - Tracker- und Journal-Hinweis „Reward waiting with Edrin Vale“
  - visuelle Abnahme

## 9. Unverändert
- Questziele, Schrittfolgen und Nachfolger aller Story-Quests
- `prologue.completed`, Klassenwahl, Trials, M4, Wegsteine
- `QuestLog` (keine neuen Zustände), Dialoge, NPCs, Mara, `Readable`
- Grove-Warden-Cache, Loot, Affixe, Drops, Gold- und Verkaufswerte
- `SaveSystem` und Migrationen (v15)
