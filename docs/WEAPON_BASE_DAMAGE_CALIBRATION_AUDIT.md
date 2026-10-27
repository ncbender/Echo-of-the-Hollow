# Weapon Base Damage Calibration Audit (Loot & Equipment 2.7)

Stand: `dev/item-foundation-10` (nach `916398a`). Reines Lese-Audit. Es wurden kein Code, keine Daten und keine Tests geändert.
Quellen:
- `scripts/combat/combat_component.gd` (`_make_hit`, `_fire_projectiles`, Flowing Draw)
- `data/weapons/*.tres`, erzeugt von `tools/generate_weapon_families.gd`
- `data/items/*.tres`
- `CharacterStatModifier` und die übrigen `AttackModifier`

Alle Zahlen sind **absolute HP-Werte aus `AttackDefinition.damage`**, also vor jedem Multiplikator.
- `*` = Godot-Default 10.0: Der Wert ist in der Datei nicht geschrieben, gilt aber.
- Der Generator kennzeichnet Schaden und Haltungsschaden ausdrücklich als **Platzhalter** („PLACEHOLDERS, not designed yet“).
- Referenz des Generators ist das Einhandschwert mit Quick 12 / 550 ms und Heavy 26 / 850 ms. Neue Familien sind auf gleichen Schaden pro Sekunde skaliert.

## A. Attack-Damage-Matrix

### A.1 Nahkampf- und Zauberfamilien (Combo-Pfadbaum L/H, je 14 Knoten)
Rollen (`flow_role`): 0 = Base Quick, 1 = Base Heavy, 2 = Combo Step, 3 = Quick Finisher, 4 = Heavy Finisher.

| family_id | Quick-Knoten: L (0), LL, HL (2), LLL, HLL, LHL, HHL (3) | Heavy-Knoten: H (1), HH, LH (2), LLH, LHH, HLH, HHH (4) | Haltungsschaden Q / H | Ausnahmen (nicht zusammengefasst) |
|---|---|---|---|---|
| `one_handed_sword` | **12** (sword_light_1/2/3, …) | **26** (sword_heavy, sword_lh_thrust, sword_llh_crush, …) | 8 / 30 | – |
| `two_handed_sword` | **22** (greatsword_light_1/2/3, …) | **48** (greatsword_heavy, greatsword_lh_overhead, greatsword_llh_whirl, …) | 16 / 50 | – |
| `axe` | **14** | **32** | 10* / 37 | – |
| `dagger` | **9** | **21** | 6 / 24 | **`dagger_hhh` (Thousand Cuts): 7 × 3 Treffer pro Ziel** (`max_hits_per_target` 3, `rehit_interval` 0.04 s) = 21 gesamt |
| `mace` | **15** | **34** | 10* / 40 | – |
| `spear` | **13** | **30** | 9 / 35 | LHL und HHL mit 160°-Bogen (Geometrie, kein Schaden) |
| `staff` | **13** | **28** | 8 / 32 | Nahkampf (keine Projektile) |
| `wand` | **10*** | **23** | 7 / 27 | Alle 14 Knoten sind Projektile. **`wand_lhl`: 2 × 5** (Streuung 12°), **`wand_hhl`: 2 × 5** (Streuung 20°) |

- **Charge-Stufen:** Keine Spielerwaffe hat ein `charge_profile`. Combat Flow 1.5 lädt nicht auf. `_make_hit` setzt den Charge-Faktor deshalb immer auf 1.0.
  - Charge-Profile gibt es nur beim Legacy-Baum (Gegner, Test-Fixtures `tests/fixtures/legacy_*.tres`). Default-Faktoren dort: 1.0 / 1.35 / 1.9.
- **„Voll aufgeladen“:** `HitData.is_full_power()` gilt bei Flow-Waffen genau für Rolle 4 (Heavy Finisher).
- **Tags:** Rolle 3 trägt `finisher`, Rolle 1/2/4 auf H-Knoten tragen `heavy`, Rolle 4 trägt `heavy` und `finisher`.

### A.2 Bogen (`bow`, 10 Knoten, alle Projektile, `projectile_count` 1, `pierce` 0)
| Knoten | Rolle | HP | Haltungsschaden | Tags |
|---|---|---|---|---|
| `bow_l` (normaler Pfeil, Quick Shot) | 0 | **13** | 9 | – |
| `bow_p` (Precision Shot, RMB gehalten + LMB) | 1 | **32** | 37 | `precision` |
| `bow_pll` | 2 | 13 | 9 | – |
| `bow_ll`, `bow_pl`, `bow_lpl` | 3 | 13 | 9 | `finisher` |
| `bow_lp`, `bow_llp`, `bow_plp`, `bow_pllp` | 4 | 32 | 37 | `precision`, `finisher` |

