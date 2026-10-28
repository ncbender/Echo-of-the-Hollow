# Loot & Quest Architecture 1.0 – Audit

Read-only-Audit (Branch `audit/loot-quest-architecture-10`, Basis `3ee9bdd`). Keine Implementierung, keine Tests/Playtests,
keine echten Saves gelesen, keine Daten-/Szenen-/UI-/Save-Änderungen. Fremde Arbeitskopie-Änderungen (`project.godot`,
`docs/Design/`, `docs/tasks/`) unberührt.

Neuer Designstand (Vorgabe, nicht Gegenstand des Audits): einmalige **Magic**-Klassenwaffe nach Klassenwahl
(warrior → `steel_greatsword`, arcanist → `oak_staff`, shadowrunner → `iron_dagger`), Klassenidentität =
`prologue.chosen_class`, alle Klassen dürfen alle Familien nutzen, Grunt-/Wolf-Drops unverändert, ein Regionsboss mit
garantiert genau **einem Rare** aus den zwölf Hollowwood-Modellen, Questbelohnungen perspektivisch bei NPCs, nach drei Trials
drei erkennbare Abschlussmöglichkeiten mit genau einer Wahl, Rarity bestimmt die Affixanzahl, volles Inventar → kein Wurf
und kein Verbrauch eines Anspruchs.

Legende: **IST** = im Code vorhanden. **NEU** = Designwunsch, existiert nicht.

---

## 0. Kurzfazit

| Thema | Befund |
|---|---|
| Klassenreward-Hook | Einziger Ort der Klassenwahl: `PrologueService.choose_starting_class` (`scripts/rpg/prologue/prologue_service.gd:119-130`), ausgelöst nur über `ClassChoicePanel.choose` (2-Klick) an der `ClassChoiceStation` „Heart of the Stone“. `prologue.chosen_class` wird genau dort und nur einmal gesetzt. Kein Item-Reward vorhanden. |
| Drei Abschlussmöglichkeiten | **IST:** genau **eine** Wahlstelle (Heart of the Stone) mit **drei Karten**; Wahl von genau einer Klasse ist vollständig implementiert. **Kein** Fragezeichen/Marker an Trials oder am Altar. Drei getrennte Abgabe-Interaktionen existieren **nicht**. |
| Regionsboss | `grove_warden` (`data/enemies/grove_warden_config.tres`, `rank = 2` = einziger Boss-Rang im Projekt), Knoten `GroveWarden` in `scenes/maps/whisper_forest.tscn:233-238`, `persistent_id = &"whisper_forest_grove_warden"`. Einmalig (Flag `defeated.whisper_forest_grove_warden`), kein Respawn. Keine Equipment-Tabelle, nur feste Drops. Nicht an Story gebunden; ab Haven-Ankunft frei erreichbar. |
| Rare-Pool (12 Modelle) | 9 Waffen: Rare 3 **und** 4 möglich. `leather_cap`, `wanderer_coat`, `oak_shield`: nur 3 gültige Affixe → Rare 3 ja, **Rare 4 nie** (Shortfall, wird von `EquipmentLoot.roll` stillschweigend akzeptiert). `thundering` ist auf allen neun Waffenmodellen würfelbar, aber dort **nie wirksam**. |
| NPC-Abgabe | Story-Quests kennen nur `active`/`completed`; „bereit zur Abgabe“ und „Belohnung ausgegeben“ existieren nicht. Präzedenz für abgeleitetes „bereit“: Klassenquests (`QuestService.can_turn_in` an der Klassenstation). Edrin: kein Service, nach `the_first_binding` dialogfrei. Mara: Service-Slot belegt (`hearth_flask`). |
| Save / Loot-Feed | Save v14, keine Claim-Flags vorhanden, keine Implementierung des verworfenen Rare-Story-Rewards. Loot-Feed zeigt weiterhin **Definitions**-Rarity. Liegende Instanz-Drops sind transient (Kartenwechsel = Verlust). |

---

## A. Klassenwaffen

### A.1 Tatsächlicher Ablauf (IST)

