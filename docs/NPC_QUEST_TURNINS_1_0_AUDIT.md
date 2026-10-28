# NPC Quest Turn-ins 1.0 – Technik- und Story-Architektur-Audit

Read-only-Audit. Branch `audit/npc-quest-turnins-10` von `dev/grove-warden-rare-r2` @ `21fdde5` (Save v15).

Was dieses Audit nicht getan hat:
- keine Implementierung
- keine Daten-, Szenen-, UI- oder Save-Änderungen
- keine Tests oder Playtests
- keine echten Saves geöffnet

Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst. Grundlage sind der Code in diesem
Stand und das Vor-Audit `docs/LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` §E. Dessen Aussagen wurden nachgeprüft, Abweichungen sind
markiert.

Beschlossenes Prinzip (Vorgabe):
- Zielerfüllung und Abgabe sind getrennte Vorgänge.
- Die Abgabe erfolgt beim NPC.
- Rewards sind einmalig und sicher bei voller Tasche.
- Keine Duplikate durch Dialogwiederholung, Save/Load oder `resettle`.

Nicht festgelegt und auch hier **nicht** entschieden: welche Quests, welche NPCs, Story-Fortschritt bei Ziel oder Abgabe,
Reward-Werte, Save-Status/-Version, Texte.

---

## 1. Kurzfazit

- **Zustände:** Story-Quests kennen gespeichert nur `active` und `completed`, dazu einen Schrittindex.
  - Wenn der letzte Schritt erfüllt ist, wird die Quest **im selben Aufruf** `completed`. Dabei werden `completion_flag` und
    die Nachfolgerquests gesetzt.
  - „Ziele erfüllt“, „abgabebereit“, „abgegeben“ und „belohnt“ gibt es für Story-Quests nicht als eigene Zustände.
  - Alle Prolog-Endschritte, die mit `talk:` enden, sind faktisch schon **NPC-Abgaben ohne Reward**.
- **Rewards:** Story-Quests haben **kein Reward-Feld und keine Belohnung** (`StoryQuestDefinition`). Klassenquests belohnen
  nur mit einer Klassenfreischaltung, Lieferungen werden verbraucht. Item-Belohnungen in der Story gibt es nur über
  Weltobjekte (`Readable.rewards`, `StoryPickup`), nicht über Quests. **Für einen Turn-in-Piloten gibt es keinen
  vorhandenen Reward, der „an den NPC verlegt“ werden könnte.** Das ist eine Designentscheidung, kein Codeblocker.
- **`resettle`:** Es schließt beim Laden jeden aktiven Schritt ab, dessen Ziele über Zähler oder gespeicherten Fortschritt
  erfüllt sind.
  - Eine Abgabe als neuer letzter Schritt ist nur sicher mit einem **nicht kumulativen** Ziel auf einem **neuen,
    abgabeeigenen** Event.
  - Eine Abgabe als gespeicherter Zusatzzustand wird von `resettle` nie berührt, braucht aber ein neues Schema.
  - Ein abgeleiteter Claim neben `completed` (Option 1) wird von `resettle` ebenfalls nie berührt.
- **NPC-System:**
  - Pro NPC gibt es **einen** Service (`NpcDefinition.service`), und `GameHud.open_npc_service` kennt nur `hearth_flask`.
  - Ein ungehörter Dialog hat Vorrang vor dem Service.
  - Mara hat ihren Service-Slot belegt. Edrin hat **keinen** Service und ist nach `the_first_binding` dialogfrei.
  - Es gibt nur den Marker „!“ (ungehörter Storydialog mit `event_id`), **kein „?“**.
- **Empfehlung Status:** **Option 1** (Quest bleibt wie heute `completed`, Abgabe/Reward als eigenes `WorldState`-Flag,
  Anspruch abgeleitet). Ohne Save-Version, `resettle`-sicher, Story-Kette unverändert, Muster wie M4 und R2.
  - Rückwirkung auf alte Stände ist dabei eine **offene Entscheidung**.
  - Sie lässt sich ohne Schemaänderung sowohl rückwirkend (rein abgeleitet) als auch nicht rückwirkend (Berechtigungsflag bei
    Abschluss) bauen.
- **Pilot-Empfehlung:** `the_first_binding` bei **Edrin Vale** (Haven, Nordtor).
  - Edrin ist bereits der abschließende Gesprächspartner, hat keinen Service und keine Folge-Dialoge.
  - Das Abschlussflag `prologue.completed` liest **kein** Gameplay-Code.
  - Der Nachfolger `the_first_signs` ist ein offener Stub.
  - Klassenwahl, Wegstein und M4 liegen **vorher**.

---

## 2. Bestehende Queststatus (Audit A)

### 2.1 Datenmodell

| Ebene | Ort | Inhalt |
|---|---|---|
| Story-Definition | `scripts/rpg/quests/story_quest_definition.gd` | `steps`, `completion_flag`, `next_quest_ids`, `open_ended`. **Kein Reward, kein Auftraggeber/NPC-Feld** |
| Schritt | `scripts/rpg/quests/story_step.gd` | `objectives`, `completion_flag` (Flag pro Schritt) |
| Ziel | `scripts/rpg/quests/story_objective.gd` | `event_id`, `amount`, `cumulative` (liest den Weltzähler `count.<event>` statt des Schrittfortschritts) |
| Klassenquest | `scripts/rpg/quests/class_quest_definition.gd` | `class_id`, `objectives` (`TrialObjective`), `deliveries` (`ItemCost`), `requires_prologue`, `available` |
| Laufzeit/Save | `scripts/rpg/quests/quest_log.gd` | `entries[id] = {"state": "active"\|"completed", "step", "progress"}`. `from_dict` **verwirft** jeden anderen Zustand mit Warnung (`quest_log.gd:50-52`) |