- **Flowing Draw** (Mastery ≥ 10, LMB ≥ 0,25 s gehalten):
  - Es gibt **keinen eigenen Angriff.** Er schießt `weapon.node("L")` = `bow_l` wiederholt, also 13 HP pro Pfeil.
  - Ein Zyklus hat 3 Schüsse (`CombatFlowRules.flowing_draw_shots`) und startet neu, solange LMB gehalten bleibt.
  - Der laufende erste Quick Shot zählt als Schuss 1.
- **Precision und Heavy:** Precision-Pfeile tragen `precision` statt `heavy`. Effekte, die auf `heavy` + `finisher` prüfen (z. B. `finisher_power`), greifen beim Bogen deshalb nie.
- **Mehrere Projektile:** Der Bogen hat keine. Mehrfachprojektile gibt es nur beim Zauberstab (A.1).

## B. Waffenbestand (`slot_kind` 10 = Einhand, 11 = Zweihand; Slot immer Main Hand)
| Item | Familie | Slot | `base_stats` | Crafting-Profil | Quality | Besonderheit |
|---|---|---|---|---|---|---|
| iron_sword | one_handed_sword | 1H | – | – | nein | Startausrüstung |
| militia_sword | one_handed_sword | 1H | physical_damage 5 | – | nein | Magic, Rezept |
| forged_blade | one_handed_sword | 1H | physical_damage 6, poise_damage 4 | 4 Affixe, 2 Essenzen, 2 Sockel, ilvl 12 | ja | Debug-Kit |
| echo_blade | one_handed_sword | 1H | physical_damage 8 | – | nein | Legendary, Schockwelle (`EchoShockwaveEffect`) |
| crushing_oath | one_handed_sword | 1H | physical_damage 4 | Quality + 1 Sockel | ja | Unique, `ComboModifierEffect` auf `sword_llh_crush` (Schaden ×1.0, Haltung ×1.5, Reichweite ×1.25) |
| stormcaller_fang | one_handed_sword | 1H | physical_damage 8, poise_damage 4 | Evolution, Quality, Essenzen | ja | Epic, Evolution `stormcaller` |
| steel_greatsword | two_handed_sword | 2H | – | – | nein | Startausrüstung |
| forged_greatsword | two_handed_sword | 2H | physical_damage 10, poise_damage 8 | wie forged_blade | ja | Debug-Kit |
| iron_axe | axe | 1H | – | – | nein | – |
| iron_dagger | dagger | 1H | – | – | nein | – |
| iron_mace | mace | 1H | – | – | nein | – |
| ash_spear | spear | 2H | – | – | nein | – |
| oak_staff | staff | 2H | – | – | nein | – |
| oak_wand | wand | 1H | – | – | nein | – |
| hunting_bow | bow | 2H | – | – | nein | – |

**Prüfung der Referenzwaffen:** militia_sword → one_handed_sword, steel_greatsword → two_handed_sword, iron_axe → axe,
iron_dagger → dagger, ash_spear → spear, oak_staff → staff, oak_wand → wand, iron_mace → mace, hunting_bow → bow.
Alle **korrekt** zugeordnet.
- Die `physical_damage`-Basiswerte sind globale Prozentpunkte am Charakter, kein Waffenschaden.
- Sie stehen in Konkurrenz zum künftigen LOCAL-Basiswert (siehe Entscheidung 4).

## C. Schadenspipeline

1. **Absolute Zahl:** `CombatComponent._make_hit` (`combat_component.gd:787`) setzt
   `hit.damage = AttackDefinition.damage × charge_profile.damage_multiplier(tier)`.
   - Bei Spielerwaffen ist kein Profil gesetzt, der Faktor ist also 1.0.
   - Haltungsschaden, Knockback und Hitstop werden analog gesetzt.
   - Die Waffe (`ItemDefinition`) liefert **keine** Zahl, nur über `weapon_family_id` die Angriffe.
