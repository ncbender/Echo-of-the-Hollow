# NPC Quest Turn-ins 1.0 · T2: Edrin Vale Quest Reward Service

Branch `dev/npc-quest-turnins-10-t2` von `dev/npc-quest-turnins-10-t1` @ `02f47f7`. Save bleibt **v15**, keine neuen Felder, keine
Migration. Die Reward-Logik aus T1 (`QuestRewardService`, `docs/NPC_QUEST_TURNINS_1_0_T1.md`) ist **unverändert**. Fremde Änderungen
(`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.

## 1. Phase A – Befunde

| # | Frage | Befund |
|---|---|---|
| 1 | Wie registriert ein NPC einen Service? | `NpcDefinition.service` (Daten) **und** `offers_service` am `StoryNpc`-Knoten der Szene |
| 2 | Wie öffnet das HUD das Fenster? | `GameHud.open_npc_service(service, site)`: Map Service-ID → Fenster, `close_windows()`, `open(character, site)` |
| 3 | Vorrang ungehörter Dialoge? | `StoryNpc.interact`: Ein ungehörter Dialog öffnet immer den Dialog. Den Service gibt es nur, wenn kein Dialog vorliegt oder der aktuelle schon gehört ist |
| 4 | Bleibt ein gehörter Dialog erreichbar? | Im Flask-Fenster über den Knopf „Talk to <NPC>“. Dasselbe Muster nutzt jetzt auch das neue Fenster |
| 5 | Minimale Erweiterung? | ein zweiter Eintrag in der Service-Map plus ein Fenster. Kein Multi-Service-System, Edrins Slot war frei |
| 6 | Schließen/Aktualisieren? | `_process` versteckt das Fenster, sobald der Spieler den NPC-Bereich verlässt (wie Flask). Kartenwechsel entlädt das HUD. Jede Interaktion öffnet neu und baut aus dem Service neu auf |
| 7 | Anzuzeigende T1-Ergebnisse? | `state` (none/pending/claimed), `can_claim` (Grund als Tooltip/Status), `claim` (`""` oder Grund) |

Konflikt geprüft: Edrins wiederholbare Hinweise (`edrin_early`, `edrin_shrine_hint`) öffneten bisher bei jedem Gespräch. Jetzt
öffnet nach dem ersten Hören der Service, und der Hinweis bleibt über „Talk to Edrin Vale“ erreichbar. Ungehörte Storydialoge
(`edrin_intro`, `edrin_threat`) behalten ihren Vorrang. Getestet, kein Stopp nötig.

## 2. Registrierung (geänderte Dateien)

| Datei | Änderung |
|---|---|
| `data/npcs/edrin.tres` | `service = &"quest_rewards"` |
| `scenes/maps/home_base.tscn` | Knoten `Edrin`: `offers_service = true` |
| `scripts/ui/game_hud.gd` | `quest_reward_panel`, Service-Map `{hearth_flask, quest_rewards}`, Aufruf `window.open(character, site)` (gleiche Signatur beider Fenster) |
| `scripts/ui/quest_reward_panel.gd` | neues `UiWindow` `QuestRewardPanel` |
| `localization/ui.csv` | `UI_QUEST_REWARDS`, `UI_QUEST_REWARD_CLAIM`, `UI_QUEST_REWARD_GOLD`, `UI_QUEST_REWARD_SUCCESS`, `UI_QUEST_REWARD_RECEIVED`, `UI_QUEST_REWARDS_NONE` |
| `tests/playtest/gallery_screens.gd` | Bildschirm `quest_rewards` (Pending-Zustand bei Edrin) |

Mara, `FlaskPanel` und `hearth_flask` sind unverändert.

## 3. Fenster „Quest Rewards“
- **Liste:** Story-Quests mit `turn_in_gold > 0` und `turn_in_npc_id` = NPC des Fensters (Daten aus T1). Für Edrin ist das
  nur `the_first_binding`. Der Zustand jeder Quest kommt aus `QuestRewardService.state`, nie aus `QuestLog` allein.

| Zustand | Anzeige |
|---|---|
| `none` (alle Quests) | „No rewards available.“, keine Claim-Aktion |
| `pending` | Karte „The First Binding“, Zeile „Reward: 60 Gold“. Im Footer „Claim Reward“, deaktiviert mit Grund, wenn `can_claim` ablehnt (z. B. Trial) |
| `claimed` | Karte mit „Reward received.“, keine Claim-Aktion |

- Gehörter Dialog: Knopf „Talk to Edrin Vale“.
- **Claim:** Footer-Aktion `QuestRewardPanel.claim()`.
  - Sie liest `pending_quest()` neu aus dem Service, sperrt den Knopf und ruft
    `QuestRewardService.claim(character, quest_id, session)` auf.
  - Erfolg zeigt sie nur bei `""` an: „Received 60 Gold.“
  - Sonst zeigt sie den Grund des Service.
  - Danach baut sie das Fenster aus dem Service neu auf.
  - Gold, Flag und Meilenstein-Save übernimmt allein T1. Die UI setzt keine Flags und schreibt kein Gold gut.
- **Doppelklick / veraltetes Fenster:** Gibt es keinen offenen Reward mehr, zahlt `claim()` nichts, und die letzte Meldung
  bleibt stehen. Eine Zahlung, die in der Zwischenzeit anderswo erfolgt ist, wird nicht wiederholt.

## 4. Dialoge
- `edrin_threat` ist weiterhin der Abschluss von `the_first_binding` (unverändert über `DialogueService.finish` →
  `notify(talk:edrin_threat)`).
  - Der Service ersetzt ihn nicht, überspringt ihn nicht, markiert ihn nicht und nutzt ihn nicht als Reward-Auslöser.
- Nach dem Dialog ist der Reward `pending`. Beim nächsten Gespräch mit Edrin öffnet sich das Fenster, weil Edrin dann keinen
  Dialog mehr hat.
- Vor dem Abschluss öffnet ein ungehörter Storydialog wie bisher. Die Story geht weiter: Nach `edrin_intro` sind das Nordtor
  (`prologue.haven_settled`) und `the_whispering_stone` erreichbar.

## 5. Save und Altstände
- Es gibt keine neuen Felder. Das Fenster rekonstruiert alles bei jedem Öffnen und vor jedem Claim aus den T1-Flags.
- R-B gilt unverändert: Ein historisch abgeschlossener Stand ohne Entitlement zeigt „No rewards available.“, zahlt nichts und
  setzt keine Flags.
- Sicher geprüft wurde Edrins Service in diesen Fällen:
  - Quest aktiv
  - Quest historisch abgeschlossen
  - Entitlement fehlt
  - Reward schon abgeholt
  - Trial läuft
  - Spieler geht weg

## 6. Tests
Neue Suite `tests/integration/test_quest_turnin_t2.gd` mit 9 Tests. Sie lädt die echte `home_base`, spricht Edrin über
`StoryNpc.interact` an und claimt über den Footer-Knopf bzw. `QuestRewardPanel.claim`. Dateien landen nur unter
`user://test_saves/quest_turnin_t2/`.

| Auftrag # | Test |
|---|---|
| 1, 2, 20 | `test_only_edrin_has_the_reward_service` |
| 3, 4, 5, 6, 9, 10, 11, 12, 16 | `test_edrin_talk_first_then_one_claim_of_60_gold`: zuerst der ungehörte `edrin_threat`, Abschluss und Nachfolger, `pending`, Titel, Karte, „60 Gold“, „Claim Reward“, Doppelklick → genau 60 Gold, ein Meilenstein-Save, „Received 60 Gold.“, danach „Reward received.“, weitere Klicks und Gespräche zahlen nichts |
| 7, 8 | `test_no_entitlement_no_payout` (historisch abgeschlossen) |
| 13, 14 | `test_save_load_rebuilds_pending_and_claimed` |
| 12 | `test_stale_window_never_pays_twice` |
| 15 | `test_trial_lock_stays_in_force` (Knopf deaktiviert, Grund, keine Zahlung) |
| 3, 18 | `test_edrins_dialogues_stay_reachable` (`edrin_intro` zuerst, Tor und Story weiter, `edrin_shrine_hint` erst als Dialog, dann über „Talk“) |
| 17 | `test_mara_flask_service_unchanged` |
| 19 | `test_window_closes_when_walking_away_and_leaves_nothing_open` |

| Suite | Ergebnis |
|---|---|
| quest_turnin_t2 (neu) | 9/9 grün |
| quest_turnin_t1, consumables, hud, story | grün (47/47 zusammen mit T2) |
| haven, shrine, class_trials_m1, save, prologue | 44/45. Rot ist nur der **bekannte Altfehler** `test_prologue::test_migration_v3_to_v4` (auf `849192c` identisch rot, siehe T1) |
| `check_project.ps1` | OK |

Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-/Haven-/Klassen-/Crafting-/Arena-Loops und die UI-Galerie. Der neue
Galerie-Bildschirm `quest_rewards` ist eingetragen, aber nicht ausgeführt.

## 7. Risiken
- Edrin ohne offenen Reward und ohne Dialog öffnet jetzt das Fenster „No rewards available.“. Vorher sagte er eine Idle-Line.
  Das ist dasselbe Verhalten wie bei Mara.
- Wiederholbare Edrin-Hinweise sind nach dem ersten Hören nur noch über „Talk“ erreichbar (Muster Mara).
- Der Footer-Knopf claimt die erste offene Quest des NPCs. Bei mehreren gleichzeitig offenen Rewards bräuchte es Knöpfe pro
  Karte. Mit T2 gibt es nur eine Quest.
- Die visuelle Abnahme fehlt: Fenster und Footer wurden nur headless geprüft.

## 8. Offen für T3
- „?“-Marker über Edrin bei `pending` (`StoryNpc._draw`, „!“ behält Vorrang).
- Tracker- und Journal-Hinweis „Reward waiting with Edrin Vale“.
- Galerie `--only=quest_rewards` und visuelle Abnahme in einer Auflösung.

## 9. Unverändert
- `QuestRewardService` und T1-Flags, R-B, Questziele, Schrittfolgen und Nachfolger, Reward-Wert (60)
- Dialogdaten, Mara und `FlaskPanel`, `StoryNpc`
- Class Trials, M4, Grove-Warden-Cache, Loot, Wirtschaftswerte
- Save-Version und Migrationen
