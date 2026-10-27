# Weapon Base Damage Implementation 1.0 (Loot & Equipment 2.7)

Branch `dev/weapon-base-damage-10` (Basis `e0575f4`). Umsetzung des freigegebenen Waffenbasis-Schadensmodells für
gewöhnliche Spielerwaffen. Vorarbeit: `WEAPON_BASE_DAMAGE_CALIBRATION_AUDIT.md`, `WEAPON_ITEM_MAPPING_2_7.md`,
`ITEM_FOUNDATION_1_0.md`.

## 1. Modell (wie umgesetzt)

```
D_weapon = (base_weapon_damage × Q + Σ local flat) × (1 + Σ local % / 100)     Q = ItemStats.quality_factor (max. Quality 20)
D_attack = D_weapon × AttackDefinition.weapon_damage_multiplier                 danach unverändert alle AttackModifier
B_ref(L) = B1 × (1 + 0,012 × (L − 1)),  L = 1..100                              WeaponDamage.reference_at
```

| Ort | Rolle |
|---|---|
| `ItemDefinition.base_weapon_damage` | Basiswert des Waffenmodells; 0 = noch nicht umgestellt |
| `WeaponDamage` (`scripts/rpg/items/weapon_damage.gd`, neu) | einzige Berechnung von D_weapon und B_ref; `is_on_model`, `is_local`, `reference_of` |
| `WeaponFamily.reference_base_damage` | Familienreferenz B1 (generiert) |
| `AttackDefinition.weapon_damage_multiplier` | Angriffsfaktor (generiert, ungerundet); 0 = absoluter `damage` (Gegner, Legacy) |
| `AttackDefinition.damage` | bleibt bei Spielerwaffen als Referenzschaden bei Familienbasis (Anzeige/Tests); `WeaponFamily.validate` prüft `multiplier × B1 = damage` |
| `CombatComponent.weapon_base_damage`, `weapon_damage()`, `base_damage()` | D_weapon des getragenen Items; 0 → Familienreferenz. Projektile speichern D_weapon beim Abschuss |
| `PlayerProgressionBridge._refresh_weapon_damage` | rechnet D_weapon bei jeder Ausrüstungs-, Quality-, Crafting- und Statänderung neu aus der Instanz (nie inkrementell); während eines wartenden Familienwechsels behält die laufende Familie ihren Wert |

**Kompatibilitätsgrenze (eine Regel, keine zweite Engine):** Hat das Main-Hand-Item kein `base_weapon_damage` (oder ist
keine Waffe ausgerüstet), ist D_weapon = B1 der Familie. Da `multiplier = alter Schaden / B1`, entsteht exakt der bisherige
Schaden; globale Basisboni und Quality dieser Waffen wirken wie zuvor über `StatResolver`.

**Reihenfolge der Modifier unverändert:** D_attack entsteht in `_make_hit` vor der Modifier-Liste (Charge 1.0 → Parry-Counter →
`CharacterStatModifier` inkl. Krit → Item-/Talent-Effekte). Mehrfachtreffer und Projektile bilden weiterhin je Treffer
eigene `HitData` (Krit, Life on Hit, Status je Treffer). Schockwelle, Essenzentladung, Burst rechnen weiter auf `hit.damage`.

**Quality:** Bei umgestellten Waffen nur auf `base_weapon_damage` (`ItemStats.quality_scales_base_stats` = false für sie),
nie auf globale Stats oder Haltungsschaden. Nicht umgestellte Waffen unverändert. Haltungsschaden bleibt absolut in
`AttackDefinition.poise_damage`.

**Generator:** `tools/generate_weapon_families.gd` trägt pro Familie `"base"` (B1) und schreibt
`weapon_damage_multiplier = damage / base` nach Fork-/Mehrfachtreffer-Teilung (also pro Treffer/Projektil). Die
`.tres` sind neu generiert; Diff = nur die neuen Felder.

## 2. Waffenstand

**Umgestellt (10):**

| Item | Familie | base | Quick | Heavy / Precision | Sonderfälle (je Treffer) |
|---|---|---|---|---|---|
| iron_sword | one_handed_sword | 12 | 12 | 26 | – |
| militia_sword | one_handed_sword | 12,6 | 12,6 | 27,3 | globaler +5 % `physical_damage` **entfernt** |
| steel_greatsword | two_handed_sword | 22 | 22 | 48 | – |
| iron_axe | axe | 14 | 14 | 32 | – |
| iron_dagger | dagger | 9 | 9 | 21 | Thousand Cuts 3 × 7 |
| iron_mace | mace | 15 | 15 | 34 | – |
| ash_spear | spear | 13 | 13 | 30 | – |
| oak_staff | staff | 13 | 13 | 28 | – |
| oak_wand | wand | 10 | 10 | 23 | LHL/HHL 2 × 5 |
| hunting_bow | bow | 13 | 13 | 32 (P) | Flowing Draw 3 × 13 (normale Schüsse) |

Alle Werte bei Item-Level 1 und Quality 0; sie sind identisch zur Baseline (`tests/fixtures/weapon_damage_baseline_2_7.json`),
außer militia_sword (+5 % jetzt lokal statt global). Item-Level wurde nirgends neu belegt (alle Instanzen ohne Profil: 1).

**Vorerst unverändert (5):** stormcaller_fang, crushing_oath, echo_blade (V2 als späterer Prototyp beschlossen),
forged_blade, forged_greatsword (Blocker §5). Sie laufen über die Kompatibilitätsgrenze mit exakt bisherigem Schaden.

## 3. Local-Affixe