2. **Reihenfolge** (alle Faktoren multiplikativ auf `hit.damage`, Liste `CombatComponent.modifiers`):
   1. Charge (bei Flow 1.0).
   2. `DefenseComponent.CounterModifier`: nach einer Parade × `counter_damage_multiplier`, einmalig, nur direkte Treffer. Wird in `Player._ready` zuerst eingehängt.
   3. `CharacterStatModifier` (Bridge):
      - × (1 + `physical_damage`/100). Bei Skills stattdessen `skill_damage` plus `physical_damage` nur bei physischen Skills.
      - × (1 + `damage_dealt`/100).
      - Haltungsschaden × (1 + `poise_damage`/100).
      - Nur `heavy` + `finisher`: × (1 + `finisher_power`/100) auf Schaden und Haltung.
      - Knockback × (1 + `knockback_power`/100).
      - **Krit:** Chance `crit_chance`, dann × (1,5 + `crit_damage`/100), Tag `crit`.
      - Globale Stats enthalten Items, Affixe, Sets, Talent-Stats, Tränke und Armor Mastery, alles über `StatResolver`.
   4. Effekt-Modifier aus `ItemEffectRunner.rebuild` (Items, Sets, Essenzen, Evolution **und Talente** über `TalentService.effect_entries`):
      - `ComboModifierEffect` (`damage_multiplier`)
      - `TaggedHitModifierEffect` (`damage_multiplier`, z. B. `full_charge_only`)
      - `ConditionalHitBonusEffect` (`damage_percent` × power)
      - `EssencePoiseEffect`, `EssenceResonanceEffect`
   5. **Verteidigung des Empfängers:**
      - `Hurtbox.receive_hit` → `hit_filter` (Block/Parry über `DefenseComponent`).
      - Beim Spieler × `incoming_damage_multiplier` (Armor, `damage_reduction`) × physische oder magische Resistenz.
      - **Gegner haben keine Schadensreduktion,** nur Status- und Knockback-Resistenz.
      - Danach `HealthComponent.apply_hit`.
   6. **Nach dem Treffer** (`hit_landed`, über `ItemEffectRunner`):
      - `life_on_hit`
      - Bleed- und Chill-Würfe
      - Folgeschaden aus den Effekten in Punkt 3
3. **Eigenständige Schadenswerte, die NICHT mit der Waffenbasis skalieren dürfen:**
   - `SkillHitSpec.damage` × `SkillParams.damage_multiplier` × `damage_scale` (`SkillCast.deliver`). Skills sind absolut und waffenunabhängig, die Modifier-Liste wird danach angewendet.
   - Status-DoT (`StatusEffectDefinition.damage_per_second`, z. B. Bleeding).
   - `HitTriggerEffect.consume_damage_per_stack` (Rupture pro Stapel).
   - Gegner-Angriffe (Legacy-`AttackDefinition`, absolut).
   - **Abgeleitet, skaliert heute schon mit dem modifizierten Treffer:**
     - `EssenceDischargeEffect`: `hit.damage × 0,35 × power × shock`.
     - `EchoShockwaveEffect`: `hit.damage × 0,4`.
     - `HitTriggerEffect.burst_damage_ratio`.
     - Sie skalieren nach dem Umbau automatisch mit. Eine Entscheidung ist nötig, ob das gewollt ist.
4. **Mehrfachtreffer und Projektile:**
   - **Melee:** Die Hitbox begrenzt über `configure_limits(max_hits_per_target, rehit_interval, max_targets)`. `max_targets` 0 bedeutet unbegrenzt viele Ziele.
     - Thousand Cuts: 3 separate `HitData`, jeder läuft durch alle Modifier. Krit, Life on Hit und Status werden 3× gewürfelt.
   - **Projektile:** `_fire_projectiles` erzeugt `projectile_count` Geschosse.
     - Jedes trifft über `_on_projectile_hit` → `_make_hit(…, tier 0)` eigenständig.
     - Es gibt **keine Deduplizierung pro Ziel:** Beide Zauberstab-Forks können dasselbe Ziel treffen (2 × 5 = 10).
     - Krit und On-Hit gelten je Projektil. Die Essenzentladung ist pro `attack_instance_id` nur einmal möglich.
5. **Relevante Tests für den Umbau:**
   - **Daten und Flow:** `test_combat_data`, `test_combat_flow` (unit), `test_weapon_families`, `test_combat_flow_player`, `test_light_attack`, `test_heavy_attack`, `test_bow`, `test_hits`, `test_mastery`, `test_defense` (Counter).
   - **Items und Stats:** `test_crafting_stats`, `test_sockets_quality`, `test_item_foundation`, `test_equipment`, `test_item_effects`, `test_essences`, `test_evolution`.
   - **Abgrenzung (Skills und Talente bleiben unverändert):** `test_skills`, `test_talents`.

## D. Kalibrierungsvorschau (rein rechnerisch, nichts angewendet)

**VORSCHLAG A – Basis = aktueller Quick-Schaden der Familie.**
- Multiplikator Quick 1,00, Heavy = Heavy / Quick, gerundet auf 2 Nachkommastellen.
- Abweichung = Rundungsfehler gegenüber dem heutigen Wert.

**VORSCHLAG B – eine gemeinsame Referenzbasis 12** (Einhandschwert-Quick, Generator-Referenz).
- Familienunterschiede stecken dann in den Multiplikatoren.