| # | Ereignis | Code | Zustand danach | Save |
|---|---|---|---|---|
| 1 | Ankunft `whispering_stone` | `GameMap._ready` → `StoryService.notify("enter:whispering_stone")` | Quest `the_whispering_stone` Schritt 0 → 1, Flag `prologue.shrine_reached` | kritisch (`SessionState._on_story_progressed`, `scripts/rpg/session_state.gd:125-129`) |
| 2 | Trial starten | `TrialStation.interact` (`scripts/world/trial_station.gd:22-36`) → `PrologueService.begin_trial` (`prologue_service.gd:37-50`) | temporäre Klasse/Build/Loadout-Kopie, `stage = IN_PROGRESS` | keiner; laufender Trial wird nie gespeichert (`prologue_state.gd:3-5`) |
| 3 | Trial abgeschlossen | `PrologueService.record` → `end_trial(true)` (`:53-71`) | `completed_trials += id` (nur erster Abschluss), alles Temporäre verworfen, danach `StoryService.notify("trial_complete")` (kumulativer Zähler `count.trial_complete`) | Trial 1/2: **kein** kritischer Save (Schritt nicht fertig), nur periodisch; Trial 3/3: Schritt 1 fertig → kritisch |
| 4 | Klassenwahl | `ClassChoiceStation.interact` → `GameHud.open_class_choice` → `ClassChoicePanel.choose` (2 Klicks, `scripts/ui/class_choice_panel.gd:61-86`) → `PrologueService.choose_starting_class` | `classes.unlock` + `set_active`, `chosen_class = id`, `stage = COMPLETED`, `notify("class_chosen")` → Schritt 2 fertig, Flag `prologue.first_class_selected` | **zwei** kritische Anforderungen im selben Frame: Panel (`:81`, Erfolgsanzeige erst nach `save_finished`) und `_on_story_progressed` |
| 5 | Wegstein erwecken | `Waystone.awaken` (`scripts/world/waystone.gd:47-60`), Bedingung `C_after_choice` = Flag `prologue.first_class_selected` (`whispering_stone.tscn:44-45, 282-286`) → `WaystoneService.activate` → `notify("waystone:whispering_stone")` | Quest `the_whispering_stone` **completed**, Flag `prologue.stone_awakened`, `the_first_binding` startet | kritisch (Waystone + Story) |
| 6 | Klassenfreischaltung | bereits in #4 (`unlock`); keine separate Freischaltung bei Questabschluss | – | – |

Bisherige Inventarvergabe im Prolog: Startausrüstung bei `CharacterFactory.create_new` (`iron_sword`, `steel_greatsword`,
`leather_cap`, `wanderer_coat`, 3× `minor_potion`, Herkunft `starting`; `data/progression/progression_rules.tres:33`),
`MemoryFragment` (`hollow_essence`, Readable mit Platzprüfung), Story-Pickups. **Trials und Klassenwahl vergeben keine Items**
(Regel in `prologue_service.gd:4-6` und `trial_definition.gd:3-5`: „never grants … items“ – gilt für Trials).

### A.2 Mögliche Hooks für die Magic-Klassenwaffe

| Hook | Bewertung |
|---|---|
| **In** `choose_starting_class` (synchron, nach `unlock/set_active`) | Gleicher Frame wie Wahl → Item, `chosen_class` und Claim-Flag landen gemeinsam im nächsten Snapshot. **Konflikt mit Vorgabe 9:** die Klassenwahl ist permanent und darf nicht am Inventar scheitern; ein Reward im selben Aufruf müsste bei vollem Inventar übersprungen werden → dann braucht es ohnehin einen zweiten Ausgabeort. Würde außerdem den Prolog-Kontrakt „Wahl = nur Klasse“ verändern. |
| **Abgeleiteter Anspruch** + eigener Claim-Aufruf | „verfügbar“ = `prologue.is_completed()` ∧ `chosen_class ∈ Mapping` ∧ nicht `reward.<…>`-Flag. Kein Event-Abo, idempotent, korrekt nach Save/Load und für Altstände. Ausgabe über einen expliziten Claim (Präzedenz `Readable`: Platzprüfung → Ausgabe → Flag, `scripts/world/readable.gd:34-49`). **Technisch sicherster Weg.** |
| Claim-Ort: `ClassChoicePanel` nach der Wahl | Panel bleibt nach Wahl an der Station erreichbar (Abschluss-Text `:105-112`), Station ist jederzeit wieder besuchbar (Wegstein-Reise). Kleinster UI-Einstieg; ortsgebunden. |
| Claim-Ort: NPC in Haven (Edrin/Mara) | passt zu Vorgabe 6, braucht aber Service-Erweiterung (§E). |
| Claim bei Questabschluss (`story_progressed`) | nicht empfohlen: Signal ist einmalig (`_settle` nur für aktive Quests), ein voller Rucksack verpasst das Ereignis; abgeleiteter Zustand ist robuster. |

Zeitpunkt (Wahl / Wegstein / `the_first_binding`) ist **offen** – technisch macht nur der Zustand, aus dem „verfügbar“
abgeleitet wird, einen Unterschied (`prologue.is_completed()` vs. Questzustand).

### A.3 Randfälle

