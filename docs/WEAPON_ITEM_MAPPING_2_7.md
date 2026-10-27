# Weapon Item Mapping 2.7 (Read-only Design Audit)

Stand: `dev/item-foundation-10` (nach `d263919`). Reines Lese-Audit. Es wurden kein Code, keine Itemdaten und keine Tests geändert.
Vorarbeit: `docs/WEAPON_BASE_DAMAGE_CALIBRATION_AUDIT.md` (Pipeline, Angriffsmatrix), `docs/ITEM_FOUNDATION_1_0.md`.

Quellen:
- `data/items/*.tres` (alle Items mit `weapon_family_id`)
- `scripts/rpg/items/item_definition.gd`, `item_instance.gd`, `inventory.gd` (`add_item` setzt das Item-Level)
- `scripts/rpg/crafting/crafting_profile.gd`, `item_stats.gd` (Quality), `data/crafting/evolutions/stormcaller.tres`
- Bezugsquellen: `data/progression/progression_rules.tres`, `data/base/buildings/smithy.tres`,
  `data/professions/recipes/bs_militia_sword.tres`, `data/enemies/*` (Drops), `scripts/world/game_map.gd` (F4/F7), `scenes/arena/test_arena.tscn`

Kennzeichnung: **IST** = in Daten/Code belegt, **VORSCHLAG** = rechnerischer Vorschlag (nichts angewendet), **OFFEN** = Designentscheidung nötig.

---

## A. Item-Inventar (IST)

**15 Spielerwaffen in 9 Familien.** Weitere Treffer für `weapon_family_id` gibt es nur bei `data/enemies/*_attacks.tres` (Gegner, keine Items) und den Familien selbst.

### A.1 Stammdaten
`slot_kind` 10 = One Hand, 11 = Two Hand. Rarity ist **nur ein Feld der Definition** (`ItemDefinition.rarity`). Es gibt keine Rarity pro Instanz und keinen Rarity-Wurf.

| Item-ID | Anzeigename | Familie | Slot | Rarity (Herkunft) | `base_stats` |
|---|---|---|---|---|---|
| `iron_sword` | Iron Sword | one_handed_sword | 1H | Normal (explizit 0) | – |
| `militia_sword` | Militia Sword | one_handed_sword | 1H | Magic (explizit 1) | `physical_damage` +5 |
| `forged_blade` | Forged Blade | one_handed_sword | 1H | Normal (**nicht geschrieben**, Default) | `physical_damage` +6, `poise_damage` +4 |
| `echo_blade` | Echo Blade | one_handed_sword | 1H | Legendary (explizit 4) | `physical_damage` +8 |
| `crushing_oath` | Crushing Oath | one_handed_sword | 1H | Unique (explizit 5) | `physical_damage` +4 |
| `stormcaller_fang` | Stormcaller Fang | one_handed_sword | 1H | Epic (explizit 3) | `physical_damage` +8, `poise_damage` +4 |
| `steel_greatsword` | Steel Greatsword | two_handed_sword | 2H | Normal (explizit 0) | – |
| `forged_greatsword` | Forged Greatsword | two_handed_sword | 2H | Normal (**nicht geschrieben**, Default) | `physical_damage` +10, `poise_damage` +8 |
| `iron_axe` | Iron Axe | axe | 1H | Normal | – |
| `iron_dagger` | Iron Dagger | dagger | 1H | Normal | – |
| `iron_mace` | Iron Mace | mace | 1H | Normal | – |
| `ash_spear` | Ash Spear | spear | 2H | Normal | – |
| `oak_staff` | Oak Staff | staff | 2H | Normal | – |
| `oak_wand` | Oak Wand | wand | 1H | Normal | – |
| `hunting_bow` | Hunting Bow | bow | 2H | Normal | – |

Alle `base_stats` sind `flat`-Werte auf **globalen Charakter-Stats** (Prozentpunkte über `StatResolver`), kein Waffenschaden.

### A.2 Item-Level, Crafting, Quality, Besonderheiten, Bezugsquelle

Item-Level entsteht **nur** in `Inventory.add_item`: `item.item_level = definition.crafting.base_item_level`, falls ein `CraftingProfile` existiert. Sonst bleibt der Instanz-Default `1` (`ItemInstance.item_level`; gespeichert als `"ilvl"` nur wenn ≠ 1).
„fehlt“ bedeutet: **kein definiertes Item-Level**, die Instanz hat technisch 1.

