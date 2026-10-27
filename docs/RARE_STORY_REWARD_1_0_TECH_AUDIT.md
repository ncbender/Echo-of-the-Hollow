# Rare Story Reward 1.0 – Quest Reward & Save Integration Audit

Read-only-Audit (Branch `audit/rare-story-reward-10`, Basis `c930cb8`). Keine Implementierung, keine Tests/Playtests,
keine echten Saves gelesen. Geprüft: Story-/Questdaten und -dienste, Journal/HUD/Dialog-UI, `ItemCreation`, `Inventory`,
`ItemInstance`, `SaveSystem`/`SaveCoordinator`/`SaveMigrations`, vorhandene Story-/Shrine-Tests.

Zielbild (verbindlich, nicht Gegenstand des Audits): Nach Questabschluss ein dauerhafter, einmaliger Anspruch auf **eine**
Rare-Waffe (ilvl 20, 3/4 Affixe 60/40, T5 75 / T4 25) aus neun Modellen; Wurf erst bei endgültiger Bestätigung; volles
Inventar verbraucht nichts; nach Claim nie wieder ein Wurf.

---

## 1. Kurzfazit

- **Quest:** `the_whispering_stone` ist technisch geeignet (einmaliger, sauberer Abschluss, Teil der linearen Kette, vom
  v4→v5-Migrationspfad abgedeckt). Inhaltlich ist sie die **vorletzte** abschließbare Quest; die tatsächlich letzte ist
  `the_first_binding` (Kandidat, falls der Reward am Ende des spielbaren Kapitels bzw. bei Edrin übergeben werden soll).
  Eine „späte Hollowwood“-Quest im eigentlichen Sinn existiert nicht – alle Story-Quests liegen im Prolog.
- **Hooks:** Es gibt **kein Reward-Feld und keine Reward-Ausgabe** für Story-Quests. Vorhanden und ausreichend:
  persistierter Queststatus (`QuestLog`), freie persistierte Weltflags (`WorldState.flags`), Abschluss-Signal
  `QuestLog.story_progressed` (→ Toast + Meilenstein-Save), Journal (J, überall erreichbar), `UiConfirmDialog`.
- **Inventar:** Ja – vor dem ersten Zufallswurf ist **zuverlässig** prüfbar, ob die Waffe aufgenommen wird
  (`Inventory.room_for` / `free_slots`; `add_instance` prüft danach exakt dieselbe Bedingung, synchron, ohne Zwischenframe).
  Keine Schnittstellenerweiterung nötig.
- **ItemCreation:** `ItemCreation.generate` deckt Rare ilvl 20 bereits vollständig ab: `AFFIX_COUNTS[RARE] = {3: 60, 4: 40}`,
  `data/loot/hollowwood_early_tiers.tres` liefert für ilvl 10–24 genau **T5 75 / T4 25**, Herkunft `ORIGIN_QUEST` existiert.
- **Save:** **Keine neue Save-Version nötig.** „Available“ ist aus dem Queststatus ableitbar, „Claimed“ passt als
  Weltflag (`WorldState.flags`, String-Wert erlaubt) in das bestehende v14-Schema. Snapshot ist ein ganzer Charakter in
  einem Frame → Item und Claim-Flag landen immer gemeinsam (oder gemeinsam nicht) im Save.
- **Kleinster Weg:** optionales Datenfeld an `StoryQuestDefinition` + kleiner zustandsloser `StoryRewardService`
  (Status/Claim) + ein schlankes Auswahlfenster (`UiWindow`) mit Einstieg über die Journal-Questkarte und
  `UiConfirmDialog` für die finale Bestätigung.

---

## 2. Tatsächliche Quest-Reihenfolge

Schema: `StoryQuestDefinition` (`scripts/rpg/quests/story_quest_definition.gd:6-17`: `id`, `display_name`, `chapter`,
`description`, `steps`, `completion_flag`, `next_quest_ids`, `open_ended`). Regeln: `StoryService`
(`scripts/rpg/quests/story_service.gd`). Die Kette ist durch `test_story_data_is_valid_and_chained`
(`tests/integration/test_story.gd:89-98`) festgeschrieben.

