# Grove Warden – Guaranteed Rare Reward 1.0: Technik- und Loot-Eligibility-Audit

Read-only-Audit. Branch `audit/grove-warden-rare-reward-10` von `dev/class-trials-20-m4` @ `145fc26` (Save v15). Keine
Implementierung, keine Tests oder Playtests, keine echten Saves. Fremde Änderungen (`project.godot`, `docs/Design/`,
`docs/tasks/`) wurden nicht angefasst.

Grundlage: der Code im aktuellen Stand sowie die Vor-Audits `docs/LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` (§C/§D/§F) und
`docs/RARE_STORY_REWARD_1_0_TECH_AUDIT.md`. Deren Aussagen wurden gegen den Code nachgeprüft. Wo sich etwas geändert hat
(Save v15, M4), steht es unten.

Beschlossen: Boss `grove_warden`, Identifier `whisper_forest_grove_warden`. Der erste gültige Kill gibt zu 100 % einen Anspruch
auf genau ein klassenunabhängiges Rare aus zwölf Modellen. Kein Weltdrop, sicher bei voller Tasche, einmalig, keine Duplikate.
Die festen Bossdrops bleiben unverändert.

Vorläufig, noch **nicht** beschlossen: ilvl 20, T5 75 / T4 25, gleich gewichtete Modelle, Claim-Ort.

---

## 1. Kurzfazit

- **Persistenz:** Ein Anspruch lässt sich **ohne Save-Version** sicher modellieren:
  - **Anspruch** = `defeated.whisper_forest_grove_warden` gesetzt **und** Claim-Flag fehlt (abgeleitet)
  - **Erhalten** = eigenes `WorldState`-Flag, das im selben Snapshot mit dem Item gespeichert wird

  Das Defeat-Flag wird nur beim echten Kill gesetzt; keine Migration schreibt es.
- **Item-Erzeugung:** Die vorhandene Pipeline genügt. `EquipmentLoot.roll` mit einer neuen Datentabelle (`chance 1.0`, nur
  Rare, ilvl 20 ohne Streuung) ist exakt der reguläre Weg ohne Sonder-Roller. Gewürfelt wird **beim Claim** (Empfehlung), nach
  der Platzprüfung.
- **Designblocker:** Rüstung und Schild (`leather_cap`, `wanderer_coat`, `oak_shield`) erreichen heute nur **3** gültige Affixe
  (furious, guarded, vital). Ein Rare mit 4 Affixen ist für 3 der 12 Modelle nicht regelkonform möglich: In 40 % der Fälle gibt
  es einen Shortfall, und jedes Rare-Rüstungsteil hat dieselben drei Affixe. Optionen in §5.
- **Zweiter Wirkungsbefund:** `thundering` ist im Pool aller neun Waffen, auf ihnen aber **nie wirksam** (§5.4). Das gilt heute
  schon für reguläre Drops.
- **Claim-Ort:** Kein vorhandenes Objekt passt ohne Änderung. Am kleinsten ist das bestehende `StoryPickup`-Muster (bedingt
  sichtbar, einmalig, Platzprüfung, Flag) am Bossplatz. Das braucht aber einen neuen platzierten Knoten und einen
  Generierungs-Pfad. Keine Festlegung, siehe §6.

---

## 2. Audit A – Grove-Warden-Kill