| family_id | Quick alt | Heavy alt | **A: Basis** | A: Q-× / H-× | A: H neu (Abw.) | **B: Q-× / H-×** (Basis 12) | B: Q / H neu (Abw.) |
|---|---|---|---|---|---|---|---|
| one_handed_sword | 12 | 26 | 12 | 1,00 / 2,17 | 26,04 (+0,15 %) | 1,00 / 2,17 | 12 / 26,04 (0 / +0,15 %) |
| two_handed_sword | 22 | 48 | 22 | 1,00 / 2,18 | 47,96 (−0,08 %) | 1,83 / 4,00 | 21,96 / 48 (−0,18 % / 0) |
| axe | 14 | 32 | 14 | 1,00 / 2,29 | 32,06 (+0,19 %) | 1,17 / 2,67 | 14,04 / 32,04 (+0,29 % / +0,13 %) |
| dagger | 9 | 21 | 9 | 1,00 / 2,33 | 20,97 (−0,14 %) | 0,75 / 1,75 | 9 / 21 (0 / 0) |
| mace | 15 | 34 | 15 | 1,00 / 2,27 | 34,05 (+0,15 %) | 1,25 / 2,83 | 15 / 33,96 (0 / −0,12 %) |
| spear | 13 | 30 | 13 | 1,00 / 2,31 | 30,03 (+0,10 %) | 1,08 / 2,50 | 12,96 / 30 (−0,31 % / 0) |
| staff | 13 | 28 | 13 | 1,00 / 2,15 | 27,95 (−0,18 %) | 1,08 / 2,33 | 12,96 / 27,96 (−0,31 % / −0,14 %) |
| wand | 10 | 23 | 10 | 1,00 / 2,30 | 23 (0 %) | 0,83 / 1,92 | 9,96 / 23,04 (−0,4 % / +0,17 %) |
| bow (L / P) | 13 | 32 | 13 | 1,00 / 2,46 | 31,98 (−0,06 %) | 1,08 / 2,67 | 12,96 / 32,04 (−0,31 % / +0,13 %) |

**Sonderfälle:**
- **Thousand Cuts** (Treffer pro Schlag):
  - A: 7/9 = 0,78 → 7,02 (+0,29 %, ×3 = 21,06)
  - B: 0,58 → 6,96 (−0,57 %)
- **Wand-Forks** (pro Projektil):
  - A: 5/10 = 0,50 → 5 (0 %)
  - B: 0,42 → 5,04 (+0,8 %)

Mit ungerundeten Multiplikatoren (z. B. 26/12 als float) wäre die Abweichung in beiden Vorschlägen 0.

**Offen:**
- Endgültige Basiswerte je Waffen-Item innerhalb einer Familie, z. B. iron_sword vs. militia_sword.
- Die Rundungsregel für Multiplikatoren.
- Der Umgang mit den vorhandenen `physical_damage`-Basiswerten.

## E. Notwendige Designentscheidungen
1. **Basis pro Familie oder pro Item:** Bekommt jede Waffe denselben Familien-Referenzwert (A oder B), oder eigene Werte nach Stufe/Rarity? Welche Werte gelten für iron_sword, militia_sword usw.?
2. **Rundung der Multiplikatoren:** 2 Nachkommastellen (≤ 0,8 % Abweichung) oder exakt erhalten (Abweichung 0)?
3. **Bezug der Haltung:** Bleibt `poise_damage` absolut in der `AttackDefinition` (Vorgabe 6: unverändert), oder wird nur HP-Schaden auf Multiplikatoren umgestellt?
4. **Vorhandene `physical_damage`-Basiswerte** auf 6 Waffen (globale Prozent-Stats): Werden sie in einen lokalen Waffenbasiswert umgewandelt, bleiben sie global, oder entfallen sie? Daran hängt, was Quality skaliert.
5. **Abgeleitete Effekte:** Sollen Echo-Schockwelle, Essenzentladung und Burst (Anteil am Treffer) mit der neuen Basis mitwachsen?
6. **Wand-Forks und Thousand Cuts:** Bleibt der Schaden pro Treffer geteilt (Mehrfachtreffer = Gesamtschaden), oder wird er pro Projektil/Treffer neu festgelegt? Soll ein Ziel zwei Forks gleichzeitig erhalten dürfen?
7. **Generator:** Familien entstehen nur über `tools/generate_weapon_families.gd`. Multiplikatoren müssten dort statt der absoluten `REF_QUICK`/`REF_HEAVY`-Platzhalter entstehen.
8. **Legacy-Baum (Gegner):** Gilt die Umstellung nur für Spielerwaffen? Gegner haben keine Waffen-Items und behalten dann absolute Werte.