| # | ID (Datei) | Start | Schritte / Abschlussbedingung | `completion_flag` | Nachfolger |
|---|---|---|---|---|---|
| 1 | `a_road_forgotten` (`data/story/a_road_forgotten.tres`) | `StoryService.begin_prologue` (`story_service.gd:32-34`) | `reach:road_signpost` → `encounter:road_ambush` → `reach:cart_site` | `prologue.road_walked` | `the_broken_cart` |
| 2 | `the_broken_cart` (`data/story/the_broken_cart.tres`) | Abschluss #1 | `encounter:cart_attack` → `talk:mara_cart` → `interact:supply_crate` ×2 (kumulativ) → `encounter:cart_second_wave` → `talk:mara_road_end` | `prologue.cart_done` | `shelter_among_the_trees` |
| 3 | `shelter_among_the_trees` (`data/story/shelter_among_the_trees.tres`) | Abschluss #2 | `enter:home_base` → `talk:mara_welcome` → `restore:old_smithy` (kumulativ) → `talk:edrin_intro` | `prologue.haven_settled` | `the_whispering_stone` |
| 4 | **`the_whispering_stone`** (`data/story/the_whispering_stone.tres`) | Abschluss #3 | `enter:whispering_stone` → `trial_complete` ×3 (kumulativ) → `class_chosen` → `waystone:whispering_stone` | `prologue.stone_awakened` | `the_first_binding` |
| 5 | `the_first_binding` (`data/story/the_first_binding.tres`) | Abschluss #4 | `enter:home_base` → `talk:mara_return` → `talk:edrin_threat` | `prologue.completed` | `the_first_signs` |
| 6 | `the_first_signs` (`data/story/the_first_signs.tres`) | Abschluss #5 | Stub-Schritt ohne Ziel, `open_ended = true` – **schließt nie ab** | – | – |

Abschlussmechanik: Gameplay meldet nur `StoryService.notify(event)` (`story_service.gd:90-108`); `_settle`
(`story_service.gd:123-142`) setzt Schritt-/Questflags, `state = "completed"`, emittiert
`QuestLog.story_progressed(quest_id, step, finished)` und startet die `next_quest_ids`. `start()` ist für bekannte
Quests ein No-op (`story_service.gd:46-47`), `_settle` läuft nur für aktive Quests (`:125`) → ein Abschluss kann **nur
einmal** stattfinden.

Erreichbarkeit von #4: Das Haven-Nordtor ist bis `prologue.haven_settled` gesperrt (`scenes/maps/home_base.tscn:44`,
`forbidden_flags`), der Übergang `ToShrine` führt nach `whispering_stone` (`home_base.tscn:326-331`). Der finale
Schritt wird durch das Erwecken des Wegsteins ausgelöst: `Waystone.awaken` → `WaystoneService.activate` →
`StoryService.notify("waystone:whispering_stone")` (`scripts/world/waystone.gd:47-60`,
`scripts/rpg/world/waystone_service.gd:41`). Unmittelbar danach öffnet `awaken` Dialogzeilen (`hud.open_lines`,
`waystone.gd:58-59`), und `SessionState._on_story_progressed` zeigt „Quest complete: …“ und fordert einen kritischen
Save an (`scripts/rpg/session_state.gd:125-129`; Toast-Verdrahtung `scripts/world/game_map.gd:62`).

Vorhandene Tests der Übergänge: `test_full_prologue_walkthrough` (`test_story.gd:112-132`, inkl. Stone → Binding),
`test_save_and_load_at_every_prologue_step` (`:149-158`), `test_story_progress_triggers_a_milestone_save` (`:203`),
`test_migrated_v4_character_continues_at_the_echoes` (`:224-232`); `test_choice_only_after_all_echoes_and_success_after_save`
und `test_waystone_activation_and_travel` (`tests/integration/test_shrine.gd:156-186, 209-220`),
`test_return_to_haven_and_main_quest` (`test_shrine.gd:245ff.`).

**Bewertung:** `the_whispering_stone` ist der letzte Meilenstein *in der Welt* (Klassenwahl + erster Wegstein) und
thematisch stark („Pfad gewählt → Waffe gewählt“). Sie ist aber nicht die späteste Quest: `the_first_binding`
endet ca. eine Minute später in Haven mit `talk:edrin_threat` und setzt `prologue.completed`. Beide liegen in der ersten
Spielstunde; eine „späte Hollowwood“-Quest gibt es nicht (vgl. `docs/LOOT_EQUIPMENT_2_6_SOURCE_AUDIT.md` §3.1/3.3).
→ **Geeignet**, mit **`the_first_binding` als Kandidat**, falls die Übergabe am Kapitelende/bei Edrin gewünscht ist.
Technisch ist der Unterschied nur der Wert eines Datenfelds (§7).

---

## 3. Quest-/Reward-Hooks

