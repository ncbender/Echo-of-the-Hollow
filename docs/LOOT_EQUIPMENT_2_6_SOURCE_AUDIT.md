# Loot & Equipment 2.6 – Hollowwood Loot & Reward Source Audit

Status: **READ-ONLY-Audit**, keine Implementierung. Branch `audit/loot-equipment-2-6-sources`
(abgezweigt von `audit/loot-equipment-2-5-economy` @ `e7f2b28`), 2026-10-27.
Geprüft: `data/`, `scenes/maps/`, `scenes/arena/`, `scripts/`. Keine Tests, Playtests oder Saves gestartet/geöffnet.
Vorarbeit: `docs/LOOT_EQUIPMENT_2_5_ECONOMY_AUDIT.md` (Gold-/Materialbestand), `docs/WEAPON_ITEM_MAPPING_2_7.md`.

Statusbegriffe (strikt):
- **SPIELBAR** – im normalen Spielverlauf ohne Debug erreichbar.
- **VORHANDEN, ABER NICHT ERREICHBAR** – Daten/Code vorhanden, keine reguläre Platzierung/Freigabe.
- **DEBUG / TEST ONLY** – nur über F-Hotkeys (`scripts/world/game_map.gd`), Tests, Save-Migrationen oder die
  Entwickler-Karte Proving Arena.
- **NICHT IMPLEMENTIERT** – nur Design/Doku.

Begriff „Hollowwood“: Weltname im Code (`scripts/rpg/world/waystone_definition.gd:3`, `data/story/the_first_signs.tres`),
keine eigene Karte. Technisch ist das die Region `hollow_outskirts` (`data/world/regions/hollow_outskirts.tres`) mit
Old Road, Haven, Whisper Forest, Whispering Stone, Proving Arena (Test), Prologue Grounds (Dev). Zwei der vier
Wegsteine sind `available = false` (`data/world/waystones/chapel_waystone.tres`, `wardens_rest.tres`) – die dortigen
Gebiete existieren nicht.

---

## 1. Kurzfazit

- **Es existiert keine Gegner-, Quest- oder Kistenquelle für Ausrüstung.** Alle Gegnerdrops sind feste
  `ItemCost`-Listen aus Gold, `hollow_essence` und `iron_ore` (`data/enemies/*.tres`). Reguläre Ausrüstung kommt nur
  aus Startausrüstung (4 Items) und Berufsrezepten (9 Items + Legacy-Iron-Sword).
- **Spielbare Kampfquellen: 6 Gegnertypen-Platzierungen in 4 Karten** – 3 Hollow Grunts (wiederholbar), 1 Boss
  (Grove Warden, einmalig), 4 einmalige Story-Begegnungen, 2 wiederholbare Wolfsbegegnungen, 3 Klassen-Trials (nur
  während des Prologs). Kein Gegner hat ein Level (`scripts/enemies/enemy_config.gd` kennt nur `rank`).
- **Quests tragen heute keine Belohnung.** 6 Story-Quests (5 abschließbar, 1 offen) haben kein Reward-Feld
  (`scripts/rpg/quests/story_quest_definition.gd`, `story_step.gd`); 3 erreichbare Klassenquests sind Gold-**Senken**
  (je 20 Gold + 3 Essence). Inhaltlich gibt es genug Quests für 30/45/65, technisch fehlt der Reward-Hook.
- **Keine Truhen.** Reward-fähige Weltobjekte: 1 Readable mit Gold (Torn Note), 1 Readable mit Essence (Memory
  Fragment), 1 Readable ohne Reward (Signpost), 3 StoryPickups (2 Quest-Kisten, 1 Muster), 3 Arena-Pickups (Test).
  Für 15/25/35 Gold gibt es realistisch nur **1–2** bestehende Objekte, nicht 3.
- **Technik:** Item-Level-Übergabe (`ItemCreation.create`, `Inventory.add_item(..., item_level)`) und einmalige
  Persistenz (World-Flags) sind vorhanden. **Instanz-Rarity und Affix-Roll beim Erzeugen fehlen vollständig**;
  Rarity ist ein Feld der Definition, Affixe entstehen nur über Resonance-Forge-Operationen.
- **Nur 4 von 33 Ausrüstungsdefinitionen haben ein `CraftingProfile`** und damit überhaupt Affix-Plätze; davon ist
  regulär keine erhältlich. Die drei-stufigen Affixe würden ab Item-Level 10 bzw. 20 T2/T1 würfeln – Konflikt mit
  „kein regelmäßiges T2/T1 in Hollowwood“ für die Planungsbänder 12–22.
- **Keine geeignete T3-Quelle (Item-Level ≥ 25) existiert.** Das wäre neuer Content.

---

## 2. Gegner und Begegnungen

