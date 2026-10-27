# Loot & Equipment 2.5 – technisches Vorbereitungs-Audit

Stand: Branch `dev/loot-equipment-25-audit` (Basis `07ff96c`). Reines Lese-Audit – **kein Code, keine Daten geändert**.
Keine Designentscheidungen; offene Punkte stehen in §7.

## 1. Ist-Zustand

### 1.1 Equipment-Slots und Item-Basis
- **Slots** (`scripts/rpg/equipment/equip_slot.gd`): 15 Ausrüstungsplätze – Head, Shoulders, Back, Chest, Wrists, Hands, Belt, Legs, Feet, Main Hand, Off Hand, Ring 1, Ring 2, Neck, Trinket.
  - Genau **ein** Waffen-Slot; die Off Hand nimmt nur Schild bzw. Off-Hand-Items auf (Weapon Mastery 1.4).
  - `SlotKind` (`scripts/rpg/items/item_definition.gd`): HEAD … TRINKET, ONE_HAND_WEAPON, TWO_HAND_WEAPON, OFF_HAND, SHIELD, RING, NECK.
- **Item-Definition** (`ItemDefinition`, `data/items/*.tres`, 69 Dateien):
  - Allgemein: `category`, `rarity` (**pro Definition**, nicht pro Instanz), `max_stack`, `slot_kind`, `armor_type`, `weapon_family_id`.
  - Werte und Wirkung: `base_stats: Array[StatModifier]`, `effects: Array[ItemEffect]`, `set_id`, `defense_profile`.
  - Wirtschaft und Crafting: `base_value`, `special_sell_value`, `crafting: CraftingProfile`.
- **Basiswerte:**
  - Waffen haben **keine** Basis-Schadenswerte. Der Schaden kommt aus `AttackDefinition` (`data/weapons/*.tres`); Item-Stats sind globale Charakterstats (z. B. `physical_damage` %).
  - 9 von 15 Waffen-Items haben `base_stats = 0` (iron_sword, steel_greatsword, die 7 neuen Familien-Items, …).
  - Rüstungen tragen meist 1 Stat (`armor`, `max_health`).
- **Waffenfamilien** (`data/weapons/`, 9): one_handed_sword, two_handed_sword, axe, dagger, spear, staff, wand, mace, bow.
  - Items je Familie: Schwert 6 (iron_sword, militia_sword, forged_blade, echo_blade, crushing_oath, stormcaller_fang); Zweihänder 2 (steel_greatsword, forged_greatsword); die übrigen sieben je 1 schlichtes Item.
- **Rüstungsfamilien** (`ItemDefinition.ArmorType`): CLOTH, LEATHER, MAIL, PLATE.
  - Zugeordnet: leather_cap, leather_gloves, worn_boots (Leather); linen_trousers (Cloth); warden_helm, warden_mail, warden_greaves (Mail).
  - **Plate hat kein Item.** Die übrigen Rüstungen haben keinen Typ.
- **Rarity** (`ItemDefinition.Rarity`): NORMAL, MAGIC, RARE, EPIC, LEGENDARY, UNIQUE, SET mit Farben.
  - Sie ist fest pro Definition (z. B. militia_sword = Magic) und bestimmt **nicht** die Zahl der Affixe.
- **Item-Level** (`ItemInstance.item_level`, Save `ilvl`): wird nur beim Hinzufügen gesetzt, wenn ein `CraftingProfile.base_item_level` existiert (`scripts/rpg/items/inventory.gd:108`). Sonst gilt 1.
  - Es gibt keine Quelle aus Gebiet, Gegner oder Charakterlevel.

### 1.2 Affixe (`scripts/rpg/crafting/affix_definition.gd`, `affix_tier.gd`, `affix_pool.gd`, `data/crafting/affixes/`)
- **12 Affixe:** bloodthirsty, cruel, crushing, executioner, furious, guarded, impactful, keen, sharpened, swift, thundering, vital.
- **Felder:** `stat`, `value_kind` (FLAT/PERCENT), `tags`, `group` (eine pro Item), `exclusion_group`, `allowed_slot_kinds`, `min_item_level`, `weight`, `tiers`.
  - Alle 12 sind FLAT; die meisten sind auf Waffen beschränkt.