| Baustein | Fundstelle | Befund |
|---|---|---|
| Reward-Feld Story-Quest | `story_quest_definition.gd:6-17`, `story_step.gd` | **fehlt** |
| Reward Klassenquest | `class_quest_definition.gd:17-19`, `quest_service.gd:82-93` | nur `deliveries` (Kosten), Belohnung = Klassenfreischaltung |
| Persistierter Queststatus | `scripts/rpg/quests/quest_log.gd:12-58` (`entries[id] = {state, step, progress}`, `to_dict`/`from_dict`) | vorhanden; Zustände nur `"active"`/`"completed"` – `from_dict` **verwirft** andere Zustände (`:50-52`), ein dritter Zustand wäre also eine Schemaänderung |
| Persistierte Flags | `scripts/rpg/world/world_state.gd:12, 24-39, 67-97` (bool/int/String; `has_flag` = vorhanden und ≠ false) | vorhanden, frei benennbar, ohne Schemaänderung |
| Präzedenzfall „einmalige Belohnung“ | `scripts/world/readable.gd:34-49` | Platzprüfung **vor** Flag und Ausgabe, volles Inventar → nichts genommen, nichts markiert, später erneut möglich; Flag `read.<id>` in `WorldState` |
| Abschluss-Ereignis | `QuestLog.story_progressed` (`quest_log.gd:10`, emittiert `story_service.gd:138`) | einmal pro Questabschluss (`finished = true`); verbunden in `session_state.gd:109-114` |
| Queständerung (UI-Refresh) | `QuestLog.changed` (`story_service.gd:50, 107`) | von `StoryNpc`/`StoryConditional`/`StoryPickup` genutzt |
| Herkunft „Quest reward“ | `ItemInstance.ORIGIN_QUEST = &"quest_reward"` (`scripts/rpg/items/item_instance.gd:56-59`), Label `item_protection.gd:78` | vorhanden, bisher **ungenutzt** |
| NPC-Service-Fenster | `NpcDefinition.service` (`scripts/rpg/story/npc_definition.gd:13-15`), `StoryNpc.interact` (`scripts/world/story_npc.gd:58-63`), `GameHud.open_npc_service` (`scripts/ui/game_hud.gd:592-601`) | **ein** Service pro NPC; Mara hat `hearth_flask` (`data/npcs/mara.tres:207`), Edrin keinen |
| Dialog | `GameHud.open_dialogue/open_lines` mit `on_done` (`game_hud.gd:272-282`) | Dialoge haben keine Item-Aktionen; `open_*` schließt alle Fenster |
| Fenster-/Input-Sperren | `GameHud.is_window_open/close_windows` (`game_hud.gd:289-299`), Esc schließt Fenster (`:526-531`), Interagieren schließt offene Fenster statt zu interagieren (`game_map.gd:176-183`) | einheitlich, kein Pausieren nötig |

Kleinster Anschluss für die drei Zustände – **ohne neue Questarchitektur**:

1. **Quest completed** – unverändert `QuestLog`-Zustand `"completed"` (bzw. `completion_flag`). Der Claim greift nicht
   in `StoryService._settle` ein; die Story läuft unabhängig weiter.
2. **Reward available** – **abgeleitet**, nicht gespeichert: `quest.reward != null and is_completed(quest) and not
   claimed`. Kein Ereignis-Abo nötig, daher idempotent gegenüber mehrfachen Callbacks und automatisch korrekt für alte
   Saves.
3. **Reward claimed** – ein Weltflag, z. B. `reward.the_whispering_stone` mit dem gewählten Modell als String-Wert
   (`WorldState.set_flag` erlaubt String, `world_state.gd:24-31`). Präzedenz: `read.<id>`, `count.<event>`.

Erneute Erreichbarkeit nach Schließen: Da „available“ abgeleitet ist, genügt ein **dauerhafter Einstieg**. Das Journal
(J, `game_hud.gd:409-417`) ist auf jeder Karte erreichbar und listet abgeschlossene Story-Quests bereits als Karten
(`scripts/ui/journal_panel.gd:57-92`). Ein Knopf „Choose reward“ auf der abgeschlossenen Questkarte (bzw. „Reward
claimed: <Modell>“) ist der kleinste globale Einstieg. Ein Toast beim Abschluss („A reward awaits – open the Journal
(J)“) zeigt ihn an. NPC-Übergabe (Edrin) wäre möglich, braucht aber einen Service-Eintrag und bindet den Claim an einen
Ort (Designentscheidung, §9).

---

## 4. Bestehende UI-Einstiege

