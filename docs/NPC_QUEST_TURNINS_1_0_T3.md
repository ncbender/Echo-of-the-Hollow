# NPC Quest Turn-ins 1.0 · T3: Quest Guidance & Visual Polish

Branch `dev/npc-quest-turnins-10-t3` von `dev/npc-quest-turnins-10-t2` @ `aaff8f1`. Save bleibt **v15**.

Nicht geändert:
- `QuestRewardService`, T1-Flags, R-B, 60 Gold
- Quests, Ziele, Nachfolger, Story-Fortschritt

Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.

## 1. Phase A – Marker-Befund
- `StoryNpc._draw` läuft **jeden Frame** (`_process` → `queue_redraw`). Der Marker wird also bei jedem Zeichnen neu gelesen,
  ohne Signale, Cache oder Initialwert. Damit wirken Entitlement, Claim, Save/Load und Kartenwechsel sofort.
- Vorher gab es nur „!“: `DialogueService.has_story_dialogue` (ungehörter Dialog mit `event_id`). „?“ gab es nicht.
- `WorldText.draw` kann jedes Zeichen darstellen. Es braucht weder ein neues Asset noch eine Marker-Engine.

## 2. Marker (`scripts/world/story_npc.gd`)
- `StoryNpc.marker()` gibt `"!"` (Storydialog), sonst `"?"` (`has_pending_reward()`), sonst `""` zurück. `_draw` zeichnet
  genau dieses Zeichen. „!“ sitzt unverändert an derselben Stelle, „?“ ist zentriert, in derselben Goldfarbe und mit demselben
  Puls.
- `has_pending_reward()` ist wahr, wenn dieser Knoten seinen Service anbietet (`offers_service`) **und** eine Story-Quest mit
  `turn_in_npc_id` = dieses NPC laut `QuestRewardService.state` `pending` ist.
  - Nie aus `QuestLog.completed` allein.
  - Andere NPCs bekommen nur dann ein „?“, wenn Daten sie als Abgabe-NPC eintragen. Heute ist das nur Edrin.
- Priorität: Ist `edrin_threat` noch ungehört, steht „!“ über Edrin. Nach dem Dialog folgt im selben Kartenaufenthalt „?“,
  nach dem Claim kein Marker mehr.

## 3. Journal (`scripts/ui/journal_panel.gd`)
- Die Karte einer **abgeschlossenen** Quest zeigt unter „Completed“ eine Reward-Zeile aus `JournalPanel.reward_text`, die
  `QuestRewardService.state` liest:

| Zustand | Reward-Zeile |
|---|---|
| `pending` | „Reward available: Return to Edrin Vale (60 Gold).“ (grün) |
| `claimed` | „Reward received: 60 Gold.“ (gedämpft) |
| `none` | keine Zeile |

- Die Quest bleibt in jedem Fall unter „Completed“. Die Journal-Struktur ist unverändert, es kommt nur eine Zeile dazu.

## 4. Tracker (`scripts/ui/objective_panel.gd`)
- `ObjectivePanel.reward_lines` ergibt eine Hinweiszeile „Return to Edrin Vale for your reward.“ pro `pending`-Reward, auch
  wenn die Quest abgeschlossen ist. Ohne anderen Titel steht sie unter „Journey“, sonst durch eine Leerzeile abgesetzt, nach den
  Story-Zeilen und vor den Klassenquests.
- Sie ist **kein** Questziel:
  - `StoryService.tracker_lines` ist unverändert und enthält die Zeile nicht.
  - Es wird keine Quest reaktiviert.
  - Trial- und Prolog-Hinweise sowie die Klassenwahl kommen weiter zuerst.
- Nach dem Claim verschwindet die Zeile im nächsten Frame (das Panel liest jeden Frame neu). Bei `none` fehlt sie.
- Texte: `UI_QUEST_REWARD_JOURNAL_PENDING`, `UI_QUEST_REWARD_JOURNAL_CLAIMED`, `UI_QUEST_REWARD_TRACKER` in
  `localization/ui.csv`.

## 5. QuestRewardPanel
Geprüft in den Screenshots (§6):
- Titel, Questkarte, „Reward 60 Gold“ und „Claim Reward“ (Footer, volle Breite) sind sichtbar.
- „Reward received.“ und „No rewards available.“ erscheinen korrekt.
- „Talk to Edrin Vale“ ist in allen drei Zuständen erreichbar.
- „Close [G / Esc]“ ist sichtbar.
- Es gibt keine Überlappungen und keine doppelte Erfolgsmeldung. Erfolg meldet nur die Statuszeile, und nur nach einem `""`
  von `claim`.

**Behoben (einziger echter Befund):**
- Problem: Bei `pending` lag der Tastaturfokus auf „Talk to Edrin Vale“. `UiWindow._focus_first` durchsucht nur den Body,
  „Claim Reward“ sitzt im Footer. Enter hätte also das Gespräch statt der Abholung ausgelöst.
- Fix: `QuestRewardPanel._focus_first` fokussiert „Claim Reward“, wenn der Knopf sichtbar und aktiv ist, sonst greift das
  Basisverhalten (Muster `StashPanel`/`ProfessionsPanel`).
- Nachweis: Test und Screenshot bei 720p.

Der Claim läuft weiterhin ausschließlich über `QuestRewardService.claim`.