### 2.1 Gegnerdefinitionen

`EnemyConfig` (`scripts/enemies/enemy_config.gd`): `rank` = Normal/Elite/Boss, `drops: Array[ItemCost]` (feste Mengen),
Mastery-/Klassen-XP. **Kein Gegnerlevel, kein Loot-Level, keine Drop-Chance, keine Loot-Tabelle.**

| ID | Name | Datei | Rank | Gold | Weitere Drops | Mastery/Klassen-XP |
|---|---|---|---|---|---|---|
| `hollow_grunt` (Default-ID) | Hollow Grunt | `data/enemies/grunt_config.tres` (Szene `scenes/enemies/grunt.tscn`) | Normal | 3 | 1 `hollow_essence`, 2 `iron_ore` | 20 / 30 |
| `grove_warden` | Grove Warden | `data/enemies/grove_warden_config.tres` | **Boss** (2) | 25 | 1 `hollow_essence`, 2 `iron_ore` | 20 / 30 |
| `rootbound_husk` | Rootbound Husk | `data/enemies/rootbound_husk.tres` | Normal | 2 | – | 15 / 20 |
| `hollowfang_wolf` | Hollowfang Wolf | `data/enemies/hollowfang_wolf.tres` | Normal | 1 | – | 15 / 20 |
| `hardened_husk` | Hardened Husk | `data/enemies/hardened_husk.tres` | **Elite** (1) | 4 | 1 `hollow_essence` | 30 / 40 |

Kein Gegner droppt Ausrüstung, Verbrauchsgüter oder Crafting-Währungen.

### 2.2 Platzierte Quellen

Technischer Hook für alle: `Enemy.defeated` → `GameMap._spawn_drops` (`scripts/world/game_map.gd:115-120`) →
transientes `ItemPickup` ohne Item-Level (`scripts/world/item_pickup.gd:40`, Herkunft `ORIGIN_FOUND`).

| Quelle (ID) | Karte / Szene | Gegner | Erreichbarkeit | Einmalig? | Gold gesamt | Status |
|---|---|---|---|---|---|---|
| `GruntA/B/C` | Whisper Forest, `scenes/maps/whisper_forest.tscn:220-227` | 3 × Hollow Grunt | ab Haven (Osttor, keine Bedingung, `home_base.tscn` `ToForest`) | **wiederholbar** (kein `persistent_id`, respawnt bei jedem Laden) | 9 / Besuch | SPIELBAR |
| `GroveWarden` (`whisper_forest_grove_warden`) | Whisper Forest, `whisper_forest.tscn:229-234` | Grove Warden (Boss, Grunt-Szene ×1,3) | ab Haven | einmalig (Flag `defeated.whisper_forest_grove_warden`, `game_map.gd:89-103`) | 25 | SPIELBAR |
| Encounter `road_ambush` | Old Road, `scenes/maps/old_road.tscn:445-461` | 2 × Rootbound Husk | Quest `a_road_forgotten` Schritt 1 | einmalig (`encounter.road_ambush`) | 4 | SPIELBAR (Prolog-Pfad) |
| Encounter `cart_attack` | Old Road, `old_road.tscn:480-503` | 2 × Rootbound Husk, 1 × Wolf | Quest `the_broken_cart` Schritt 0 | einmalig | 5 | SPIELBAR (Prolog-Pfad) |
| Encounter `cart_second_wave` | Old Road, `old_road.tscn:505-528` | 2 × Wolf, 1 × Hardened Husk | Quest `the_broken_cart` Schritt 3 | einmalig | 6 | SPIELBAR (Prolog-Pfad) |
| Encounter `road_side_wolves` | Old Road, `old_road.tscn:463-478` | 2 × Wolf | immer (Old Road ab Haven-Südtor erneut betretbar) | **wiederholbar** (`persistent = false`) | 2 / Besuch | SPIELBAR |
| Encounter `shrine_path` | Whispering Stone, `scenes/maps/whispering_stone.tscn:310-324` | 1 × Rootbound Husk, 1 × Wolf | nach Haven-Nordtor (`prologue.haven_settled`, `home_base.tscn:42-44`) | einmalig | 3 | SPIELBAR |
| Encounter `shrine_side_wolves` | Whispering Stone, `whispering_stone.tscn:326-341` | 2 × Wolf | wie oben | **wiederholbar** | 2 / Besuch | SPIELBAR |
| Trial `trial_warrior` | Whispering Stone + Prologue Grounds (`TrialWarrior`) | 2 × Rootbound, 1 × Hardened (`data/trials/trial_warrior.tres:42`) | nur vor Prolog-Abschluss (`prologue_service.gd:28-29`) | Welle wiederholt sich, solange Ziele offen (`trial_station.gd` `_process`) | 8 / Welle | SPIELBAR (nur Prolog) |
| Trial `trial_arcanist` | dto. | 3 × Rootbound (`trial_arcanist.tres:47`) | dto. | dto. | 6 / Welle | SPIELBAR (nur Prolog) |
| Trial `trial_shadowrunner` | dto. | 2 × Wolf, 1 × Rootbound (`trial_shadowrunner.tres:49`) | dto. | dto. | 4 / Welle | SPIELBAR (nur Prolog) |
| Trials in Prologue Grounds | `scenes/maps/prologue.tscn:74-131` | wie oben | nur über „Prologue Grounds (dev)“-Tor der Arena (`test_arena.tscn` `GatePrologue`), Karte `show_on_map = false` | – | – | DEBUG / TEST ONLY |
| Debug-Spawn | jede `GameMap` (`game_map.gd:173-174`, Aktion `debug_spawn_enemy`) | Hollow Grunt | F-Hotkey | beliebig | 3 je | DEBUG / TEST ONLY |
| Training Dummies | Proving Arena, `scenes/arena/test_arena.tscn:80-86` | Dummies (keine Drops) | Haven-Westtor | – | 0 | DEBUG / TEST ONLY |

