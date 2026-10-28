# Chapter 1 – „The Ashen Trail“ · Story & World Integration Audit 1.0

Read-only-Audit. Keine Implementierung, keine Tests, kein Playtest, keine Spielstände geöffnet.
Branch `audit/ashen-trail-story-world-10` von `dev/npc-quest-turnins-11-m3` @ `97dcd43` (enthält Class Trials 2.0,
Grove Warden Rare R2 `21fdde5`, NPC Quest Turn-ins 1.0/1.1). Fremde Änderungen (`project.godot`, `docs/Design/`,
`docs/tasks/`) unberührt.

Quellenkennzeichnung in diesem Dokument:

| Kürzel | Bedeutung |
|---|---|
| **[IMPL]** | im Spiel implementiert (Daten/Szenen/Code, Pfad angegeben) |
| **[DOKU]** | verbindliche Designvorgabe/Doku im Repo (`docs/*.md`, `CLAUDE.md`) |
| **[IDEE]** | nur als Idee/Plan dokumentiert, nicht implementiert |
| **[UNKLAR]** | widersprüchlich oder ungeklärt – beide Quellen genannt |
| **[VORSCHLAG]** | Vorschlag dieses Audits, **kein Kanon** |

---

## 1. Executive Summary

- **Story-Endpunkt:** Der spielbare Hauptstrang endet mit `the_first_binding` (Edrins Gespräch `talk:edrin_threat`
  → Flag `prologue.completed`). Danach startet automatisch `the_first_signs` („The Roots Remember: The First Signs“), ein
  **offener Stub** ohne Ziel, der nie abschließt. Das ist der einzige echte Einstiegspunkt für das nächste Kapitel.
- **Vorhandene Kapitel-1-Planung ist sehr dünn**, aber existiert und hat Vorrang vor neuen Namen:
  Kapitelname **„The Roots Remember“** und Questname **„The First Signs“** [IMPL], Edrins Bedrohung „Roots under the
  Hollowwood are moving … something deep in those woods“ [IMPL], zwei geplante Wegsteine **Chapel Waystone** und
  **Warden's Rest** „for a later part of the Hollowwood“ [IMPL als `available = false`], „Mehr Hollowwood mit Chapel
  Waystone und Warden's Rest“ [IDEE, `PROLOGUE_AND_HAVEN.md`]. `docs/Design/` enthält **keine** Story-/Weltplanung (nur
  Weapon Mastery). Es gibt kein Lore-Dokument.
- **Keine freien Gebietsübergänge.** Alle vier Haven-Tore sind belegt; Old Road, Whisper Forest und Whispering Stone
  haben je genau einen Ausgang (zurück nach Haven). Jeder neue Abschnitt braucht **einen neuen `MapTransition`** an einer
  bestehenden Wand. Am naheliegendsten: Ostwand des Whisper Forest (Kartenzelle (2,1) frei).
- **„The Ashen Trail“ passt nur bedingt.** Asche/Glut/Feuer hat **keinen** Anker in der vorhandenen Lore (Wurzeln,
  Wald, „Hollow“-Kreaturen, ein Stein, der sich erinnert). Mehrere Namen kollidieren mit vorhandenen Begriffen
  („Forgotten“, „Fallen“, „-bound“, „Hollow“). Der Kapitelname kollidiert mit dem bereits implementierten Kapitel
  „The Roots Remember“. → Entscheidung nötig (§7, §11).
