# Pre-Alpha Item Foundation 1.0

Branch `dev/item-foundation-10` (Basis `bf4aba8`). Strukturelle Grundlagen für Loot & Equipment 2.0–2.6
nach den verbindlichen Regeln der Aufgabe. Vorarbeit: `docs/LOOT_EQUIPMENT_25_TECHNICAL_AUDIT.md`.

## 1. Audit der aktuellen Definitionen (Phase 1)

| Bereich | Ist (Code/Daten) | Umstellung |
|---|---|---|
| Affixplätze | `CraftingProfile.affix_slots` `@export_range(0, 6)`; Daten: forged_blade/forged_greatsword = 4, sonst 0 | **gefahrlos**: Obergrenze 5 + Validierung; kein Item nutzt > 4 |
| Essenzen | `essence_slots` `@export_range(0, 2)`, `ItemStats.active_essences` begrenzt auf 2 | bleibt; Konstante statt Literal |
| Affix-Tiers | `AffixTier.tier` (1 = stärkste), je Affix **3** Tiers (T3 ab ilvl 1, T2 ab 10, T1 ab 20, Werte je Affix) | **nicht gefahrlos**: Werte für T5–T1 fehlen (Blocker, §3) |
| Gespeicherte Affixe | `{"affix","tier","stat","flat","percent"}`; Wirkung nur über gespeicherte `flat/percent` | Tier ist nur Anzeige/künftige Operationen → Stats hängen nicht an der Tier-Nummer; Tier-Modell muss aber explizit werden |
| Kategorien | nicht vorhanden | **gefahrlos**: reines Metadatum, keine Berechnung liest es |
| Wirkungsbereich | nicht vorhanden; alle Affixe wirken charakterweit (`StatResolver`) | **gefahrlos** als Metadatum mit Default GLOBAL (= heutiges Verhalten); lokale Berechnung offen (§4) |
| Quality | `ItemStats.QUALITY_PERCENT_PER_POINT = 1.0` auf `base_stats` (Filter `quality_stats`), 0–`max_quality` (≤ 20) | Faktor 0,5 ist eine Konstante; dieselbe Konstante nutzen `ItemDescriber`, `CraftingPanel`, `CraftingService` |
| Quality-Ziele | 4 Items mit Profil und `quality`-Operation: forged_blade, forged_greatsword, stormcaller_fang, crushing_oath | alle haben `base_stats` (`physical_damage`, `poise_damage`); Rüstung/Schmuck ohne Profil |
| Talente | `TalentNodeDefinition` mit eigenen Stat-Boni am Charakter | keine Berührung mit Affixen |

Berechnungsstellen: `ItemStats.modifiers` (einzige Stelle Item → `StatModifier`), `ItemInstance.affix_modifiers`,
`AffixPool.compute` (Plätze, Tiers nach ilvl), `AffixDefinition.roll/validate`, `ItemStats.sanitize` (Laden).

## 2. Implementiert (Phasen 2–5)

| Feld / Regel | Ort | Wirkung heute |
|---|---|---|
| `CraftingProfile.MAX_AFFIX_SLOTS = 5`, `MAX_ESSENCE_SLOTS = 2`, `affix_slots` `@export_range(0, 5)` | `crafting_profile.gd` | Validierung; `affix_limit()` begrenzt Pool und Augment auch bei ungeprüften Daten |
| `CraftingProfile.validate(item_id)` (Affixplätze, Essenzen ≤ 2, `max_quality` ≤ 20) | über `ItemDefinition.validate` | alle 69 Items gültig |
| `AffixDefinition.category` (`OFFENSIVE`, `DEFENSIVE`, `UTILITY`, `RESOURCE`) | `affix_definition.gd`, 5 `.tres` | Metadatum, keine Berechnung |
| `AffixTiers` (`COUNT = 5`, T5 ab 1, T4 ab 10, T3 ab 25, T2 ab 45, T1 ab 70; `highest_tier`, `model_of`) | `affix_tiers.gd` (neu) | Regeln für Fünf-Tier-Affixe |
| `AffixDefinition.tier_model` (3 = Prototyp, 5 = Zielmodell) + Validierung (Fünf-Tier: alle T5–T1, Schwellen exakt) | `affix_definition.gd` | alle 12 Affixe bleiben `3` |
| Affixeintrag `"tier_model"` (beim Würfeln gesetzt), `AffixDefinition.tier_of(entry)` liest den Tier nur im eigenen Modell | `affix_definition.gd`, `item_instance.gd` | Anzeige/Werte unverändert |
| Save v11: Migration stempelt `"tier_model": 3` auf alle gewürfelten Affixe (Tasche, Lager, Waisen) | `save_migrations.gd` | keine Wertänderung |
| `AffixDefinition.scope` (`GLOBAL` Default, `LOCAL`), `ItemDefinition.allows_local_affixes(kind)` | `affix_definition.gd`, `item_definition.gd` | alle 12 GLOBAL; LOCAL nie im Pool |
| `ItemStats.QUALITY_PERCENT_PER_POINT = 0.5`, `MAX_QUALITY = 20`, `quality_factor`, `quality_percent_text` | `item_stats.gd`; genutzt von `ItemDescriber`, `CraftingPanel`, `CraftingService` | Quality 20 = +10 % auf vorhandene Basiswerte |