| Punkt | Befund (Beleg) |
|---|---|
| Config | `data/enemies/grove_warden_config.tres`: `id = &"grove_warden"`, „Grove Warden“, `rank = 2` (einziger Boss-Rang), `mastery_xp_reward 20`, `class_xp_reward 30` |
| Szene / Knoten | `scenes/maps/whisper_forest.tscn:233-238`, `Enemies/GroveWarden` (Grunt-Szene ×1,3, `config` + `attacks` überschrieben), `persistent_id = &"whisper_forest_grove_warden"`, **kein** `equipment_loot` |
| Death-Hook | `HealthComponent.apply_hit` emittiert `died` nur beim Übergang auf tot. Der Guard `if is_dead(): return` steht in `scripts/combat/health_component.gd:63-80`. Danach `Enemy._on_died` → `defeated.emit(self)` (`scripts/enemies/enemy.gd:167-171`). `health.reset()` gibt es bei Gegnern nur in `_ready` (`enemy.gd:45`). → **ein `defeated` pro Leben** |
| Verdrahtung | `GameMap.register_enemy` (`scripts/world/game_map.gd:84-91`) verbindet `_spawn_drops` und nur bei `persistent_id` `_on_persistent_enemy_defeated`. Beide sind gegen Doppelverbindung geschützt (`is_connected`) |
| Defeat-Flag | `defeated.<persistent_id>` (`game_map.gd:94-100`) über `WorldState.set_flag`. Gleicher Wert wird nicht erneut gesetzt (`scripts/rpg/world/world_state.gd:28-34`). Es ist der **einzige** Schreiber dieses Flags im Code (grep `set_flag` + `defeat`). Keine Migration setzt `defeated.*` (`scripts/rpg/save/save_migrations.gd` ohne Treffer) |
| Kein Respawn | `_remove_defeated_enemies` (`game_map.gd:104-108`) entfernt den Boss bei jedem Kartenladen. Getestet: `test_defeated_boss_stays_gone_after_save_and_load` (`tests/integration/test_economy.gd:117-157`) |
| Bestehende Rewards | feste Drops aus der Config: 1 `hollow_essence`, 2 `iron_ore`, 25 `gold_coin`. Sie sind **transiente** `ItemPickup`s (`game_map.gd:132-141`, `spawn_pickup` :111-117), nicht gespeichert (siehe Test oben). Dazu Mastery-/Klassen-XP. In einer Trial wird nichts gedroppt (`PrologueService.rewards_blocked`, `game_map.gd:133-134`) |
| Persistenzzeitpunkt | Das Flag wird **sofort im Speicher** gesetzt. Beim Tod wird **kein** Save angefordert |
| Reguläre Saves | periodisch alle 300 s aktiver Spielzeit (`scripts/rpg/save/save_coordinator.gd:24`, :88); manuell (Esc); Meilensteine nur bei Story-Schritt, Restaurierung, Klassenwahl, Wegstein und M4-Claim (`scripts/rpg/session_state.gd:121,129`, `scripts/world/waystone.gd:57`). Ein Boss-Kill ist **kein** Meilenstein |
| Wiederholung / Doppelereignis | `died` wird nur einmal emittiert; `set_flag` ist idempotent; Equipment-Wurf-Guard `equipment_rolled` (`game_map.gd:138-140`). Ein zweites `defeated` desselben Knotens ist im Code nicht möglich. Ein zweiter Kill entsteht nur über einen Reload **ohne** gespeichertes Flag (nächste Zeile) |
| Ende vor dem nächsten Save | Flag und liegende Drops gehen **gemeinsam** verloren. Nach dem Laden lebt der Boss wieder und kann erneut besiegt werden. Pro Spielstand gibt es höchstens einen Sieg; nichts dupliziert sich |
| Tod vor Klassenwahl | Möglich: Das Haven-Osttor `ToForest` hat keine Bedingung (`scenes/maps/home_base.tscn:345-350`), Haven ist ab `prologue.haven_discovered` erreichbar. Klassenunabhängig; das Flag wird gleich gesetzt. Folge für den Reward: `furious` wirkt bis zur Klassenwahl nicht, weil `basic_adventurer` keine Ressource hat (`scripts/rpg/classes/class_runtime.gd:212-215`, `data/classes/basic_adventurer.tres` ohne `resource`) |
| Trial-Kontext | `whisper_forest` ist keine Trial-Karte (`ProgressionRules.trial_map_ids`). Beim Betreten endet eine laufende Trial (`game_map.gd` `_ready`, `PrologueService.end_trial`), ein Kill in einer Trial ist dort also ausgeschlossen |

**Bosslogik:** Für den Reward muss sie **nicht** geändert werden. Das Defeat-Flag reicht als Auslöser, wenn der Anspruch abgeleitet
wird (§3). Ein zusätzlicher Meilenstein-Save beim Kill wäre eine optionale Änderung an `GameMap` und für die Korrektheit
nicht nötig (Entscheidung E9).

---

## 3. Audit B – Einmaliger Anspruch

### 3.1 Vergleich mit M4
M4 (`docs/CLASS_TRIALS_2_0_M4.md`) speichert einen **expliziten** Zustand `prologue.class_reward` none/pending/claimed (Save v15),
weil eine Klassenidentität in alten Ständen nicht als echte Wahl belegbar war. Beim Boss liegt das anders: Das Defeat-Flag
**ist** ein authentischer, nur beim echten Kill geschriebener Nachweis. Ein eigener Pending-Zustand würde nur die Information
dieses Flags duplizieren.

### 3.2 Empfohlenes Modell: drei getrennte Fakten, zwei gespeichert

| # | Fakt | Speicherung | Gesetzt durch |
|---|---|---|---|
| 1 | Boss besiegt | `defeated.whisper_forest_grove_warden` (vorhanden) | `GameMap._on_persistent_enemy_defeated` (unverändert) |
| 2 | Anspruch vorhanden | **abgeleitet:** (1) ∧ ¬(3) ∧ Reward-Daten gültig | nichts (keine Signal-Abhängigkeit) |
| 3 | Rare erhalten | neues Weltflag, z. B. `reward.whisper_forest_grove_warden` (String-Wert erlaubt: `world_state.gd:29`; Wert z. B. die Instanz-ID oder das Modell) | nur der Claim-Service, im selben synchronen Aufruf wie `Inventory.add_instance` |

Nach CLAUDE.md gehört Weltzustand nur in `WorldState`, daher das Flag und nicht `PrologueState`. Präzedenzfälle für solche Flags:
`pickup.<id>` (`scripts/world/story_pickup.gd:37-38`), `read.<id>` (`scripts/world/readable.gd:26-27`), `pickup_taken.<id>`.

### 3.3 Prüfpunkte