| Item-ID | Item-Level | CraftingProfile / `allowed_operations` | Quality | Einzigartiges | Bezugsquelle |
|---|---|---|---|---|---|
| `iron_sword` | fehlt (Instanz 1) | – | nein | – | **Regulär:** Startausrüstung (`starting_items`); Haven-Smithy-Rezept `forge_iron_sword` (3 Iron Ore + 1 Timber) |
| `militia_sword` | fehlt (Instanz 1) | – | nein | – | **Regulär:** Blacksmithing-Rezept `bs_militia_sword` (Stufe 1, 3 Iron Ingot + 1 Oak Plank). Zusätzlich Pickup in der Test-Arena (Dev) |
| `forged_blade` | **12** (`base_item_level`) | imprint, augment, reforge, essence_insert/extract, socket_open/insert/remove, quality; 4 Affixe, 2 Essenzen, 2 Sockel | ja (max 20, `quality_stats` leer = alle Basiswerte) | – | **Debug Only** (F4-Crafting-Kit, F7) |
| `forged_greatsword` | **12** | wie forged_blade | ja (wie oben) | – | **Debug Only** (F4, F7) |
| `stormcaller_fang` | **15** | evolve, quality, essence_insert/extract; 2 Essenzen; `evolution_id` stormcaller | ja | Evolution (Item-XP): Stufe 2 +6 `physical_damage`, +10 `finisher_power`; Stufe 3 Mutation Storm Charge (Heavy Finisher ×1,3 Schaden/Knockback) oder Steadfast (+40 Armor, Haltung ×1,4); Tag `evolving` | **Debug Only** (F4, F7) |
| `crushing_oath` | **15** | quality, socket_open/insert/remove; 1 Sockel | ja | `ComboModifierEffect` auf `sword_llh_crush`: Reichweite ×1,25, Haltung ×1,5, Schaden ×1,0 | **Debug Only** (F7) |
| `echo_blade` | fehlt (Instanz 1) | – | nein | `EchoShockwaveEffect`: Heavy Finisher → 40 % des Treffers an Gegner im Radius 52, Haltung 10, 0,5 s Cooldown | **Debug Only** (F7) |
| `steel_greatsword` | fehlt (Instanz 1) | – | nein | – | **Regulär:** Startausrüstung |
| `iron_axe`, `iron_dagger`, `iron_mace`, `ash_spear`, `oak_staff`, `oak_wand`, `hunting_bow` | fehlt (Instanz 1) | – | nein | – | **Debug Only** (F7) |

- **Gegner-Drops** (`data/enemies/*`): nur Hollow Essence, Iron Ore und Gold. Es gibt **keine Waffen-Drops und keine Loot-Tabellen**.
- **F7** (`GameMap.give_debug_items`) gibt jedes ausrüstbare Item einmal. **F4** gibt forged_blade, forged_greatsword und stormcaller_fang.
- Für Echo Blade, Crushing Oath und Stormcaller Fang gibt es also **keine reguläre Quelle**.

---

## B. Basisschaden-Vorschläge (VORSCHLAG)

Formel: `B_ref(L) = B1 × (1 + 0,012 × (L − 1))`. Abweichung = `base / B_ref(L) − 1`.
- **Item-Level-Spalte:** **fett** = IST (`base_item_level`), *kursiv* = **Vorschlag**, da das Item-Level fehlt.
- Die Äquivalenz-Werte setzen die Angriffsmultiplikatoren aus Kalibrierungs-Vorschlag A voraus: Quick 1,00 bei Basis = Familien-Quick, also Basis 12 ≙ heutigem Schwertschaden.

### B.1 Gewöhnliche Waffen (eindeutig)