### 2.2 Antworten 1–9

| # | Frage | Befund (Beleg) |
|---|---|---|
| 1 | Welche Status gibt es? | `""` (unbekannt), `active`, `completed` (`quest_log.gd:15-16, 50`). Story-Quests zusätzlich `step`. Abgeleitet: `StoryService.at_step/is_active/is_completed` (`story_service.gd:54-64`), Klassenquest „bereit“ = `QuestService.objectives_done` (`quest_service.gd:58-62`) |
| 2 | Wann `completed`? | Story: `StoryService._settle` setzt beim letzten erfüllten Schritt `state = "completed"` + `completion_flag` und startet `next_quest_ids` (`story_service.gd:123-143`). Klassenquest: nur `QuestService.turn_in` an der Klassenstation (`quest_service.gd:82-93`) |
| 3 | Wann Rewards? | Story: **nie** (kein Feld). Klassenquest: `classes.unlock` im `turn_in` (`quest_service.gd:91`). Readable/StoryPickup sind Weltobjekte, keine Quests |
| 4 | Getrennte Ziel-/Reward-Flags? | Story: nein, `completed` ist Ende und Ziel zugleich. Klassenquest: „Ziel erfüllt“ abgeleitet ≠ `completed`, das ist die einzige Trennung im Code. Eigene Reward-Flags gibt es nur außerhalb der Quests: `read.<id>`, `pickup.<id>`, `prologue.class_reward`, `boss_reward.<id>` |
| 5 | Wie liest das Journal? | Es liest `quests.state` und `step` direkt (`scripts/ui/journal_panel.gd:57-107`): Current/Completed, Schritte bis zum aktuellen, Zähler nur bei `amount > 1`. Klassenquests ACTIVE/COMPLETED (`:122-140`). HUD-Tracker `StoryService.tracker_lines` (`story_service.gd:147-160`) über `scripts/ui/objective_panel.gd:69` |
| 6 | Rein storygesteuert? | Alle sechs Story-Quests. Abschluss nur über `StoryService.notify(event)` |
| 7 | Echte NPC-Auftraggeber? | Keine Quest hat ein Auftraggeber-Feld. Faktisch durch NPC-Gespräch **abgeschlossen**: `the_broken_cart` (Mara), `shelter_among_the_trees` (Edrin), `the_first_binding` (Edrin). Gestartet werden alle Story-Quests automatisch (`next_quest_ids`), keine durch NPC-Annahme. Klassenquests: Station, kein NPC |
| 8 | Event-Counter? | Jedes `notify` erhöht `count.<event>` (`story_service.gd:91`). Kumulativ gelesen werden: `interact:supply_crate` (×2, `the_broken_cart`), `restore:old_smithy` (`shelter_among_the_trees`), `trial_complete`, `class_chosen` (`the_whispering_stone`) |
| 9 | Was schreibt `resettle` fort? | Jede **aktive** Story-Quest, deren aktueller Schritt erfüllt ist (§3). Praktisch relevant sind die kumulativen Schritte aus #8. Klassenquests werden übersprungen |

---

## 3. `StoryService.resettle` und Risiken

**Ablauf:**
- Aufruf in `Character.from_dict` (`scripts/rpg/character.gd:198`), **nach** `quests.from_dict` und `world.from_dict`, also bei
  jedem Laden und bei jeder synthetischen Rundreise.
- `resettle` (`story_service.gd:45-51`) ruft für jede aktive Story-Quest `_settle(..., announce = false)` auf: keine Signale,
  kein Meilenstein-Save, kein Toast.
- Die Erfüllung prüft `step_done` (`:111-118`) über `objective_value` (`:79-85`):
  - **kumulativ** liest sie den Weltzähler `count.<event>`
  - **nicht kumulativ** liest sie `progress[index]`; dieser wird bei jedem Schrittwechsel geleert (`:131`)
- `_settle` läuft in einer Schleife, kann also **mehrere** Schritte und die ganze Quest abschließen und dabei auch still
  Nachfolger starten (`start(..., announce)`, `:141-142`). Flags pro Schritt und pro Quest werden dabei gesetzt.

**Was das für einen Turn-in bedeutet:**

| Turn-in-Modell | Wird es durch `resettle` übersprungen? |
|---|---|
| Neuer letzter Schritt mit **kumulativem** Ziel | **Ja, Gefahr.** Jeder alte Zähler ≥ amount schließt den Schritt beim Laden still ab. Besonders bei Wiederverwendung eines `talk:`-Events: wiederholbare Dialoge erhöhen ihren Zähler bei jedem Ende (`dialogue_service.gd:69-72`) |
| Neuer letzter Schritt, **nicht kumulativ**, Event, das bisher nie gemeldet wurde (z. B. ein abgabeeigenes `turnin:<quest>`) | Nein. Der Fortschritt startet mit dem Schritt bei 0, und nur `notify` mit genau diesem Event erhöht ihn |
| Neuer gespeicherter Zustand `ready_to_turn_in` | Nein. `resettle` iteriert nur `active_ids` (`quest_log.gd:27-32`). Aber: `from_dict` verwirft den Zustand heute, ein älterer Build verlöre die Quest (Schema) |
| Option 1: `completed` + Reward-Flag | Nein. `resettle` liest und schreibt keine Reward-Flags, `completed`-Quests sind nicht aktiv |