- **Tiers:** je **3** pro Affix, Tier 1 ist das stärkste.
  - Beispiel sharpened: T3 ab ilvl 1 = 4–7, T2 ab ilvl 10 = 8–12, T1 ab ilvl 20 = 13–18.
  - Gewürfelt werden **ganze Zahlen** innerhalb des Tiers.
- **Pool** (`AffixPool.compute`):
  - Gewichtung = Affixgewicht × Tieranteil × Material-Tag-Multiplikator × Focus.
  - Vorschau und Wurf nutzen dieselbe Liste; die Reihenfolge ist deterministisch.
- **Gespeicherter Eintrag:** `{"affix", "tier", "stat", "flat", "percent"}` am `ItemInstance.affixes`. Einträge ohne `affix` sind Legacy-Würfe (wirken, sind aber nicht reforgebar).
- **Berechnung:**
  - `ItemStats.modifiers` (`scripts/rpg/crafting/item_stats.gd`) wandelt Basiswerte (mit Quality), Affixe, Imprint-Material, Sockel und Evolution in `StatModifier` um.
  - `StatResolver` rechnet `Σflat · (1 + Σpercent/100)` **charakterweit**.
- **Local/Global:** **nicht unterstützt.** Alle Affixe sind global. Ein „lokaler“ Modifier, der nur den Basiswert des Items ändert, fehlt im Datenmodell und in der Berechnung. Waffen haben ohnehin keinen Item-Basisschaden.

### 1.3 Quality, Upgrade-Zähler, Herkunft, Schutz
- **Quality** (`ItemInstance.quality`, Save `quality`):
  - 0 bis `CraftingProfile.max_quality` (Standard 20).
  - **+1 % pro Stufe** (`ItemStats.QUALITY_PERCENT_PER_POINT := 1.0`) auf `base_stats`, optional gefiltert über `quality_stats`.
  - Operation `quality` (Forge Crystal) hebt um +1 an.
- **Upgrade-Zähler:**
  - Es gibt keinen Zähler je Upgrade-Art.
  - Vorhanden ist `ItemInstance.revision`: steigt bei jeder Crafting-Änderung und verhindert, dass eine veraltete Vorschau doppelt angewendet wird.
  - `progress` ist ein frei belegbares Dictionary.
- **Herkunft:** `ItemInstance.origin` mit found, crafted, quest_reward, starting, unknown_legacy (`scripts/rpg/items/item_instance.gd`); wird beim Entstehen gesetzt.
- **Schutz** (`scripts/rpg/items/item_protection.gd`):
  - Favorit und Sperre nur auf Einzelitems.
  - `destroy_block` blockiert: Questitems, Unique/Set (außer explizit erlaubt), Ausgerüstetes, in Presets Referenziertes, Gesperrtes, Favoriten.

### 1.4 Unique, Set, Essence, Forge
- **Unique/Legendary:**
  - crushing_oath (Unique, `ComboModifierEffect` auf `sword_llh_crush`, Profil nur quality und Sockets).
  - echo_blade (Legendary, Schockwelle).
  - stormcaller_fang (Rare, Evolution).
- **Set:** `data/sets/hollow_warden.tres` (3 Teile Mail; 2er-Bonus +20 HP; 3er-Bonus Schaden/Haltung und Heil-Effekt), `scripts/rpg/items/set_definition.gd`, `set_bonus.gd`.
- **Essenzen:** `data/crafting/essences/` (stone_golem, storm_wolf), Resonanz `thunder_quake`; max. 2 Slots.
- **Sockel:** garnet (Gem), impact_rune (Rune); max. 4 Slots pro Profil.
- **Materialien (Imprint):** blood_steel, frost_glass, storm_ore (`data/crafting/materials/`) mit Imprint-Modifiern und Tag-Gewichtung.
- **Resonance Forge** (`scripts/rpg/crafting/crafting_service.gd`, UI `scripts/ui/crafting_panel.gd` „Resonance Forge 2.0 (Old Smithy)“):
  - Operationen imprint, augment, reforge, essence_insert/extract, socket_open/insert/remove, quality, evolve (`scripts/rpg/crafting/crafting_ops.gd`, Kosten in `data/crafting/operations/*.tres`).
  - **Reforge ersetzt das vom Spieler gewählte Affix** (`_check_reforge`: „Choose the affix to reforge.“).
  - Augment füllt einen freien Platz.