## 6. Visuelle Abnahme (echt gerendert, nicht headless)
Die vorhandene UI-Galerie wurde **begrenzt** ausgeführt (`ui_gallery.gd -- --only=…`):
- Sie lädt nur `home_base` und die genannten Bildschirme.
- Es läuft kein Prolog-, Klassen- oder Galerie-Gesamtprogramm.

Neue Galerie-Bildschirme in `tests/playtest/gallery_screens.gd`, Zustand über `_binding_reward`:

| Bildschirm | Inhalt |
|---|---|
| `quest_rewards` | Fenster, pending |
| `quest_rewards_claimed` | Fenster, claimed |
| `quest_rewards_none` | Fenster, kein Anspruch (Stand vor T1) |
| `hud_edrin_reward` | „?“ über Edrin und Tracker-Hinweis |
| `hud_edrin_story` | „!“ über Edrin (`edrin_threat` offen), kein „?“ |
| `journal_reward` | abgeschlossene Quest-Karte mit Reward-Zeile |

| Lauf | Ergebnis |
|---|---|
| 1920×1080, 100 %, alle sechs | `RESULT: OK (16 checks, 0 failed)` |
| 1280×720, 150 %, fünf (ohne `hud_edrin_story`) | `RESULT: OK (14 checks, 0 failed)` |

Alle Screenshots (`tests/output/gallery/*quest_rewards*`, `*hud_edrin*`, `*journal_reward*`) habe ich selbst angesehen:
- Texte lesbar, keine Überlappung, Knöpfe in normaler Größe.
- Bei 720p/150 % scrollt das Journal, die Reward-Zeile liegt unterhalb des sichtbaren Bereichs, ist aber erreichbar.
- Das Fenster liegt zentriert und verdeckt Edrin samt Marker. Das ist das übliche Verhalten aller Fenster.

Hinweis: Der Galerie-Charakter hat einen künstlichen Mischzustand (`shelter_among_the_trees` aktiv neben abgeschlossener
`the_first_binding`). Deshalb zeigt der Tracker beides. Das liegt an den Galerie-Daten, nicht am Produktverhalten.

## 7. Tests
Neue Suite `tests/integration/test_quest_turnin_t3.gd` mit 7 Tests, echte `home_base`, synthetische Zustände. Dateien nur
unter `user://test_saves/quest_turnin_t3/`.

| Auftrag # | Test |
|---|---|
| 1, 3, 4, 5, 17 | `test_story_mark_first_then_question_mark_until_the_claim` („!“ → Dialog → „?“ im selben Aufenthalt → Claim → kein Marker; Mara kein „?“) |
| 7, 8 | `test_marker_after_save_load_and_map_change` |
| 2, 6, 11 | `test_historical_completion_shows_no_reward_guidance` |
| 9, 10, 12, 13, 14, 19 | `test_journal_and_tracker_follow_the_reward_state` (Helfer und echte Journal-Karte/Tracker-Labels, keine Reaktivierung, keine Objective-Zeile, Nachfolger) |
| 15, 16, 18 | `test_window_pays_once_and_trial_lock_holds` |
| 20 | `test_contract_unchanged` (60 Gold, Edrin, Flag-Namen, v15, Nachfolger) |
| Fokus-Fix | `test_pending_window_focuses_claim_reward` |

| Suite | Ergebnis |
|---|---|
| quest_turnin_t3 (neu) | 7/7 grün |
| quest_turnin_t2, quest_turnin_t1, hud, story, haven, shrine, consumables | grün |
| world_ui, class_trials_m3, prologue | 23/24. Rot ist nur der **bekannte Altfehler** `test_prologue::test_migration_v3_to_v4` (identisch rot auf `849192c`) |
| `check_project.ps1` | OK |

Nicht gelaufen: Full-Suite, Prolog-/Haven-/Klassen-/Crafting-/Arena-Loops, Galerie-Gesamtlauf.

## 8. Einschränkungen
- Das Fenster verdeckt beim Öffnen Edrin und seinen Marker (Standard-Fensterplatzierung).
- Der Footer-Knopf claimt die erste offene Quest eines NPCs. Bei mehreren gleichzeitigen Rewards bräuchte es Knöpfe pro Karte
  (siehe T2).
- `has_pending_reward` iteriert pro Frame über alle Story-Quests. Bei sechs Quests ist das vernachlässigbar, bei sehr vielen
  Quests sollte man cachen.
- Die visuelle Abnahme deckt 1080p/100 % und 720p/150 % ab, nicht 4K.

## 9. Wiederverwendung für weitere NPCs
Ein weiterer Abgabe-NPC braucht nur Daten:
- `turn_in_gold` und `turn_in_npc_id` an der Quest
- `service = &"quest_rewards"` am NPC
- `offers_service = true` am Szenenknoten

Marker, Journal-Zeile, Tracker-Zeile und Fenster folgen automatisch. Ein NPC mit einem anderen Service (z. B. Mara) bräuchte
weiterhin eine Lösung für mehrere Services pro NPC (Audit E8, nicht umgesetzt).

## 10. Unverändert
- `QuestRewardService`, T1-Flags, R-B, 60 Gold
- Questziele, Schrittfolgen, Nachfolger, `StoryService` (inklusive `tracker_lines`), `QuestLog`
- Dialogdaten, Mara und `FlaskPanel`
- Class Trials, M4, Grove-Warden-Cache, Loot, Wirtschaftswerte
- Save-Version und Migrationen