**Weitere Risiken:**
- Nachgezogene Abschlüsse senden beim Laden kein `story_progressed`. Ein Reward, der an diesem Signal hinge, würde bei
  Altständen nie ausgelöst oder müsste beim Laden nachgezogen werden. → **Rewards nie an `story_progressed` oder `notify`
  hängen**, sondern an eine eigene, idempotente Claim-Funktion.
- `_settle` beim Laden startet Nachfolger still. Würde die Quest-Vollendung auf die Abgabe verschoben (Option 2 oder
  Abgabe-Schritt), verschiebt sich auch das Starten der Nachfolger. Siehe §5.
- Bestehende Tests dazu: `tests/integration/test_class_trials_m1.gd:98-260` (idempotent, still, unfertige Schritte bleiben,
  fertiger Prolog unberührt) und `test_class_trials_m2.gd:216`.

---

## 4. NPC-/Dialog-Service-Architektur (Audit B)

### 4.1 Bestand

| Element | Ort | Verhalten |
|---|---|---|
| NPC-Daten | `scripts/rpg/story/npc_definition.gd`, `data/npcs/mara.tres`, `data/npcs/edrin.tres` | `dialogues` (erste passende gewinnt), `idle_lines`, **ein** `service` |
| Dialog | `scripts/rpg/story/dialogue_definition.gd` | `condition`, `lines`, `event_id`, `repeatable`. Abschluss setzt `dialogue.<id>` und meldet `event_id`. **Keine Aktionen, keine Optionen, keine Auswahl** |
| Auswahl | `DialogueService.pick` (`scripts/rpg/story/dialogue_service.gd:50-59`) | Liste in Reihenfolge, Bedingung + nicht wiederholbar-und-gehört |
| Interaktion | `StoryNpc.interact` (`scripts/world/story_npc.gd:58-70`) | Ist der Dialog ungehört, öffnet der Dialog. Ist er gehört oder fehlt, öffnet der Service, falls Knoten `offers_service` **und** `service ≠ ""`. Sonst kommt ein Idle-Bark |
| Service-Fenster | `GameHud.open_npc_service` (`scripts/ui/game_hud.gd:592-601`) | feste Map `{hearth_flask: flask_panel}`. Unbekannt → false → Idle-Bark |
| Dialog im Service | `FlaskPanel` (`scripts/ui/flask_panel.gd:62-68`) | Knopf „Talk to <NPC>“ für den (gehörten) aktuellen Dialog. Damit bietet Mara heute **Service + Dialog gleichzeitig** an |
| Marker | `StoryNpc._draw` (`story_npc.gd:98-100`) | goldenes „!“ nur bei `DialogueService.has_story_dialogue` (ungehört + `event_id`). **Kein „?“** im Projekt |
| Priorität zwischen Objekten | `Interactable.find_active` (`scripts/world/interactable.gd:30-35`) | erstes sichtbares Objekt in Reichweite (Gruppenreihenfolge), keine Priorisierung |

### 4.2 NPCs

| NPC | Szenen | Präsenz | Service | Dialoge (Priorität) |
|---|---|---|---|---|
| Mara Veyne | `home_base.tscn:293-301` (`StoryNpc`, `offers_service = true`); `old_road.tscn:410-417` (Companion-Skript, kein `StoryNpc`) | Haven ab `prologue.haven_discovered` | `hearth_flask` | `mara_return` (first_binding S1), `mara_welcome`, `mara_smithy_hint`, `mara_road_end`, `mara_cart`, `mara_crates_hint`, `mara_follow`, `mara_history` (wiederholbar ab `dialogue.mara_welcome` → in Haven hat Mara praktisch immer einen gehörten Dialog → Service öffnet) |
| Edrin Vale | `home_base.tscn:303-310` (`StoryNpc`, **ohne** `offers_service`) | Haven ab `prologue.haven_discovered` | **keiner** | `edrin_threat` (first_binding S2, einmalig), `edrin_intro` (shelter S3, einmalig), `edrin_early` (shelter ≤ S2), `edrin_shrine_hint` (whispering_stone aktiv). Danach nur `idle_lines` |

### 4.3 Kann ein NPC Dialog/Service **und** Abgabe gleichzeitig anbieten?
- **Heute nein.** Eine Abgabe ist weder Dialog-Aktion noch Service. Ein zweiter Service pro NPC geht nicht (ein Feld, eine Map
  im HUD).
- Ein Dialog **mit** `event_id` kann nur ein Story-Event melden. Ein Reward im Dialog ist nicht vorgesehen und hätte keinen
  Platzcheck.