- **Craftbare Basen mit Profil:**
  - forged_blade und forged_greatsword: `affix_slots = 4`, 2 Essenzen, 2 Sockel, `base_item_level = 12`.
  - stormcaller_fang: Evolution.
  - crushing_oath: Quality und 1 Sockel.
  - **Keine Rüstung und kein Schmuck hat ein Crafting-Profil.**

## 2. Wiederverwendbare Strukturen

| Struktur | Datei | Wiederverwendung für 2.5 |
|---|---|---|
| Transaktion mit Vorschau | `CraftingService.preview/execute`, `CraftingPreview`, `CraftingRequest` (Revision) | Reforge, Refine, Elevate und Quality als Operationen: Vorschau = Ausführung, Ablehnung ohne Kosten, Doppelklick-Schutz |
| Affix-Pool | `AffixPool.compute` (inkl. `replace_index`) | Reforge-Neuwurf eines Platzes; Gruppen- und Exklusionsregeln |
| Affix-Tiers | `AffixDefinition.get_tier/tiers_for_level`, `AffixTier` | Refine (Wert im Tier), Elevate (Tierwechsel) – Tierzahl siehe §3 |
| Operationsdaten | `CraftingOperationDefinition` (`costs`, `focus_costs`) | Kosten neuer Operationen als Daten |
| Material-Plan Tasche+Lager | `ProfessionService.material_plan` / `uses_stash` | Kosten an Berufs-Werkbänken inkl. Lager (nach Old-Storehouse-Restaurierung) |
| Berufe/Werkbänke | `ProfessionService`, `Character.professions`, Ruinen mit `profession_id` | „passende Berufswerkbank“ und Berufsfortschritt für garantierte Crafting-Affixe |
| Schutz | `ItemProtection.destroy_block`, Favorit/Sperre | Schutz vor riskanten Operationen (falls gewünscht) |
| Herkunft | `ItemInstance.origin` | Unterscheidung gefunden/gecraftet für Crafting-Affixe |
| Werteberechnung | `ItemStats.modifiers` (eine Stelle), `StatResolver` | Quality-Faktor und lokale Modifier zentral einbauen |
| Verkauf | `EconomyService` (`base_value × rarity_sell_factors`, Schutz, atomar) | Preise, sobald Basiswerte entschieden sind |
| Salvage | `SalvageService` (Werkbank des Rezepts, atomar, Rollback) | Rückgewinnung aus aufgewerteten Items |
| UI | `CraftingPanel` (Auswahl, Vorher/Nachher, Kosten Have/Need, echte Chancen, Bestätigen), `UiConfirmDialog`, `ProfessionsPanel` (Werkbank-Seiten inkl. Salvage-Seite mit Auswahl + Bestätigung), `ItemDescriber`, `ItemTooltip`, `UiWindow.footer` | Upgrade-Seite an der Werkbank im Muster der Salvage-Seite; Vorschau- und Kostenkarten aus dem Forge-Panel |
| Item-Felder | `ItemInstance.progress`, `revision` | Zwischenablage, falls kein Schemawechsel gewünscht |

## 3. Fehlende Voraussetzungen und Konflikte mit den besprochenen Regeln

