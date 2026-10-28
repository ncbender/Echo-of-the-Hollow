# Grove Warden – Guaranteed Rare Reward 1.0 · R1: Rare-Pool & Eligibility

Branch `dev/grove-warden-rare-r1` von `audit/grove-warden-rare-reward-10` @ `d9f59b6` (= M4 `145fc26` + Audit-Doku).
Grundlage: `docs/GROVE_WARDEN_RARE_REWARD_1_0_AUDIT.md` (§4, §5). Save bleibt **v15**, keine neuen Felder, keine Migration.
Nicht umgesetzt (laut Auftrag): Death-Hook, Anspruch/Claim, Cache/UI, Inventarvergabe, Boss-Saves, Thundering-Bereinigung.
Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.

---

## 1. Phase A – Keen technisch verifiziert

| Frage | Befund (Beleg) |
|---|---|
| 1. Globaler Krit-Bonus? | ja: `keen.tres` `scope` = GLOBAL (Standard), `stat = crit_chance`, flat in Prozentpunkten |
| 2. Wirkt auf Kopf/Brust/Schild? | ja: `ItemStats.modifiers` filtert nur LOCAL-Einträge aus (`scripts/rpg/crafting/item_stats.gd:26-27`). `Character._stat_sources` nimmt jedes Item aus `equipment.equipped_items()` (alle Slots der aktiven Loadout, `scripts/rpg/character.gd:244-247`) → `StatResolver.resolve` → `PlayerProgressionBridge.apply_stats` → `CharacterStatModifier.stats` (`player_progression_bridge.gd:122-125`) |
| 3. Unabhängig von der Waffenfamilie? | ja: `CharacterStatModifier.modify_hit` liest nur `stats[crit_chance]`, keine Familien- oder Slotprüfung (`scripts/rpg/progression/character_stat_modifier.gd:30-33`), gilt auch für Skill-Treffer (`applies_to_skill_hits`) |
| 4. Bestehende Sperren? | **nur** die Slotliste `allowed_slot_kinds = [10, 11, 14, 15]`. Keine Exclusion-Gruppe, keine `required_attack_tags`, keine Stufenvorgabe. `GameDatabase._validate_crafting` verlangt, dass jedes `generation_affixes`-Affix `allows_slot` erfüllt; daher muss die Slotliste erweitert werden |
| 5. Furious + Guarded + Vital + Keen gemeinsam? | ja: vier verschiedene Gruppen (`resource_gain`, `armor`, `max_health`, `crit_chance`), keines hat eine `exclusion_group` |

Ergebnis: **positiv**, kein Blocker. Es gibt keine neuen Effekte und keine Änderung am StatResolver.

## 2. Phase B – Änderungen an den drei Item-Pools

| Datei | vorher | nachher |
|---|---|---|
| `data/crafting/affixes/keen.tres` `allowed_slot_kinds` | `[10, 11, 14, 15]` | `[1, 4, 10, 11, 13, 14, 15]` (+ Kopf, Brust, Schild) |
| `data/items/leather_cap.tres` `generation_affixes` | furious, guarded, vital | furious, guarded, **keen**, vital |
| `data/items/wanderer_coat.tres` | dto. | dto. |
| `data/items/oak_shield.tres` | dto. | dto. |

Unverändert: Keen-Gewicht 100, Tiers/Werte (T5 0,5–1, T4 1–1,5, Schritt 0,1), alle anderen Affixe und Gewichte, Armored
(`rollable = false`, LOCAL, ohne Schild), keine lokale Armor-Basis, keine neuen Affixe.

### Auswirkungen auf reguläre Drops (bewusst)
- Grunt-Tabelle (`leather_cap`, `wanderer_coat`) und Wolf-Tabelle (`oak_shield`) würfeln Keen jetzt mit. Tabellen,
  Dropchancen, Modellgewichte, Rarity- und Tier-Gewichte sind unverändert.
- Identitätsanteil pro Affix bei diesen drei Modellen: vorher je 1/3, jetzt je 1/4 beim ersten Zug. Anteil der Magic-Drops
  dieser Modelle mit Keen: 0,4 · 1/4 + 0,4 · 2/4 + 0,2 · 3/4 = **45 %**. Furious, Guarded und Vital erscheinen entsprechend seltener.