| Affix | Datei | Art | T5 (1) | T4 (10) | T3 (25) | T2 (45) | T1 (70) |
|---|---|---|---|---|---|---|---|
| Tempered Blade | `tempered_blade.tres` | LOCAL %, `weapon_damage` | 3–5 | 6–8 | 9–12 | 13–16 | 17–20 |
| Striking | `striking.tres` | LOCAL flat, `reference_share` | 3–6 | 5–9 | 8–12 | 11–16 | 15–22 |

- Striking: Gewürfelt wird ein ganzzahliger Prozentanteil (wie alle Affixe ganzzahlig, `AffixDefinition.roll`); gespeichert werden
  `"flat" = B_ref(item_level) × Anteil / 100` (einmalig) und `"share"`. Danach keine Neuberechnung mit Quality oder Stats.
- Beide `tier_model` 5, zählen zu den max. 5 regulären Plätzen, eigene Gruppen (zusammen erlaubt).
- `ItemStats.modifiers` gibt LOCAL-Einträge nie an `StatResolver`; `ItemDescriber` zeigt sie als „(local)“ und die
  Waffen-Basis als „Weapon Damage“.
- **Funktionsstand:** Berechnung, Würfeln, Speichern/Laden und Anzeige funktionieren (getestet). Im Spiel aber **nicht
  erreichbar**: `AffixPool` bietet LOCAL nur auf umgestellten Waffen an, und keine umgestellte Waffe hat ein `CraftingProfile`.
  Es wurden keine Pools, Loot-Quellen oder Profile aktiviert.
- Sharpened (GLOBAL), Guarded (GLOBAL Flat Armor) und alle übrigen Affixe unverändert.

## 4. Betroffene Skills / Global-Boni
- Physische Skills mit militia_sword verlieren die bisherigen +5 % `physical_damage` (der Bonus war global). Alle anderen
  Skills, DoTs, Rupture, Gegnerangriffe: unverändert, keine Waffenbasis-Skalierung.
- Talente und Talentbedingungen unverändert.

## 5. Blocker und offene Balancefragen
1. **forged_blade / forged_greatsword (BLOCKIERT):** Ihr `physical_damage` (+6 / +10) ist global und wirkt auch auf physische
   Skills; ihr `poise_damage` (+4 / +8) ist global und heute Quality-Ziel. Eine Übertragung erfordert eine nicht getroffene
   Entscheidung (V1 Äquivalenz vs. V3 Referenz + Bonus; Umgang mit Poise-Basis, mit Skills und mit gespeicherten `sharpened`-
   Würfen auf diesen Instanzen). Daher nicht umgestellt.
2. **Spezialwaffen V2** (stormcaller_fang, crushing_oath, echo_blade): beschlossen, aber laut Auftrag noch nicht umgesetzt.
3. **Affix-Gewichte** der zwei neuen Affixe: Platzhalter (Affix 100, je Tier 100, Tags `physical`/`attack` wie Sharpened). Erst
   relevant, wenn LOCAL-Affixe würfelbar werden.
4. **Striking ganzzahlig:** Prozentanteil ganzzahlig gewürfelt (Konvention aller Affixe). Falls kontinuierlich gewünscht: nur
   `AffixDefinition.roll` ändern.
5. **Basis pro Definition:** `base_weapon_damage` steht in der Definition (fester Basiswert des Modells, kein Wurf). Eine
   Skalierung mit dem Instanz-Item-Level (künftiger Loot mit variablem ilvl) ist nicht umgesetzt und offen.
6. Weiter offen aus dem Mapping-Audit: Item-Level-Quellen ohne `CraftingProfile`, Echo-Blade-Level.

## 6. Save
**Keine Versionsänderung (bleibt v11), keine Migration.** `base_weapon_damage` steht nur in der Definition. Striking-Einträge
haben einen zusätzlichen optionalen Schlüssel `"share"` (additiv, `_normalized_affix` behält ihn); vorhandene Saves enthalten
keine LOCAL-Affixe. Folge: gespeicherte militia_sword-Instanzen verlieren den globalen +5 % und erhalten die lokale Basis 12,6.
Keine echten Saves oder `settings.cfg` berührt.

## 7. Tests
Neu: `tests/integration/test_weapon_base_damage.gd` (15 Tests): alle 122 Knoten gegen die Baseline (Schaden, Haltung,
Projektile, Treffer/Ziel, ungerundete Multiplikatoren), Gegner absolut, Quick/Heavy aller 10 Waffen, militia ohne Doppelbonus,
Spezialwaffen unverändert (Echo Blade 12 × 1,08 echt getroffen), Quality 0/20, Striking-Roll aus B_ref (ilvl 1/25/70) inkl.
Speichern/Laden, Tempered Blade, beide zusammen, Pool nur auf Modellwaffen, echte Treffer: Thousand Cuts (3 × 14 bei D 18),
Zauberstab-Forks (2 × 10 bei D 20), Precision Shot (64 bei D 26), Flowing Draw (je 26), Projektil-Snapshot.
Mutationsprobe (Skalierung deaktiviert) → 5 Tests schlagen an.

Angepasst: `test_item_foundation` (zwei Tests prüfen nun die bestehenden GLOBAL-Affixe), `test_affix_pool` (Anzahl 10–14).

Lauf (gezielt): weapon_base_damage, combat_data, combat_flow, weapon_families, hits, light_attack, heavy_attack, bow,
defense, combat_flow_player, mastery, equipment, weapon_switch, inventory_ui, sockets_quality, crafting_save, crafting_stats,
crafting_ops, item_effects, evolution, essences, save, forge_ui, skills, item_foundation, affix_pool –
**226 bestanden, 0 fehlgeschlagen**. `tools/check_project.ps1`: OK. Keine Playtests, keine Galerie, keine Vollsuite.