| Baustein | Fundstelle | Nutzen |
|---|---|---|
| Questabschluss-Anzeige | Toast über `SessionState.message` (`session_state.gd:127`, `game_map.gd:62`), `ToastFeed.push` (`scripts/ui/toast_feed.gd:20`) | Hinweis „Reward available“ |
| Questjournal | `JournalPanel` (`journal_panel.gd`; Completed-Karten `:80-92`) | dauerhafter Einstieg + Claimed-Anzeige; Doku-Kommentar nennt das Journal „read-only“ (`:7`) – ein Knopf, der nur ein anderes Fenster öffnet, ändert keine Daten |
| Einmalige Auswahl als Vorbild | `ClassChoicePanel` (`scripts/ui/class_choice_panel.gd`): Karten in `HFlowContainer`, Auswahl → Bestätigung, kritischer Save, Erfolg erst nach `save_finished` (`:61-99`) | Ablauf- und Save-Rückmeldungsvorlage; die 2-Klick-Bestätigung dort ist **älter** – CLAUDE.md verlangt für neue Bestätigungen `UiConfirmDialog` |
| Modale Bestätigung | `UiConfirmDialog.ask(title, message, confirm_text, on_confirm)` (`scripts/ui/ui_confirm_dialog.gd:33-60`) | `_resolve` kehrt zurück, wenn bereits unsichtbar, und leert `_on_confirm` **vor** dem Aufruf → zweiter Klick/Enter ruft nichts erneut auf; Cancel hat Fokus, Esc bricht ab |
| Fensterbasis / Footer | `UiWindow` (`scripts/ui/ui_window.gd:19`, `footer`) | primäre Aktion im Footer (Regel CLAUDE.md) |
| Item-Icon | `ItemIcon.setup(definition)` + `rarity` (`scripts/ui/item_icon.gd:20-60`) | Definition-Icon mit **Rare-Rahmen ohne Instanz** (`icon.rarity = RARE`) |
| Seltenheitsfarbe/-name | `UiTheme.rarity_color/rarity_name/rarity_pips` (`scripts/ui/ui_theme.gd:88-133`) | Rare-Farbe und Wort |
| Familienname | `ItemDescriber.type_name(definition)` (`scripts/ui/item_describer.gd:180`) | Waffenfamilie ohne Instanz |
| Item-Tooltip | `ItemTooltip.show_for(character, instance, anchor)` (`scripts/ui/item_tooltip.gd:33`) | braucht eine **Instanz** → für die Auswahl ungeeignet; nach dem Claim für die echte Waffe nutzbar |
| Vorschau-Instanz (Präzedenz) | `ProfessionsPanel` erzeugt `ItemCreation.create(..., "preview")` (`scripts/ui/professions_panel.gd:462`) | hier **nicht** empfohlen: Vorgabe „keine vollständige Instanz vor Bestätigung“; Basisschaden lässt sich ohne Instanz berechnen (§5) |
| Galerie | `GalleryScreens.ALL` (`tests/playtest/gallery_screens.gd:6-11`) | neues Fenster dort eintragen (Regel) |

**Empfohlener minimaler UI-Umfang**
- Ein `UiWindow` „Choose your reward“ mit neun Karten (Icon mit Rare-Rahmen, Name, Familie, „Item Level 20 · Rare“,
  Basis-Waffenschaden, Hinweis „3–4 random affixes, rolled when you claim“). Klick wählt nur aus (UI-Zustand, nichts
  gespeichert, nichts erzeugt); erneuter Klick auf eine andere Karte wechselt; Schließen jederzeit.
- Footer-Knopf „Claim“ → `UiConfirmDialog.ask(...)`. Bestätigen ruft genau den Service-Claim.
- Volles Inventar: Status-Text im Fenster (Readable-Text als Vorlage, `readable.gd:41`), Fenster bleibt offen.
- Erfolg: Fenster zeigt den Claimed-Zustand (gewählte Waffe; optional `ItemTooltip` der echten Instanz), Toast mit
  Instanz-Rarity (der Loot-Feed zeigt Definitions-Rarity, `docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md` §5).
- Einstieg: Journal-Karte der Quest; Toast beim Questabschluss. Texte über `localization/ui.csv` (`UI_...`).

---

## 5. Inventory und ItemCreation

**Die neun Modelle** (`data/items/<id>.tres`; alle Normal, `max_stack = 1`, `base_item_level = 1`, kein `CraftingProfile`,
`base_weapon_damage` = Familienreferenz → Modellfaktor 1,0; Familien `data/weapons/*.tres`):

| Item-ID | Slot | Familie | B1 | Basis bei ilvl 20 = B1 × (1 + 0,012 × 19) | `generation_affixes` |
|---|---|---|---|---|---|
| `iron_sword` | 1H | one_handed_sword | 12 | 14,736 | 13 IDs |
| `steel_greatsword` | 2H | two_handed_sword | 22 | 27,016 | 13 |
| `iron_axe` | 1H | axe | 14 | 17,192 | 13 |
| `iron_dagger` | 1H | dagger | 9 | 11,052 | 13 |
| `iron_mace` | 1H | mace | 15 | 18,420 | 13 |
| `ash_spear` | 2H | spear | 13 | 15,964 | 13 |
| `oak_staff` | 2H | staff | 13 | 15,964 | 13 |
| `oak_wand` | 1H | wand | 10 | 12,280 | 13 |
| `hunting_bow` | 2H | bow | 13 | 15,964 | 12 (ohne `executioner`) |