| Fall | Befund |
|---|---|
| `prologue.chosen_class` als Quelle | stabil: einziger Schreiber im Spielcode ist `choose_starting_class:126` (sonst nur `class_playtest.gd:56-57`, Debug-Playtest). Spätere Klassenwechsel (`Character.switch_class`, `character.gd:75-86`) und Klassenquests (`QuestService.turn_in`) ändern es **nie**. → Klassenreward darf **nicht** `classes.active_class_id` lesen. |
| `basic_adventurer` | Startklasse (`progression_rules.gd:12`), nie `chosen_class` (nicht in `prologue_class_ids`, `can_choose:109-110`). Mapping ohne Eintrag → kein Anspruch (fail-closed nötig). |
| Fehlende/inkonsistente Wahl | `PrologueState.from_dict` (`prologue_state.gd:170-180`) prüft `chosen_class` **nicht** gegen `stage` oder `prologue_class_ids`. Ein Save mit `stage = completed` und `chosen_class = ""` oder unbekannter ID wird geladen. Claim muss daher `chosen_class ∈ prologue_class_ids` **und** Mapping-Eintrag prüfen. |
| Altstände | v3→v4 (`save_migrations.gd:93-113`) setzt `chosen_class` **heuristisch** auf die erste freigeschaltete von warrior/arcanist/shadowrunner (keine echte Wahl). v4→v5 setzt bei fertigem Prolog `the_whispering_stone`/`the_first_binding` auf completed. Abgeleiteter Anspruch → solche Altstände erhalten den Reward rückwirkend (gewollt? → Blocker 5). |
| Inventar voll | `Inventory.room_for` / `free_slots` (`scripts/rpg/items/inventory.gd:41, 72`) prüfen exakt die Bedingung von `add_instance` (`:120`) – vor dem Wurf zuverlässig prüfbar (bestätigt im Vor-Audit `RARE_STORY_REWARD_1_0_TECH_AUDIT.md` §5). |
| Erneuter Aufruf / Save-Load | nur über ein persistiertes Claim-Flag in `WorldState.flags` sicher (frei benennbar, v14-kompatibel). Doppelklick: `UiConfirmDialog` + Flag-Prüfung. |
| Laufender Trial | Wahl ist während eines Trials gesperrt (`can_choose:107-108`); `end_trial` stellt Loadout aus Kopie wieder her – ein Item darf nicht während eines Trials vergeben werden (Claim zusätzlich an `not classes.in_trial()` binden). |

### A.4 Generierung Magic ilvl 5 (nur Prüfung, kein Level festgelegt)

`ItemCreation.generate(def, MAGIC, db, rng, hollowwood_early_tiers, 5, origin)` (`scripts/rpg/items/item_creation.gd:58-91`):
- `generation_affixes` vorhanden für alle drei Waffen (13 IDs), Definitions-Rarity Normal → zulässig.
- ilvl 5 explizit → Level-Prüfung ok; Tier-Tabelle `data/loot/hollowwood_early_tiers.tres` Band 1–9 = **nur T5** → `covers(5)`.
- Magic-Anzahl 1/2/3 = 40/40/20 (`AFFIX_COUNTS`, `:17-23`); Pool nach Ausschlussgruppen ≥ 11 → kein Shortfall möglich.
- Ergebnis: **gültige Magic-Waffe mit ausschließlich T5-Affixen**, Waffenbasis `WeaponDamage.base_for_level(def, 5)` einmalig.
- Herkunft: `ItemInstance.ORIGIN_QUEST` (`&"quest_reward"`, `item_instance.gd:56`) existiert und ist ungenutzt; ob „Quest reward“
  für eine Klassenwahl das richtige Label ist, ist offen (`ORIGIN_STARTING` wäre die Alternative).
- Hinweis zu Vorgabe 8: `ItemCreation.create` setzt die **Definitions**-Rarity ohne Affixe. `wanderer_coat` hat Definitions-Rarity
  **Magic** (`data/items/wanderer_coat.tres`) → der Startmantel ist eine Magic-Instanz mit **0** regulären Affixen. Bestehender
  Widerspruch zu „Rarity bestimmt Affixanzahl“ (nur Anzeige, keine Logik), nicht durch dieses Feature verursacht.

---

## B. Trials und drei Abschlussmöglichkeiten

| Frage | Befund (IST) |
|---|---|
| Welche Trials? | `trial_warrior` („Echo of the Warrior“), `trial_arcanist`, `trial_shadowrunner` (`data/trials/*.tres`), Klassen = `ProgressionRules.prologue_class_ids` (`progression_rules.gd:33`). Pedestale `TrialWarrior/TrialArcanist/TrialShadowrunner` in `scenes/maps/whispering_stone.tscn:214, 234, 254`. |
| Abschluss | sobald alle `objectives` erfüllt (`PrologueService.record:83-100`) → `end_trial(true)` → `completed_trials`. Persistiert in `PrologueState` (+ Story-Zähler). Abbrechen (`end_trial(false)`) zählt nicht. |
| Marker | Trials: nur Welttext-Suffix „(walked)“ (`trial_station.gd:90-91`), **kein** „?“/„!“. Altar „Heart of the Stone“ (`whispering_stone.tscn:274-277`, `class_choice_station.gd`): pulsierender Glanz, **kein** Zustandsmarker. „?“ gibt es nur auf ungelesenen `Readable`s (`readable.gd:71-72`); „!“ nur auf `StoryNpc` mit ungehörtem Storydialog (`story_npc.gd:98-100`). HUD-Tracker zeigt „Echoes walked (n/3)“ und danach „Choose your path“. `EchoHint` (`whispering_stone.tscn:195`) zeigt nur einen Erklärtext während Schritt 1. |
| Drei Abgabe-Interaktionen? | **Existieren nicht.** Nach drei Trials sind die Pedestale nur noch „walked“; ein erneuter Trialstart ist bis zur Wahl erlaubt (zählt aber nicht erneut). Die Wahl findet ausschließlich am **einen** Altar statt. |
| Gleichwertig? | Die drei Karten unterscheiden sich nur in Klasse/Text/Ressource (`ClassChoicePanel._card`). Wirkung identisch strukturiert: genau eine Klasse wird freigeschaltet + aktiviert; die beiden anderen bleiben gesperrt und sind später über Klassenquests (`data/quests/unlock_*.tres`, `QuestService`) freischaltbar. Keine weitere unterschiedliche Wirkung. |
| Verbindliche Wahl | `PrologueService.choose_starting_class` (einmalig; `can_choose` lehnt nach `is_completed()` ab). |