- Rare/Epic/Legendary-Shortfall der Rüstung: vorher max. 3 Affixe, jetzt **4**. Legendary (5) endet weiterhin mit Shortfall 1;
  `test_loot_foundation::test_short_pools_end_with_a_documented_shortfall` wurde von 3/„only 3 of 5“ auf 4/„only 4 of 5“
  angepasst.
- Andere Kopf-/Brust-/Schild-Items (`warden_helm`, `warden_mail` = Set, `warlord_helm`) haben weder `generation_affixes`
  noch ein Crafting-Profil, also ändert sich bei ihnen nichts. **Hinweis:** Der Crafting-Pool (`AffixPool`) nimmt alle
  Affixe nach Slotregel. Ein künftiges crafting-fähiges Rüstungs- oder Schild-Item würde Keen dort anbieten.
- Alte Instanzen: Gespeicherte Affixe werden nie neu gewürfelt. Eine alte Kappe ohne Keen bleibt ohne Keen (getestet).
- Doku nachgezogen: `docs/CRAFTING_DESIGN.md` (Slot-Spalte Keen), `docs/LOOT_FOUNDATION_1_0.md` §Pools,
  `docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md` §Affixe.

## 3. Phase C – Grove-Warden-Quelltabelle

Die vorhandene Struktur trägt die Tabelle **direkt** (`EquipmentLootTable` + `EquipmentLoot.roll`). Es braucht keinen neuen Code
und keinen Sonder-Roller: Die Rare-Anzahl 3/4 = 60/40 kommt aus `ItemCreation.AFFIX_COUNTS[RARE]`, Identität, Tier und Wert
kommen aus `AffixRoller`.

| Datei | Inhalt |
|---|---|
| `data/loot/grove_warden_rare_reward.tres` | `id grove_warden_rare_reward`, `chance 1.0`, zwölf `item_ids` (je einmal → gleiches Gewicht, `randi_range`), `rarity_weights {2 (RARE): 100}`, `source_level 20`, `level_spread 0`, `tier_weights` → eigene Tabelle |
| `data/loot/grove_warden_rare_tiers.tres` | `id grove_warden_rare`, ein Band 20–20 = `{T5: 75, T4: 25}` |

Eine eigene Tier-Tabelle statt `hollowwood_early_tiers` (Band 10–24 liefert bei ilvl 20 ebenfalls 75/25): Damit ändert ein
künftiger Rebalance der regulären Hollowwood-Tabelle den Boss-Reward nicht stillschweigend. Andere Item-Level sind bewusst
nicht konfiguriert (ein Wurf außerhalb von 20 würde abgelehnt).

Die Tabellen sind **nicht** verdrahtet: kein `Enemy.equipment_loot`, kein Death-Hook, keine Pickups. `EquipmentLoot.roll` gibt
Instanzen mit `ORIGIN_FOUND` zurück; die Herkunftsfrage (Audit E6) bleibt für R2 offen.

## 4. Ergebnisse für alle zwölf Modelle (ilvl 20, Rare)

„Pool“ = `generation_affixes`; „sicher ≥ 4“ = erschöpfende Suche über **alle** legalen Zugreihenfolgen
(`_dead_end` in der Test-Suite). Damit ist ein Shortfall bei Rare für kein RNG-Ergebnis möglich.

| Modell | Slot | Pool | sicher ≥ 4 | Rare 3 / 4 erreicht (Seed 4242) | Basis ilvl 20 | Thundering im Pool |
|---|---|---|---|---|---|---|
| iron_sword | 1H | 13 | ja | ja / ja | 14,736 | **ja** |
| steel_greatsword | 2H | 13 | ja | ja / ja | 27,016 | **ja** |
| iron_axe | 1H | 13 | ja | ja / ja | 17,192 | **ja** |
| iron_dagger | 1H | 13 | ja | ja / ja | 11,052 | **ja** |
| iron_mace | 1H | 13 | ja | ja / ja | 18,420 | **ja** |
| ash_spear | 2H | 13 | ja | ja / ja | 15,964 | **ja** |
| oak_staff | 2H | 13 | ja | ja / ja | 15,964 | **ja** |
| oak_wand | 1H | 13 | ja | ja / ja | 12,280 | **ja** |
| hunting_bow | 2H | 12 (ohne executioner) | ja | ja / ja | 15,964 | **ja** |
| leather_cap | Kopf | 4 | ja | ja / ja | – | nein |
| wanderer_coat | Brust | 4 | ja | ja / ja | – | nein |
| oak_shield | Schild | 4 | ja | ja / ja | – | nein |