| Besprochen | Ist | Fehlt / Konflikt |
|---|---|---|
| Reforge: **zufälliger** regulärer Affixplatz, vollständiger Neuwurf | Spieler wählt den Platz | Zufallsauswahl des Platzes; Kennzeichnung „regulär“ vs. „Crafting-Affix“ |
| Refine: gewählten Affixwert im Tier verbessern | – | Operation; Regel „verbessern“ (um wie viel?); ganzzahlige Werte begrenzen die Schritte (T3 sharpened 4–7 = 4 Werte) |
| Elevate: ein Tier höher mit 75/60/40/20 % | **3 Tiers** pro Affix | Vier Erfolgsquoten setzen **5 Tiers** voraus; der Wert beim Tierwechsel (neu würfeln, Position halten?) ist offen; die ilvl-Grenze pro Tier besteht |
| Quality 0–20, **+0,5 %**/Stufe auf geeignete Basiswerte | 0–20, **+1 %**/Stufe auf `base_stats` (gefiltert über `quality_stats`) | Faktor ändern (wirkt auf bestehende Items); „geeignete“ Basiswerte definieren; Waffen ohne Basiswerte profitieren nicht |
| Max. **5** reguläre Affixe; Local und Global teilen sie | `affix_slots` 0–6 pro Profil, nur global | Obergrenze 5; Local-Modifier-Typ (Datenfeld, Berechnung nur auf den Item-Basiswert), Waffen-Basiswerte als Ziel |
| Bis zu 2 garantierte Crafting-Affixe je Berufsfortschritt | – | Kennzeichnung im Affix-Eintrag; Regeln je Beruf und Rang; Zählt das zu den 5 Plätzen? |
| Verbesserungen an der passenden Berufswerkbank, nicht an der Forge | Alle Operationen an der Resonance Forge (Old Smithy); Kosten nur aus der Tasche | Werkbank-Zuordnung je Item-Art (Waffen → Schmied? Leder → Tanner? …); Lagerverbrauch wie bei Rezepten |
| Rarity bestimmt Affixe/Loot | Rarity pro Definition fest | Rarity pro Instanz (Save-Feld) und Zuordnung Rarity → Affixzahl |
| Loot-Equipment | keine Loot-Tabellen, keine Zufallsdrops | Loot-Pools, Dropchancen, Item-Level-Quelle |
| Profile für Rüstung/Schmuck | nur 4 Waffen-Items mit Profil | Profile (Slots, Quality-Stats) für alle zu verbessernden Basen |
| Affixe für Rüstung/Schmuck | 2 von 12 auf Rüstung (guarded, vital), keen auf Ring/Hals | Affix-Abdeckung je Slot |

## 4. Materialien und Gold

### 4.1 Materialien – tatsächlich erhältlich
| Material | Quelle(n) |
|---|---|
| timber | Woodcutting (oak_tree 3, old_oak 5), Pickup Old Road (2) |
| stone | Mining forest_rock (3) |
| iron_ore | Mining (iron_vein 2, rich_iron_vein 3, ancient_deposit 3 einmalig), Drops Grunt (2) und Grove Warden (2, einmalig) |
| flax_fiber | Herbalism wild_flax (2) |
| duskleaf | Herbalism duskleaf_patch (1), duskleaf_cluster (2) |
| raw_hide | Skinning stag_remains (2), elk_remains (3) |
| hollow_essence | Drops Grunt, Hardened Husk, Grove Warden; Pickup Whispering Stone |
| iron_ingot, oak_plank, cured_leather, linen_cloth | Rezepte (Schmelzen, Sägen, Gerben, Weben) |
| supply_crate | 2 Pickups Old Road (Kosten der Old Smithy) |
| gold_coin | siehe 4.3 |
| pattern_leather_bracers | Pickup Whisper Forest (Rezept-Item) |

### 4.2 Nur definiert (keine reguläre Quelle; nur Debug-Kits in `scripts/world/game_map.gd`)
- **Crafting-Währungen:** imprint_shard, focus_catalyst, transmute_core, forge_crystal, socket_chisel, essence_siphon, awakening_stone.
- **Materialien und Sockelsteine:** blood_steel_ingot, storm_ore, frost_glass (Imprint); garnet, impact_rune.
- **Essenzen:** storm_wolf_essence, stone_golem_essence.
- **Craftbare Basen:** forged_blade, forged_greatsword, stormcaller_fang.
- **Ausrüstung ohne Quelle:**
  - echo_blade, crushing_oath, warlord_helm, silver_ring, bone_amulet, hollow_charm.
  - Warden-Set; die Drops von Grove Warden umfassen es nicht.
  - Die 7 neuen Familienwaffen.
  - copper_ring, militia_sword und oak_shield gibt es nur in der Arena (dev) bzw. per Rezept (militia_sword, oak_shield).
- **Startausrüstung** (`data/progression/progression_rules.tres`): iron_sword, steel_greatsword, leather_cap, wanderer_coat, 3 minor_potion.

### 4.3 Berufe, Werkbänke, Rezepte, Gold
- **9 Berufe:**
  - Sammeln: Mining, Herbalism, Woodcutting, Skinning.
  - Herstellen: Blacksmithing, Leatherworking, Tailoring, Woodworking, Alchemy.