- **Empfehlung:** Kapitel 1 als Ausbau von `the_first_signs` innerhalb der bestehenden Planung („tieferes Hollowwood“
  mit Chapel Waystone und Warden's Rest), Einstieg über Edrin, Zugang über den Whisper Forest. Ein Ash-/Cinder-Motiv
  nur, wenn es bewusst als neuer Lore-Baustein beschlossen wird.
- **Technisch ist ein Kapitel ohne neue Systeme und ohne Save-Version machbar** (Story-Quests, Bedingungen, Encounter,
  Boss-Muster, Turn-in-Rewards, Wegsteine existieren). Echte Risiken: kumulative Ziele + `resettle` bei Altständen,
  fehlendes Story-Event für Gegner-/Boss-Kills, `open_ended`-Umbau von `the_first_signs`, keine Fernkampf-Gegner-KI.

---

## 2. Tatsächlicher Story-Kanon (bis Prolog-Ende)

### 2.1 Ausgangssituation [IMPL]
- `a_road_forgotten`: „You wake on an overgrown forest road far from any town. The only way is north.“
  (`data/story/a_road_forgotten.tres`). Herkunft, Name, Vergangenheit des Spielers: **nicht definiert**.
- Klasse zu Beginn: Basic Adventurer (`CharacterFactory`, `CLASS_QUESTS.md`).

### 2.2 Hauptfiguren [IMPL]
| Figur | Quelle | Kanon im Spiel |
|---|---|---|
| **Mara Veyne** | `data/npcs/mara.tres` | Versorgerin, Wagen auf der Old Road von Bestien überfallen; „Doesn't mean I'm used to getting it“; führt nach Haven; „we work hard to keep it true“; kennt Havens Vergangenheit nur vage („Depends who you ask“). Service: Hearth Flask (+ Quest-Rewards-Zugang). |
| **Edrin Vale** | `data/npcs/edrin.tres` | Wächter am Nordtor von Haven; kennt den Whispering Stone („It has been a long time since it answered anyone“); Träger der Bedrohung. Service: Quest Rewards. |
| Spieler | – | namenlos, wortkarg, „still figuring out what“ nach der Klassenwahl. |
| Die Stimme/der Stein | `whispering_stone.tscn` | „Heart of the Stone“, Echos dreier Pfade; Memory Fragment „Three stood here when the stone was whole.“ |

### 2.3 Storyaufgaben in tatsächlicher Reihenfolge [IMPL]
| # | Quest | Ort | Schritte → Flags |
|---|---|---|---|
| 1 | A Road Forgotten | Old Road | `reach:road_signpost` → `encounter:road_ambush` (`prologue.road_cleared`) → `reach:cart_site`; `prologue.road_walked` |
| 2 | The Broken Cart | Old Road | `encounter:cart_attack` → `talk:mara_cart` (`prologue.mara_rescued`) → 2× `interact:supply_crate` kumulativ (`prologue.supplies_recovered`) → `encounter:cart_second_wave` (`prologue.cart_defended`) → `talk:mara_road_end`; `prologue.cart_done`; Reward 30 Gold + 3 Timber + 2 Stone bei Mara |
| 3 | Shelter Among the Trees | Haven | `enter:home_base` (`prologue.haven_discovered`) → `talk:mara_welcome` → `restore:old_smithy` kumulativ (`prologue.smithy_restored`) → `talk:edrin_intro`; `prologue.haven_settled` (Nordtor öffnet) |
| 4 | The Whispering Stone | Whispering Stone | `enter:whispering_stone` (`prologue.shrine_reached`) → 1× `trial_complete` kumulativ → `class_chosen` kumulativ (`prologue.first_class_selected`) → `waystone:whispering_stone`; `prologue.stone_awakened` |
| 5 | The First Binding | Haven | `enter:home_base` → `talk:mara_return` → `talk:edrin_threat`; `prologue.completed`; Reward 60 Gold bei Edrin |
| 6 | The First Signs (Kapitel „The Roots Remember“) | – | ein Stub-Schritt ohne Ziel, `open_ended = true` |

### 2.4 Wichtige Entdeckungen/Ereignisse [IMPL]
- Old Road: Signpost „One arm still points north: HAVEN. The other arm lies rotting in the grass.“; Torn Note „Third
  shipment delayed. Mara went ahead before sunrise.“ (12 Gold).
- Fallen Trunks blockieren die Straße nach Norden bis `prologue.cart_done` („There is no way through on your own.“).
- Haven: ummauertes Ruinendorf, zehn feste Ruinen, „Most of these houses had families in them once.“
- Whispering Stone: Stein „answered“ den Spieler; drei Echos (Warrior, Arcanist, Shadowrunner) mit eigenen Trial-Karten
  (The Broken Bastion, The Shattered Sanctum, The Veiled Passage – nur während Trials, `show_on_map = false`).

### 2.5 Klassenwahl und Storybedeutung [IMPL]
- Wahl einer Klasse, deren eigenes Echo bestanden ist (Class Trials 2.0 M1, `PrologueService.can_choose`). „Choose the
  path that will take root within you.“ → „A path has taken root within you. Haven should hear of it.“
- Storybedeutung: Der Spieler trägt einen „Pfad“, den der Stein lange niemandem gegeben hat. Konsequenzen über
  Edrins Aussage hinaus: **nicht definiert**.

### 2.6 Eingeführte Konflikte [IMPL]
- Kreaturen auf den Straßen: „Those things weren't normal.“ – „No. And they weren't always like that.“ (Edrin).
  Gegnernamen: Hollow Grunt, Hardened Husk, Rootbound Husk, Hollowfang Wolf.
- Bedrohung: „The roots under the Hollowwood are moving. Something deep in those woods is pulling at them, and every
  night it pulls a little harder.“ – „When it reaches the old roads, Haven will need more than walls.“
- Spannung Edrin ↔ Mara über das Tempo („They've barely reached Haven, Edrin.“).

### 2.7 Hinweise auf größere Bedrohungen [IMPL]
- „the thing in those woods gets closer every night“ (Edrin, `edrin_intro`).
- „Something stirs in the Hollowwood.“ / „Whatever walks the woods is drawing closer to Haven.“ (`the_first_signs`).
- Grove Warden im Whisper Forest: Boss, aber ohne Story-Einbindung (kein Dialog, kein Event).

### 2.8 Offene Handlungsstränge [IMPL, inhaltlich offen]
1. Was zieht an den Wurzeln, und wo „deep in those woods“?
2. Was die Kreaturen früher waren („weren't always like that“).
3. Havens Vergangenheit, leere Häuser, nicht restaurierbare Ruinen (Fallen Barracks, Common Hall, Trading House,
   Forgotten Study: „Restoration unavailable for now.“).
4. „Three stood here when the stone was whole“ – wer die drei waren, warum der Stein beschädigt ist.
5. Maras Versorgungsroute („Third shipment“) – Herkunft der Lieferungen, wohin der zweite Wegweiserarm zeigte.
6. Herkunft des Spielers.
7. Zwei Wegsteine Chapel Waystone / Warden's Rest („undiscovered“).

### 2.9 Widersprüche/Unklarheiten
| Thema | Quelle A | Quelle B | Status |
|---|---|---|---|
| Echos für die Wahl | `PROLOGUE_AND_HAVEN.md`: „3× `trial_complete`“, „Wahl erst nach allen drei Echos“ | `CLASS_TRIALS_2_0_M1.md` + `data/story/the_whispering_stone.tres` (amount 1) + `prologue_service.gd:159`: ein eigener Trial genügt | **[UNKLAR – Doku veraltet]**, Implementierung = CT 2.0 |
| Grove Warden | `WORLD_SYSTEM.md`: „Test-Boss“ | `CLASS_TRIALS_2_0_TECH_AUDIT.md`: „Regionsboss von Hollowwood“; Grove Warden Rare R2: echter Boss mit Rare-Reward | **[UNKLAR]** narrative Rolle undefiniert |
| Hollowwood | `waystone_definition.gd`, `the_first_signs`, Edrin: Weltname | keine Karte heißt so; Region-ID `hollow_outskirts` („Hollow Outskirts“); `LOOT_EQUIPMENT_2_6_SOURCE_AUDIT.md`: „keine eigene Karte“ | **[UNKLAR]** ob Whisper Forest *Teil* des Hollowwood ist oder sein Rand |
| Haven-Ruinen | `WORLD_SYSTEM.md`: „sechs Ruinen“ | `PROLOGUE_AND_HAVEN.md`, `home_base.tscn`: zehn | Doku veraltet (Artisan Quarter) |
| Klassenstruktur | `GAME_VISION.md`: 5 Startklassen | Prolog: 3 wählbar, Guardian/Soulbinder ausgeblendet | bewusst (CLASS_QUESTS) |
| Kapitel 1 | Auftrag: „Chapter 1 – The Ashen Trail“ | `the_first_signs.tres`: Kapitel „The Roots Remember“, „Main quest, chapter one“ | **[UNKLAR]** – Entscheidung nötig (§11 E1) |

---

## 3. Prolog-Ende und Anschluss

1. **Wo endet der spielbare Hauptstrang?** Mit `talk:edrin_threat` → `the_first_binding` completed → `prologue.completed`
   (`data/story/the_first_binding.tres`). Danach optional: 60 Gold bei Edrin abholen.
2. **Direkt nach der permanenten Klassenwahl:** `the_whispering_stone` Schritt 3 (Wegstein erwecken) →
   `prologue.stone_awakened` → `the_first_binding` startet (Rückkehr nach Haven, Mara, Edrin). Klassenwahl/Wegstein sind
   **vor** dem Kapitelanschluss abgeschlossen.
3. **Signale für den nächsten Abschnitt:** `StoryService._settle` startet `next_quest_ids` beim Abschluss →
   `the_first_signs` wird `active` mit Schritt 0. Zusätzlich gesetzt: `prologue.completed`. Weitere Signale existieren
   nicht. `prologue.completed` wird im Code **nur** in `save_migrations.gd` gelesen (v4→v5) – keine Szene/Bedingung nutzt es.
4. **Nächster echter Einstiegspunkt:** `the_first_signs` (aktiv, Schritt 0, Fortschritt `{}` in allen Ständen nach dem
   Prolog, auch migrierten v1–v4-Ständen).
5. **Geplante Kapitel-1-Inhalte mit Vorrang:** Kapitel „The Roots Remember“, Quest „The First Signs“, die Bedrohung
   „deep in those woods“, Chapel Waystone, Warden's Rest, „Mehr Hollowwood“. Inhaltlich ist darüber hinaus **nichts**
   festgelegt (keine Orte, Gegner, Figuren).
6. **Blockierrisiken:** siehe §9. Kurz: Ein neues Kapitel blockiert nichts, solange (a) `the_first_signs` weiter Schritt 0
   als ersten echten Schritt hat, (b) keine Ziele auf Ereignisse warten, die Altstände schon verbraucht haben
   (Grove-Warden-Kill, persistente Encounter), und (c) neue Gebietszugänge nur an Flags hängen, die alle
   abgeschlossenen Stände haben (`prologue.completed`).

Migrierte Stände (v4→v5) erhalten `the_first_signs` aktiv mit Schritt 0 (`save_migrations.gd:173-174`).

Nicht umbauen (Auftrag): Class Trials, Klassenwahl, Wegsteine, Grove-Warden-Reward, NPC-Turn-ins.

---

## 4. Bestehende Welt und Wege

Region `hollow_outskirts` (`data/world/regions/hollow_outskirts.tres`); Karte als Zellengraph (`MapDefinition.map_cell`).

```
            (-1,-1) Bastion*   (0,-1) Sanctum*   (1,-1) Passage*        * nur Trials, unsichtbar
            (-1,0)  Prologue†  (0,0)  Whispering Stone                  † Entwicklerzugang
            (-1,1)  Arena‡  ── (0,1)  Haven ── (1,1) Whisper Forest     ‡ Test
                                 │
                               (0,2)  Old Road
```

| Gebiet | Pfad | Narrative Funktion | Ein-/Ausgänge | Gegner & Interaktionen | Storybedingungen | Geplant, nicht implementiert |
|---|---|---|---|---|---|---|
| **Old Road** | `scenes/maps/old_road.tscn`, `data/world/maps/old_road.tres` | Start, Mara, Wagen, Tutorial | nur Nord → Haven (`ToHaven`); Südwand geschlossen | Story-Encounter road_ambush, cart_attack, cart_second_wave (persistent), SideWolves; Signpost, Torn Note, 2 Kisten, RestArea, 2 Sammelknoten | Trunks-Sperre bis `prologue.cart_done`; Encounter/Mara über Quest-Schritte | – |
| **Haven** | `scenes/maps/home_base.tscn` | Basis, Ruinen, NPCs, Klassenstation, Wegstein | Süd → Old Road, Nord → Whispering Stone, Ost → Whisper Forest, West → Arena (**alle belegt**) | keine Gegner; 10 Ruinen, Mara, Edrin, Wegstein | Nordtor gesperrt bis `prologue.haven_settled`; NPCs ab `prologue.haven_discovered` | weitere Restaurierungen (4 Ruinen „unavailable for now“) |
| **Whispering Stone** | `scenes/maps/whispering_stone.tscn` | Schrein, Echos, Klassenwahl | nur Süd → Haven; Nordwand geschlossen | shrine_path, SideWolves; Heart of the Stone, Wegstein, Memory Fragment, RestStone, 4 Sammelknoten (Stufe 3) | Echo-Hinweis Schritt 1; Wegstein ab `prologue.first_class_selected` | – |
| **Whisper Forest** | `scenes/maps/whisper_forest.tscn` | Farm-/Sammelgebiet, Boss | nur West → Haven; Ost-, Nord-, Südwand geschlossen | 3 Hollow Grunts (respawnen), Grove Warden (persistent) + Warden's Cache, 15 Sammelknoten, Hunter's Pack | **keine** (ab Haven frei zugänglich, auch vor der Klassenwahl) | – |
| Trial-Karten | `trial_warrior/arcanist/shadowrunner.tscn` | Echos | nur über Trials | Bastion Guardian, Sanctum Warden, Passage Alpha | nur in Trials | – |
| Proving Arena / Prologue Grounds | `scenes/arena/test_arena.tscn`, `scenes/maps/prologue.tscn` | Test/Entwickler | – | – | – | – |
| Chapel Waystone, Warden's Rest | `data/world/waystones/*.tres` (ohne `map_id`) | „later part of the Hollowwood“ | – | – | `available = false` | **[IDEE]** Gebiete existieren nicht |

**Ungenutzte Übergänge/Routen:** keine. Vorhandene, narrativ offene Richtungen (nur Andeutung, keine Geografie):
- Whisper Forest **Ost** (Wald „deep“; Zelle (2,1) frei) – passt zu Edrins „deep in those woods“. **Empfohlen.**
- Old Road **Süd** (Herkunft der Lieferungen, zweiter Wegweiserarm) – Rückweg aus der Story, eher spätere Kapitel.
- Whispering Stone **Nord** (Zelle (0,-1) ist von der unsichtbaren Trial-Karte belegt; nur im Kartengraph ein Konflikt).

Keine neue Geografie ist hier festgelegt; die Richtungen sind nur Optionen für die Entscheidung E3 (§11).

---

## 5. NPCs und Dialoge (nach dem Prolog)

| NPC | Ort | Dialoge nach `prologue.completed` | Service | Offene Storybezüge |
|---|---|---|---|---|
| **Edrin Vale** | Haven, Nordtor | kein passender Story-Dialog mehr (alle an Quests gebunden, die abgeschlossen sind); G öffnet daher direkt das Quest-Rewards-Fenster (`StoryNpc.interact`), Idle-Zeilen („The north road is quiet. For now.“) nur ohne Service | Quest Rewards (60 Gold für The First Binding) | Bedrohung in den Wurzeln, Stein, Havens Wehrhaftigkeit |
| **Mara Veyne** | Haven | `mara_history` (wiederholbar, ab `dialogue.mara_welcome`); Idle „Watch the treeline.“ | Hearth Flask + Quest-Rewards-Zugang (The Broken Cart) | Versorgung/Lieferungen, Havens Geschichte, Old Road |
| Heart of the Stone (Objekt) | Whispering Stone | Trial-Start nur vor der Wahl; danach ohne Story-Funktion | – | „Three stood here“, beschädigter Stein |

**Empfohlene Ansprechpartner für den neuen Abschnitt (max. drei) [VORSCHLAG]:**
1. **Edrin Vale** – Questgeber und Kapitelabschluss (er hat die Bedrohung eingeführt und ist heute der Turn-in-NPC von
   `the_first_binding`). Ein neuer Story-Dialog muss **vor** seinen Idle-Zeilen greifen; seine Quest-Rewards-Belegung
   bleibt unverändert.
2. **Mara Veyne** – praktischer Gegenpol, Hinweise zu Wegen/Vorräten, optionaler Turn-in. Hearth Flask und
   Quest-Rewards-Zugang bleiben unverändert.
3. **Eine neue Figur im neuen Gebiet** (z. B. an der „Chapel“) – nur falls beschlossen (E4). Alternativ der Whispering
   Stone als nicht-menschliche Stimme (Memory Fragment-Muster `Readable`).

Technik: Dialoge sind `DialogueDefinition`s (Bedingung, Zeilen, Event, `repeatable`); **erster passender Dialog gewinnt**
(Reihenfolge in `data/npcs/*.tres`). Neue Kapitel-Dialoge über `StoryCondition` (Quest/Schritt) an den Anfang der Liste.

---

## 6. Gameplay nach der Klassenwahl

| Bereich | Bestand [IMPL] |
|---|---|
| Regionen | Old Road, Haven, Whispering Stone, Whisper Forest (alle frei) |
| Reguläre Gegner | Whisper Forest: 3 Hollow Grunts (respawnen je Betreten); SideWolves auf Old Road und am Stein |
| Bosse | Grove Warden (einmalig, Rare-Reward im Warden's Cache) |
| Loot | Equipment-Drops Grunts/Wölfe (`EquipmentLoot`, `hollow_grunt_equipment`, `hollowwood_wolves_equipment`), feste Drops (Gold, Iron Ore, Hollow Essence) |
| Quests | Klassenquests der zwei nicht gewählten Klassen (8 Hollow-Kreaturen, 3 Essence + 20 Gold); Story: nur Stub |
| Turn-ins | Mara (The Broken Cart), Edrin (The First Binding) |
| Wegsteine | Haven, Whispering Stone aktiv; Chapel/Warden's Rest „undiscovered“ |
| Rast/Heilung | Checkpoints RestArea (Old Road), RestStone (Stein); Hearth Flask + Mara-Upgrades; Tränke |
| Erkundung | Memory Fragment, Torn Note, Hunter's Pack (Muster), Sammelknoten |
| Systeme | Berufe/Werkstätten, Restaurierung, Resonance Forge, Haven-Lager, Talente/Skills/Presets, Weapon Mastery |

1. **Funktionierende Loops:** Wald farmen → sammeln/herstellen → Werkstätten restaurieren; Klassenquest-Kills im Wald;
   Mastery-XP über Kills; Boss einmal → Rare.
2. **Leerlaufstellen:** Tracker zeigt dauerhaft „Something stirs in the Hollowwood. Your journey continues in a future
   update.“; Edrin ohne Inhalt; keine neue Region, kein Gegnerfortschritt (keine Gegnerstufen), Boss nach einem Kill
   erledigt.
3. **Wiederverwendbare Begegnungsmuster:** `Encounter` + `EncounterSpawn` (persistent/pro Besuch, Bark, Hinweis,
   Wellen in Trials), `StoryConditional` (Sperren/Freigaben), `StoryTrigger`, `Readable`, `StoryPickup`,
   Boss = Grunt-Szene + `EnemyConfig` + `attacks` + `persistent_id` (Grove-Warden-Muster), `BossRewardCache`
   (generisch: `boss_id` + `EquipmentLootTable`), `Checkpoint`, `Waystone`.
4. **Unterstützende Systeme:** Story-Quests mit Schritten/Flags/Folgequest, Journal/Tracker (Kapitelzeile), NPC-Turn-ins
   (Gold + Materialien), Boss-Frame im HUD, Meilenstein-Saves pro Schritt, Weltkarte aus `MapDefinition`.
5. **Tatsächliche technische Hindernisse:**
   - Kein Story-Event für Gegner-/Boss-Kills (`StoryService.notify` nur aus Encounter, Map-Eintritt, Dialog, Readable,
     StoryPickup, StoryTrigger, Restaurierung, Trials, Wegstein). Ein Mini-Boss als Questziel braucht ein **Encounter**
     um den Boss (vorhanden) oder eine kleine Erweiterung.
   - Keine Fernkampf-Gegner-KI (`enemy.gd` nur Nahkampf; `CLASS_TRIALS_2_0_TECH_AUDIT.md` §F.2).
   - Keine Gegnerstufen (`EnemyConfig` kennt nur `rank`).
   - Platzhaltergrafik (prozedurale Formen); jede neue Karte ist Szenenbau von Hand.

---

## 7. Bewertung von „The Ashen Trail“ [Konzept = VORSCHLAG des Auftrags]

| Element | Lore-Passung | Überschneidung | Ersetzt Geplantes? | Umsetzbar mit Bestand? | Neue Storyentscheidung? |
|---|---|---|---|---|---|
| **Kapitel „The Ashen Trail“** | schwach: kein Asche-/Feuer-Motiv im Kanon (Wurzeln, Wald, Stein); einziges Feuer = Old Smithy „A Fire Rekindled“ | – | **ja, Kapitelname**: `the_first_signs` trägt bereits Kapitel „The Roots Remember“ / „chapter one“ | ja | **ja**: Ursprung der Asche, Verhältnis zur Wurzel-Bedrohung |
| **The Forgotten Crossing** | neutral; „old roads“ (Edrin) passt zu einer Kreuzung | „A Road Forgotten“ (Quest), „The Forgotten Study“ (Ruine), Designsystem „The Forgotten Chronicle“ | nein | ja (Map + Encounter) | gering (Lage) |
| **The Fallen Watch** | mittel (Wachposten passt zu Edrin als Wächter) | „The Fallen Barracks“ (Haven-Ruine), Fallen Trunks; inhaltliche Nähe zu **Warden's Rest** | **möglich**: könnte Warden's Rest faktisch ersetzen | ja | ja: Bezug zu Haven-Wachen/Barracks |
| **The Cinder Hollow** | schwach/heikel: „Hollow“ ist der Name der Bedrohung (Hollow Grunt, Hollowwood, Hollow Essence) – ein Ort „Hollow“ legt eine Quelle fest | Spieltitel „Echoes of the Hollow“ | **ja, potenziell**: definiert, was „the Hollow“ ist | ja | **ja, groß** |
| Quest „Ash on the Road“ | Edrin: „When it reaches the old roads“ – passt strukturell, Asche nicht | – | nein | ja | Asche-Motiv |
| Quest „The Silent Watch“ | wie Fallen Watch | „The north road is quiet“ (Edrin-Idle) | s. o. | ja | wie Fallen Watch |
| Quest „Beneath the Cinders“ | „roots … deep“ passt zu „beneath“; Cinders nicht | – | nein | ja | Asche-Motiv |
| **Mini-Boss „The Cinderbound Sentinel“** | schwach (Cinder) | „-bound“: Rootbound Husk, „The First Binding“; Sentinel/Warden/Guardian-Familie (Grove Warden, Sanctum Warden, Bastion Guardian) | nein | ja als Nahkampf-Boss im Grove-Warden-Muster; **kein** Fernkampf/keine Feuer-Effekte ohne neue Systeme | ja |

**Fazit:** Struktur (drei Abschnitte, drei Quests, Wachposten, Mini-Boss) ist realistisch und passt zur Zielgröße. Das
**Asche-/Glut-Thema** ist ein **neuer Lore-Baustein ohne Anker** und kollidiert mit dem bestehenden Kapitelnamen.
„Cinder Hollow“ würde die zentrale offene Frage („was ist the Hollow“) vorwegnehmen.

**Alternative auf Basis vorhandener Planung [VORSCHLAG]:** Kapitel **„The Roots Remember“** fortsetzen,
`the_first_signs` als erste Kapitelquest ausbauen, Gebiete am Planungsrahmen „Mehr Hollowwood mit Chapel Waystone und
Warden's Rest“ ausrichten:
- Abschnitt 1 – tieferer Wald östlich des Whisper Forest (Wurzeln sichtbar „in Bewegung“).
- Abschnitt 2 – Umfeld der **Chapel** (Chapel Waystone).
- Abschnitt 3 – **Warden's Rest** (Warden's Rest-Wegstein), Mini-Boss.
„Ashen Trail“-Elemente lassen sich wiederverwenden, wenn das Asche-Motiv bewusst beschlossen wird (z. B. als Spur der
Bedrohung) – das ist eine Entscheidung (E2), kein Befund.

---

## 8. Empfohlener Kapitelaufbau [VORSCHLAG, keine Dialogtexte, keine Werte]

Arbeitsname: Kapitel „The Roots Remember“ (bestehend). Platzhalter-Ortsnamen in Anführungszeichen.

| Phase | Inhalt | Vorhanden / neu |
|---|---|---|
| **Einstieg** | `the_first_signs` Schritt 0 wird ein echtes Ziel: Edrin spricht den Spieler an (neuer Dialog, Event `talk:edrin_signs` o. ä.). | Quest vorhanden (Stub) · Dialog **neu** |
| **Spielerziel** | Herausfinden, was „deep in those woods“ an den Wurzeln zieht, und einen ersten Ankerpunkt (Wegstein) im tieferen Wald sichern. | Bedrohung vorhanden · Ziel **neu** |
| **Entdeckung 1** | Neuer Ausgang im Whisper Forest (Ost), freigeschaltet über `StoryConditional` mit `prologue.completed`; Abschnitt „tieferer Wald“: Encounter, Spuren (Readables). | Muster vorhanden · Karte **neu** |
| **Entdeckung 2** | „Chapel“-Umfeld: Chapel Waystone erwecken (Datensatz `available = true`, `map_id`), Rast. Optional zentrale NPC-Begegnung. | Wegstein-Daten vorhanden · Karte/NPC **neu** |
| **Konfliktentwicklung** | Die Kreaturen werden organisierter/stärker; Hinweis, dass die Wurzel-Bedrohung einen Mittelpunkt hat (ohne ihn zu benennen). | **neu** (Text) |
| **Höhepunkt** | Mini-Boss an „Warden's Rest“ als **persistentes Encounter** (Story-Event `encounter:<id>`), Boss-Frame; optional `BossRewardCache`. | Muster vorhanden · Boss **neu** |
| **Abschluss** | Warden's Rest-Wegstein, Rückkehr zu Edrin (Turn-in optional, Daten `turn_in_*`), Ausblick auf die nächste Quest (neuer Stub). | Turn-in-System vorhanden · Inhalte **neu** |

Größe: 3 kleine Abschnitte (1–3 Karten), 3 Story-Quests oder 1 Quest mit mehreren Schritten + 2 Folgequests,
1 NPC-Gespräch-Zentrum (Edrin), 1 Mini-Boss.

---

## 9. Technische Anschlüsse und Save-Risiken

| Bereich | Kleinste Erweiterung | Neue Systeme? | Save-Version? |
|---|---|---|---|
| Questdaten | `data/story/the_first_signs.tres` ausbauen + 1–2 neue `StoryQuestDefinition`s | nein | nein |
| Storyflags | neue `completion_flag`s (z. B. `chapter1.*`), frei in `world.flags` | nein | nein |
| Gebietsübergänge | neue `MapDefinition` + Eintrag in `hollow_outskirts.tres` + `MapTransition` + `SpawnPoint`s; Sperre per `StoryConditional` | nein | nein |
| NPC-Dialoge | neue `DialogueDefinition`s **vorne** in `edrin.tres`/`mara.tres` (erster Treffer gewinnt) | nein | nein |
| Encounter | `Encounter` + `EncounterSpawn`, bestehende Gegner-Configs | nein | nein |
| Mini-Boss | neue `EnemyConfig` + `attacks` (Grove-Warden-Muster), im persistenten Encounter | nein (nur Daten) | nein |
| Save/Load | Quest-Einträge, Flags, Zähler, `encounter.<id>`, `defeated.<id>` sind generisch | nein | **nein** (v15 bleibt) |
| Journal/Tracker | `chapter` + Schrittbeschreibung; Turn-in-Zeilen über `turn_in_place` | nein | nein |
| NPC-Questbelohnung | `turn_in_gold`/`turn_in_npc_id`/`turn_in_items` (nur nicht-`open_ended` Quests) | nein | nein |
| Wegsteine | `chapel_waystone`/`wardens_rest`: `available = true`, `map_id`, Knoten in der Szene (`validate_data` prüft Map) | nein | nein |

**Risiken (nachgewiesen):**
1. **`open_ended`-Umbau von `the_first_signs`.** Alle Stände nach dem Prolog stehen auf Schritt 0 mit leerem Fortschritt.
   Wird Schritt 0 durch ein echtes Ziel ersetzt, laufen sie korrekt weiter. **Nicht** Schritte vor Index 0 einfügen.
   Bleibt die Quest `open_ended`, darf nur der **letzte** Schritt ziellos sein (`StoryService.validate_data`) und sie
   kann **keinen Turn-in-Reward** tragen (`QuestRewardService.validate_quest`). Empfehlung: `open_ended` entfernen,
   Abschluss → `next_quest_ids` → neuer Stub (E5).
2. **`StoryService.resettle` + kumulative Ziele.** Beim Laden werden aktive Quests still (ohne Save/Toast/Reward)
   weitergeschaltet, wenn kumulative Zähler erfüllt sind. Altstände haben Zähler wie `count.enter:whisper_forest`,
   `count.enter:home_base`, `count.encounter:*`, `count.waystone:*`. → Kapitelziele nur **nicht-kumulativ** oder mit
   **neuen** Event-IDs; sonst überspringen Altstände Schritte und bekommen keinen Live-Abschluss (Rewards zählen nur
   live: `_settle(announce)`).
3. **Bereits verbrauchte einmalige Ereignisse.** Grove Warden ist in vielen Ständen besiegt (`defeated.whisper_forest_grove_warden`)
   und sendet **kein** Story-Event. Ein Ziel „Grove Warden besiegen“ würde Altstände dauerhaft blockieren. Gleiches gilt
   für persistente Encounter (`encounter.<id>` gesetzt → keine Wiederholung). → Nur neue persistente IDs als Ziele.
4. **Wiederholte Events.** `enter:<map>` feuert bei jedem Betreten (nicht-kumulativ zählt nur ab aktuellem Schritt) –
   unkritisch. `talk:*` mit `repeatable = false` feuert einmal; Dialog muss per Bedingung genau im passenden Schritt
   erreichbar sein (sonst Soft-Lock, vgl. CT 2.0 M1).
5. **Gesetzte Abschlussflags.** `prologue.completed` existiert in allen fertigen Ständen (auch v4→v5-Migration). Als
   Freischaltbedingung für den neuen Zugang geeignet. `prologue.started` und Prolog-Flags nicht wiederverwenden.
6. **Wegstein-/Klassenwahlbedingungen.** Zugang nicht an Klassenwahl-Details koppeln (`prologue.first_class_selected` ⊂
   `prologue.completed`). Neue Wegsteine erst `available`, wenn ihre Karte existiert (sonst Validierungsfehler).
7. **Whisper Forest ist vor der Klassenwahl erreichbar.** Ein neuer Ostausgang **muss** per `StoryConditional` gesperrt
   sein, sonst betreten Prolog-Spieler (Basic Adventurer, evtl. in Trial-Phase) das Kapitel.
8. **Edrin/Mara-Interaktion.** `StoryNpc.interact` (`scripts/world/story_npc.gd:59`): ein **ungehörter** Dialog öffnet
   zuerst; ist er gehört (oder fehlt er), öffnet G das Service-Fenster (Edrin: Quest Rewards, Mara: Hearth Flask). Gehörte
   Dialoge bleiben über den Knopf „Talk to …“ im Service-Fenster erreichbar (`QuestRewardPanel` Z. 162–165, Flask-Fenster
   `NPC_QUEST_TURNINS_1_1_M2.md`). Kapitel-Dialoge: Bedingung „`the_first_signs` aktiv, Schritt n“, **vorne** in der Liste
   (erster Treffer gewinnt). Services bleiben unverändert. Ein Questschritt darf nur an einem `repeatable = false`-Dialog
   hängen, der in genau diesem Schritt gewählt wird.

Keine Migration, kein neuer Queststatus nötig.

---

## 10. Meilensteine (max. vier) [VORSCHLAG]

### M1 – Einstieg & erster Abschnitt (erstes spielbares Stück)
- **Spielbar:** Edrin gibt den Auftrag; Ostausgang im Whisper Forest öffnet nach `prologue.completed`; eine neue kleine
  Karte mit 1–2 Encountern und einem Fund; Rückkehr.
- **Ziel:** Leerlauf nach dem Prolog beenden; Story läuft sichtbar weiter.
- **Systeme:** Story-Quest-Daten (`the_first_signs` ausgebaut), Dialog, `StoryConditional`, `MapDefinition`, Encounter.
- **Abhängigkeiten:** E1–E3, E5 (§11).
- **Tests später:** `story`/`prologue`-nahe Suite für `the_first_signs` (Altstand Schritt 0 läuft weiter, resettle
  überspringt nichts), `world` (Übergänge/Spawns), gezielte Dialogsuite.
- **Abnahme:** Neuer Stand und v15-Altstand mit fertigem Prolog erreichen den neuen Abschnitt; Prolog-Spieler nicht;
  Tracker/Journal zeigen den neuen Schritt.

### M2 – Zweiter Abschnitt & Wegstein
- **Spielbar:** zweite Karte, Chapel Waystone erweckbar und als Reiseziel nutzbar, Rastpunkt.
- **Systeme:** Wegstein-Daten, Checkpoint, Encounter.
- **Tests später:** `waystone`-Suite, `world`, `save` (Wegstein über Save/Load).
- **Abnahme:** Reise Haven ↔ Chapel; keine Reise im Kampf/in Trials (bestehende Regeln).

### M3 – Höhepunkt: Mini-Boss
- **Spielbar:** dritte Karte/Abschnitt, Mini-Boss in persistentem Encounter, Boss-Frame, optional Cache.
- **Systeme:** `EnemyConfig`/Attacks (Daten), `Encounter`, optional `BossRewardCache` + Loot-Tabelle.
- **Tests später:** gezielte Boss-/Encounter-Suite (einmalig, Save/Load, kein Doppel-Event), ggf. `grove_warden_reward`
  als Muster, `hud` nur bei Boss-Frame-Änderung.
- **Abnahme:** Kill → Story-Schritt genau einmal, nach Laden bleibt Boss besiegt, keine Dopplung.

### M4 – Abschluss, Turn-in, Ausblick
- **Spielbar:** Warden's Rest-Wegstein, Rückkehr zu Edrin, Turn-in-Reward, neue Folgequest als Stub.
- **Systeme:** Turn-in-Felder, Dialoge, `next_quest_ids`.
- **Tests später:** `quest_turnin_*` (gezielt neue Quest), `story`, Journal/Tracker-Galerie gezielt (nur neue Bildschirme).
- **Abnahme:** Kapitel abschließbar; Reward einmal; Altstände blockieren nicht; Journal zeigt Abschluss + Ausblick.

Keine Full-Suite, keine vollständigen Prolog-/Haven-Loops ohne Freigabe (Efficient Testing 1.1).

---

## 11. Offene Designentscheidungen (für die Freigabe)

| # | Entscheidung | Optionen |
|---|---|---|
| E1 | Kapitelname | „The Roots Remember“ beibehalten (implementiert) · durch „The Ashen Trail“ ersetzen · „The Ashen Trail“ als Unterabschnitt/Questtitel |
| E2 | Asche-/Glut-Motiv | nicht verwenden · als neue Spur der Wurzel-Bedrohung beschließen (neuer Lore-Baustein, Ursprung offen) |
| E3 | Zugang | Whisper Forest Ost (empfohlen) · Whispering Stone Nord · Old Road Süd · anderes |
| E4 | Zentrale NPC-Begegnung | nur Edrin/Mara · neue Figur im neuen Gebiet · Stein als Stimme |
| E5 | Quest-Struktur | `the_first_signs` ausbauen und abschließbar machen + neuer Stub (empfohlen) · Stub behalten, neue Kapitelquests parallel (braucht anderen Startauslöser) |
| E6 | Gebietsnamen | Chapel/Warden's Rest aus der Wegstein-Planung nutzen · Konzeptnamen (Forgotten Crossing, Fallen Watch, Cinder Hollow) · Mischung |
| E7 | Rolle des Grove Warden | bleibt Nebenboss ohne Story · wird narrativ eingebunden (ohne Kill als Ziel, §9 Risiko 3) |
| E8 | „Was ist the Hollow?“ | in Kapitel 1 offen lassen (empfohlen) · andeuten · festlegen |
| E9 | Zugang erst nach Prolog | `prologue.completed` (empfohlen) · früher |

---

## 12. Quellen und Dateipfade

- Regeln: `CLAUDE.md`
- Story-Daten: `data/story/a_road_forgotten.tres`, `the_broken_cart.tres`, `shelter_among_the_trees.tres`,
  `the_whispering_stone.tres`, `the_first_binding.tres`, `the_first_signs.tres`
- NPCs: `data/npcs/mara.tres`, `data/npcs/edrin.tres`
- Welt: `data/world/regions/hollow_outskirts.tres`, `data/world/maps/*.tres`, `data/world/waystones/*.tres`
- Szenen: `scenes/maps/old_road.tscn`, `home_base.tscn`, `whispering_stone.tscn`, `whisper_forest.tscn`,
  `trial_warrior.tscn`, `trial_arcanist.tscn`, `trial_shadowrunner.tscn`
- Gegner: `data/enemies/*.tres` (Grove Warden: `grove_warden_config.tres`, `grove_warden_attacks.tres`)
- Code: `scripts/rpg/quests/story_service.gd` (`notify`, `resettle`, `_settle`, `validate_data`),
  `scripts/rpg/quests/story_quest_definition.gd`, `scripts/rpg/quests/story_objective.gd`,
  `scripts/rpg/prologue/prologue_service.gd` (`can_choose`), `scripts/rpg/world/waystone_service.gd`,
  `scripts/rpg/world/waystone_definition.gd`, `scripts/rpg/story/dialogue_service.gd`,
  `scripts/rpg/story/dialogue_definition.gd`, `scripts/rpg/save/save_migrations.gd` (v4→v5, Z. 140–178),
  `scripts/world/boss_reward_cache.gd`, `scripts/world/encounter.gd`, `scripts/world/game_map.gd`,
  `scripts/world/story_npc.gd` (`interact`), `QuestRewardPanel` (Talk-Knopf)
- Doku: `docs/GAME_VISION.md`, `docs/PROLOGUE_AND_HAVEN.md`, `docs/WORLD_SYSTEM.md`, `docs/DEVELOPMENT_ROADMAP.md`,
  `docs/CLASS_QUESTS.md`, `docs/CLASS_TRIALS_2_0_M1.md`, `docs/CLASS_TRIALS_2_0_TECH_AUDIT.md`,
  `docs/GROVE_WARDEN_RARE_R2.md`, `docs/GROVE_WARDEN_RARE_REWARD_1_0_AUDIT.md`, `docs/NPC_QUEST_TURNINS_1_0_AUDIT.md`,
  `docs/NPC_QUEST_TURNINS_1_0_T1.md`, `docs/NPC_QUEST_TURNINS_1_1_M2.md`, `docs/LOOT_EQUIPMENT_2_6_SOURCE_AUDIT.md`,
  `docs/PROGRESSION_SYSTEM.md`, `docs/SAVE_SYSTEM.md` (Schemaregel, v15)
- `docs/Design/` (nur gelesen): `WEAPON_MASTERY_COMBAT_FLOW_1_4_1_5.md` – keine Story-/Weltinhalte.