| Item-ID | Familie (Referenz) | Item-Level | B_ref(L) | base_weapon_damage | Abw. | Begründung |
|---|---|---|---|---|---|---|
| `iron_sword` | one_handed_sword | *1* | 12,00 | **12** | 0 % | Startwaffe, Rezept ohne Stufe. Ist die Familienreferenz |
| `steel_greatsword` | two_handed_sword | *1* | 22,00 | **22** | 0 % | Startwaffe, Referenz der Familie |
| `iron_axe` | axe | *1* | 14,00 | **14** | 0 % | einzige Waffe der Familie, „plain“ |
| `iron_dagger` | dagger | *1* | 9,00 | **9** | 0 % | wie oben |
| `iron_mace` | mace | *1* | 15,00 | **15** | 0 % | wie oben |
| `ash_spear` | spear | *1* | 13,00 | **13** | 0 % | wie oben |
| `oak_staff` | staff | *1* | 13,00 | **13** | 0 % | wie oben |
| `oak_wand` | wand | *1* | 10,00 | **10** | 0 % | wie oben |
| `hunting_bow` | bow | *1* | 13,00 | **13** | 0 % | wie oben |
| `militia_sword` | one_handed_sword | *1* | 12,00 | **12,6** | +5,0 % | Rezept auf Blacksmithing-Stufe 1, also kein höheres Level ableitbar. 12 × 1,05 entspricht dem heutigen +5 % `physical_damage` (Gruppe A) |

### B.2 Waffen mit globalem Basisbonus (Varianten)
- **V1 Äquivalenz:** Der globale Bonus entfällt. Basis = `B1 × (1 + pd/100)`, also heutiger Effektivschaden, unabhängig vom Item-Level.
- **V2 Referenz:** Basis = `B_ref(L)`. Der globale Bonus bleibt (Gruppe B/C behalten).
- **V3 Referenz + Bonus:** Basis = `B_ref(L) × (1 + pd/100)`. Der globale Bonus entfällt, die Waffe liegt über der Kurve.

| Item-ID | Item-Level | B_ref(L) | V1 Basis (Abw.) | V2 Basis (Abw.) + global | V3 Basis (Abw.) |
|---|---|---|---|---|---|
| `forged_blade` | **12** | 13,584 | 12,72 (−6,4 %) | 13,58 (0 %) + 6 % | 14,40 (+6,0 %) |
| `forged_greatsword` | **12** | 24,904 | 24,20 (−2,8 %) | 24,90 (0 %) + 10 % | 27,39 (+10,0 %) |
| `stormcaller_fang` | **15** | 14,016 | 12,96 (−7,5 %) | 14,02 (0 %) + 8 % | 15,14 (+8,0 %) |
| `crushing_oath` | **15** | 14,016 | 12,48 (**−11,0 %**, außerhalb Leitlinie) | 14,02 (0 %) + 4 % | 14,58 (+4,0 %) |
| `echo_blade` Var. a | *1* (Instanz-IST) | 12,00 | 12,96 (+8,0 %) | 12,00 (0 %) + 8 % | 12,96 (+8,0 %) |
| `echo_blade` Var. b | *15* (Annahme, analog Stormcaller/Oath; **keine Datenquelle**) | 14,016 | 12,96 (−7,5 %) | 14,02 (0 %) + 8 % | 15,14 (+8,0 %) |

**Empfehlung zur Diskussion (nicht entschieden):**
- **forged_blade / forged_greatsword: V3.** Gruppe A, der Bonus wandert vollständig in die lokale Basis. Beim Greatsword liegt das genau am Rand der Leitlinie (+10 %).
- **Sonderwaffen: V2** bis zur Designentscheidung. Das ändert sie am wenigsten und löscht nichts blind (Regel 12).

**Striking-Spanne zur Einordnung** (rechnerisch, Familienreferenz beim Item-Level, höchster Tier nach `AffixTiers`):

| Item-Level | Höchster Tier | Spanne Einhandschwert | Spanne Zweihandschwert |
|---|---|---|---|
| 1 | T5 | 0,36–0,72 | 0,66–1,32 |
| 12 / 15 | T4 | 0,68–1,22 / 0,70–1,26 | 1,25–2,24 (bei 12) |

Die Affixe Striking und Tempered Blade **existieren noch nicht**. Alle 12 Affixe sind GLOBAL und `tier_model` 3.

---

## C. Spezialwaffen – Zuordnung der globalen Basisboni

Gruppen:
- **A** = gewöhnlicher Basisbonus, wird durch `base_weapon_damage` ersetzt
- **B** = expliziter Gameplay-Effekt, bleibt
- **C** = unklar, Designentscheidung nötig