**Trennung IST vs. NEU:** „Spieler erkennt drei Optionen und wählt genau eine“ ist **funktional bereits erfüllt** (ein Altar,
drei Karten, 2-Klick-Bestätigung, Meilenstein-Save). Es fehlt nur der **Hinweis**, dass nach drei Trials die Wahl wartet.

**Kleinste Erweiterung (nicht festgelegt, zwei Varianten):**
1. *Ein Marker am bestehenden Altar*: `ClassChoiceStation._draw` zeichnet einen Zustandsmarker, solange
   `PrologueService.can_choose(character, any) == ""` (Muster `StoryNpc`-„!“). Keine neuen Knoten, Dialoge oder Regeln.
2. *Drei Wahlpunkte an den Pedestalen*: `TrialStation` zeigt nach allen drei Trials einen Marker und öffnet das **bestehende**
   `ClassChoicePanel` mit vorausgewählter Klasse. Regel bleibt in `PrologueService`; aber: Pedestal-Interaktion ist heute
   „Trial starten“ – Doppelbelegung bis zur Wahl muss entschieden werden.

Welche Variante „drei geeignete Abschlussmöglichkeiten“ meint, ist eine **Designentscheidung** (Blocker 2).

---

## C. Regionsboss

| Merkmal | Befund |
|---|---|
| Identität | Config-ID `grove_warden`, Anzeigename „Grove Warden“, `rank = 2` (Boss), `data/enemies/grove_warden_config.tres`; einziger Boss-Rang im Projekt (`hardened_husk` = Elite). Region `hollow_outskirts` (`data/world/regions/hollow_outskirts.tres`). |
| Szene | `scenes/maps/whisper_forest.tscn:233-238`, Knoten `Enemies/GroveWarden`, `persistent_id = &"whisper_forest_grove_warden"`, **kein** `equipment_loot`. |
| Erreichbarkeit | Haven-Osttor `ToForest` (`home_base.tscn:345-351`) **ohne** Bedingung → ab `prologue.haven_discovered` frei, also **vor** Trials/Klassenwahl möglich. Kein Story-Bezug, keine Quest. Wegstein `wardens_rest` ist `available = false`. |
| Hooks | `Health.died` → `Enemy._on_died` → `Enemy.defeated` (`enemy.gd:167-171`). `GameMap.register_enemy` (`game_map.gd:82-89`) verbindet `_spawn_drops` (`:130-138`) und – nur bei `persistent_id` – `_on_persistent_enemy_defeated` (`:96-98`). |
| Derzeitige Drops | fest: 1× `hollow_essence`, 2× `iron_ore`, 25× `gold_coin` (Config `drops`); keine Ausrüstung. |
| Einmaligkeit | Flag `defeated.whisper_forest_grove_warden` (`defeat_flag`, `:92-93`) in `WorldState.flags`; `_remove_defeated_enemies` (`:102-106`) entfernt ihn bei jedem Kartenladen. **Kein Respawn.** Getestet: `test_defeated_boss_stays_gone_after_save_and_load` (`tests/integration/test_economy.gd:117-157`). |
| Save beim Tod | **keiner** angefordert; Flag landet erst im nächsten periodischen/manuellen/Meilenstein-Save. Absturz davor → Boss lebt wieder, erneute Besiegung möglich (je Save höchstens ein Sieg). |
| Weltpickup | `GameMap.spawn_item_pickup` (`:120-127`) übergibt die Instanz unverändert; `ItemPickup` ist transient. Der Test oben bestätigt: liegende Bossbeute wird **nicht** gespeichert. |

**Garantierter Rare genau einmal – was existiert:**
- `Enemy.equipment_loot` + `_spawn_drops` + Meta `equipment_rolled` = genau ein Wurf pro Tod. `EquipmentLoot.roll` mit
  `chance = 1.0` ist garantiert (`rng.randf() >= 1.0` nie wahr, `equipment_loot.gd:12`); `rarity_weights = {RARE: 100}` ist gültig
  (`equipment_loot_table.gd:21-40`). Zwölf Modelle in einer Tabelle sind zulässig. → **Datenseitig ohne Code ausdrückbar**,
  als Export am platzierten Knoten (nicht an der Config → Testspawns über `spawn_enemy(config)` bleiben unberührt).