Formel: `WeaponDamage.reference_at` / `model_factor` / `base_for_level` (`scripts/rpg/items/weapon_damage.gd:41-67`,
`LEVEL_SLOPE = 0.012` `:13`). Werte rechnerisch ermittelt (nicht ausgeführt); Gegenprobe: `iron_mace` ilvl 12 = 16,980
in `docs/LOOT_FOUNDATION_1_0.md:156`. Die UI kann den Wert **ohne Instanz** über
`WeaponDamage.base_for_level(definition, 20, db)` anzeigen.

**`ItemCreation.generate`** (`scripts/rpg/items/item_creation.gd:58-91`):
- Rare-Anzahl bereits genau gefordert: `AFFIX_COUNTS[RARE] = {3: 60.0, 4: 40.0}` (`:17-23`).
- Item-Level explizit übergeben (20) → kein Rückgriff auf Definitionsquelle (`:62`).
- Ablehnungen vor jedem Wurf: keine `generation_affixes`, Unique/Set, Level außerhalb 1–100, Tier-Tabelle deckt Level
  nicht (`:63-72`) – alle neun Modelle erfüllen die Voraussetzungen.
- Tier-Tabelle: `data/loot/hollowwood_early_tiers.tres` Band 10–24 = `{4: 25, 5: 75}` → exakt T5 75 / T4 25. Alle
  15 Affixe nutzen das Fünf-Tier-Modell (`data/crafting/affixes/*.tres`, `tier_model = 5`); T4 ist ab ilvl 10 erreichbar
  (`AffixTiers.MIN_ITEM_LEVELS`, `scripts/rpg/crafting/affix_tiers.gd:16`).
- Eligibility: `AffixRoller.roll_one` (`scripts/rpg/crafting/affix_roller.gd:82-93`) zieht Identität, dann Tier, dann Wert;
  bei zu kleinem Pool → `shortfall` statt Regelbiegung (`item_creation.gd:87-89`). Für Waffen mit 12–13 IDs ist Rare 4
  in den Loot-Foundation-Stichproben ohne Shortfall erreicht worden (`docs/LOOT_FOUNDATION_1_0.md:156-157`); für alle
  neun Modelle ist das per Test abzusichern (§8), nicht hier behauptet.
- `origin`-Parameter (`:60, :75`) → `ItemInstance.ORIGIN_QUEST`. Ergebnis wird **nicht** ins Inventar gelegt (`:57`).
- RNG wird injiziert (`rng`); Präzedenz Lootquellen: `GameMap.loot_rng` (`docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md` §2).

**Instanz-IDs:** `ItemInstance.create` → `IdGenerator.new_id("itm")` = 64 Bit aus dem OS-CSPRNG
(`item_instance.gd:62-64`, `scripts/rpg/id_generator.gd:9-10`) – stabil, gespeichert, Kollision praktisch ausgeschlossen.

**Inventar** (`scripts/rpg/items/inventory.gd`):
- `free_slots()` (`:41-42`), `is_full()` (`:51-52`), `room_for(item_id)` (`:72-83`; Waffe: `free_slots() * 1`).
- `add_instance(item)` (`:120-136`) übernimmt die Instanz **unverändert** (gleiches Objekt, gleiche ID, kein Re-Roll);
  Ablehnungen nur bei: `null`, unbekannter Definition, leerer/doppelter ID, ungültiger Menge, `is_full()` für
  Slot-Items. Bei Ablehnung **keine** Änderung, kein Signal.
- Pickup-Präzedenz: `ItemPickup` übergibt per `add_instance` (`docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md` §2).

**Antwort auf die Kernfrage:** **Ja.** Vor dem ersten Zufallswurf ist zuverlässig feststellbar, dass die Waffe
aufgenommen wird: `room_for(item_id) >= 1` (bzw. `not is_full()`) ist dieselbe Bedingung, die `add_instance` später
prüft; alle übrigen Ablehnungsgründe sind vorab ausgeschlossen (Definition validiert, ID frisch, Menge 1). Prüfung,
Generierung und Übergabe laufen synchron in **einem** Aufruf; zwischen ihnen kann kein Frame, kein Save und keine
andere Inventaränderung liegen. **Keine Schnittstellenerweiterung nötig.**

Seiteneffekte bei fehlgeschlagenem Add: `generate` verändert nichts außerhalb der neuen Instanz und des RNG-Zustands;
die verworfene Instanz existiert nur lokal (nicht gespeichert, nicht im Inventar). Einziger Effekt wäre ein verbrauchter
RNG-Schritt – bei richtiger Reihenfolge (Claim-Flag erst nach Erfolg) bleibt der Anspruch erhalten.

---

## 6. Save- und Idempotenzanalyse

Grundlagen:
- `SaveSystem.VERSION = 14` (`scripts/rpg/save/save_system.gd:20`). Hinweis: `docs/SAVE_SYSTEM.md` Abschnitt
  „Migrationen“ nennt noch „Aktuell: Version 13“ (`docs/SAVE_SYSTEM.md:91`, Doku-Abweichung; „Format (Version 14)“ steht korrekt oben).