Für alle zwölf gilt: nur Rarity Rare, ilvl exakt 20, jedes eligible Affix nur T5 (75) / T4 (25), keine Duplikate, keine
Exclusion-Verstöße, keine Essenzen/Sockel, kein Essenz-Slot an den Definitionen, Armored nirgends im Pool.

## 5. Weitere Gameplay-Hinweise für R2 (keine Blocker für R1)
- `oak_shield` kann nur eine Klasse mit `can_use_shields` tragen (heute Warrior, Guardian, Soulbinder; `false` bei
  `basic_adventurer`, `arcanist`, `shadowrunner`). Der Pool ist klassenunabhängig, das gewürfelte Schild ist es nicht.
  Dasselbe gilt für reguläre Wolf-Drops.
- `furious` wirkt erst nach der Klassenwahl (Audit §2). `wanderer_coat` hat die Definitions-Rarity Magic; Verkauf, Salvage und
  Loot-Feed lesen die Definitions-Rarity (Audit §4.2, offener Punkt der Loot Foundation).

## 6. Phase D – Thundering: offener Gameplay-Eligibility-Blocker

**Befund (Code + Test):**
- `shock_damage` wird nur von `EssenceDischargeEffect` gelesen (`scripts/rpg/effects/essence_discharge_effect.gd:37`, einziger
  Treffer für `SHOCK_DAMAGE` außerhalb von `stats.gd`). Daneben liefert `storm_ore` den Stat als Material-Imprint, aber keine
  Wirkung.
- `EssenceDischargeEffect` gibt es nur in der Essenz `data/crafting/essences/storm_wolf.tres`. Sie wird außerdem nur bei
  einem Treffer mit `heavy` + `finisher` ausgelöst.
- Essenzen sind nur auf Items mit `essence_slots` aktiv (`ItemStats.active_essences`): `forged_blade`, `forged_greatsword`,
  `stormcaller_fang`. Keines davon hat `generation_affixes` (Thundering kommt dort nur über Crafting).
- `thundering` ist auf die Slots 10/11 beschränkt, und es gibt genau einen Waffen-Slot.
  → Auf den neun Reward-Waffen kann Thundering **nie** eine Wirkung haben. Auf Rüstung, Schild, Ring und Hals kann es nicht rollen.
- Test `test_thundering_rolls_on_all_nine_weapons_without_a_shock_source` prüft: eligible bei ilvl 20 auf allen neun Waffen;
  `ItemStats.effects` einer solchen Waffe enthält keinen `EssenceDischargeEffect`; die Reward-Tabelle würfelt Thundering mit
  festem Seed tatsächlich. Der Test bleibt grün, solange der Befund besteht. Er **verschleiert ihn nicht**, sondern belegt ihn.

**Häufigkeit (exakt berechnet, Gewichte 100/90/80/30, Exclusions):** Rare-Waffe mit 13er-Pool 8,6 % (3 Affixe 7,6 %,
4 Affixe 10,1 %), `hunting_bow` 9,3 %. Über den ganzen Zwölfer-Pool hat **≈ 6,5 % aller Grove-Warden-Rares** ein
wirkungsloses Affix. Für reguläre Magic-Waffendrops gilt der Befund heute schon.

**Nicht geändert:** globale Eligibility, Name, Gewicht, Pools der Waffen. Der Pool ist damit **nicht vollständig
wirkungssicher**.

Lösungsoptionen für den freizugebenden Folgemeilenstein:

| # | Option | Wirkung |
|---|---|---|
| T1 | `thundering` aus den `generation_affixes` der neun Waffen entfernen | kleinste Datenänderung. Ändert reguläre Drops; Crafting auf Essenz-Waffen bleibt |
| T2 | `required_essence_slots` o. ä. als Eligibility-Regel in `AffixRoller` (analog `required_attack_tags`) | regelbasiert, greift auch im Crafting. Neue Eligibility-Regel, Code + Tests |
| T3 | eigene Shock-Quelle ohne Essenz (z. B. Waffeneffekt) | neue Gameplay-Wirkung, Balance-Freigabe nötig |
| T4 | hinnehmen und dokumentieren (Status quo) | keine Änderung. Widerspricht „keine wirkungslosen Affixe“ |

## 7. Tests (Efficient Testing 1.1)

Ausgeführt mit `./tools/run_tests.ps1 -Suite "…"`:

| Suite | Ergebnis |
|---|---|
| `grove_warden_rare_pool` (neu, 15 Tests) | **15/15 grün** |
| `loot_foundation` | 16/16 grün (Shortfall-Test bewusst angepasst) |
| `hollowwood_loot` | 10/10 grün |
| `affix_pool` | 8/8 grün |
| `item_foundation` (inkl. `test_real_data_validates`) | 13/13 grün |

Abdeckung der Auftragspunkte 1–20 in `tests/unit/test_grove_warden_rare_pool.gd`:

| Punkte | Test |
|---|---|
| 1–5 | `test_reward_table_holds_the_approved_parameters`, `test_rolls_are_rare_level_20_and_spread_evenly`, `test_every_eligible_affix_draws_only_t5_and_t4_at_75_25` |
| 6–10 | `test_every_eligible_affix_…`, `test_every_model_reaches_three_and_four_without_shortfall` (erschöpfende Suche), `test_armour_pool_is_exactly_the_four_global_affixes`, `test_rolls_have_no_duplicates_exclusions_or_essences` |
| 11–13 | `test_keen_works_on_cap_coat_and_shield_independent_of_the_weapon` (Stat-Delta = gewürfelter Wert, gleich mit anderer Waffenfamilie), `test_keen_on_armour_reaches_the_hit_through_the_stat_modifier` (synthetisch 100 % → jeder Treffer krit über `CharacterStatModifier`) |
| 14 | `test_other_global_affixes_keep_their_effect` |
| 15 | `test_armored_stays_disabled` |
| 16 | `test_weapon_base_damage_formula_unchanged` |
| 17 | `test_grunt_and_wolf_tables_unchanged` |
| 18 | `test_regular_armour_drops_can_now_roll_keen` |
| 19 | `test_old_instances_stay_unchanged` |
| 20 | `test_thundering_rolls_on_all_nine_weapons_without_a_shock_source` |

Nicht ausgeführt: Full-Suite, Prolog-/Haven-/Crafting-Loops, Arena, Galerie, echte Saves. Bekannter Altfehler
`test_migration_v3_to_v4` (veraltetes Rarity-Fixture) liegt in der nicht ausgeführten `save`-Suite und wurde nicht angefasst.
Neue Regressionen in den ausgeführten Suites: keine.

## 8. Verbleibende R2-Blocker / Entscheidungen
1. **Thundering** (§6): offener Gameplay-Eligibility-Blocker. Folgemeilenstein T1–T4.
2. Audit E3–E10 unverändert offen: Erzeugungszeitpunkt (Empfehlung: beim Claim), Claim-Ort, Altstände (R1 abgeleitet /
   R2 v16), Herkunft `found` vs. `quest_reward`, Claim in Trials, Meilenstein-Save, Rückmeldung und Loot-Feed.
3. `EquipmentLoot.roll` gibt den Shortfall nicht weiter. Für diesen Pool ist er bewiesen unmöglich (§4). Bei künftigen
   Pool-Änderungen muss der Test `test_every_model_reaches_three_and_four_without_shortfall` mitgeprüft werden.
4. Shield-Klassenbindung und Definitions-Rarity des Mantels (§5): Designhinweis, kein technischer Blocker.