- Kombiniert mit dem Persistenz-Flag ergibt das „einmal pro berechtigter Besiegung“ **innerhalb** der Persistenzregeln.

**Was dabei kollidiert (nicht lösen, nur benennen):**
1. **Vorgabe 9:** Der Wurf passiert beim Tod, unabhängig vom Inventar; bei vollem Inventar bleibt das Item liegen
   („Inventory full – … stays on the ground“, `item_pickup.gd:48-50`). Das ist „Generierung trotz vollem Inventar“.
2. **Transienz:** Kartenwechsel/Laden ohne Aufheben → Rare verloren, Boss bleibt tot (Flag) → Anspruch endgültig verbraucht.
3. `EquipmentLoot.roll` ignoriert `shortfall` → Rüstung/Schild würden als Rare mit 3 statt 4 Affixen fallen (§D).
4. Item-Level eines Boss-Rares ist nicht festgelegt; jede Tabelle braucht ein Level ≤ 24 (Tier-Abdeckung), sonst Ablehnung.

Ein Vorgabe-9-konformer Weg bräuchte einen **Anspruch statt Weltdrop** (Flag „Belohnung offen“ beim Tod, Wurf erst bei
Interaktion mit Platzprüfung – Muster `Readable`), z. B. ein bedingt sichtbares Interactable am Bossplatz oder Ausgabe über
einen NPC. Das ist eine Architekturentscheidung (Blocker 3).

---

## D. Rare-Pool – alle zwölf Modelle

Grundlagen: Eligibility = `AffixRoller.eligible` (`scripts/rpg/crafting/affix_roller.gd:20-48`), Generierung nur aus
`ItemDefinition.generation_affixes`, LOCAL erlaubt. Ausschlussgruppen: `element_core` (bloodthirsty/thundering),
`control_core` (crushing/impactful). Slotlisten (`data/crafting/affixes/*.tres`): Waffenaffixe nur Slot 10/11; `keen` 10/11/14/15;
`guarded` Rüstung 1–9 + Schild 13; `furious`/`vital` ohne Liste (alle Slots); `armored` LOCAL, Rüstung 1–9, `rollable = false`.
Executioner nur bei Familien mit Angriff `heavy`+`finisher` – alle Familien außer `bow` (Datenprüfung `data/weapons/*.tres`).
Keine Familie hat `attack_speed_scaling = 0` → Swift wirkt überall.

| Modell | Slot | `generation_affixes` (IDs) | max. gültige Anzahl | Rare 3 | Rare 4 |
|---|---|---|---|---|---|
| `iron_sword` | 1H | bloodthirsty, cruel, crushing, executioner, furious, impactful, keen, sharpened, striking, swift, tempered_blade, thundering, vital (13) | 11 (Gruppen) → Kappe 5 | ja | ja |
| `iron_axe` | 1H | dto. (13) | 5 | ja | ja |
| `iron_dagger` | 1H | dto. (13) | 5 | ja | ja |
| `iron_mace` | 1H | dto. (13) | 5 | ja | ja |
| `ash_spear` | 2H | dto. (13) | 5 | ja | ja |
| `steel_greatsword` | 2H | dto. (13) | 5 | ja | ja |
| `oak_staff` | 2H | dto. (13) | 5 | ja | ja |
| `oak_wand` | 1H | dto. (13) | 5 | ja | ja |
| `hunting_bow` | 2H | dto. **ohne executioner** (12) | 10 → 5 | ja | ja |
| `leather_cap` | Kopf | furious, guarded, vital (3) | **3** | ja | **nein** (Shortfall 1) |
| `wanderer_coat` | Brust | furious, guarded, vital (3) | **3** | ja | **nein** |
| `oak_shield` | Schild | furious, guarded, vital (3) | **3** | ja | **nein** |

Bei Rare = 3/4 mit 60/40 trifft Rüstung/Schild also in ~40 % der Rare-Würfe einen Shortfall; das Item bleibt Rare mit 3 Affixen,
und **jeder** Rare-Rüstungsdrop hat zwangsläufig exakt furious + guarded + vital (nur Tiers/Werte variieren).

**Tatsächliche Wirksamkeit** (Verbraucher der Stats):