- Snapshot = `Character.to_dict()` (`scripts/rpg/character.gd:146-164`) mit `inventory`, `stash`, `quests`, `world`
  in **einem** synchronen Aufruf zur Schreibzeit (`scripts/rpg/save/save_coordinator.gd:113-131`); Schreiben
  temp → prüfen → .bak → rename (`save_system.gd:58-94`). Es gibt keine getrennte Reihenfolge Quest vs. Inventar:
  beide stehen im selben Payload.
- Saves entstehen nur in `SaveCoordinator._process/flush` (ein Write pro Frame, nur bei `can_write`, `:76-111`) –
  nie mitten in einem synchronen Spielaufruf. Kritische Saves werden bei Fehlschlag wiederholt (`:126-127`).
- Quests: `QuestLog.to_dict/from_dict` (`quest_log.gd:35-58`); Flags: `WorldState.to_dict/from_dict`
  (`world_state.gd:67-97`, String-Werte bleiben String).
- **Kein vorhandenes Reward-/Claim-Flag** für Story-Quests.

Empfohlene Claim-Reihenfolge (ein synchroner Aufruf, kein `await`):
`Modell ∈ erlaubte Liste` → `Quest completed` → `nicht claimed` → `room_for ≥ 1` → `generate` (Fehler → Abbruch) →
`add_instance` (Fehler → Abbruch, kein Flag) → **unmittelbar** `set_flag(reward.<quest>, model_id)` → `changed`-Signale →
`request_critical_save`.

| Risiko | Bewertung | Schutzklasse |
|---|---|---|
| Doppelklick bei Bestätigung | `UiConfirmDialog._resolve` ignoriert Aufrufe bei unsichtbarem Dialog und leert `_on_confirm` vor dem Aufruf (`ui_confirm_dialog.gd:52-60`); zusätzlich prüft der Service das Claim-Flag | IN EINER SITZUNG GESCHÜTZT (und nach Save/Load über das Flag) |
| Mehrfacher Questabschluss-Callback | `_settle` schließt nur aktive Quests ab (`story_service.gd:125`); „available“ ist abgeleitet, kein Callback erzeugt Items | IN EINER SITZUNG GESCHÜTZT, NACH SAVE/LOAD GESCHÜTZT |
| Speichern vor der Auswahl | Auswahl ist reiner UI-Zustand; Save enthält „completed, nicht claimed“ → nach Laden wieder verfügbar | NACH SAVE/LOAD GESCHÜTZT |
| Speichern während der Ausgabe | Claim ist synchron; Snapshot erfolgt frühestens im nächsten Frame und enthält Item **und** Flag gemeinsam | IN EINER SITZUNG GESCHÜTZT, NACH SAVE/LOAD GESCHÜTZT |
| Laden nach erfolgreichem Claim | Flag in `world.flags` gespeichert → kein erneuter Claim | NACH SAVE/LOAD GESCHÜTZT (sobald ein Save nach dem Claim geschrieben wurde) |
| Item nach Claim weggeworfen/verschoben/zerlegt | Flag ist unabhängig vom Besitz; nichts prüft das Item | NACH SAVE/LOAD GESCHÜTZT |
| Fehler nach Generierung, vor Übergabe | `add_instance` kann nach Vorprüfung praktisch nicht ablehnen; falls doch: kein Flag, Anspruch bleibt, nächster Versuch würfelt neu (kein Duplikat) | IN EINER SITZUNG GESCHÜTZT (kein Duplikat; theoretisch neuer Wurf) |
| Laufzeitfehler (Script-Error) zwischen `add_instance` und `set_flag` | Godot bricht die Funktion ab → Item im Inventar, Flag fehlt → zweiter Claim möglich. Minimierbar durch direkte Abfolge ohne Code dazwischen, nicht ausschließbar | **NICHT ABGESICHERT** (Restrisiko, sehr klein) |
| Absturz nach Claim, vor erfolgreichem Save | Item und Flag gehen **gemeinsam** verloren → Anspruch wieder offen, neuer Wurf; kein Duplikat | kein Duplikat, aber **NICHT ABGESICHERT** gegen Neu-Wurf; keine Crash-Sicherheit versprochen |
| Laden eines älteren Saves (anderer Slot/Autosave) vor dem Claim | Spieler kann neu wählen/würfeln („Save-Scumming“); in jedem einzelnen Save höchstens eine Waffe | **NICHT ABGESICHERT** (systembedingt, wie bei allen Würfen; Designentscheidung) |
| Erneute Erzeugung bei UI-Neuöffnung | UI erzeugt nichts; Anzeige aus Definitionen + `WeaponDamage.base_for_level`; Claimed-Anzeige aus Flag | IN EINER SITZUNG GESCHÜTZT, NACH SAVE/LOAD GESCHÜTZT |
| Alte Entwicklungssaves mit abgeschlossener Quest | „available“ abgeleitet → Reward erscheint nach dem Laden verfügbar; v4→v5-Migration setzt die Quest für fertige Prologe ebenfalls auf `completed` (`scripts/rpg/save/save_migrations.gd:161-170`) | funktioniert ohne Migration; ob gewollt = Designentscheidung |