| Fall | Verhalten im empfohlenen Modell |
|---|---|
| Entitlement beim ersten Kill | sofort, weil abgeleitet. Kein eigener Schreibvorgang, kein Callback nötig |
| Wiederholte Death-Signale | wirkungslos: Das Flag ist idempotent, der Anspruch ist abgeleitet, und kein Signal erzeugt ein Item |
| Volles Inventar | Der Claim prüft `Inventory.room_for(model) ≥ 1` **vor** dem Wurf. Alle zwölf Modelle sind 1-Slot-Items (`max_stack = 1`), also reicht `free_slots() ≥ 1` für jedes Modell. `add_instance` prüft dieselbe Bedingung (`scripts/rpg/items/inventory.gd:72-83, 120-136`). Bei Ablehnung: kein Wurf, kein Flag, Anspruch bleibt |
| Save/Load nach Kill | Das Flag ist gespeichert, also besteht der Anspruch nach dem Laden. Nicht gespeichert: Boss lebt wieder, kein Anspruch, kein Verlust |
| Save/Load nach Claim | Item **und** Claim-Flag stehen im selben `Character.to_dict`-Snapshot (`scripts/rpg/save/save_coordinator.gd` – ein Snapshot pro Frame, nie mitten in einem synchronen Aufruf). Kein zweiter Claim |
| Absturz nach Claim, vor Save | Item und Flag gehen gemeinsam verloren, der Anspruch ist wieder offen, beim nächsten Claim wird **neu** gewürfelt. Ein Duplikat entsteht nicht. Ein Meilenstein-Save direkt nach dem Claim (Muster M4) verkleinert das Fenster |
| Alte Saves mit besiegtem Boss | Anspruch entsteht automatisch (abgeleitet), siehe §7 |
| Unabhängig von Klassenwahl | ja. Weder Ableitung noch Claim lesen `prologue` oder die aktive Klasse. Ob ein Claim während einer laufenden Trial gesperrt wird (wie in M4), ist zu entscheiden; empfohlen ist sperren, weil Trials keine Belohnungen geben |
| Nur UI-Aktion? | nein. Alle Prüfungen liegen im Service, die UI ruft nur `claim` auf (Muster `PrologueService.claim_class_reward`) |

**Restrisiko** (wie im Vor-Audit): Ein Script-Fehler zwischen `add_instance` und `set_flag` ließe das Item ohne Flag zurück. Das
lässt sich durch direkte Abfolge ohne Code dazwischen minimieren, aber nicht ausschließen. Save-Scumming über ältere Slots vor
dem Claim ist systembedingt möglich; pro Spielstand gibt es höchstens ein Item.

**Save-Version:** **nicht nötig**, denn `world.flags` nimmt freie Keys auf. Nötig würde sie nur, wenn alte Stände den Reward
**nicht** bekommen sollen (§7, Variante R2).

Kein Mailbox-System: Das Modell ist ein Flag-Paar pro Boss, wie bei `read.<id>`.

---

## 4. Audit C – Item-Erzeugung

### 4.1 API
- `ItemCreation.generate(definition, rarity, db, rng, tier_weights, item_level, origin, id)` (`scripts/rpg/items/item_creation.gd:58ff.`)
  - `AFFIX_COUNTS[RARE] = {3: 60.0, 4: 40.0}` (:17-23) entspricht der Loot Foundation. Die Anzahl wird **einmal** über
    `AffixRoller.pick` gezogen, danach wird pro Affix `AffixRoller.roll_one` aufgerufen (`scripts/rpg/crafting/affix_roller.gd:82-93`).
  - Ist der Pool erschöpft, entsteht ein `shortfall` mit `note`; das Item bleibt mit weniger Affixen bestehen (`item_creation.gd`,
    Ende von `generate`).
  - Ablehnungen vor jedem Wurf: keine `generation_affixes`, Unique/Set, Level außerhalb 1–100, Tier-Tabelle deckt den Level nicht.
- `EquipmentLoot.roll(table, db, rng)` (`scripts/rpg/items/equipment_loot.gd:10-22`) zieht ein Modell mit gleichen Gewichten,
  dann die Rarity nach Tabellengewichten, dann den Level, und ruft `generate` mit `ORIGIN_FOUND` auf. **Den `shortfall` gibt es
  nicht weiter.**
  - Mit `chance = 1.0` ist der Wurf garantiert, weil `randf() >= 1.0` nie eintritt.
  - `EquipmentLootTable.validate` (`scripts/rpg/items/equipment_loot_table.gd:21-45`) prüft Modelle, Rarity und Tier-Abdeckung.
  → Eine Tabelle `chance 1.0`, `rarity_weights {2: 100}`, `source_level 20`, `level_spread 0`, zwölf `item_ids` drückt das
  vorläufige Design **rein datenseitig** aus. Es braucht keinen Sonder-Roller.