| Affix | Wirkung | Befund für die zwölf Modelle |
|---|---|---|
| sharpened (`physical_damage`) | `CharacterStatModifier.modify_hit:17-20` | wirkt auf **alle** Nicht-Skill-Treffer (auch Stab/Zauberstab, unabhängig vom Schadenstyp); auf Skills nur bei `damage_type == physical` |
| cruel / keen | `:30-33` | wirksam (Cruel nur bei Krit; ohne Keen-Quelle nur Basis-Krit) |
| crushing (`poise_damage`) | `:22` | wirksam |
| impactful (`knockback_power`) | `:29` | wirksam |
| executioner (`finisher_power`) | `:23-26` | wirksam auf 8 Familien; Bogen ausgeschlossen (korrekt) |
| swift (`attack_speed`) | `player_progression_bridge.gd:144` | wirksam |
| bloodthirsty (`life_on_hit`) | `player_progression_bridge.gd:229` | wirksam |
| vital / guarded | Health / Armor in der Bridge | wirksam |
| furious (`resource_gain`) | `ClassRuntime.gain` (`class_runtime.gd:212-215`) | wirkt nur mit Klassenressource; **`basic_adventurer` hat keine** → vor der Klassenwahl wirkungslos (Boss vor Klassenwahl erreichbar, §C) |
| **thundering** (`shock_damage`) | nur `EssenceDischargeEffect` (`essence_discharge_effect.gd:37`, Storm-Wolf-Essenz) | Essenzen nur auf Items mit `CraftingProfile` (`forged_blade`, `forged_greatsword`, `stormcaller_fang`, `crushing_oath`). Thundering ist waffenexklusiv und es gibt **genau einen Waffen-Slot** → auf allen neun Waffenmodellen **nie wirksam** (Gewicht 30, also selten, aber möglich) |
| striking / tempered_blade (LOCAL) | `WeaponDamage.of` | wirksam auf allen neun Waffen, nie in `StatResolver` |

**Ausgeschlossene, an sich geeignete GLOBAL-Affixe:** keine. Für Waffen sind alle 11 slotfähigen GLOBAL-Affixe in der Liste
(Bogen ohne Executioner = korrekt, da wirkungslos). Für Rüstung/Schild sind die drei Listeneinträge genau die heute
slotzulässigen GLOBAL-Affixe; `keen` ist auf Rüstung slotseitig gesperrt; `armored` ist LOCAL und `rollable = false`.
→ Rare 4 auf Rüstung/Schild ist **nur durch neue, freizugebende Eligibility** erreichbar (nicht Teil dieses Audits).

---

## E. NPC-Questabgabe

**Story-Quests, Abschlussart (IST):**

| Quest | letzter Schritt | Abschluss durch |
|---|---|---|
| `a_road_forgotten` | `reach:cart_site` | Weltaktion |
| `the_broken_cart` | `talk:mara_road_end` | NPC (Mara, Old Road) |
| `shelter_among_the_trees` | `talk:edrin_intro` | NPC (Edrin, Haven) |
| `the_whispering_stone` | `waystone:whispering_stone` | Weltaktion (Wegstein) |
| `the_first_binding` | `talk:edrin_threat` | NPC (Edrin, Haven) |
| `the_first_signs` | Stub, `open_ended` | nie |
| Klassenquests `unlock_*` | `QuestService.turn_in` | **Station** (Klassenstation, kein NPC), Lieferkosten, schaltet Klasse frei |

Die Trials sind **keine Quests** (eigener `PrologueState`), haben keine Abgabe.

**Vier Zustände – was existiert:**

| Zustand | Story-Quest | Klassenquest |
|---|---|---|
| Questziel erreicht | implizit: letzter Schritt erfüllt ⇒ sofort `completed` (kein Zwischenzustand) | abgeleitet: `QuestService.objectives_done` bei `state == "active"` |
| bereit zur NPC-Abgabe | **fehlt** | abgeleitet (`can_turn_in`, an Station gebunden) |
| Quest abgeschlossen | `QuestLog`-Zustand `completed` + `completion_flag` | `completed` nach `turn_in` |
| Belohnung ausgegeben | **fehlt** (kein Reward-Feld) | = Klassenfreischaltung im selben Aufruf |

`QuestLog.from_dict` verwirft andere Zustände als `active`/`completed` (`quest_log.gd:48-50`) → ein gespeicherter Zustand
„ready“/„reward_claimed“ wäre eine Save-Schemaänderung. Ohne Schemaänderung möglich: „bereit“ und „ausgegeben“ **ableiten**
bzw. als `WorldState`-Flag speichern (Präzedenz `read.<id>`, `pickup_taken.<id>`, `defeated.<id>`).

**NPC-Architektur (IST):** `StoryNpc.interact` (`story_npc.gd:58-70`): ungehörter Dialog → Dialog; sonst Service-Fenster
(nur wenn Knoten `offers_service` und `NpcDefinition.service` gesetzt); sonst Idle-Bark. `GameHud.open_npc_service`
(`game_hud.gd:592-601`) kennt nur `&"hearth_flask"`. Ein Service pro NPC. Dialoge haben keine Item-Aktionen, nur `event_id`.
Marker „!“ nur für ungehörte Storydialoge mit `event_id`.

| NPC | Präsenz | Service | nach `the_first_binding` |
|---|---|---|---|
| Mara (Haven) | ab `prologue.haven_discovered` (`home_base.tscn:296-298`) | `hearth_flask` (belegt) | Service-Fenster |
| Edrin (Haven, Nordtor) | ab `prologue.haven_discovered` (`:306-307`), kein `offers_service` | **keiner** | keine Storydialoge mehr → nur Idle-Lines |