- **Kleinste sichere Erweiterung** (Empfehlung, nicht umgesetzt):
  1. **Service-Erweiterung statt Dialog-Aktion.** Ein neuer Service-Typ (z. B. Turn-in-Fenster) in `open_npc_service`
     eingetragen.
     - Für Edrin reicht der freie Slot (`service` + `offers_service` am Knoten).
     - Für Mara bräuchte es entweder einen **Abschnitt im vorhandenen Service-Fenster** (Muster „Talk“-Knopf im
       `FlaskPanel`) oder `service` als Liste. Das ist eine Architekturänderung, für einen Piloten nicht nötig.
  2. Die Abgabe-Aktion ruft nur einen zustandslosen Service (`claim`-Muster aus M4/R2) und meldet höchstens ein **eigenes**
     Event.
  3. Die Interaktionsreihenfolge bleibt: ein ungehörter Storydialog zuerst, dann Service/Abgabe. So kann eine Abgabe nie
     einen Storydialog verdrängen.
- **Mehrere Quests je NPC:** Das Turn-in-Fenster listet alle offenen Abgaben des NPCs (Daten: Quest → NPC-ID) mit je einem
  Knopf. Jede Abgabe ist eine eigene Transaktion. Es braucht keine Auswahl im Dialog.

---

## 5. Quest-/Story-Abhängigkeiten (Audit C)

Tatsächliche Reihenfolge laut `next_quest_ids` (stimmt mit der bekannten Folge überein):
`a_road_forgotten` → `the_broken_cart` → `shelter_among_the_trees` → `the_whispering_stone` → `the_first_binding` →
`the_first_signs`. Der Start erfolgt über `StoryService.begin_prologue` (`story_service.gd:15-17`).

| Quest (`data/story/`) | Start | Schritte (Event) | Abschluss-Trigger | NPC | Reward | Nachfolger / wer liest das Abschlussflag | Blockade durch NPC-Abgabe? | Pilot? |
|---|---|---|---|---|---|---|---|---|
| `a_road_forgotten` | neues Spiel | `reach:road_signpost` → `encounter:road_ambush` (Flag `road_cleared`) → `reach:cart_site` | Weltaktion | – | – | `the_broken_cart`; `prologue.road_walked` lässt Mara an der Road erscheinen (`old_road.tscn:87-89`) | **hoch** (Prolog-Einstieg, kein NPC) | nein |
| `the_broken_cart` | nach 1 | `encounter:cart_attack` → `talk:mara_cart` (`mara_rescued`) → `interact:supply_crate` ×2 kum. (`supplies_recovered`) → `encounter:cart_second_wave` (`cart_defended`) → `talk:mara_road_end` | Mara (Old Road) | – | `shelter_among_the_trees`; `prologue.cart_done` steuert Maras Folgen, Trümmer und den Übergang nach Haven (`old_road.tscn:92-105, 161-162`, `mara.tres` C_follow) | **hoch**: der Weg nach Haven hängt am Flag. Mara verlässt die Road, Rückkehr unklar | nein |
| `shelter_among_the_trees` | nach 2 | `enter:home_base` (`haven_discovered`) → `talk:mara_welcome` → `restore:old_smithy` kum. (`smithy_restored`) → `talk:edrin_intro` | Edrin (Haven) | – | `the_whispering_stone`; `prologue.haven_settled` **öffnet das Nordtor** (`home_base.tscn:42-44`, `forbidden_flags`) | **sehr hoch**, wenn der Abschluss auf die Abgabe verschoben wird: Tor, Whispering Stone, Trials, Klassenwahl, M4 und Wegstein hingen daran | nur Option 1 (Abschluss unverändert) |
| `the_whispering_stone` | nach 3 | `enter:whispering_stone` (`shrine_reached`) → `trial_complete` kum. → `class_chosen` kum. (**`first_class_selected`**) → `waystone:whispering_stone` | Wegstein | – | `the_first_binding`; `prologue.first_class_selected` gibt die Wegstein-Aktivierung frei (`whispering_stone.tscn:42-44, 225`). `prologue.stone_awakened` liest nur `save_migrations.gd` | mittel: nur der Start von `the_first_binding` verschiebt sich. Wahl, Wegstein und M4 hängen an Schritt-Flags bzw. `PrologueState`, nicht am Quest-Abschluss | nein (kein NPC) |
| `the_first_binding` | nach 4 | `enter:home_base` → `talk:mara_return` → `talk:edrin_threat` | Edrin (Haven) | – | `the_first_signs` (Stub); `prologue.completed` liest **nur** `save_migrations.gd` (grep `scenes`, `data`, `scripts`) | **gering**: der Nachfolger ist offen; Klassenwahl, Wegstein und M4 liegen vorher | **ja** (Empfehlung) |
| `the_first_signs` | nach 5 | Stub-Schritt ohne Ziel, `open_ended` | nie | – | – | – | – | nein |

**Getrennte Ebenen** (dürfen verschiedene Ereignisse sein):

| Ebene | Heute im Code |
|---|---|
| Story-Meilenstein erreicht | Schritt-/Quest-`completion_flag` in `_settle` (z. B. `prologue.first_class_selected` beim Wahl-Schritt) |
| Questziele erfüllt | `step_done` des letzten Schritts, heute = Abschluss |
| NPC-Reward abgeholt | existiert nicht |

**Unabhängig von jeder Quest-Abgabe** und damit nicht blockierbar, solange Schritt-Flags und Events unverändert bleiben:
- Trial-Fortschritt (`PrologueState.completed_trials`, `prologue_service.gd`)
- Klassenwahl (`PrologueService.can_choose`: Trials + `PrologueState`, kein Quest-Status)
- M4 (`prologue.class_reward`)
- Wegstein (`activation_condition` = Flag `first_class_selected`, `WaystoneService.activate`)
- Klassenquests (`requires_prologue` → `PrologueState.is_completed`, nicht Quest `the_first_binding`)