- Tier-Gewichte: `data/loot/hollowwood_early_tiers.tres` Band 10–24 = `{4: 25, 5: 75}` → bei ilvl 20 exakt T5 75 / T4 25.
  T4 ist ab ilvl 10 erreichbar (`AffixTiers`), alle 15 Affixe haben fünf Tiers (`data/crafting/affixes/*.tres`).
- Instanz-ID über `IdGenerator` (OS-CSPRNG), gespeichert. Die Instanz behält Rarity, Level, Basis und Affixe (Loot Foundation, Save v14).

### 4.2 Status aller zwölf Modelle (`data/items/<id>.tres`)

„Pool“ = Anzahl der `generation_affixes`; „max. gültig“ = nach Gruppen und Exclusions (`element_core`: bloodthirsty/thundering,
`control_core`: crushing/impactful) und der Kappe `CraftingProfile.MAX_AFFIX_SLOTS = 5`.

| Modell | Slot | Def.-Rarity | Basis ilvl 20 | Pool | max. gültig | in regulärer Tabelle | Rare möglich | ilvl 20 / T5–T4 | Rare 3 | Rare 4 |
|---|---|---|---|---|---|---|---|---|---|---|
| `iron_sword` | 1H (10) | Normal | 14,736 | 13 | 5 | Grunt | ja | ja | ja | ja |
| `steel_greatsword` | 2H (11) | Normal | 27,016 | 13 | 5 | Wolf | ja | ja | ja | ja |
| `iron_axe` | 1H | Normal | 17,192 | 13 | 5 | Grunt | ja | ja | ja | ja |
| `iron_dagger` | 1H | Normal | 11,052 | 13 | 5 | Grunt | ja | ja | ja | ja |
| `iron_mace` | 1H | Normal | 18,420 | 13 | 5 | Grunt | ja | ja | ja | ja |
| `ash_spear` | 2H | Normal | 15,964 | 13 | 5 | Grunt | ja | ja | ja | ja |
| `oak_staff` | 2H | Normal | 15,964 | 13 | 5 | Wolf | ja | ja | ja | ja |
| `oak_wand` | 1H | Normal | 12,280 | 13 | 5 | Wolf | ja | ja | ja | ja |
| `hunting_bow` | 2H | Normal | 15,964 | 12 (ohne executioner) | 5 | Wolf | ja | ja | ja | ja |
| `leather_cap` | Kopf (1) | Normal | – | **3** | **3** | Grunt | ja | ja | ja | **nein** |
| `wanderer_coat` | Brust (4) | **Magic** | – | **3** | **3** | Grunt | ja | ja | ja | **nein** |
| `oak_shield` | Schild (13) | Normal | – | **3** | **3** | Wolf | ja | ja | ja | **nein** |

- Basiswerte: B1 × (1 + 0,012 × 19), Modellfaktor 1,0 (`scripts/rpg/items/weapon_damage.gd`). Rechnerisch übernommen aus
  `RARE_STORY_REWARD_1_0_TECH_AUDIT.md` §5, nicht ausgeführt.
- Regulär: `data/loot/hollow_grunt_equipment.tres` (7 Modelle, ilvl 3–7, Normal/Magic 75/25), `data/loot/hollowwood_wolves_equipment.tres`
  (5 Modelle, ilvl 8–12, 60/40). Alle zwölf sind also EquipmentLoot-fähig, bisher aber nie als Rare.
- Keine Monster-Essence-Affixe: Essenzen sind kein Affix. `generate` setzt `essences` nie. Essenz-Slots haben nur Items mit
  `essence_slots` (`forged_blade`, `forged_greatsword`, `stormcaller_fang`), keines der zwölf.
- Keine doppelten oder ungültigen Affixe: Das stellt `AffixRoller.eligible` sicher (Id-, Gruppen- und Exclusion-Sperre, Slot,
  Familie, Tier am Level; `affix_roller.gd:20-48`).
- `wanderer_coat`: Die Definition ist Magic, die Instanz wäre Rare. `generate` erlaubt das (nur Unique/Set werden abgelehnt).
  Verkauf und Salvage lesen weiter die **Definitions**-Rarity (offener Punkt 4 in `docs/LOOT_FOUNDATION_1_0.md`), der Loot-Feed
  ebenso (`scripts/ui/hud/loot_feed.gd`).

### 4.3 Wann das Item entsteht

| | Beim Kill erzeugen | Beim Claim erzeugen (Empfehlung) |
|---|---|---|
| Speicherort bis zur Abholung | Instanz außerhalb des Inventars → **neues Save-Feld** (gespeicherte Pending-Instanz). Das ist ein Mailbox-Ansatz, den der Auftrag ausschließt | keiner. Der Anspruch ist abgeleitet |
| Reload / mehrfacher Claim | Identität fest, sobald gespeichert | Claim und Flag liegen im selben Snapshot, kein Duplikat. Vor dem Claim neu würfelbar durch Laden eines älteren Stands oder einen Absturz vor dem Save |
| Inventar voll | Instanz existiert schon und wartet | kein Wurf, keine verworfene Instanz |
| RNG-Stabilität | ein Wurf pro Kill | ein Wurf pro erfolgreichem Claim. `GameMap.loot_rng` wird pro Karte zufällig geseedet (`game_map.gd:39-40`), Reproduzierbarkeit gibt es also wie bei allen Drops nicht |
| Dauerhafte Reward-Identität | ab dem Kill | ab dem Claim (die Instanz-ID kann als Flag-Wert gespeichert werden) |