| Item | Bonus (IST) | Gruppe | Beleg |
|---|---|---|---|
| `forged_blade` | `physical_damage` +6 | **A** | Rarity Normal (Default), keine `effects`, Beschreibung „Craftable weapon base“. Reiner Basiswert eines Crafting-Rohlings |
| `forged_blade` | `poise_damage` +4 | **C** | Kein Schadensbonus. Haltung bleibt laut Regel 14, ist aber heute Quality-Ziel (`quality_stats` leer). Offen: global lassen oder lokal machen |
| `forged_greatsword` | `physical_damage` +10 | **A** | wie forged_blade |
| `forged_greatsword` | `poise_damage` +8 | **C** | wie forged_blade |
| `militia_sword` | `physical_damage` +5 | **A** (vorläufig) | Keine Effekte, kein Profil, Rezeptwaffe. Rarity Magic ist fest in der Definition, nicht gewürfelt. Falls „Magic“ künftig gewürfelte Affixe bedeuten soll → C |
| `stormcaller_fang` | `physical_damage` +8 (Basis) | **C** | Epic, Evolutionswaffe. Der Basiswert ist nicht als Effekt beschrieben, gehört aber zu einem Sonderitem (Regel 12) |
| `stormcaller_fang` | `poise_damage` +4 (Basis) | **C** | wie forged_blade |
| `stormcaller_fang` | Evolution Stufe 2: `physical_damage` +6, `finisher_power` +10 | **B** | `EvolutionStage.modifiers`, als Evolutionsfortschritt beschrieben („Awakened Edge“). Läuft über `ItemStats._evolution_parts` |
| `stormcaller_fang` | Mutation Storm Charge / Steadfast | **B** | `TaggedHitModifierEffect` bzw. Armor + Haltung. Kein Basisbonus |
| `crushing_oath` | `physical_damage` +4 | **C** | Unique. Sein expliziter Effekt (`ComboModifierEffect`, Schaden ×1,0) betrifft **nur** Reichweite/Haltung. Der +4 ist ein separater Basiswert ohne Beschreibung |
| `crushing_oath` | `ComboModifierEffect` | **B** | Effekt `crushing_oath`, verändert keinen Schaden |
| `echo_blade` | `physical_damage` +8 | **C** | Legendary ohne Profil/Quality. Der Effekt (Schockwelle) ist separat. Der +8 ist ein Basiswert eines Sonderitems |
| `echo_blade` | `EchoShockwaveEffect` | **B** | 40 % von `hit.damage`. Skaliert nach dem Umbau automatisch mit der neuen Basis (siehe D.1) |

**Konflikte:**
1. **Kein Konflikt bei den B-Effekten** selbst. Konflikt entsteht bei den **C-Basiswerten** der drei Sonderwaffen: Bleibt der globale Bonus (V2), wirkt er zusätzlich auch auf Skills mit physischem Schaden und auf andere Treffer. Ein lokaler Waffenwert täte das nicht.
2. **Stormcaller Evolution Stufe 2** addiert `physical_damage` global. Das ist ein Muster für „Waffenschaden über einen globalen Stat“. Ob Evolutionsboni künftig lokal sein sollen, ist offen (Regel 12: zunächst behalten).
3. **Quality auf Sonderwaffen:**
   - Stormcaller und Oath skalieren heute ihre globalen Basiswerte mit Quality.
   - Bei V2 würde Quality künftig die lokale Basis **und** den globalen Bonus skalieren, wenn `quality_stats` leer bleibt.
4. **Echo Blade hat kein Item-Level** und keine Quality. Für eine Legendary ist ilvl 1 vermutlich nicht beabsichtigt, aber nicht belegbar.

---

## D. Risiken

### D.1 Doppelte Schadensanwendung
1. **Basisbonus + lokale Basis:**
   - Wird `base_weapon_damage` auf Äquivalenz bemessen (V1/V3) und `physical_damage` bleibt in `base_stats`, zählt der Bonus doppelt.
   - Gruppe-A-Werte müssen im selben Schritt entfernt werden.
2. **Lokale Prozente über `StatResolver`:**
   - `ItemStats.modifiers` gibt **alle** Item-Stats an `StatResolver` weiter. Danach wendet `CharacterStatModifier` × (1 + `physical_damage`/100) an.
   - Lokale Affixe (Tempered Blade, Striking) dürfen nicht zusätzlich als globaler Stat landen.