Die einzigen Quest-Abschluss-Abhängigkeiten im Gameplay sind `road_walked`, `cart_done`, `haven_settled` und die
`next_quest_ids`.

---

## 6. Pilotkandidaten (Audit D)

| | K1 `the_first_binding` → Edrin | K2 `shelter_among_the_trees` → Edrin | K3 `the_broken_cart` → Mara |
|---|---|---|---|
| Warum geeignet | Edrin beendet die Quest bereits (`talk:edrin_threat`); Edrin hat keinen Service und ist danach dialogfrei; das Prolog-Ende ist ein natürlicher Abgabemoment | Edrin beendet sie bereits (`talk:edrin_intro`); früher Haven-Moment | Mara beendet sie (`talk:mara_road_end`); Auftraggeberin der Cart-Handlung |
| Vorhandene Dialoge/Services | `edrin_threat` (einmalig), danach nur Idle. Service-Slot frei | `edrin_intro` (einmalig); danach `edrin_shrine_hint` (wiederholbar, ohne Event) während `the_whispering_stone` | auf der Road ist Mara ein **Companion** (`old_road.tscn:410-417`), kein `StoryNpc`, kein Service; in Haven Service belegt |
| Rückkehr möglich? | jederzeit: Haven-Wegstein, Edrin steht ab `haven_discovered` dauerhaft (`home_base.tscn:303-310`) | jederzeit in Haven | Road-Mara verschwindet mit `haven_discovered` (`mara.tres` C_follow); eine Abgabe müsste nach Haven ausweichen |
| Story-Abhängigkeiten | Abschlussflag ungelesen, Nachfolger Stub; alles Kritische liegt vorher | Abschlussflag öffnet das Nordtor → Option 2 oder ein Abgabe-Schritt würde den ganzen Klassenpfad hinter die Abgabe legen | `cart_done` → Weg nach Haven |
| Volle Tasche | unproblematisch bei Option 1 (Claim bleibt offen, Haven-Lager direkt daneben, `StashService`) | dto., aber sehr früh mit wenig Lagerplatz | Road ohne Lager |
| Technischer Eingriff | klein: Service-Typ + Edrin-Knoten `offers_service`, Claim-Service, Daten | klein bei Option 1, sehr hoch bei Option 2 | hoch (Companion-Skript, Ortswechsel) |

**Empfehlung: K1 `the_first_binding` bei Edrin Vale.** Das ist keine Freigabe, Edrin ist als Pilot nicht beschlossen.

**Einschränkung:** Es gibt keinen bestehenden Reward für diese Quest. Der Pilot braucht eine **Designfreigabe für den
Reward-Inhalt** (§12). Ohne Reward wäre die Abgabe nur ein Flag.

---

## 7. Statusmodell-Empfehlung (Audit E)

| Kriterium | **Option 1:** `completed` bleibt, Reward-Flag | **Option 2:** neuer Zustand `ready_to_turn_in` | **Option 3:** Abgabe als letzter Story-Schritt (vorhandenes `talk:`-Muster) |
|---|---|---|---|
| Kurzbeschreibung | Abschluss wie heute; Anspruch = `completed` ∧ ¬`quest_reward.<id>` (abgeleitet), Abgabe setzt das Flag | `QuestLog.state` bekommt einen dritten Wert; `completed` erst beim NPC | Datenänderung: ein Schritt mit Ziel `turnin:<quest>` (nicht kumulativ), den die NPC-Abgabe meldet |
| Journal | unverändert + Anzeige „Reward waiting with Edrin“ (abgeleitet) | jede Stelle mit `state` (Journal `:61-64`, `StoryCondition.met` `:131-151`, `StoryService.is_active/is_completed`) muss den neuen Wert kennen | zeigt den Abgabe-Schritt automatisch als „[now]“ |
| Story-Abhängigkeiten | **keine Änderung** (Flags und Nachfolger wie heute) | `completion_flag` und Nachfolger erst bei Abgabe → Blockaderisiko (§5) | wie Option 2 (Abschluss erst nach Abgabe) |
| Save/Load | keine Schemaänderung (`world.flags` frei) | **Schemaänderung**: `QuestLog.from_dict` verwirft unbekannte Zustände (`quest_log.gd:50-52`) → Version + Migration + älterer Build lehnt ab | keine Schemaänderung; Schritt-Indizes bleiben gültig, wenn **angehängt** |
| `resettle` | unberührt | unberührt (nicht aktiv) | sicher nur mit neuem, nicht kumulativem Event (§3) |
| NPC-Dialog | Abgabe als Service-Aktion, kein Dialogzwang | dto. + Zustandsübergang | Abgabe muss `notify(turnin:…)` senden; Reward getrennt nötig, da Story keine Rewards kennt |
| Duplikatschutz | Flag im selben synchronen Aufruf wie die Gutschrift (M4/R2-Muster) | Zustandswechsel im selben Aufruf | Story-Schritt einmalig, Reward bräuchte trotzdem ein eigenes Flag |
| Alte Stände | abgeleitet → rückwirkend; mit Berechtigungsflag → nicht rückwirkend (§9) | Migration muss entscheiden | aktive Altstände bekommen den neuen Schritt; bereits `completed` nie |
| Testaufwand | gering (Claim-Suite + `save`) | hoch (Story, Bedingungen, Journal, Migration, alle Prolog-Tests) | mittel (Story-Tests, Prolog-Bedingungen mit `max_step`) |