Die Entscheidung ist offen (E3). Für „beim Claim“ sprechen: keine Schemaänderung, kein Mailbox-Speicher, und es passt zu M4
sowie zum Rare-Story-Audit.

---

## 5. Audit D – Armor/Shield-Affixpool

### 5.1 Vollständige Affixliste (`data/crafting/affixes/*.tres`, 15 Einträge)
Slotnummern: 1 Kopf, 4 Brust, 10 1H, 11 2H, 13 Schild, 14 Ring, 15 Hals. `allowed_slot_kinds` leer = alle Slots.

| Affix | Stat | Scope | Slots | Gruppe / Exclusion | würfelbar | auf Kopf/Brust/Schild heute |
|---|---|---|---|---|---|---|
| furious | resource_gain | GLOBAL | alle | resource_gain | ja | **eligibel** (in allen drei Pools) |
| vital | max_health | GLOBAL | alle | max_health | ja | **eligibel** |
| guarded | armor | GLOBAL | 1–9, 13 | armor | ja | **eligibel** |
| armored | armor (%) | **LOCAL** | 1–9 (kein Schild) | local_armor_percent | **nein** | ausgeschlossen: `rollable = false`, nicht im Pool, Schild nicht in der Slotliste |
| keen | crit_chance | GLOBAL | 10, 11, 14, 15 | crit_chance | ja | Slot gesperrt |
| cruel | crit_damage | GLOBAL | 10, 11 | crit_damage | ja | Slot gesperrt |
| sharpened | physical_damage | GLOBAL | 10, 11 | physical_damage | ja | Slot gesperrt |
| swift | attack_speed | GLOBAL | 10, 11 | attack_speed | ja | Slot gesperrt |
| crushing | poise_damage | GLOBAL | 10, 11 | poise_damage / control_core | ja | Slot gesperrt |
| impactful | knockback_power | GLOBAL | 10, 11 | knockback_power / control_core | ja | Slot gesperrt |
| bloodthirsty | life_on_hit | GLOBAL | 10, 11 | life_on_hit / element_core | ja | Slot gesperrt |
| thundering | shock_damage | GLOBAL | 10, 11 | shock_damage / element_core | ja | Slot gesperrt |
| executioner | finisher_power | GLOBAL | 10, 11 (+ `required_attack_tags` heavy+finisher) | finisher_power | ja | Slot gesperrt; zusätzlich `fits_family` = false für Nicht-Waffen (`scripts/rpg/crafting/affix_definition.gd:59-73`) |
| striking | weapon_damage (flat) | LOCAL | 10, 11 | local_weapon_damage_flat | ja | Slot gesperrt; LOCAL wirkt nur über `WeaponDamage` |
| tempered_blade | weapon_damage (%) | LOCAL | 10, 11 | local_weapon_damage_percent | ja | Slot gesperrt; dto. |

### 5.2 Wirkung auf Rüstung/Schild, falls geöffnet (technisch, ohne Freigabe)
- **GLOBAL-Affixe** gehen unabhängig vom Slot als `StatModifier` in den `StatResolver` (`scripts/rpg/crafting/item_stats.gd:15-27`:
  nur LOCAL wird ausgefiltert). Auf Rüstung **wirksam wären** also: keen, cruel, sharpened, swift, crushing, impactful,
  bloodthirsty, weil ihre Verbraucher Charakter-Stats lesen (`CharacterStatModifier`, `PlayerProgressionBridge`; Belege in
  `LOOT_QUEST_ARCHITECTURE_1_0_AUDIT.md` §D).
- **Faktisch wirkungslos:** `thundering` (nur `EssenceDischargeEffect`, `scripts/rpg/effects/essence_discharge_effect.gd:37`,
  Essenzen nur auf Waffen mit Essenz-Slots), `executioner` (scheitert an `fits_family`, Slot kein Waffen-Slot), `striking` und
  `tempered_blade` (LOCAL Waffenbasis, auf Rüstung nicht berechnet).
- **Armored:** weiterhin deaktiviert. LOCAL-Einträge erreichen den `StatResolver` nie (`item_stats.gd:27`). Einziger
  LOCAL-Verbraucher ist `WeaponDamage` (Waffenbasis). Eine lokale Armor-Basis-Berechnung über `base_stats` fehlt. Stand bestätigt
  durch `docs/LOOT_FOUNDATION_1_0.md:133-136, 193`. Selbst geöffnet passt es nicht auf den Schild (Slotliste 1–9).
- **Konflikte:** Für Rüstung entstehen keine neuen Exclusions. `element_core` und `control_core` erlauben je nur ein Affix ihres
  Paars. Gruppen-Duplikate verhindert `eligible`.