Atomarität, die die Architektur tatsächlich bietet: **In-Memory-Atomarität pro Frame** (synchroner Aufruf, Snapshot nur
zwischen Frames) plus **Save-Atomarität pro Datei** (ganzer Charakter, temp/rename, .bak). Keine Transaktion über
Absturzgrenzen; kein Journal. Idempotenz entsteht ausschließlich über das persistierte Claim-Flag.

**Save-Version:** **Nicht nötig.** Flag-Namen sind freie Keys in `world.flags`; ein neues optionales Export-Feld an
`StoryQuestDefinition` ist Datendefinition, kein Save-Schema. Bedarf entstünde nur, wenn (a) ein eigener Questzustand
wie `"reward_claimed"` in `QuestLog` gespeichert würde (`from_dict` verwirft ihn heute) oder (b) alte Saves den Reward
**nicht** erhalten sollen (dann z. B. Migration v14→v15, die für bereits abgeschlossene Quests `reward.<id>` =
`"legacy"` setzt). Beides wird nicht empfohlen.

---

## 7. Minimaler Integrationsvorschlag

(Vorschlag, nicht implementiert.)

1. **Daten:** neue Resource `StoryRewardChoice` (z. B. `scripts/rpg/quests/story_reward_choice.gd`):
   `item_ids: Array[StringName]` (die neun), `rarity = RARE`, `item_level = 20`, `tier_weights: AffixTierWeights`.
   Optionales Export-Feld `reward_choice: StoryRewardChoice` an `StoryQuestDefinition`; Instanz z. B.
   `data/story/rewards/whispering_stone_weapon.tres`, referenziert aus `data/story/the_whispering_stone.tres`.
   Questwechsel auf `the_first_binding` = Referenz umhängen. Validierung in `StoryService.validate_data` ergänzen
   (Modelle existieren, sind Waffen, haben `generation_affixes`, Tier-Tabelle deckt ilvl). Keine Quest-ID im Code.
2. **Regeln:** zustandsloser `StoryRewardService` (analog `StoryService`/`WaystoneService`):
   `state(character, quest_id) -> "none" | "locked" | "available" | "claimed"`, `claim_error(character, quest_id, item_id)`,
   `claim(character, quest_id, item_id, rng) -> {error, item}` in der Reihenfolge aus §6. Flag-Konstante
   `reward.<quest_id>`, Wert = gewähltes Modell. `ItemCreation.generate(..., ORIGIN_QUEST)` + `Inventory.add_instance`.
   Keine Goldänderung.
3. **Save:** keine Versionsänderung, keine Migration. Nach erfolgreichem Claim `SessionState.request_critical_save`;
   Erfolgsmeldung erst nach `save_finished` (Muster `ClassChoicePanel`, CLAUDE.md „Erfolg erst nach Schreiben“).
4. **UI:** ein `UiWindow` „Choose your reward“ (§4) + Knopf auf der Journal-Questkarte + Toast bei Abschluss
   (`_on_story_progressed` bzw. ein Listener auf `story_progressed` mit `finished`). Bestätigung nur über
   `UiConfirmDialog`. Eintrag in `GalleryScreens`.
5. **Tier-Tabelle:** entweder Referenz auf `hollowwood_early_tiers.tres` (exakt passend) oder eigene Tabelle mit Band
   20–20 `{5: 75, 4: 25}`, damit spätere Drop-Balancing-Änderungen den Reward nicht mitverändern (empfohlen: eigene).

Nicht nötig: neue Questzustände, Mailbox, Belohnungstruhe, Bodenablage, neue Inventar-API, neues Autoload.

---

## 8. Gezielter späterer Testplan

Neue Suite `tests/integration/test_story_reward.gd` (feste Seeds, nur `user://test_saves/`), plus Wiederholung der
direkt betroffenen Suites: `story`, `shrine` (nur wenn Journal/Shrine berührt), `inventory`, `save`, `loot_foundation`,
`hollowwood_loot` (wenn Tier-Tabelle geteilt). Keine Vollsuite, kein Prolog-/Haven-/Crafting-Playtest.