3. **Quality zweifach:** `ItemStats.modifiers` skaliert heute `base_stats` mit `quality_factor`. Wenn Q zusätzlich in D_weapon wirkt, muss das globale Quality-Scaling für Schadensbasiswerte entfallen bzw. über `quality_stats` gefiltert werden.
4. **Absolut + Multiplikator:**
   - Gegner (Legacy-Baum) nutzen `AttackDefinition.damage` absolut weiter.
   - Ein Feld mit doppelter Bedeutung (absolut für Gegner, Multiplikator für Flow-Waffen) ist fehleranfällig.
   - Getrenntes Feld oder eindeutige Umschaltung in `_make_hit` nötig.
5. **Abgeleitete Effekte** skalieren mit `hit.damage`: Echo-Schockwelle 0,4, `EssenceDischargeEffect` 0,35, `HitTriggerEffect.burst_damage_ratio`. Sie steigen automatisch mit der neuen Basis.
6. **Skills:**
   - `SkillCast.deliver` liefert absolute Werte. Physische Skills nutzen heute globales `physical_damage`.
   - Lokale Waffenprozente dürfen dort nie ankommen (Regel 13).
   - Entfällt ein globaler Bonus (Gruppe A), werden physische Skills **schwächer**. Das ist eine Folgeänderung, die bewusst entschieden werden muss.
7. **Mehrfachtreffer:**
   - Thousand Cuts (3 × 7) und Zauberstab-Forks (2 × 5) teilen den Schaden heute im Generator. Multiplikatoren müssen pro Treffer gelten, nicht als Summe.
   - Krit/On-Hit werden pro Treffer gewürfelt (unverändert).
8. **Counter nach Parade** (`CounterModifier`) bleibt multiplikativ auf dem Treffer. Kein Doppelrisiko, wenn D_weapon vor der Modifier-Liste entsteht.

### D.2 Quality und Local/Global
- `quality_stats` ist bei allen 4 Profilen leer. Damit skaliert Quality heute auch `poise_damage`. Nach dem Umbau: Soll Quality nur die Basis (Q in D_weapon) betreffen?
- Nur 4 Waffen haben Quality. 11 Waffen haben kein `CraftingProfile`. Q = 1 ist bei ihnen fest.
- **LOCAL-Affixe:**
  - `AffixDefinition.scope` LOCAL existiert, ist aber nie im Pool. `ItemDefinition.allows_local_affixes` erlaubt sie für Waffen.
  - Offen: Wird `sharpened` (globales `physical_damage`, nur Waffen-Slots) zu Tempered Blade? Ein neues lokales Affix daneben ergäbe zwei Schadensaffixe.
- **Imprint `blood_steel`** (`physical_damage` global) und **Sockel** (z. B. Garnet) bleiben global, sofern nicht entschieden.
- Stats immer neu über `StatResolver`. D_weapon muss bei Ausrüstungswechsel, Quality- und Crafting-Revision neu aus der Instanz berechnet werden, nie inkrementell.

### D.3 Fehlende Item-Level
- 11 von 15 Waffen haben kein definiertes Item-Level. `Inventory.add_item` kann ein Level **nur** aus `CraftingProfile.base_item_level` setzen.
- Für ilvl ≠ 1 ohne Profil braucht es ein neues Definitionsfeld oder ein Minimalprofil. Ein Minimalprofil würde Crafting-Semantik verändern.
- Item-Level ist dauerhaft (Regel 6). Bekommt eine Definition später ein anderes Level, behalten vorhandene Instanzen ihr gespeichertes bzw. Default-Level 1. Ein Angleichen wäre eine Save-Migration (ausgeschlossen, offen).
- Ist `base_weapon_damage` fest pro Definition, bestimmt das Item-Level nur den Striking-Roll (Tier und Familienreferenz). Ob die Basis künftig mit dem Instanz-Level skaliert (Loot mit variablem ilvl), ist offen.

### D.4 Save v11
- **Keine Formatänderung**, wenn `base_weapon_damage` nur in der Definition steht. Instanzen speichern `ilvl`, `quality` und `affixes`.
- **Quality:** Gespeicherte Stufen bleiben, die Wirkung wechselt von „globaler Bonus × Q“ zu „lokale Basis × Q“. Das ist eine Wertänderung ohne Migration (wie bei Item Foundation 1.0).
- **Striking/Tempered** als gewürfelte Affixe → neue Affixeinträge (`tier_model` 5). Die Fünf-Tier-Werte der bestehenden Affixe fehlen weiterhin. Vorhandene `tier_model: 3`-Einträge bleiben unberührt.
- **`sharpened`-Einträge** auf vorhandenen forged-Instanzen: Wird das Affix lokal, ändert sich die Bedeutung gespeicherter Werte → Versionssprung + Migration (`SaveSystem.VERSION` 11 → 12). Laut Auftrag keine automatische Migration, deshalb offen.