- **Wichtige Nebenwirkung:** `generate` liest den Pool **nur** aus `ItemDefinition.generation_affixes`. Eine Öffnung an
  `leather_cap`, `wanderer_coat` oder `oak_shield` ändert damit **auch die regulären Grunt- und Wolf-Drops**. Ein Reward-eigener
  Pool bräuchte einen neuen Parameter an `generate` bzw. `EquipmentLoot`, also eine API-Änderung.

### 5.3 Exakter Designblocker
Für `leather_cap`, `wanderer_coat` und `oak_shield` gibt es heute genau **drei** legale und eligible Affixe. Rare zieht 4 mit 40 %.
Diese Würfe enden in einem **Shortfall** von 1: Das Item bleibt Rare mit 3 Affixen, `EquipmentLoot.roll` verschweigt den
Shortfall. Außerdem trägt **jedes** Rare-Rüstungsteil zwangsläufig furious + guarded + vital; nur Tiers und Werte variieren. Ein
regelkonformes 4-Affix-Rare ist ohne neue Freigabe **nicht** erreichbar.

**Optionen** (jede braucht eine Entscheidung, nichts davon ist umgesetzt):

| # | Option | Vorteile | Nachteile |
|---|---|---|---|
| O1 | Shortfall hinnehmen (Standard der Loot Foundation): Rüstung/Schild-Rare mit 3 Affixen | keine Regeländerung, keine Code- oder Datenänderung an Affixen, reguläre Drops unberührt | „Rare 3/4“ gilt für 3 von 12 Modellen nicht; Rare-Rüstung immer gleich; ein Rare-Kappe ist praktisch ein Magic-plus |
| O2 | Reward-Pool auf die **neun Waffen** begrenzen | volle Rare-Qualität (3/4, Vielfalt); reine Datenentscheidung in der Reward-Tabelle; reguläre Drops unberührt | ändert den beschlossenen Zwölf-Modell-Pool; Rüstungsfreunde gehen leer aus |
| O3 | Rüstung/Schild per Freigabe für einen **wirksamen** GLOBAL-Weapon-Affix öffnen (Kandidat `keen`: hat schon Nicht-Waffen-Slots 14/15) | 4 legale Affixe für alle drei Modelle, keine neuen Effekte | ändert **reguläre** Drops und Crafting mit, außer `generate` bekommt einen Pool-Parameter; Balance- und Designfreigabe nötig (Krit auf Rüstung); wirkt sich auf `AffixPool`-Crafting aus |
| O4 | `armored` aktivieren (LOCAL Armor-%) mit neuer lokaler Armor-Berechnung | thematisch passend für Rüstung | neue Gameplay-Berechnung (verboten ohne Freigabe); Schild bliebe trotzdem bei 3 (Slotliste); Werte und Tests nötig |

Empfehlung für den kleinsten sicheren Weg: **O1 oder O2**. O1 hält den Zwölfer-Pool, O2 die Rare-Qualität. O3 und O4 sind eigene
Design-Meilensteine.

### 5.4 Wirkungsbefund `thundering` auf den neun Waffen
`thundering` (Gewicht 30) liegt in allen neun Waffenpools. `shock_damage` liest nur `EssenceDischargeEffect`
(`essence_discharge_effect.gd:37`), und Essenzen tragen nur `forged_blade`, `forged_greatsword` und `stormcaller_fang`. Bei genau
einem Waffen-Slot ist `thundering` auf den neun Modellen **nie wirksam**. Das betrifft heute schon reguläre Magic-Drops. Ein
garantiertes Rare kann ihn ebenfalls ziehen.

Gegen die Vorgabe „keine wirkungslosen Affixe“ steht das als **offene Entscheidung** (E7): hinnehmen wie reguläre Drops, oder aus
den `generation_affixes` der neun Waffen entfernen (ändert reguläre Drops).

Analog: `furious` wirkt erst ab der Klassenwahl, ist danach aber dauerhaft wirksam. Das ist kein Blocker.

---

## 6. Audit E – Claim-Ort

Kriterien: nach dem Kill erreichbar (a), vor der Klassenwahl erreichbar (b), kein Soft-Lock (c), bei voller Tasche später
wiederkommen (d), UI ohne neue Infrastruktur (e), Story-Bezug (f).