Haven hat keine Gegner (`docs/PROLOGUE_AND_HAVEN.md:62-65`). Gegner/Begegnungen für Chapel Waystone, Warden's Rest
oder „The First Signs“: **NICHT IMPLEMENTIERT**.

**Zählung:** 8 spielbare Gegner-/Begegnungsquellen im Dauerspiel (3 Grunts als eine Gruppe, Warden, 4 einmalige
Story-Begegnungen, 2 wiederholbare Wolfsgruppen) + 3 prologgebundene Trial-Quellen.
Davon wiederholbar dauerhaft: **3** (Grunt-Gruppe, `road_side_wolves`, `shrine_side_wolves`).

Hinweise:
- Die Trial-Wellen geben echtes Gold/Essence in die Tasche (Drops über `map.spawn_enemy` → `register_enemy`),
  solange Ziele offen sind – eine unbegrenzte, prologgebundene Quelle.
- Progressionsposition (aus Inhalt nachweisbar): Old Road = Spielstart/Tutorial-Kämpfe; Whisper Forest = freier
  Haven-Nachbar (kein Story-Gate, Boss ohne Quest); Whispering Stone = nach Haven-Ansiedlung. Ein numerischer
  Schwierigkeitsgrad lässt sich nur über HP/Rank ablesen (Wolf 50 HP, Rootbound 70, Hardened 160), nicht über Level.

---

## 3. Quests

### 3.1 Story-Quests (`data/story/`, `StoryQuestDefinition`)

Schema: `id, display_name, chapter, description, steps, completion_flag, next_quest_ids, open_ended`
(`scripts/rpg/quests/story_quest_definition.gd:6-17`); Schritt: `description, objectives, completion_flag`
(`story_step.gd`). **Kein Reward-Feld.** `StoryService` (`scripts/rpg/quests/story_service.gd`) gibt nichts aus.

| # | ID | Name | Start | Abschluss (letzter Schritt) | Erreichbar | Gold / Items | Einmalig |
|---|---|---|---|---|---|---|---|
| 1 | `a_road_forgotten` | A Road Forgotten | New Game | `reach:cart_site` | SPIELBAR | – | ja |
| 2 | `the_broken_cart` | The Broken Cart | nach 1 | `talk:mara_road_end` (inkl. 2 Supply Crates, 2 Begegnungen) | SPIELBAR | – (Kisten sind Questitems) | ja |
| 3 | `shelter_among_the_trees` | Shelter Among the Trees | nach 2 | `talk:edrin_intro` (inkl. `restore:old_smithy`) | SPIELBAR | – | ja |
| 4 | `the_whispering_stone` | The Whispering Stone | nach 3 | `waystone:whispering_stone` (3 Trials, Klassenwahl) | SPIELBAR | – | ja |
| 5 | `the_first_binding` | The First Binding | nach 4 | `talk:edrin_threat` | SPIELBAR | – | ja |
| 6 | `the_first_signs` | The First Signs | nach 5 | offen: „continues in a future update“ | SPIELBAR, nicht abschließbar | – | – |

Alle Story-Quests sind ein linearer Hauptpfad; es gibt **keine Nebenquests**. Whisper Forest und Grove Warden
sind an keine Quest gebunden.

### 3.2 Klassenquests (`data/quests/`, `ClassQuestDefinition`)

Schema: `objectives` + `deliveries` (`scripts/rpg/quests/class_quest_definition.gd:8-19`). Abgabe an der Klassenstation
(Haven `home_base.tscn:198`, Arena). Belohnung = Klassenfreischaltung; Gold wird **verbraucht**, nicht vergeben.