- **5 Werkstätten (Haven-Ruinen):** Old Smithy (Blacksmithing, zugleich Resonance Forge), Tanner's Lodge, Weaver's House, Woodwright's Workshop, Alchemist's Cottage.
- **Rezepte** (`data/professions/recipes/`, 19; davon 2 nicht herstellbar):
  - Verarbeitung: iron_ore 3 → iron_ingot; timber 2 → oak_plank; raw_hide 2 → cured_leather; flax 3 → linen_cloth.
  - Ausrüstung: militia_sword (3 Ingot + 1 Plank); oak_shield (4 Plank + 1 Leder); Lederhandschuhe, -stiefel und -armschienen; Leinenhose, Mantel, Seilgürtel, Reiseumhang.
  - Tränke: 4 Alchemie-Tränke.
- **Material-Verbrauch:** Tasche zuerst, dann Haven-Lager, aber nur an Haven-Werkbänken und nur nach Restaurierung des Old Storehouse (`ProfessionService.uses_stash`). Restaurierungen nutzen denselben Plan. **Die Resonance Forge zieht nur aus der Tasche.**
- **Goldquellen:**
  - Drops: Grunt 3, Hardened Husk 4, Rootbound Husk 2, Hollowfang Wolf 1, Grove Warden 25 (einmalig, persistent).
  - Pickup Old Road 12.
  - Kein Quest-, Truhen- oder Verkaufsgold; es gibt keinen Händler (die Trading-House-Ruine ist ohne Funktion).
- **Gold-Sinks:**
  - Flask-Upgrades bei Mara (gesamt 8950, vorläufig, `progression_rules.tres`).
  - Talent-Respec (10 + 2/Level, erster gratis, `data/progression/talent_rules.tres`).
  - Klassen-Freischaltquests (je 20 Gold + 3 Hollow Essence, `data/quests/unlock_*.tres`).
- **Verkaufswerte:**
  - `EconomyService` steht (Basiswert × Rarity-Faktor 1,0/1,6/2,5/4,0/7,0; Unique/Set nur mit eigenem Wert).
  - **Kein Item hat `base_value`, nichts ist verkaufbar.**
- **Drops:**
  - `EnemyConfig.drops: Array[ItemCost]` werden beim Tod **garantiert und fest** gespawnt (`scripts/world/game_map.gd:_spawn_drops`).
  - Keine Chancen, keine Loot-Pools, keine Rarity- oder Affixwürfe.

## 5. Save- und Migrationsrisiken (aktuell Version 10)

1. **Rarity pro Instanz:** neues Feld. Alte Items brauchen einen Default (die Definitionsrarity). Das ist eine Schemaänderung mit Migration (nicht raten, `ORIGIN_LEGACY`-Muster).
2. **Tier-Nummern:** Gespeicherte Affixe tragen `tier` (1 = stärkste). Kommen Tiers hinzu (z. B. 5 für Elevate) oder werden sie umnummeriert, ändern alte Einträge stillschweigend ihre Bedeutung. Dafür braucht es eine Tier-Migration oder eine stabile Tier-ID.
3. **Quality-Faktor 1 % → 0,5 %:** Bestehende Items mit Quality verlieren Werte. Entweder bewusst akzeptieren oder die alte Stufe umrechnen.
4. **Affixplätze:** Wird `affix_slots` auf max. 5 gesenkt oder ein Crafting-Affix-Platz eingeführt, können Items bereits mehr Affixe haben.
   - Regel nötig, z. B. „überzählige behalten, kein Neuwurf“.
   - `progress` kann nicht Anwendbares aufbewahren (`ItemInstance.progress`).
5. **Neue Affix-Felder** (lokal/global, regulär/crafting, gesichert): Alte Einträge haben sie nicht. Defaults müssen festgelegt sein; Legacy-Einträge ohne `affix` existieren schon.
6. **Reforge-Semantik:** Gespeicherte Vorschauen gibt es nicht; die `revision`-Prüfung bleibt gültig. Kein Save-Risiko, aber ein Verhaltenswechsel.
7. **Ort der Upgrades:** Bleiben Forge-Operationen neben den Werkbänken bestehen, gibt es doppelte Wege für dieselbe Änderung. Ein Entfernen braucht keine Migration, aber eine Entscheidung (§7).
8. **Loot-Items:** Neue Zufalls-Items erzeugen pro Instanz Affixe und ilvl. Das Speichermodell (`ItemInstance.to_dict`) kann das schon; nur die neuen Felder aus 1.–5. fehlen.

## 6. Empfohlene sichere Reihenfolge