| Kandidat | Mechanik (Beleg) | a | b | c | d | e | f | Aufwand / Haken |
|---|---|---|---|---|---|---|---|---|
| **K1 Bossplatz, Whisper Forest** (z. B. „Warden's Cache“) | `StoryPickup` (`scripts/world/story_pickup.gd`): `condition` (`StoryCondition.required_flags = [defeated.whisper_forest_grove_warden]`) steuert die Sichtbarkeit live über `flag_changed`. Einmal-Flag `pickup.<id>`, Platzprüfung vor Ausgabe, Meldung über `hud.notify`. Präzedenz `HuntersPack` (`whisper_forest.tscn:208-216`) | ja, sofort | ja | ja | ja (bleibt sichtbar bis zur Abholung) | ja (Prompt + Toast) | stark | **neuer platzierter Knoten** in `whisper_forest.tscn`. `StoryPickup.take` kennt nur `add_item` mit fester ID → braucht einen optionalen Generierungs-Pfad (Tabelle) oder eine kleine Schwesterklasse. Das Taken-Flag wäre dann das Claim-Flag |
| K2 Heart of the Stone (M4-Footer) | `ClassChoicePanel.footer` (`scripts/ui/class_choice_panel.gd`) | ja | nur ab `prologue.haven_settled` (Nordtor `home_base.tscn:44`, `C_gate_barred`) | ja (nur Wartezeit) | ja | ja | schwach | vermischt Klassen- und Boss-Reward; früher Kill → Abholung erst nach Story-Fortschritt. Die visuelle Abnahme des M4-Footers steht ohnehin noch aus |
| K3 Edrin (Haven) | `StoryNpc` + `NpcDefinition.service` (`scripts/rpg/story/npc_definition.gd:13-15`); Edrin hat keinen Service | ja | ja (ab `haven_discovered`) | ja | ja | **nein**: `GameHud.open_npc_service` kennt nur `hearth_flask` (`scripts/ui/game_hud.gd:592-601`), braucht neues Fenster bzw. Service | mittel | neues Service-Fenster nötig |
| K4 Mara (Haven) | Service-Slot belegt (`hearth_flask`) | ja | ja | ja | ja | nein (mehrere Services pro NPC fehlen) | mittel | Architekturerweiterung |
| K5 Journal (J) | `JournalPanel` listet nur Quests | ja | ja | ja | ja | nein (Boss ist keine Quest, keine Karte) | schwach | neue Journal-Sektion |
| K6 `Readable` am Bossplatz | `readable.gd:34-49` (Platzprüfung vor Flag, `rewards` nur feste `ItemCost`) | ja | ja | ja | ja | ja | gut | gleiche Haken wie K1 (neuer Knoten, keine Generierung); sichtbar auch vor dem Kill, außer man kapselt es in `StoryConditional` |
| K7 Haven-Lager / Briefkasten | `StashService` | – | – | – | – | – | – | **ausgeschlossen** (Mailbox-Charakter) |

Bewertung ohne Festlegung: K1 erfüllt alle sechs Kriterien mit vorhandenen Mechaniken, braucht aber einen neuen platzierten Knoten
und eine kleine Generierungs-Erweiterung. K2 ist ohne neuen Knoten machbar, verletzt aber (b) für frühe Kills und vermischt zwei
Belohnungen. K3 bis K5 brauchen neue UI-Infrastruktur.

**Entscheidung erforderlich (E4).** Laut Auftrag wird kein Objekt angelegt.

---

## 7. Audit F – Altstände

| Zustand | Erkennung | Empfohlene Behandlung |
|---|---|---|
| Boss besiegt, Rare nie verfügbar (alle Stände vor dem Feature, v1–v15) | Defeat-Flag gesetzt, Claim-Flag fehlt | **R1 (empfohlen):** Anspruch entsteht abgeleitet. Das Flag ist authentisch: einziger Schreiber `GameMap`, keine Migration setzt es. Eine Klassenwahl ist dafür nicht nötig |
| Boss nicht besiegt | kein Defeat-Flag | kein Anspruch; der Boss lebt und ist besiegbar |
| fehlendes Defeat-Flag nach Kill (Absturz vor Save) | kein Flag | Boss lebt wieder (`_remove_defeated_enemies` greift nicht) → neuer Kill → Anspruch. Kein Verlust, kein Duplikat |
| ungültige/doppelte Death-Signale | `died` einmal pro Leben, `set_flag` idempotent | keine Wirkung auf den Anspruch (abgeleitet) |
| Flag mit Fremdwert (z. B. String/Int) | `WorldState.has_flag` = vorhanden und ≠ false (`world_state.gd:47-48`) | gilt als besiegt. Nur durch Editieren erreichbar, akzeptabel |
| ausstehender Reward beim Save | nichts gespeichert außer Defeat-Flag | nach dem Laden wieder verfügbar |
| abgeholter Reward beim Save | Item + Claim-Flag im selben Payload | nach dem Laden `claimed`, kein Claim |

- **R1** braucht **keine** Migration und keine Save-Version. v15 bleibt.
- **Alternative R2** (keine Rückwirkung): Migration v15→v16 setzt für Stände mit Defeat-Flag das Claim-Flag auf `"legacy"`.
  Das ist überprüfbar und nicht duplizierend, verweigert aber Bestandsspielern den Reward. Bei R2 braucht es Version,
  Migration und Tests (CLAUDE.md).
- Entwicklungsstände des Projektinhabers mit besiegtem Warden bekommen bei R1 einen offenen Anspruch (E5).

---

## 8. Audit G – Umsetzungsplan (max. drei Phasen)

**Phase 1 – Eligibility- und Reward-Vertrag (Daten, kein Gameplay)**
- Dateien:
  - neue `EquipmentLootTable` z. B. `data/loot/grove_warden_rare_reward.tres` (`chance 1.0`, `{RARE: 100}`, ilvl 20, Spread 0,
    Modellliste nach E1)
  - Tier-Tabelle: Referenz auf `hollowwood_early_tiers.tres` oder eigene Band-20-Tabelle (E2)
  - Validierung über `EquipmentLootTable.validate` bzw. `GameDatabase.validate`
- Save: keine.
- Risiko: niedrig. Reguläre Tabellen und `generation_affixes` bleiben unverändert, solange O3 oder O4 nicht gewählt werden.
- Akzeptanz: Für alle Pool-Modelle und feste Seeds gilt Rare, ilvl 20, nur T5/T4, keine Duplikate oder Exclusions, keine Essenzen.
  Shortfall entspricht der gewählten Option. Reguläre Tabellen sind unverändert.
- Tests: neue gezielte Suite (feste Seeds, keine statistischen Grenzen), `hollowwood_loot`, `loot_foundation`.

**Phase 2 – Boss-Entitlement und sicherer Claim**
- Dateien:
  - ein kleiner zustandsloser Service (z. B. `scripts/rpg/world/boss_reward_service.gd`): `state`, `can_claim`, `claim(character, rng)`
  - Reihenfolge: Defeat-Flag → nicht claimed → keine Trial (E8) → `room_for` → `EquipmentLoot.roll` → `add_instance` → `set_flag`
  - Claim-Ort nach E4 (bei K1: `StoryPickup`-Erweiterung oder Schwesterklasse + Knoten in `whisper_forest.tscn`)
  - Meilenstein-Save nach dem Claim (`SessionState.request_critical_save`)
  - Texte über `localization/ui.csv`
  - Bosslogik in `GameMap`/`Enemy` bleibt unverändert, außer E9 wird gewählt
- Save: R1 → keine. R2 → v16, Migration, Tests, `docs/SAVE_SYSTEM.md`.
- Risiko: mittel (Claim-Atomarität, Sichtbarkeit des Claim-Objekts).
- Akzeptanz:
  - kein Anspruch ohne Kill
  - Anspruch nach Kill, auch nach Save/Load
  - volle Tasche: kein Wurf, kein Flag, später erfolgreich
  - genau ein Item, zweiter Claim abgelehnt, auch nach Save/Load
  - unabhängig von der Klassenwahl
  - feste Bossdrops unverändert
- Tests: neue Suite mit synthetischen Saves unter `user://test_saves/`, dazu `economy` (Boss-Persistenztest), `save`.

**Phase 3 – Integrationstests und UI-Abnahme**
- Ein gezielter Kartentest: Warden töten, Claim-Objekt erscheint, Claim, Karte neu laden, Objekt bleibt weg. Ohne
  Prolog-/Haven-Loops.
- Visuelle Abnahme des Claim-Objekts bzw. -Fensters in einer Auflösung. Die ausstehende visuelle Abnahme des M4-Altar-Footers
  lässt sich hier mitnehmen.
- Loot-Feed: Ein direkter Claim über `add_instance` erzeugt heute **keinen** Feed-Eintrag. Eine eigene Meldung ist nötig (E10).

---

## 9. Entscheidungen, die eine Freigabe brauchen

- **E1 – Rüstung/Schild:** O1 (Shortfall 3 Affixe) · O2 (nur neun Waffen) · O3 (z. B. `keen` öffnen, ändert reguläre Drops) ·
  O4 (`armored` + neue Berechnung).
- **E2 – Parameter:** ilvl 20 (liegt deutlich über allen regulären Quellen, Grunts 3–7, Wölfe 8–12) · T5 75 / T4 25 · gleiche
  Modellgewichte · Tier-Tabelle teilen oder eigene.
- **E3 – Erzeugungszeitpunkt:** beim Claim (empfohlen, ohne Schema) oder beim Kill (braucht gespeicherte Pending-Instanz, also
  Schema + Mailbox-Nähe).
- **E4 – Claim-Ort:** K1 Bossplatz (neuer Knoten), K2 Altar, K3 Edrin (neues Service-Fenster) oder anders.
- **E5 – Altstände:** R1 rückwirkend über das Defeat-Flag (empfohlen, ohne Migration) oder R2 keine Rückwirkung (v16).
- **E6 – Herkunft:** `found` (Standard von `EquipmentLoot.roll`) oder `quest_reward` (bräuchte Origin-Parameter an `roll` oder
  einen direkten `generate`-Aufruf).
- **E7 – `thundering`:** auf Waffen wirkungslos; hinnehmen oder aus den Waffenpools entfernen (ändert reguläre Drops).
- **E8 – Claim während einer Trial:** sperren (empfohlen, wie M4) oder erlauben.
- **E9 – Meilenstein-Save beim Boss-Kill:** zusätzlich (ändert `GameMap`) oder nicht (Standard; Korrektheit ohnehin gegeben).
- **E10 – Rückmeldung:** eigene Meldung für den direkten Claim; der Loot-Feed zeigt heute die Definitions-Rarity, nicht die
  Instanz-Rarity.