| ID | Name | Bedingung | Lieferung | Status |
|---|---|---|---|---|
| `unlock_warrior` | Path of Steel | Prolog abgeschlossen (`quest_service.gd:23`), 8 Kills | 3 Essence + 20 Gold | SPIELBAR (sofern nicht Prologklasse) |
| `unlock_arcanist` | Path of the Arcane | dto. | dto. | SPIELBAR (dto.) |
| `unlock_shadowrunner` | Path of Shadows | dto. | dto. | SPIELBAR (dto.) |
| `unlock_guardian` | Oath of the Guardian | `available = false` | dto. | VORHANDEN, ABER NICHT ERREICHBAR |
| `unlock_soulbinder` | Bond of Souls | `available = false` | dto. | VORHANDEN, ABER NICHT ERREICHBAR |

Pro Charakter sind 2 Klassenquests spielbar (die Prologklasse ist bereits freigeschaltet, `quest_service.gd` `can_start`).

### 3.3 Eignung für 30 / 45 / 65 Gold (keine Zuweisung)

- **Inhaltlich vorhanden:** 5 abschließbare, einmalige Story-Quests in klarer Reihenfolge. Mögliche Kandidaten
  (nur Positionsbefund): `the_broken_cart` (Ende Old Road), `shelter_among_the_trees` (Haven/Old Smithy),
  `the_whispering_stone` bzw. `the_first_binding` (Ende des spielbaren Kapitels).
- **Technisch nicht vorhanden:** Story-Quests haben keinen Reward-Mechanismus; ein Abschluss-Reward ist neue Technik.
- **Lücke:** keine Neben- oder Gebietsquests (Whisper Forest, Grove Warden, spätere Hollowwood-Gebiete). Alle drei
  Budgets fielen auf den Prolog/Hauptpfad der ersten Spielstunde; für das „späte“ Planungsband (12–22) gibt es keine Quest.
- Klassenquests sind als Goldquelle ungeeignet (sie sind Senken); Umwidmung wäre eine Designentscheidung.

---

## 4. Truhen und Weltfunde

**Es gibt keine Truhen-/Containerklasse.** Reward-fähige Objekttypen:
- `Readable` (`scripts/world/readable.gd`): `rewards: Array[ItemCost]`, atomarer Platzcheck, einmalig über Flag
  `read.<persistent_id>` (`:26-27`, `:36-47`), Optik `Look { SIGNPOST, NOTE, STONE }`.
- `StoryPickup` (`scripts/world/story_pickup.gd`): **ein** `item_id` + `quantity`, optional `condition`/`event_id`,
  Flag `pickup.<persistent_id>`.
- `ItemPickup` (`scripts/world/item_pickup.gd`): **ein** Item beim Berühren, Flag `pickup_taken.<persistent_id>`
  (`game_map.gd:123-127`).

Keiner dieser Typen übergibt ein Item-Level (alle rufen `Inventory.add_item` ohne `item_level`).

| Objekt (ID) | Typ | Karte / Position | Belohnung | Bedingung | Persistenz | Status |
|---|---|---|---|---|---|---|
| `road_note` „Torn Note“ | Readable (NOTE) | Old Road (-555, -60), `old_road.tscn:388-394` | **12 Gold + 2 Timber** | keine | einmalig (`read.road_note`) | SPIELBAR |
| `road_signpost` „Old Signpost“ | Readable (SIGNPOST) | Old Road (40, 410), `old_road.tscn:368-374` | – | keine | einmalig gelesen | SPIELBAR (ohne Reward) |
| `memory_three_stood` „Memory Fragment“ | Readable (STONE) | Whispering Stone (490, 0), `whispering_stone.tscn:295-302` | 1 `hollow_essence` | keine (Karte nach Nordtor) | einmalig | SPIELBAR |
| `cart_crate_west` / `cart_crate_south` | StoryPickup | Old Road (-176,-372) / (128,-262), `old_road.tscn:420-437` | je 1 `supply_crate` (Questitem für Old Smithy) | `the_broken_cart` Schritt 2 | einmalig | SPIELBAR, aber Questobjekt |
| `forest_hunters_pack` „Hunter's Pack“ | StoryPickup | Whisper Forest (-285, -112), `whisper_forest.tscn:207-213` | 1 `pattern_leather_bracers` (Rezeptmuster, Magic) | keine | einmalig | SPIELBAR |
| `ancient_deposit` | Sammelknoten (`respawn_seconds = 0`) | Whisper Forest (290, -150), `whisper_forest.tscn:171-173` | 3 `iron_ore` | Mining 1 | einmalig (Gathering-Save) | SPIELBAR (kein Gold-/Item-Hook) |
| `arena_militia_sword` / `arena_oak_shield` / `arena_copper_ring` | ItemPickup | Proving Arena (-120…-80, -40), `test_arena.tscn:90-108` | je 1 Ausrüstungsitem | keine | einmalig | DEBUG / TEST ONLY (Entwicklerkarte, physisch über Haven-Westtor betretbar) |
| `TheStone` „Heart of the Stone“ | Klassenwahl | Whispering Stone (0, -262) | Klasse | Prolog | – | SPIELBAR (kein Item-Reward) |
| Wegstein `whispering_stone` | Waystone | Whispering Stone (150, -285) | Schnellreise | `prologue.first_class_selected` | Weltzustand | SPIELBAR (kein Item-Reward) |