### D.5 Generator
- Familien nur über `tools/generate_weapon_families.gd`:
  - `REF_QUICK` (12) und `REF_HEAVY` (26) skalieren neue Familien absolut.
  - `"fixed"` hält die Werte von one_handed_sword (12/26) und two_handed_sword (22/48).
  - Forks (`roundf(damage / fork)`) und Mehrfachtreffer (`roundf(damage / multi)`) teilen Schaden.
- Für Multiplikatoren muss der Generator die Werte relativ zur Familienbasis (Tabelle oben) schreiben.
- Haltung, Knockback und Hitstop bleiben absolut (Regel 14).
- Rundung: Bei `roundf` entstehen Abweichungen ≤ 0,8 % (siehe Kalibrierungsaudit D).
- Ein Neugenerieren überschreibt alle `data/weapons/*.tres`. Gegner-Angriffe (`data/enemies/*_attacks.tres`) erzeugt der Generator nicht; sie bleiben absolut.

### D.6 Vorhandene gezielte Tests für den Umbau
| Bereich | Suites |
|---|---|
| Angriffsdaten/Flow | `combat_data`, `combat_flow`, `weapon_families`, `combat_flow_player`, `light_attack`, `heavy_attack`, `bow`, `hits`, `mastery`, `defense` (Counter) |
| Waffen-Items | `equipment` (alle 15 Waffen), `weapon_switch` (Familienwechsel), `inventory_ui` |
| Quality/Item-Level | `sockets_quality` (Quality 20, ilvl 12 bleibt), `crafting_save` (ilvl aus Profil, Default 1), `item_foundation`, `affix_pool` (Tiers nach ilvl), `crafting_stats`, `crafting_ops` |
| Sonderwaffen | `item_effects` (Echo Blade, Crushing Oath), `evolution` (Stormcaller), `essences` |
| Save | `save`, `crafting_save`, `save_foundation` (v-Migrationen) |
| Abgrenzung | `skills`, `talents` (Skills bleiben absolut) |

---

## E. Offene Designentscheidungen (OFFEN)
1. **Item-Level ohne CraftingProfile:** Neues Definitionsfeld (z. B. `item_level`) oder Minimalprofil? Bleiben alle Normal-Waffen auf ilvl 1?
2. **Echo Blade Item-Level:** 1 (heutiger Instanzwert) oder ein anderes Level (z. B. 15 analog Stormcaller/Oath, ohne Datenbasis)?
3. **Militia Sword:** Gruppe A (Bonus → Basis 12,6) bestätigen? Was bedeutet Rarity Magic ohne Affixe?
4. **Sonderwaffen-Basiswerte (Gruppe C)** für Stormcaller (+8), Crushing Oath (+4), Echo Blade (+8):
   - V1 Äquivalenz
   - V2 Referenz + globaler Bonus bleibt
   - V3 Referenz + Bonus lokal
5. **`poise_damage`-Basiswerte** (forged_blade, forged_greatsword, stormcaller_fang): global lassen? Weiter Quality-Ziel (`quality_stats`)?
6. **Physische Skills:** Wenn globale Gruppe-A-Boni entfallen, verlieren physische Skills diese Prozente. Ausgleich oder gewollt?
7. **`sharpened` vs. Tempered Blade:** umwandeln (mit Migration) oder parallel? Was passiert mit Imprint (`blood_steel`) und Sockelboni?
8. **Abgeleitete Effekte** (Echo-Schockwelle, Essenzentladung, Burst): Sollen sie mit der neuen Basis mitwachsen? (aus Kalibrierungsaudit E.5)
9. **Basis fest pro Definition oder abhängig vom Instanz-Item-Level** (für künftigen Loot mit variablem ilvl)?
10. **Familienreferenz für Striking:** Ist sie `B_ref(L)` der Familie oder die konkrete Basis der Waffe? Laut Vorgabe die Familienreferenz. Bestätigen, weil die Sonderwaffen von der Kurve abweichen.