Local/Global zählt nicht als eigener Platz: `affix_limit()` zählt alle regulären Affixe gemeinsam.
Talente bleiben unberührt (charakterbezogene Stat-Boni, keine Affixe).

## 3. Unverändert (Gameplay)
- Alle Schadens-, Verteidigungs- und Talentwerte: alle Affixe GLOBAL wie bisher, `StatResolver` und `ItemStats.modifiers`
  rechnen Affixe, Imprint, Sockel und Evolution exakt wie vorher.
- Affix-Pool, Gewichte, Tiers und Werte der 12 Affixe (11 Waffen-Affixe auf der Forged Blade, wie zuvor).
- Essenzen (max. 2), Sockel, Evolution, Crafting-Kosten, Operationen, Rezepte, Loot, Gold.
- **Geändert ist nur Quality:** +0,5 % statt +1 % je Stufe (verbindliche Regel 6).

## 4. Blockiert / offen (Designentscheidung nötig)
1. **Fünf-Tier-Werte der 12 Affixe:** Wertespannen und Gewichte für T5–T1 sind nicht entworfen. Die Affixe bleiben auf dem
   Dreistufen-Prototyp (T1 dort ab ilvl 20). Bei der Umstellung muss entschieden werden, was mit gespeicherten
   `tier_model: 3`-Einträgen passiert (Wert behalten und als welcher Tier gelten, oder nicht aufwertbar); der Code
   liest sie bis dahin nie als Fünf-Tier-Tier. Danach kann `MODEL_THREE` entfallen (keine Dauer-Sonderregel).
2. **Lokale Berechnung:** Reihenfolge Basiswert × Quality vs. lokaler Flat/Prozent, Ziel-Basiswert je Stat. LOCAL-Affixe
   sind deshalb nicht würfelbar. Waffen haben keinen Item-Basisschaden (Schaden aus `AttackDefinition`) – ohne
   Designvorgabe keine neuen Basiswerte.
3. **Off Hand und Trinket:** in den Regeln weder Waffe/Rüstung noch Ring/Amulett → vorerst nur GLOBAL.
4. **Kategorien grenzwertig:** bloodthirsty (Life on Hit → Defensive), impactful (Knockback → Utility), swift
   (Attack Speed → Offensive), crushing (Poise Damage → Offensive) sind vorläufig zugeordnet.
5. **„Geeignete“ Quality-Basiswerte:** Quality erreicht nur die 4 Items mit Profil (forged_blade, forged_greatsword,
   stormcaller_fang, crushing_oath); ihre Basiswerte sind globale Prozentpunkt-Stats (`physical_damage`,
   `poise_damage`), kein echter Waffenschaden. Rüstung und Schmuck haben kein Crafting-Profil → kein Quality-Weg;
   keine Stats erfunden. Ob `quality_stats` gefiltert werden soll, ist offen.
6. **Überzählige Affixe:** kein Item kann heute > 4 haben; eine Regel für Items über einem künftigen Limit fehlt.
7. Weiterhin offen aus dem Audit §7: Reforge/Refine/Elevate, Crafting-Affixe, Werkbänke, Rarity pro Instanz,
   Kosten, Item-Level-Quellen, Loot (bewusst nicht implementiert).

## 5. Save-Risiken
- **v10 → v11:** nur additiv (`tier_model` in Affixeinträgen). Alte Dateien werden nicht umgeschrieben, nur beim nächsten
  Speichern im neuen Format. Ein v11-Save ist für einen älteren Build „neuer“ und wird dort abgelehnt.
- **Quality:** gespeicherte Stufen bleiben; ihre Wirkung halbiert sich (z. B. Quality 20: +10 % statt +20 %). Bewusst
  ohne Umrechnung (Pre-Alpha, keine Legacy-Sonderregel). Betrifft nur die 4 Items mit Profil.
- Keine echten Saves oder `settings.cfg` berührt; Tests nur unter `user://test_saves/`.

## 6. Tests
Suites (gezielt, Lauf am Ende): item_foundation (neu, 13 Tests), affix_pool, crafting_ops, crafting_save (+ v10→v11),
save, crafting_stats, equipment, sockets_quality, forge_ui, inventory_ui, armor_mastery, inventory –
**106 bestanden, 0 fehlgeschlagen**. `tools/check_project.ps1`: OK. Keine Playtests, keine Galerie, keine Vollsuite.
Angepasst: zwei Quality-Erwartungen (+20 % → +10 %), zwei Versionsprüfungen (`== 10` → `>= 10`).