**Zählung:** 6 spielbare Weltfund-Objekte mit Item-Ausgabe (Torn Note, Memory Fragment, 2 Supply Crates, Hunter's
Pack, Ancient Deposit), davon **1** mit Gold. Keine Truhe. 3 Arena-Pickups nur Test.

### 4.1 Eignung für 15 / 25 / 35 Gold (keine Zuweisung)

- **Torn Note** trägt bereits 12 Gold (Designkontext: bleibt) – kein freier Kandidat.
- **Memory Fragment** (`Readable.rewards`): technisch sofort goldfähig (gleicher Mechanismus wie Torn Note).
- **Old Signpost**: technisch goldfähig, inhaltlich ein Wegweiser am Spielstart (Belohnung dort wäre ein Fremdkörper).
- **Hunter's Pack**: `StoryPickup` kann nur **ein** Item geben; Gold zusätzlich zum Muster bräuchte Technik oder
  einen Ersatz des Musters.
- Supply Crates sind Questobjekte; Ancient Deposit ist ein Sammelknoten ohne Gold-Hook.

**Ergebnis:** reale Kandidaten für 3 Weltfundbudgets = **1 sicher (Memory Fragment), 1 bedingt (Hunter's Pack oder
Signpost)**. Mindestens ein Budget hat keine bestehende Quelle; „späte“ Weltfunde fehlen ganz.

---

## 5. Existierende Ausrüstung und Bezugsquellen

Felder aus `data/items/<id>.tres`. Rarity ist ein **Definitionsfeld** (`scripts/rpg/items/item_definition.gd:25`).
Item-Level: `creation_item_level()` = `crafting.base_item_level` oder `base_item_level` (`:102-103`); „–“ = 0 → Instanz 1.
Affix-Eignung setzt ein `CraftingProfile` mit `affix_slots > 0` voraus (`scripts/rpg/crafting/affix_pool.gd:18-20`).

Bezug: **START** = `data/progression/progression_rules.tres:9-32` (`starting_items`, `ORIGIN_STARTING`);
**REZEPT** = `data/professions/recipes/`; **SMITHY** = Legacy-Rezept `data/base/buildings/smithy.tres`;
**F7** = `GameMap.give_debug_items` (jedes ausrüstbare Item einmal, `game_map.gd:210-220`);
**F4** = `DEBUG_CRAFTING_ITEMS` (`game_map.gd:20-25`); **ARENA** = `test_arena.tscn`; **MIG** = nur Save-Migrations-
Tabellen (`scripts/rpg/save/save_migrations.gd:255-273`).

### 5.1 Waffen (`category = 0`)

| ID | Slot / Familie | Rarity | Item-Level | CraftingProfile | Bezug | Status | Effekte |
|---|---|---|---|---|---|---|---|
| `iron_sword` | 1H / one_handed_sword | Normal | 1 | – | START, SMITHY | REGULÄR ERHÄLTLICH | – |
| `steel_greatsword` | 2H / two_handed_sword | Normal | 1 | – | START | REGULÄR ERHÄLTLICH | – |
| `militia_sword` | 1H / one_handed_sword | Magic | 1 | – | REZEPT `bs_militia_sword`, ARENA | REGULÄR ERHÄLTLICH | – |
| `iron_axe` | 1H / axe | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `iron_dagger` | 1H / dagger | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `iron_mace` | 1H / mace | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `oak_wand` | 1H / wand | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `ash_spear` | 2H / spear | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `oak_staff` | 2H / staff | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `hunting_bow` | 2H / bow | Normal | 1 | – | F7, MIG | NUR DEBUG / TEST | – |
| `forged_blade` | 1H / one_handed_sword | Normal | 12 | 4 Affix, 2 Essence, 2 Sockel | F4, F7 | NUR DEBUG / TEST | – |
| `forged_greatsword` | 2H / two_handed_sword | Normal | 12 | ja (wie Blade) | F4, F7 | NUR DEBUG / TEST | – |
| `stormcaller_fang` | 1H / one_handed_sword | Epic | 15 | Evolve/Quality/Essence, keine Affixe | F4, F7 | NUR DEBUG / TEST | Evolution `stormcaller` |
| `echo_blade` | 1H / one_handed_sword | Legendary | 15 | – | F7, MIG | NUR DEBUG / TEST | 2 `ItemEffect` |
| `crushing_oath` | 1H / one_handed_sword | Unique | 15 | Quality/Sockel (1), keine Affixe | F7, MIG | NUR DEBUG / TEST | 2 `ItemEffect` |