| # | Test | Erwartung |
|---|---|---|
| 1 | Quest abschließen ohne Claim | `the_whispering_stone` `completed`, Nachfolger aktiv, `state = available`, Inventar unverändert |
| 2 | Vor Abschluss | `state = locked`, `claim` abgelehnt, kein RNG-Verbrauch |
| 3 | Fenster öffnen/schließen/wieder öffnen | weiterhin `available`, keine neuen Instanzen, Inventar/Stash unverändert |
| 4 | Alle neun Modelle (je ein Claim auf frischem Charakter) | genau 1 neue Instanz des Modells, `effective_rarity = RARE`, `item_level = 20`, `base_weapon_damage = base_for_level(def, 20)`, `origin = quest_reward` |
| 5 | Verteilung (3000 Generierungen über denselben Pfad) | 3/4 Affixe ≈ 60/40 (± 3 %), nur T5/T4 mit T4 ≈ 25 % (± 3 %), keine Duplikate/Ausschlüsse, kein Shortfall bei allen neun Modellen |
| 6 | Kein Roll vor Bestätigung | Auswahl/Wechsel in der UI ändert RNG-Zustand und Inventar nicht (Zähler-RNG oder Seed-Vergleich) |
| 7 | Inventar voll | `claim` → Fehler „inventory full“, kein `generate` (RNG unverändert), kein Flag; nach Platz schaffen Claim erfolgreich |
| 8 | Doppelklick | `UiConfirmDialog.confirm()` zweimal bzw. `claim` zweimal → genau 1 Item, zweiter Aufruf „already claimed“ |
| 9 | Save/Load vor Claim | Laden → `available`, Claim danach möglich |
| 10 | Save/Load nach Claim | Laden → `claimed`, Flag-Wert = Modell, Item mit identischem `to_dict`, kein weiterer Claim |
| 11 | Item nach Claim entfernt (Tasche → Lager, `remove_instance`, Salvage) | bleibt `claimed`, auch nach Save/Load |
| 12 | Ungültige Item-ID (unbekannt, nicht in Liste, Rüstung) | abgelehnt, kein Item, kein Flag |
| 13 | Generierungsfehler (Test-Reward-Resource ohne Tier-Abdeckung) | Fehler, kein Item, kein Flag |
| 14 | Übergabefehler (Instanz-ID-Kollision erzwungen) | kein Flag, Inventar unverändert |
| 15 | Alter v14-Payload mit `the_whispering_stone` completed (synthetisch, kein echter Save) | nach Laden `available` |
| 16 | Datenvalidierung | `StoryService.validate_data` ohne Fehler; fehlerhafte Reward-Daten werden gemeldet |
| 17 | Questübergänge unverändert | bestehende `test_story`-Tests (Kette, Walkthrough, Milestone-Save) grün; Claim beeinflusst `QuestLog` nicht |
| 18 | Meilenstein-Save nach Claim | genau ein kritischer Save angefordert; UI-Erfolg erst nach `save_finished(ok)` |

Optionaler UI-Test (nur Fenster, keine Playtests): Fenster zeigt neun Karten mit Rare-Farbe, ilvl 20, Basisschaden;
keine Affixtexte; Claimed-Zustand ohne Knopf. Galerie-Screenshot nur gezielt (`--only=...`).

---

## 9. Blocker und notwendige Designentscheidungen

**Technische Blocker: keine.** Alle Bausteine existieren; es fehlen nur Reward-Daten, ein kleiner Service und UI.

Offene Entscheidungen:
1. **Quest:** `the_whispering_stone` (Wegstein am Stein, direkt nach Klassenwahl) oder `the_first_binding`
   (letzte abschließbare Quest, Übergabe in Haven bei Edrin)?
2. **Einstieg:** Journal (überall, empfohlen) oder NPC (Edrin bräuchte einen Service; nur ein Service pro NPC,
   `npc_definition.gd:13-15`) oder Altar am Stein (ortsgebunden)?
3. **Powerkurve:** ilvl 20 Rare liegt deutlich über allen regulären Quellen (Grunts ilvl 3–7, Wölfe 8–12,
   `docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md` §3) – bewusst so?
4. **Tier-Tabelle:** bestehende `hollowwood_early_tiers` teilen oder eigene Reward-Tabelle (empfohlen)?
5. **Alte Saves:** Reward für bereits abgeschlossene Quest rückwirkend verfügbar (empfohlen, ohne Migration) oder nicht
   (dann Migration + Version 15)?
6. **Neu-Wurf über ältere Saves / Absturz vor Save:** akzeptiert (kein Duplikat pro Save) oder zusätzliche Maßnahme
   gewünscht? Echte Absicherung ist mit der heutigen Save-Architektur nicht möglich.
7. **Shortfall-Politik:** Falls `generate` für ein Modell weniger Affixe liefert – akzeptieren (Standard Loot Foundation)
   oder als Fehler behandeln? Für die neun Waffen erwartet nicht, aber nur durch Test belegbar.
8. **Klassenbezug:** alle neun Modelle für jede Klasse wählbar (wie vorgegeben) oder Hinweis auf Klassen-/Mastery-
   Passung in der Karte? (Mastery schaltet nur Pfade frei, keine Sperre.)