**Empfehlung: Option 1.** Gründe:
- Sie trennt Zielerfüllung und Abgabe, ohne die Story-Kette, `resettle`, `StoryCondition` oder das Save-Schema anzufassen.
- Sie ist die bereits zweimal umgesetzte Architektur:
  - M4: `PrologueService.claim_class_reward`, `scripts/rpg/prologue/prologue_service.gd:202-237`
  - R2: `BossRewardService`, `scripts/rpg/world/boss_reward_service.gd`

Option 3 ist nur dann besser, wenn Design ausdrücklich will, dass die **Story erst bei Abgabe** weitergeht. Für K1 wäre das
harmlos (Stub-Nachfolger), für K2 nicht. Option 2 bringt gegenüber Option 3 nichts außer einem Schemawechsel.

Vorgeschlagene Flag-Namen (nur Vorschlag):
- `quest_reward.<quest_id>` (Abgabe/Belohnung erhalten)
- optional `quest_turnin.<quest_id>` (Berechtigung, §9)

Werte immer `bool true`. Begründung: `WorldState.has_flag` vergleicht `!= false` und wirft bei String-Werten
(`scripts/rpg/world/world_state.gd:48`, Befund aus R2).

---

## 8. Reward- und Inventarsicherheit (Audit F)

| Baustein | Befund (Beleg) |
|---|---|
| Gold | `gold_coin` ist Währung: `room_for` gibt `CURRENCY_ROOM` zurück, braucht keinen Slot (`scripts/rpg/items/inventory.gd:16, 76-77`). Gold kann eine Gutschrift nie an der Tasche scheitern lassen |
| Material | `Inventory.add_item` ist **pro Item** alles-oder-nichts (`inventory.gd:91-117`): Rückgabe leer bei zu wenig Platz |
| Equipment | Neue Instanz über `ItemCreation.generate` oder `EquipmentLoot.roll`, Übergabe mit `add_instance` (`inventory.gd:120-136`, lehnt bei voller Tasche/doppelter ID ab) |
| Kapazität mehrerer Items | **keine** gemeinsame API. Vorbild für einen Gesamtplan: `SalvageService._room_after_removal` (`scripts/rpg/professions/salvage_service.gd:159-173`, Stapel zuerst, dann Slots) |
| Bestehende einmalige Claims | M4 (`prologue.class_reward`, Prüfung → Erzeugung → `add_instance` → Zustand), R2 (`boss_reward.<id>`, Prüfung → Wurf → `add_instance` → Flag), `StoryPickup` (Prüfung → `add_item` → `pickup.<id>`) |
| **Negativ-Vorbild** | `Readable.interact` (`scripts/world/readable.gd:34-49`): Platz wird **je Reward einzeln** geprüft (zwei Nicht-Stapel-Items sehen beide denselben freien Slot), und das `read.<id>`-Flag wird **vor** der Gutschrift gesetzt, die Rückgabe von `add_item` ignoriert. Bei gemischten Rewards ist eine **Teilauszahlung mit gesetztem Flag** möglich. Heutige Daten sind unkritisch: Torn Note = 12 Gold (Währung) + 2 Timber; Memory Fragment = 1 Essence |

**Gold + Ausrüstung in einem Reward:** technisch möglich. Teilauszahlung verhindern:
1. Alle Prüfungen vor jeder Änderung: Zustand, Trial, NPC, Gesamtplatz über **alle** Nicht-Währungs-Teile (Plan wie
   `_room_after_removal`).
2. Instanzen erst nach bestandener Prüfung erzeugen (Wurf nach der Platzprüfung, R2).
3. Gutschrift in fester Reihenfolge: zuerst die Teile, die scheitern können (Instanzen, Stapel), zuletzt Währung (kann nicht
   scheitern).
4. Scheitert ein Teil trotzdem, die bereits gutgeschriebenen Teile zurücknehmen. Vorbild ist das Rollback in `SalvageService`
   (`salvage_service.gd:150-153`, `remove_quantity` + `add_instance`). Kein Flag setzen.
5. Erst nach vollständiger Gutschrift das Reward-Flag setzen, dann einen Meilenstein-Save (`request_critical_save`).
6. Alles in **einem** synchronen Aufruf. Der `SaveCoordinator` macht seinen Snapshot in einem eigenen Frame
   (`scripts/rpg/save/save_coordinator.gd`) und sieht alles oder nichts.

Volle Tasche: Es kommt eine klare Meldung, der Anspruch bleibt, kein Wurf, keine Weltbeute. Das Haven-Lager steht neben
Edrin.

---

## 9. Altspielstände (Audit G, synthetisch über die Save-Logik)