**Waffenfamilien ohne reguläre Waffe:** axe, dagger, mace, wand, spear, staff, bow (7 von 9; `data/weapons/`).

### 5.2 Rüstung, Schilde, Schmuck, Trinkets

| ID | Slot | Rarity | Item-Level | CraftingProfile | Bezug | Status |
|---|---|---|---|---|---|---|
| `leather_cap` | Head (Leather) | Normal | – | – | START | REGULÄR ERHÄLTLICH |
| `wanderer_coat` | Chest | Magic | – | – | START | REGULÄR ERHÄLTLICH |
| `leather_gloves` | Hands (Leather) | Normal | – | – | REZEPT `lw_leather_gloves` | REGULÄR ERHÄLTLICH |
| `worn_boots` | Feet (Leather) | Normal | – | – | REZEPT `lw_worn_boots` | REGULÄR ERHÄLTLICH |
| `leather_bracers` | Wrists | Normal | – | – | REZEPT `lw_leather_bracers` (Muster Hunter's Pack) | REGULÄR ERHÄLTLICH |
| `rope_belt` | Belt | Normal | – | – | REZEPT `tl_rope_belt` | REGULÄR ERHÄLTLICH |
| `linen_trousers` | Legs (Cloth) | Normal | – | – | REZEPT `tl_linen_trousers` | REGULÄR ERHÄLTLICH |
| `padded_mantle` | Shoulders | Normal | – | – | REZEPT `tl_padded_mantle` | REGULÄR ERHÄLTLICH |
| `traveler_cloak` | Back | Normal | – | – | REZEPT `tl_traveler_cloak` | REGULÄR ERHÄLTLICH |
| `oak_shield` | Shield | Normal | – | – | REZEPT `ww_oak_shield`, ARENA | REGULÄR ERHÄLTLICH |
| `warlord_helm` | Head | Rare | – | – | F7 | NUR DEBUG / TEST |
| `warden_helm` / `warden_mail` / `warden_greaves` | Head / Chest / Legs (Mail) | Set (`hollow_warden`, `data/sets/hollow_warden.tres`) | – | – | F7 | NUR DEBUG / TEST |
| `copper_ring` | Ring | Normal | – | – | ARENA, F7 | NUR DEBUG / TEST |
| `silver_ring` | Ring | Magic | – | – | F7 | NUR DEBUG / TEST |
| `bone_amulet` | Neck | Normal | – | – | F7 | NUR DEBUG / TEST |
| `hollow_charm` | Trinket | Magic | – | – | F7 | NUR DEBUG / TEST |

**Zählung:** 33 Ausrüstungsdefinitionen TECHNISCH EXISTIEREND; **14 REGULÄR ERHÄLTLICH** (4 Start, 10 Rezept;
`iron_sword` zusätzlich SMITHY); 19 NUR DEBUG / TEST. Reguläre Items: alle Item-Level 1, Normal oder Magic (Magic nur als
Definitionsrarity, **ohne Affixe**), keine `CraftingProfile`, keine Effekte. Ringe, Amulette, Trinkets: **keine reguläre
Quelle**. Kein Item hat `base_value` (`docs/LOOT_EQUIPMENT_2_5_ECONOMY_AUDIT.md` §5).

### 5.3 Affix-Eignung (Pool-Datenlage)

`data/crafting/affixes/` (14 Affixe):
- Waffen (1H/2H): `bloodthirsty`, `cruel`, `crushing`, `executioner`, `impactful`, `sharpened`, `swift`, `thundering`,
  `keen` + slotfreie `furious`, `vital`.
- Rüstung/Schild: `guarded` (Slots 1–9, 13) + `furious`, `vital`.
- Ring/Amulett: `keen` (14, 15) + `furious`, `vital`. Trinket: nur `furious`, `vital`.
- `striking`, `tempered_blade`: LOCAL, Fünf-Tier-Modell (Stufen ab Item-Level 1/10/25/45/70), werden vom Pool
  **ausgeschlossen** (`affix_pool.gd:34-35`).
- Alle 12 übrigen Affixe: Drei-Tier-Modell, **T2 ab Item-Level 10, T1 ab 20** (z. B. `keen.tres`).

Folge: Rüstung, Schmuck und Trinkets hätten bei Rare (3–4) bzw. Epic (4–5) mit nur 3 möglichen Affixen einen zu kleinen
Pool (Gruppen-Ausschluss pro Item). Im Planungsband 12–22 würden die Drei-Tier-Affixe regulär T2/T1 würfeln.

---

## 6. Technische Loot-/Reward-Schnittstellen

| Schnittstelle | Ist-Zustand | Beleg | Bewertung |
|---|---|---|---|
| Gegnerdrops | feste `ItemCost`-Liste je `EnemyConfig`, keine Chance, keine Tabelle, kein Level, transientes `ItemPickup` | `enemy_config.gd:56-62`, `game_map.gd:106-120` | **TEILWEISE VORHANDEN** |
| Quest-Rewards | Story-Quests ohne Reward-Feld; Klassenquests nur `deliveries` (Kosten) | `story_quest_definition.gd`, `class_quest_definition.gd:17-19` | **FEHLT** |
| Weltcontainer | keine Truhe; `Readable.rewards` (Liste, atomar), `StoryPickup` (1 Item), `ItemPickup` (1 Item) | `readable.gd:12,36-47`, `story_pickup.gd:53-62`, `item_pickup.gd` | **TEILWEISE VORHANDEN** |
| ItemCreation mit Item-Level | `ItemCreation.create(def, amount, db, item_level)`, `Inventory.add_item(id, n, origin, item_level)`; kein Weltobjekt/Drop übergibt es | `item_creation.gd:13-20`, `inventory.gd:91-115` | **VORHANDEN UND NUTZBAR** (API), ungenutzt von Quellen |
| Iteminstanz-Rarity | `ItemInstance` hat kein Rarity-Feld; Rarity nur `ItemDefinition.rarity` (auch Economy/Crafting lesen die Definition) | `item_instance.gd:9-44`, `economy_service.gd:18-26` | **FEHLT** |
| Affix-Roll beim Erzeugen | `ItemCreation` würfelt nichts; Affixe nur über `CraftingService`-Operationen (Imprint/Augment/Reforge) mit `AffixPool.compute` + `AffixDefinition.roll`; Pool verlangt `CraftingProfile` | `crafting_service.gd:195-231`, `affix_pool.gd:14-40`, `affix_definition.gd:76` | **TEILWEISE VORHANDEN** (Bausteine, kein Erzeugungspfad) |
| Rarity → Affixanzahl (0 / 1–3 / 3–4 / 4–5 / 5) | keine Regel; Limit nur `CraftingProfile.affix_slots` (max 5) | `crafting_profile.gd:10-16` | **FEHLT** |
| Einmalige Reward-Persistenz | World-Flags `defeated.*`, `encounter.*`, `read.*`, `pickup.*`, `pickup_taken.*`; Item-Level im Save (`ilvl`) | `game_map.gd:89-127`, `encounter.gd`, `item_instance.gd:85,124` | **VORHANDEN UND NUTZBAR** |
| Herkunft | `ORIGIN_FOUND` für Pickups/Readables, `ORIGIN_STARTING`, `ORIGIN_CRAFTED` | `item_pickup.gd:40`, `character_factory.gd:12` | VORHANDEN UND NUTZBAR |
| Verkauf / Händler | `EconomyService.sell` ohne Aufrufer, kein `base_value` | `economy_service.gd:1-12` | TEILWEISE (kein Händler) |

---

## 7. Geeignete Kandidaten für die geplanten Gold- und Ausrüstungsbudgets

Nur Kandidaten auf Basis existierender Quellen; **keine Festlegung**.

1. **Normale Ausrüstungsquellen (Gegner):** Hollow Grunts (Whisper Forest, wiederholbar, einzige normale Gegner mit
   bereits mehrteiligem Drop), Rootbound Husk/Hollowfang Wolf in `road_side_wolves`/`shrine_side_wolves`
   (wiederholbar). Einmalige Story-Begegnungen der Old Road eignen sich nur als feste Tutorial-Drops.
2. **Besondere Begegnungen für gezielteren Loot:** Grove Warden (einziger Boss, einmalig, `persistent_id`);
   Hardened Husk in `cart_second_wave` (einziger Elite in einer einmaligen Begegnung); `shrine_path` (erste
   Begegnung nach der Ansiedlung).
3. **Quests für feste frühe Gold-/Ausrüstungsbelohnungen:** `the_broken_cart`, `shelter_among_the_trees`,
   `the_whispering_stone`/`the_first_binding` – alle Hauptpfad, alle ohne Reward-Technik.
4. **Weltobjekte für Erkundungsbelohnungen:** Memory Fragment (Readable, sofort goldfähig), Hunter's Pack
   (StoryPickup, nur 1 Item), Old Signpost (technisch möglich, inhaltlich schwach). Torn Note bleibt bei 12 Gold.
5. **Frühe Magic-/Rare-Kandidaten (Definitionen):** Basen mit regulärer Familie/Slot: `iron_sword`, `steel_greatsword`,
   `militia_sword`, die sieben Familienwaffen (`iron_axe` … `hunting_bow`), alle Rezept-Rüstungen, `copper_ring`,
   `bone_amulet`. Alle bräuchten ein `CraftingProfile` mit Affix-Plätzen; Rarity müsste Instanz-Eigenschaft werden,
   sonst ist z. B. jedes `militia_sword` Magic.
6. **T3-Quelle (Item-Level ≥ 25):** **keine.** Höchstes Item-Level einer Definition ist 15 (Debug-Uniques); kein
   Gegner, keine Quest, kein Objekt hat ein Level. Eine T3-Quelle wäre **neuer Content** (z. B. die nicht verfügbaren
   Gebiete Chapel Waystone / Warden's Rest – nur als Ort, nicht als Vorschlag).
7. **Drei Lücken:** siehe Abschnitt 8, Blocker 1–3.

**Budgetarithmetik (nur Information):** Warden 25 + Torn Note 12 + Quests 30/45/65 (140) + Weltfunde 15/25/35 (75)
= 252 Gold; die Differenz zum Rahmen von ≈ 270 entfiele auf Gegnergold. Davon sind heute zuweisbar: 37 (Warden, Note),
technisch sofort 1 Weltfund (Memory Fragment); 140 Quest-Gold und ≥ 1 Weltfundbudget haben keinen Hook bzw. keine Quelle.

---

## 8. Fehlende Inhalte / Blocker

1. **Kein Loot-Erzeugungspfad.** Drops, Readables und Pickups geben nur feste Item-IDs ohne Item-Level, ohne
   Instanz-Rarity und ohne Affixe; Rarity ist Definitions-Eigenschaft, Affixe entstehen nur in der Resonance Forge, und
   nur 4 Definitionen (alle Debug) haben ein `CraftingProfile`. Gefundene und hergestellte Ausrüstung können so nicht
   denselben Pool nutzen.
2. **Kein Quest-Reward-Mechanismus und zu wenig Questinhalt.** Story-Quests haben kein Reward-Feld; es gibt nur
   den linearen Prolog-/Haven-Hauptpfad (5 Quests), keine Neben- oder Gebietsquests, nichts für das späte Band.
3. **Zu wenig Quellen/Content für das Level-Band 3–22.** Kein Gegnerlevel, keine Truhen, nur 1–2 freie Weltfunde,
   7 von 9 Waffenfamilien sowie Ringe/Amulette/Trinkets ohne regulären Bezug, keine Quelle über Item-Level 1, keine
   T3-Quelle; zudem würfeln die vorhandenen Drei-Tier-Affixe ab Level 10/20 T2/T1.

Weitere: wiederholbare Trial-Wellen als unbegrenzte Prolog-Goldquelle; Debug-Grunt-Spawn droppt reguläres Gold;
Proving Arena (Test) ist physisch über Haven erreichbar, ihre Pickups sind daher faktisch erhältlich.

---

## 9. Designentscheidungen für den nächsten Schritt

Nur zu treffende Entscheidungen, keine Werte:

1. **Quellenlevel-Modell:** Wo wird das Quelllevel festgelegt – pro `EnemyConfig`, pro Platzierung/Encounter oder
   pro Karte (`MapDefinition`)? Und welche bestehenden Quellen gehören in welches Planungsband (früh/mittel/spät),
   obwohl heute nur Old Road, Whisper Forest und Whispering Stone existieren?
2. **Rarity und Affixe an der Instanz:** Rarity als Instanzfeld (Save-Schema!) mit Roll beim Erzeugen über
   `ItemCreation`, und Affix-Eignung über ein Standard-`CraftingProfile` je Slot oder je Definition? Dazu: wie die
   Drei-Tier-Affixe für Hollowwood auf T3 begrenzt werden (Datenumbau vs. Quelllimit) und ob Rüstung/Schmuck mehr
   Affixe brauchen, damit Rare/Epic überhaupt füllbar sind.
3. **Reward-Träger:** (a) Story-Quests erhalten einen Abschluss-Reward (welche drei Quests), (b) Truhe als neuer
   Objekttyp oder Erweiterung von `Readable`/`StoryPickup`, (c) Drop-Chancen/Loot-Tabellen statt fester `drops`,
   (d) Umgang mit Trial-Wellen-Gold, Debug-Spawn und Arena-Pickups, (e) ob fehlende Quellen (Nebenquests, späte
   Weltfunde, T3-Quelle) als Content-Paket vor der Loot-Technik kommen.
