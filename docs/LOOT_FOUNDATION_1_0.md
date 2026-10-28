# Loot Foundation 1.0 – Rarity, Affix Tiers & Item Generation

Branch `dev/loot-foundation-10` (Basis `b1e2b20`, Audit 2.6). Technisches Fundament der beschlossenen
Hollowwood-Lootprogression: gültige Normal-/Magic-/Rare-Instanzen (Architektur bis Legendary) mit Item-Level,
Instanz-Rarity und Affixen werden **isoliert** erzeugt, gespeichert und geladen. Keine Drops, Quest-Belohnungen,
Gold, Weltobjekte, Händler, Reforge/Refine/Elevate oder Crafting-UI.

## 1. Baseline (Phase A)

| Bereich | Vorher | Nachher |
|---|---|---|
| Rarity | nur `ItemDefinition.rarity` | `ItemInstance.rarity` (eigene Instanz-Rarity), Definition bleibt Vorgabe |
| Erzeugung | `ItemCreation.create` (Level, Waffenbasis) | derselbe Vertrag + `ItemCreation.generate` (kein zweiter Generator) |
| Affix-Tiers | 12 GLOBAL-Affixe im Drei-Tier-Prototyp (T1 ab ilvl 20), Tier-Gewichte je `AffixTier.weight` | alle 15 Definitionen Fünf-Tier; Tier-Gewichte nur als Eingabe (`AffixTierWeights`) |
| Pool | `AffixPool.compute` (nur Crafting, nur GLOBAL) | `AffixRoller` = gemeinsamer Eligibility-/Roll-Kern für Crafting-Pool und Generierung |
| Affix-Gewichte | alle 100 | Standard 100, Executioner 90, Bloodthirsty 80, Thundering 30, LOCAL 100 |

Bestehende Effektbedingungen (unverändert, nur gelesen):
- **Executioner** (`finisher_power`): wirkt in `CharacterStatModifier` nur bei Treffern mit den Tags `heavy` **und** `finisher`.
  Familien mit solchen Angriffen: alle außer **Bogen** (Bogen-Finisher tragen `precision`, nie `heavy`).
- **Thundering** (`shock_damage`): wirkt nur in `EssenceDischargeEffect` (Storm-Wolf-Essenz). Keine Eligibility-Regel → bleibt
  würfelbar (Gewicht 30), Wirkung weiterhin nur mit der Essenz.
- **Bloodthirsty** (`life_on_hit`): Heilung pro verbundenem Treffer in `PlayerProgressionBridge._on_player_hit_landed`.
- **Guarded** = GLOBAL `armor` flat, **Sharpened** = GLOBAL `physical_damage` – unverändert.
- Ausschlussgruppen: `element_core` (Bloodthirsty/Thundering), `control_core` (Crushing/Impactful) – unverändert.

Save-Strategie: eine Version (v13 → v14), reine Dict-Migration mit eingefrorener Tabelle (Muster `V12_WEAPON_MODELS`),
synthetische Payloads in Tests, keine echten Saves geöffnet.

## 2. Instanz-Rarity und Save v14 (Phase B)

- `ItemInstance.rarity: int` – `ItemDefinition.Rarity` der Instanz; `RARITY_FROM_DEFINITION` (−1) = nicht instanzeigen
  (Stapel, Vorschauen). `effective_rarity(definition)` liefert die gültige Rarity.