**Wo ein NPC Belohnungsgeber sein könnte, ohne die Story zu beschädigen:** Edrin nach `prologue.completed` ist der
konfliktfreiste Kandidat: Slot frei, keine konkurrierenden Storydialoge, Haven ist Rückkehrpunkt. Eine Ausgabe dort darf weder
`talk:`-Events senden noch an `StoryService._settle` hängen; sie würde nur ein Flag setzen. Mara bräuchte entweder mehrere
Services pro NPC oder ein Service-Fenster mit Reward-Abschnitt (beides Architekturerweiterung). Ausgabe im Dialog selbst ist
nicht vorgesehen (`DialogueDefinition` ohne Aktionen) – nicht empfohlen.

Auswirkungen auf Bestand: keine, solange „bereit“/„ausgegeben“ abgeleitet bzw. Flags sind. Journal (`journal_panel.gd`)
zeigt nur `active`/`completed`; ein „Reward waiting at …“-Hinweis wäre reine Anzeige. Questabschlussbedingungen bleiben
unverändert.

---

## F. Inventar, Save und Loot-Feed

| Punkt | Befund |
|---|---|
| Magic/Rare-Generierung | `ItemCreation.generate` (einziger Generator) deckt beides ab; Ablehnungen vor jedem Wurf; Shortfall dokumentiert, Item bleibt. |
| Platzprüfung vor Wurf | `room_for`/`free_slots` = Bedingung von `add_instance`; synchron in einem Aufruf ohne Frame dazwischen → zuverlässig. Bei Weltdrops findet **keine** Prüfung vor dem Wurf statt (Wurf beim Tod). |
| Einmaligkeit / Signale | `_settle` nur für aktive Quests; `choose_starting_class` nur einmal (`can_choose`); Enemy-Wurf durch Meta-Guard; Encounter-Dedupe. Kein Reward hängt heute an einem Signal. |
| Save v14 | `SaveSystem.VERSION = 14` (`save_system.gd:20`). `Character.to_dict` enthält `prologue` (`stage`, `completed_trials`, `chosen_class`) und `world.flags` (bool/int/String). Snapshot = ganzer Charakter in einem Frame → Item + Flag gemeinsam. Kein neues Schema nötig für Flag-basierte Claims. |
| Bestehende Claim-Flags | `read.<id>` (Readables), `pickup_taken.<id>`, `defeated.<id>`, `waystone.<id>`, `dialogue.<id>`, `count.<event>`, Quest-/Schrittflags. **Kein** `reward.*`- oder Klassenreward-Flag. |
| Altstände ohne Klassenidentität | `stage != completed` → kein Anspruch (korrekt). v3→v4-Heuristik und unvalidiertes `from_dict` siehe A.3. |
| Weltdrop-Persistenz | Instanz-Pickups transient; nur `ItemPickup.persistent_id` mit fester `item_id` ist persistent (`_remove_taken_pickups`, `game_map.gd:147-151`) – für **Instanzen** gibt es keine Weltpersistenz. |
| Loot-Feed | `PlayerProgressionBridge.item_received(item_id, quantity)` (`player_progression_bridge.gd:16`), emittiert in `item_pickup.gd:54`; `LootFeed.push` färbt nach `definition.rarity` (`scripts/ui/hud/loot_feed.gd:33-36`). **Weiterhin offen:** Magic/Rare-Instanzen erscheinen als Normal; `wanderer_coat` erscheint immer als Magic. Ein Klassen-/Boss-Reward über `add_instance` direkt (ohne Pickup) erzeugt **gar keinen** Feed-Eintrag. |
| Doku-Abweichung | `docs/SAVE_SYSTEM.md:91` „Aktuell: Version 13“ (Code: 14) – unverändert seit Vor-Audit. |

**Verworfener Rare-Story-Reward:** `git grep` über `scripts`, `data`, `scenes`, `tests`, `localization` nach `reward_choice`,
`StoryRewardService`, `story_reward`, `reward.the_`: **keine Treffer**. `ORIGIN_QUEST` existiert seit Item Integrity
(Label „Quest reward“), wird aber nirgends gesetzt. Einziges Artefakt ist das Dokument
`docs/RARE_STORY_REWARD_1_0_TECH_AUDIT.md` (Commit `3ee9bdd`, Branch `audit/rare-story-reward-10`). **Keine Implementierung.**

---

## G. Empfohlene Umsetzungsreihenfolge (max. vier Meilensteine)

### M1 – Klassen-Magic-Waffe (Anspruch + Claim)
- **Dateien/Subsysteme:** neue Daten-Resource Klassen→Modell (keine `match`-Kette), kleiner zustandsloser Service
  (`state`/`claim`), Claim-Einstieg am bestehenden `ClassChoicePanel` (oder später NPC aus M4), `WorldState`-Flag,
  `ItemCreation.generate`, `Inventory.add_instance`, Toast mit Instanz-Rarity, `localization/ui.csv`, `GalleryScreens` falls Fenster.