1. **Entscheidungen aus §7 festhalten** (Spezifikation), bevor Code entsteht.
2. **Daten- und Schemafundament** in einem Schritt mit Migration und `save`-Tests:
   - Rarity pro Instanz, Affix-Felder (regulär/crafting, lokal/global), stabile Tier-Kennung bzw. Tier-Migration, Quality-Faktor-Regel.
   - Noch ohne neue Spiellogik.
3. **Berechnung:** Lokale Modifier in `ItemStats.modifiers` (eine Stelle); Waffen- und Rüstungs-Basiswerte, falls lokal gewünscht. Tests: Stats unverändert für alte Items.
4. **Operationen in `CraftingService`** (Transaktion, Vorschau = Ausführung, Revision): Reforge (zufälliger Platz), Refine, Elevate (Erfolgsquote als Daten), Quality. Jeweils mit gezielten Tests (Ablehnung kostet nichts, Doppelklick).
5. **Werkbank-Integration:**
   - Zuordnung Item-Art → Beruf/Werkbank; Kosten über `ProfessionService.material_plan` (Tasche + Lager).
   - Upgrade-Seite im `ProfessionsPanel` nach dem Muster der Salvage-Seite.
   - Danach Forge-Operationen entsprechend der Entscheidung zurückbauen.
6. **Crafting-Affixe** nach Berufsfortschritt (an Rezept bzw. Herstellung gebunden).
7. **Materialquellen und Kosten** (Balancing-Werte) – erst nach Freigabe.
8. **Loot:** Pools, Rarity- und Affixwürfe, ilvl-Quelle, Drops.
9. **Wirtschaft:** Basiswerte, Händler (Trading House?), Gold-Sinks – zuletzt, mit `EconomySimulation`.

## 7. Vor der Implementierung zu entscheiden

1. **Elevate:** Wie viele Tiers soll es geben – fünf, damit 75/60/40/20 % passen, oder Quoten für drei Tiers? Was passiert mit dem Wert beim Aufstieg (neu würfeln im neuen Tier, relative Position halten, Minimum)? Gilt die ilvl-Grenze je Tier weiter?
2. **Refine:** Um wie viel verbessert sich der Wert – +1, ein Anteil der Spanne oder bis zum Maximum? Werte weiter ganzzahlig?
3. **Reforge:** Wird ein Crafting-Affix nie getroffen? Gibt es Focus-Kosten weiter?
4. **Quality:** Was zählt als „geeigneter“ Basiswert (nur `armor`/`max_health`? Waffen ohne Basiswert)? Werden bestehende Quality-Werte umgerechnet oder neu interpretiert (+1 % → +0,5 %)?
5. **Local vs. Global:**
   - Welche Affixe sind lokal?
   - Bekommen Waffen einen Item-Basisschaden, der mit den Angriffsdaten (AttackDefinition) zusammenspielt?
6. **Plätze:** Zählen die bis zu zwei Crafting-Affixe zu den fünf regulären Plätzen oder kommen sie dazu? Welcher Berufsrang schaltet den ersten bzw. zweiten frei?
7. **Werkbänke:**
   - Welche Werkbank verbessert welche Item-Art (Schmuck, Trinket, Schild)?
   - Bleibt die Resonance Forge für Imprint, Essenzen, Sockel und Evolution?
   - Werden Augment und Reforge dort entfernt?
8. **Rarity:**
   - Wird Rarity pro Instanz gewürfelt?
   - Wie viele Affixe pro Rarity?
   - Bleiben Unique/Set/Legendary fest?
9. **Kosten und Ressourcen:**
   - Welche Materialien und Währungen kosten Reforge, Refine, Elevate und Quality?
   - Sollen die heute nur per Debug erhältlichen Crafting-Währungen eine Quelle bekommen oder ersetzt werden?
10. **Schutz:** Sollen Sperre oder Favorit riskante Upgrades (Elevate-Fehlschlag, Reforge) verhindern oder nur Zerstörung und Verkauf?
11. **Alte Items:**
    - Überzählige Affixe bei weniger Plätzen?
    - Wie werden Legacy-Affixe (ohne `affix`) behandelt?
    - Bekommen Profile für bisherige Items einen Default?
12. **Item-Level:** Woher kommt es künftig (Gebiet, Gegner, Rezeptstufe)?