| Altzustand | Was der Code beim Laden tut | Folge für Option 1 |
|---|---|---|
| aktive Quest, Ziele unvollständig | `from_dict` übernimmt `active/step/progress`; `resettle` ändert nichts | Abschluss später regulär → Anspruch entsteht dann |
| aktive Quest, Ziele erfüllt (nur kumulativ möglich, z. B. Zähler vorab) | `resettle` schließt still ab (`character.gd:198`) | Quest `completed` ohne Signal → ein abgeleiteter Anspruch entsteht; ein Berechtigungsflag müsste in `_settle` gesetzt werden (läuft auch still) |
| bereits `completed` | unverändert | **abgeleitet: Anspruch offen (rückwirkend)**; mit Berechtigungsflag: kein Anspruch |
| alte Rewards ausgegeben | Es gab **keine** Quest-Rewards; `read.*`/`pickup.*` sind Weltobjekte und bleiben gesperrt | keine Doppelzahlung alter Belohnungen möglich |
| Status nach `resettle` | idempotent (Test `test_class_trials_m1.gd:98`) | mehrfaches Laden ändert nichts |
| fehlende neue Turn-in-Daten | `world.flags` ohne `quest_reward.*` | = „nicht abgeholt“; keine Migration nötig |
| abgeschlossener Prolog | v4→v5-Migration **schreibt** `completed`-Einträge (Schritt 0) und `prologue.completed` für Prolog-Stände (`scripts/rpg/save/save_migrations.gd:163-175`) | **`completed` ist kein Nachweis echten Spielens.** Ein abgeleiteter Anspruch würde auch migrierten v1–v4-Ständen zufallen |

**Drei Kategorien:**

| Kategorie | Erkennbar im Save? |
|---|---|
| (1) historisch abgeschlossen | `state completed` |
| (2) historisch belohnt | existiert nicht (keine Quest-Rewards) → leer |
| (3) unter neuer Regel abgabebereit | nur erkennbar, wenn der neue Code den Abschluss **markiert** (Berechtigungsflag beim Abschluss in `_settle`) |

Ohne Markierung sind (1) und (3) nicht unterscheidbar.

**Ohne Save-Version machbar:**
- **R-A (rückwirkend):** Anspruch = `completed` ∧ ¬Reward-Flag. Alle Altstände inklusive migrierter v4-Stände bekommen eine
  Abgabe.
- **R-B (nicht rückwirkend):** Anspruch = Berechtigungsflag ∧ ¬Reward-Flag. Das Berechtigungsflag setzt nur ein Abschluss
  durch neuen Code. Altstände mit `completed` bekommen nichts. Eine Migration ist dafür nicht nötig, weil das Fehlen des
  Flags genügt.
- **R-C (selektiv, z. B. nur mit Dialognachweis `dialogue.edrin_threat`):** Das Flag schreibt nur `DialogueService.finish`.
  Migrierte v4-Stände haben es nicht. Ein Nachweis wie bei M4, aber eine **Heuristik-Entscheidung**.

Festgelegt wird hier nichts (E5).

---

## 10. Journal, Marker und UI (Audit H)

| Anzeige | Bestand | Lücke für Turn-ins |
|---|---|---|
| Journal-Eintrag | Current/Completed, Schritte, Zähler (`journal_panel.gd:57-107`) | kein „Reward waiting“ |
| HUD-Zielhinweis | `tracker_lines` nur aktive Quests (`story_service.gd:147-160`) | eine `completed`-Quest mit offener Abgabe verschwindet aus dem Tracker (Option 1) |
| NPC-„!“ | nur ungehörter Storydialog (`story_npc.gd:98-100`) | kein Abgabe-Marker |
| „?“ | existiert nicht | – |
| Dialogauswahl | keine Optionen (`dialogue_definition.gd`) | Abgabe nicht im Dialog |
| Belohnungsbestätigung | Toast (`hud.notify`) + Loot-Feed mit Instanz-Rarity (R2: `item_received(item_id, qty, item)`) | wiederverwendbar |
| Full-Inventory-Meldung | Texte in M4/R2/Readable/StoryPickup, uneinheitlich | einheitlicher Text nötig |

**Empfehlung, mit möglichst wenigen neuen Zuständen:**
- **Ein** abgeleiteter Anzeigezustand „Reward waiting“, sonst nichts.
- Marker: ein „?“ über dem NPC, solange eine Abgabe offen ist. Die Konvention „! = Story geht weiter, ? = Abgabe“ ist bekannt
  und kollidiert nicht, weil „!“ Vorrang hat.
- Tracker: eine Zeile „Return to Edrin Vale“ für jede offene Abgabe, und zwar in `tracker_lines` oder im `ObjectivePanel`.
- Journal: bei der Completed-Karte „Reward waiting with Edrin Vale“.
- Abgabe-Aktion: im Service-Fenster mit `UiWindow.footer`, Muster wie der Altar-Footer in M4.
- Keine neue UI-Szene nötig, wenn das Fenster als neuer Service-Typ ein vorhandenes `UiWindow`-Muster nutzt.
- Neue Chrome-Texte über `localization/ui.csv`.

---

## 11. Minimaler Implementierungsplan (Audit I)

Die Reihenfolge T1 → T2 → T3 ist durch die Code-Abhängigkeiten gedeckt: Der Vertrag (Service + Flags) muss vor der
NPC-Aktion stehen, die UI hängt an beidem.

**T1 – Status-/Reward-Vertrag, Save- und Story-Sicherheit**
- Umfang:
  - zustandsloser `QuestRewardService` (Name offen) mit `has_claim`, `can_claim(character, quest_id, npc_id)` und
    `claim(...)`; Ablauf nach §8
  - Reward-Daten als Resource (Quest → NPC → Reward), keine Codeketten
  - Rückwirkungsvariante nach E5 (R-A/R-B/R-C)
- Dateien:
  - neu: `scripts/rpg/quests/quest_reward_service.gd`, Reward-Definition unter `data/`
  - `GameDatabase`-Validierung
  - bei R-B **eine** Zeile in `StoryService._settle` (Berechtigungsflag bei Abschluss, auch still)