- **Abhängigkeiten:** Entscheidung Item-Level, Zeitpunkt, Herkunftslabel (Blocker 1, 5).
- **Risiken:** Altstände mit heuristischem `chosen_class`; unvalidiertes `chosen_class`; Claim während Trial; Duplikat bei
  Script-Fehler zwischen Add und Flag (Vor-Audit §6).
- **Tests später:** neue Suite (alle drei Klassen, basic/leer/unbekannt → kein Anspruch, volles Inventar → kein RNG-Verbrauch/kein
  Flag, Doppel-Claim, Save/Load vor/nach Claim, Klassenwechsel ändert nichts, Magic 1/2/3 nur T5); `prologue`, `story`, `shrine`,
  `inventory`, `save`.
- **Ausgeschlossen:** Änderungen an `choose_starting_class`-Regeln, Trials, Questbedingungen, Save-Version, Grunt/Wolf-Drops.

### M2 – Hinweis „Wahl wartet“ nach drei Trials
- **Dateien:** `ClassChoiceStation` (Variante 1) **oder** `TrialStation` + `ClassChoicePanel`-Vorauswahl (Variante 2).
- **Abhängigkeiten:** Blocker 2. Unabhängig von M1.
- **Risiken:** Variante 2 doppelt belegte Pedestal-Interaktion; Welttexte nur über `WorldText`.
- **Tests später:** `shrine`, `class_choice`/`prologue` gezielt; Galerie nur `--only`.
- **Ausgeschlossen:** neue NPCs/Dialoge, neue Questschritte, Änderung der Wahl-Regeln.

### M3 – Grove-Warden-Rare
- **Dateien:** `data/loot/` neue Tabelle (12 Modelle, Rare 100), Export am Knoten `GroveWarden` – **oder** Anspruchs-Variante
  (Flag beim Tod + Interactable/NPC mit Platzprüfung), je nach Blocker 3; ggf. Shortfall-Politik in `EquipmentLoot`.
- **Abhängigkeiten:** Blocker 3, 4; Item-Level ≤ 24 oder neue freigegebene Tier-Tabelle.
- **Risiken:** Weltdrop-Verlust bei Kartenwechsel; Wurf trotz vollem Inventar; Boss vor Klassenwahl (Furious wirkungslos);
  Rüstung Rare-Shortfall; kein Save beim Bosstod.
- **Tests später:** `hollowwood_loot`, `enemy`, `pickup`, `economy` (Bosstest), `loot_foundation`, `save`.
- **Ausgeschlossen:** Grunt-/Wolf-Tabellen, Boss-Balancing, feste Bossdrops, neue Affix-Eligibility.

### M4 – NPC-Abgabe-Gerüst (optional, danach)
- **Dateien:** `NpcDefinition.service`/`GameHud.open_npc_service` (zweiter Service-Typ), Edrin-Knoten `offers_service`,
  abgeleitete „bereit/ausgegeben“-Anzeige (Journal nur Anzeige), Marker an `StoryNpc`.
- **Abhängigkeiten:** M1 (Service existiert), Blocker 5 (NPC-Zuordnung).
- **Risiken:** Interaktionspriorität Dialog vor Service; ein Service pro NPC; Mara-Konflikt.
- **Tests später:** `story`, `npc`/`haven`, `save`.
- **Ausgeschlossen:** neue Questzustände in `QuestLog`, Questabschluss über NPC-Abgabe, Save-Version.

Loot-Feed-Umstellung auf Instanzen ist eine eigene kleine Signaländerung und kann jedem Meilenstein vorangestellt werden.

---

## H. Echte Designblocker (max. fünf)

1. **Item-Level und Zeitpunkt der Klassenwaffe** (ilvl 5 nur Vorschlag; Ausgabe bei Wahl, bei Wegstein oder bei
   `the_first_binding`/NPC?). Technisch ist ilvl 5 gültig (nur T5).
2. **Bedeutung „drei Abschlussmöglichkeiten“:** bestehender Altar mit drei Karten + Marker, oder drei Pedestale als Wahlpunkte?
   Heute existiert genau ein Wahlort.
3. **Boss-Reward als Weltdrop oder als Anspruch?** Weltdrop widerspricht Vorgabe 9 (Wurf ohne Platzprüfung) und ist bei
   Kartenwechsel endgültig verloren; Anspruch braucht eine Ausgabe-Interaktion. Zudem: Boss ist vor der Klassenwahl erreichbar.
4. **Rare-Rüstung/Schild:** 3 von 12 Modellen können nie 4 Affixe haben; Thundering ist auf Waffen wirkungslos. Pool
   belassen (Shortfall akzeptieren), Modelle ausschließen oder neue Eligibility freigeben? (Keine Abschwächung festgelegt.)
5. **NPC-Zuordnung & Altstände:** Wer gibt was aus (Edrin frei, Mara belegt)? Erhalten bereits fertige/migrierte Prologe
   (inkl. heuristischem v3→v4-`chosen_class`) den Klassenreward rückwirkend?