- `ItemCreation.create` setzt bei ausrüstbaren Items die Rarity der Definition; `generate` setzt die angeforderte.
  Zwei Instanzen derselben Definition können verschieden sein (getestet: Wanderer's Coat Magic vs. Normal).
- Speicherung: Schlüssel `"rarity"` nur, wenn instanzeigen; Laden akzeptiert nur gültige Enum-Werte (sonst Definition).
- **Save v14**, Migration `_v13_to_v14`: jeder ausrüstbare Eintrag (Tasche, Lager, Waisen) ohne `rarity` erhält die Rarity seiner
  Definition aus `SaveMigrations.V14_EQUIPMENT_RARITY` (eingefroren, 33 ausrüstbare Definitionen; ein Test prüft die Tabelle
  gegen die Daten). Unique/Set/Legendary-Identitäten bleiben, nichts wird gewürfelt, aufgewertet, dupliziert oder entfernt.
  Vorhandene `rarity` wird nie überschrieben. Stapel/unbekannte Items: unverändert. Details: `docs/SAVE_SYSTEM.md`.
- Anzeige: Inventarzelle (`ItemCell` → `ItemIcon.rarity`), Tooltip/Details (`ItemDescriber`), Statusfarbe und Rarity-Sortierung
  im Inventar nutzen die Instanz-Rarity.

## 3. Fünf Affix-Tiers (Phase C)

Schwellen (unverändert aus Item Foundation 1.0, `AffixTiers`): T5 ab 1, T4 ab 10, T3 ab 25, T2 ab 45, T1 ab 70; Item-Level ≤ 100.

| Affix | Stat (Scope) | T5 | T4 | T3 | T2 | T1 | Gewicht |
|---|---|---|---|---|---|---|---|
| Cruel | crit_damage (G) | 2–4 | 4–6 | 6–9 | 9–12 | 12–15 | 100 |
| Keen | crit_chance, Prozentpunkte (G) | 0.5–1 | 1–1.5 | 1.5–2 | 2–2.5 | 2.5–3 | 100 |
| Sharpened | physical_damage % (G) | 1–2 | 2–3 | 3–4 | 4–5 | 5–6 | 100 |
| Crushing | poise_damage % (G) | 4–6 | 7–10 | 11–14 | 15–19 | 20–25 | 100 |
| Executioner | finisher_power % (G) | 5–7 | 8–11 | 12–16 | 17–22 | 23–30 | 90 |
| Thundering | shock_damage % (G) | 8–12 | 13–18 | 19–25 | 26–33 | 34–42 | 30 |
| Vital | max_health flat (G) | 4–7 | 8–12 | 13–19 | 20–28 | 29–40 | 100 |
| Bloodthirsty | life_on_hit (G) | 1 | 1 | 2 | 2 | 3 | 80 |
| Guarded | armor flat (G) | 2–3 | 4–5 | 6–8 | 9–12 | 13–17 | 100 |
| Impactful | knockback_power % (G) | 5–8 | 9–13 | 14–19 | 20–26 | 27–35 | 100 |
| Swift | attack_speed % (G) | 1–2 | 2–3 | 3–4 | 4–5 | 5–6 | 100 |
| Furious | resource_gain % (G) | 4–6 | 7–10 | 11–15 | 16–21 | 22–28 | 100 |

Stat, Scope, Gruppe, Tags, Kategorie, Slot-Listen und Ausschlussgruppen sind unverändert.
`AffixDefinition` validiert nur noch das Fünf-Tier-Modell (exakte Schwellen, alle fünf Tiers, Werte auf `value_step`).
`AffixTier.weight` entfällt – Tier-Gewichte kommen ausschließlich vom Aufrufer (§4).

**Altes Drei-Tier-Modell:** keine Definition nutzt es mehr. `AffixTiers.MODEL_THREE` bleibt nur als Marker gespeicherter
Rolls (`tier_model: 3`, seit v11). Solche Einträge behalten ihren Wert und wirken wie bisher; `tier_of` liefert für sie `null`
(kein Fünf-Tier-Tier), der Tooltip zeigt „legacy roll“. Kein Neuwurf, keine Umdeutung.

## 4. Tier-Gewichte – frühe Hollowwood-Konfiguration

`AffixTierWeights` (Resource, Bänder `{min_level, max_level, weights: {tier: weight}}`), Daten
`data/loot/hollowwood_early_tiers.tres`:

| Item-Level | T5 | T4 | T3/T2/T1 |
|---|---|---|---|
| 1–9 | 100 % | – | – |
| 10–24 | 75 % | 25 % | – |
| ≥ 25 | **nicht konfiguriert** | | |

Ein Item-Level außerhalb aller Bänder ist nicht konfiguriert: `AffixRoller.tier_options` liefert nichts, `generate` lehnt
Magic+ ab („affix tier weights not configured for item level N“). Es gibt **keine** Standardverteilung. Höhere Level brauchen eine
explizite, freigegebene Tabelle als Eingabe. Validierung: keine Überlappung, Tier muss ab Bandbeginn erreichbar sein.

## 5. Gemeinsamer Affixgenerator (Phase D)

`AffixRoller` (`scripts/rpg/crafting/affix_roller.gd`):
- `eligible(definition, item_level, present, db, allowed_ids, include_local)` – harte Filter: ausrüstbar, < 5 reguläre Affixe,
  `rollable`, Slot-Kind (inkl. LOCAL nur auf Waffen/Rüstung/Schild), Familien-Effektbedingung (`required_attack_tags`),
  erreichbarer Tier, erlaubte IDs, keine doppelte ID/Gruppe, keine belegte Ausschlussgruppe. Gewichte lassen nie etwas zu.
- `tier_options(affix, item_level, weights)` – Tier-Ziehung getrennt von der Identität.
- `roll_one(...)` – Identität (nach `AffixDefinition.weight`) → Tier (Tabelle) → Wert (`AffixDefinition.roll`, einmalig).
- Neue Felder an `AffixDefinition`: `required_attack_tags` (Executioner: `heavy`, `finisher`), `rollable`, `value_step`
  (Keen 0.1, sonst 1).

Nutzer:
- **Crafting-Pool** (`AffixPool.compute`): Eligibility und Tier-Gewichte aus dem Kern; Tier-Tabelle =
  `ProgressionRules.crafting_tier_weights` (= frühe Hollowwood-Tabelle). Weiterhin nur GLOBAL, keine neuen Aktionen.
- **Generierung** (`ItemCreation.generate`, §6): nur IDs aus `ItemDefinition.generation_affixes`, LOCAL erlaubt.
- Reforge später: derselbe Kern (nicht aktiviert).

Kategorien (Offensive/Defensive/Utility/Resource) bleiben Metadatum; keine Kategorienmuster für 1–5 Affixe erzwungen. Eine
spätere Spezialisierung kann als zusätzlicher Filter/Gewichtsfaktor im Kern ergänzt werden.

## 6. Generierungsvertrag

`ItemCreation.generate(definition, rarity, db, rng, tier_weights, item_level = 0, origin = &"", id = "") -> Generated`

| Rarity | reguläre Affixe |
|---|---|
| Normal | 0 |
| Magic | 1 (40 %), 2 (40 %), 3 (20 %) |
| Rare | 3 (60 %), 4 (40 %) |
| Epic | 4 (60 %), 5 (40 %) |
| Legendary | 5 |

- Item-Level: explizit oder `creation_item_level()` der Definition; sonst Ablehnung (Rüstung/Schild haben keine Quelle → Aufrufer
  muss es angeben). Keine Charakterlevel-Skalierung.
- Erst `create` (Level, Instanz-Waffenbasis), dann Rarity, Herkunft und Affixe. Die Waffenbasis wird nie verändert.
- Abgelehnt (`error`, kein Item): nicht vorbereitet (`generation_affixes` leer), Unique-/Set-Definition, Unique/Set als
  angeforderte Rarity, kein Item-Level, Magic+ ohne konfigurierte Tier-Gewichte.
- **Zu kleiner Pool:** die Schleife endet, sobald nichts mehr zulässig ist (jeder Roll entfernt mindestens eine Gruppe, also
  höchstens Soll-Durchläufe). Das Item behält die gewürfelten Affixe; `shortfall` und `note` dokumentieren die Lücke
  (z. B. Legendary-Lederkappe: 3 von 5). Keine neuen Affixe oder Regeln, keine Ausschlussumgehung.
- Essenzen (max. 2) bleiben getrennt und werden nie erzeugt; Sockel ebenso.

### LOCAL-Affixe
| Affix | Wirkung | T5 | T4 | T3 | T2 | T1 | aktiv |
|---|---|---|---|---|---|---|---|
| Tempered Blade | LOCAL Weapon Damage % | 3–5 | 6–8 | 9–12 | 13–16 | 17–20 | ja (alle 9 Familien) |
| Striking | LOCAL Flat, Anteil % von `B_ref(ilvl)` | 3–6 | 5–9 | 8–12 | 11–16 | 15–22 | ja (alle 9 Familien) |
| Armored | LOCAL Armor % | 3–5 | 6–9 | 10–13 | 14–18 | 19–24 | **nein** (`rollable = false`) |

Striking speichert `flat = B_ref(Familie, ilvl) × Anteil / 100` (ohne Modellfaktor, ohne Quality) und `share`; Wirkung nur über
`WeaponDamage.of`. LOCAL-Einträge erreichen `StatResolver` nie (getestet). Armored ist nur als Daten definiert (Rüstungs-Slots
Kopf–Füße), in keinem Pool, keiner Itemliste und ohne Berechnung. Ringe/Amulette/Trinkets: nur GLOBAL.

### Vorbereitete Itemdefinitionen (`generation_affixes`)
| Items | Affixe |
|---|---|
| iron_sword, iron_axe, iron_dagger, iron_mace, ash_spear, steel_greatsword, oak_staff, oak_wand | 11 GLOBAL-Waffenaffixe + Striking + Tempered Blade (13); seit Grove Warden Rare R1.1 ohne Thundering (12, `docs/GROVE_WARDEN_RARE_R11.md`) |
| hunting_bow | wie oben ohne Executioner (12; seit R1.1 ohne Thundering: 11) |
| leather_cap, wanderer_coat, oak_shield | Furious, Guarded, Vital (die nach bestehenden Slot-Regeln zulässigen GLOBAL-Affixe); seit Grove Warden Rare R1 zusätzlich Keen (`docs/GROVE_WARDEN_RARE_R1.md`) |

Keine CraftingProfile ergänzt (sonst wären die Items schmiedbar), keine neuen Items, keine neuen Basiswerte.
`GameDatabase.validate` prüft jede Generierungs-ID gegen die Kernregeln.

## 7. Beispielgenerierungen (Seed 2026, frühe Hollowwood-Tabelle)

| Item | Rarity | ilvl | Basis | Affixe |
|---|---|---|---|---|
| iron_sword | Normal | 7 | 12.864 | – |
| iron_sword | Magic | 7 | 12.864 | Furious T5 4, Thundering T5 11 |
| hunting_bow | Magic | 12 | 14.716 | Vital T5 6 |
| iron_mace | Rare | 12 | 16.980 | Vital T5 6, Tempered Blade T4 6 %, Keen T4 1.5, Cruel T5 3 |
| steel_greatsword | Rare | 18 | 26.488 | Swift T5 2, Vital T5 6, Bloodthirsty T5 1, Striking T4 1.324 (5 % von 26.488) |
| wanderer_coat | Magic | 5 | – | Furious T5 6, Vital T5 6 |
| oak_shield | Rare | 12 | – | Vital T5 7, Furious T5 4, Guarded T4 4 |
| leather_cap | Legendary | 12 | – | Vital T4 11, Guarded T5 3, Furious T4 10 – shortfall 2 |

## 8. Tests (Phase E)

Neu: `tests/unit/test_loot_foundation.gd` (16 Tests): Fünf-Tier-Werte, Semantik und Gewichte aller 15 Affixe; Tier-Tabelle
(1–9 / 10–24 / ≥ 25 nicht konfiguriert, Validierung); Werte im Tier und auf `value_step`; Instanz-Rarity; saubere Ablehnungen;
Normal ohne Affixe mit unveränderter Basis; Magic 1/2/3 und Rare 3/4 statistisch (3000 Ziehungen, ±3 %), Epic 4/5, Legendary 5;
Shortfall (Rüstung, synthetisches exklusives Paar, leerer Pool – keine Endlosschleife); keine Duplikate/Ausschlüsse,
kein LOCAL auf Rüstung/Schild, max. 5; Executioner-Eligibility (Bogen ausgeschlossen, Thundering bleibt); ilvl 7 nur T5,
ilvl 12 T4-Anteil 25 % ±2 % (> 4000 Tier-Ziehungen, fester Seed), ilvl 24 nie T3+; Striking/Tempered über `WeaponDamage`, nie
in Charakter-Stats; deterministisch bei gleichem Seed; Save/Load eines generierten Items bitgleich; v13→v14-Migration
synthetisch (alle Listen, Sonderidentitäten, Stapel, unbekannte Items, bestehende Rarity, alle übrigen Felder); eingefrorene
Tabelle = Daten.

Angepasst (alte Drei-Tier-/v13-Annahmen): `test_affix_pool` (neue Gewichte, Tiers 5/4, ilvl 25 leer, 15 Affixe),
`test_item_foundation` (Fünf-Tier statt Drei-Tier, Tier-Schwellen über synthetische Tabelle, Armored LOCAL),
`test_crafting_save` (Drei-Tier-Eintrag ohne Fünf-Tier-Tier), `test_save_foundation` und `test_weapon_base_damage`
(Migration bis v14 ergänzt `rarity`; ilvl-70-Crafting-Pool nicht konfiguriert).

Lauf: loot_foundation, affix_pool, item_foundation, crafting_ops, crafting_save, crafting_stats, save, save_foundation,
inventory, inventory_ui, forge_ui, weapon_base_damage, equipment, stash, sockets_quality, salvage, economy –
**179 bestanden, 0 fehlgeschlagen**. `tools/check_project.ps1`: OK.
Mutationsprobe: `fits_family` immer wahr und Ausschlussfilter aus → 3 Tests rot; zurückgesetzt.
Nicht gelaufen (Policy): Vollsuite, Prolog/Haven/Klassen, Crafting-Loop, Galerie, Playtests, echte Saves.

## 9. Bewusste Entscheidungen / offene Punkte

1. **Keen-Granularität 0.1** (`value_step`): die freigegebenen Spannen (0.5–1 …) sind mit ganzzahligen Rolls nicht darstellbar.
   Technische Wahl, jederzeit in den Daten änderbar (z. B. 0.5) – **bitte bestätigen**.
2. **Crafting-Pool nutzt die frühe Hollowwood-Tier-Tabelle** (`ProgressionRules.crafting_tier_weights`), weil die alten
   Tier-Gewichte mit dem Drei-Tier-Modell entfallen. Folgen für Resonanzschmiede-Items: neue Fünf-Tier-Werte, neue Affix-Gewichte,
   T5/T4 75/25 bei ilvl 10–24; Items mit ilvl ≥ 25 bekommen vom Pool nichts angeboten (heute existiert keine solche Quelle).
   Eine eigene Crafting-Tabelle braucht eine Designfreigabe.
3. **Armored** ist mit freigegebenen Werten definiert, aber nicht würfelbar; Slot-Liste Kopf–Füße (Schild offen).
4. **Verkaufswert/Salvage** (`EconomyService`, `SalvageService`) und Lager-Sortierung lesen weiter die Definitions-Rarity
   (keine Goldänderung in diesem Auftrag). Für generierte Magic/Rare-Instanzen später auf `effective_rarity` umstellen
   (Designentscheidung zu Verkaufsfaktoren pro Instanz-Rarity).
5. Weitere Anzeigen mit Definitions-Rarity: Loot-Feed, Berufe-Panel, Crafting-Panel, Build-Panel (betreffen heute keine
   generierten Instanzen).
6. Rüstung/Schild haben nur drei zulässige Affixe → Rare 4 / Epic / Legendary erreichen ihre Sollzahl dort nicht (Shortfall,
   dokumentiert). Mehr Affixe für Rüstung brauchen freigegebene Eligibility (z. B. lokale Rüstungsbasis).
7. Rüstung und Schild haben keine freigegebene Item-Level-Quelle → `generate` braucht das Level vom Aufrufer.
8. Shortfall-Rückgabe: Item mit weniger Affixen + `shortfall`/`note`; ob eine Lootquelle in diesem Fall z. B. die Rarity
   senkt oder neu zieht, entscheidet die spätere Dropintegration.

## 10. Ausdrücklich unverändert

Gegnerdrops, Dropchancen, Quest-Rewards, Gold, Truhen/Weltobjekte, Materialkosten, Reforge/Refine/Elevate, Händler,
Crafting-UI und -Operationen, Combat-Timings, Klassen/Skills, Waffen/Gegner, `WeaponDamage`-Formel und gespeicherte Waffenbasen,
Quality-Regeln, Essenzen, Sockel, Evolution, Item-Schutz/Herkunft, `StatResolver`, Effektbedingungen aller Affixe,
`ItemDefinition.rarity` aller Definitionen.
