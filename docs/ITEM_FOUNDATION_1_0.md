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