- Akzeptanz:
  - kein Anspruch vor dem Abschluss
  - Anspruch nach dem Abschluss, auch nach Save/Load und `resettle`
  - volle Tasche: nichts gutgeschrieben, kein Flag
  - nie eine zweite Gutschrift
  - Altstand-Regel nach E5
  - Story-Kette, Flags und `resettle` unverändert
- Migration: keine (v15). Nur wenn Option 2 gewählt würde: v16.
- Tests: neue Suite `quest_turnin`, dazu `save`, `class_trials_m1` (resettle) und `prologue` (der bekannte Altfehler
  `test_migration_v3_to_v4` gesondert ausweisen).
- Ausgeschlossen: `QuestLog`-Zustände, Dialogsystem, NPC-Szenen, Class Trials, M4, R2, Loot-Rolls.

**T2 – Pilot-NPC-Interaktion und einmalige Belohnung**
- Umfang:
  - neuer Service-Typ in `GameHud.open_npc_service`
  - am Edrin-Knoten in `scenes/maps/home_base.tscn` `offers_service = true`, in `data/npcs/edrin.tres` `service`
  - Fenster mit Abgabe-Footer
  - Meilenstein-Save nach erfolgreicher Abgabe
  - Reward-Daten für `the_first_binding` nach Freigabe
- Dateien: `scripts/ui/game_hud.gd`, neues `UiWindow`-Fenster, `data/npcs/edrin.tres`, `home_base.tscn`, Reward-Resource,
  `localization/ui.csv`, Eintrag in `GalleryScreens`.
- Akzeptanz:
  - ein ungehörter `edrin_threat` hat Vorrang
  - nach dem Abschluss öffnet G das Fenster
  - Abgabe einmal
  - volle Tasche hält den Anspruch
  - Kartenwechsel und Save/Load verlieren nichts
  - Mara und `hearth_flask` unverändert
- Migration: keine.
- Tests: `quest_turnin` (Fenster headless), `hud`, `flask` bzw. die Consumables-Suite (der Service-Pfad darf nicht
  regressieren).
- Ausgeschlossen: mehrere Services pro NPC, Mara, Dialogoptionen, weitere Quests.

**T3 – Gezielte UI-/Integrationsabnahme**
- Umfang:
  - „?“-Marker in `StoryNpc._draw`
  - Tracker-Zeile und Journal-Hinweis
  - visuelle Abnahme in einer Auflösung (Fenster, Marker, Toast, Loot-Feed)
- Dateien: `scripts/world/story_npc.gd`, `scripts/rpg/quests/story_service.gd` (`tracker_lines`) bzw.
  `scripts/ui/objective_panel.gd`, `scripts/ui/journal_panel.gd`.
- Akzeptanz:
  - „?“ genau bei offenem Anspruch
  - „!“ hat Vorrang
  - kein Marker nach der Abgabe
  - Journal und Tracker zeigen die offene Abgabe
- Migration: keine.
- Tests: `quest_turnin`, `hud`, `journal` (falls vorhanden), gezielt `ui_gallery --only=<neues Fenster>`. Keine
  Prolog-/Haven-Loops.
- Ausgeschlossen: HUD-Neugestaltung, neue Notification-Engine.

---

## 12. Echte Blocker und offene Designentscheidungen

**Technische Blocker:** keiner für Option 1.

Harte Grenzen:
- `QuestLog.from_dict` verwirft neue Zustände → Option 2 nur mit Save-Version.
- Ein NPC hat einen Service → Mara nur mit einer Architekturerweiterung.
- Dialoge haben keine Aktionen → Abgabe nicht im Dialog.
- `WorldState`-Flags nur als bool, nicht als String.

**Inhaltlicher Blocker:** Keine Story-Quest hat heute eine Belohnung. Für einen Turn-in braucht es eine Freigabe, **was**
übergeben wird.

**Entscheidungen, die eine Freigabe brauchen:**
- **E1 – Statusmodell:** Option 1 (empfohlen) · Option 3 (Abgabe-Schritt, Story erst bei Abgabe) · Option 2 (neuer Zustand,
  v16).
- **E2 – Story-Fortschritt:** bei Zielerfüllung (heute, Option 1) oder erst bei Abgabe (Option 2/3; für
  `shelter_among_the_trees` riskant, §5).
- **E3 – Pilot:** `the_first_binding` → Edrin (empfohlen) · `shelter_among_the_trees` → Edrin · andere.
- **E4 – Reward-Inhalt** des Piloten (Gold, Material, Equipment, Kombination; Rarity/ilvl/Herkunft, z. B. `quest_reward`).
  Es gibt heute keinen vorhandenen Wert.
- **E5 – Altstände:** R-A rückwirkend · R-B nur neue Abschlüsse · R-C mit Dialognachweis.
- **E6 – Abgabe während einer Trial** sperren (wie M4/R2) oder erlauben.
- **E7 – Marker und Texte:** „?“-Konvention, Tracker-/Journal-Formulierung, einheitliche Full-Inventory-Meldung.
- **E8 – Mara langfristig:** mehrere Services pro NPC oder Abschnitt im Flask-Fenster (nicht für den Piloten).
- **E9 – `Readable`-Teilauszahlung** (§8): als eigener Bugfix behandeln oder belassen, weil die heutigen Daten unkritisch sind.
