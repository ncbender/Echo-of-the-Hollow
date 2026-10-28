# Grove Warden Rare · R1.1: Thundering Eligibility Fix

Branch `dev/grove-warden-rare-r11` von `dev/grove-warden-rare-r1` @ `e61c2f2`. Save bleibt **v15**, keine Migration, keine
Neuwürfe. Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst.

## 1. Gewählte Option: T1 (Item-Pool-Änderung)

`&"thundering"` wurde aus `generation_affixes` der neun Standardwaffen entfernt:
`iron_sword`, `steel_greatsword`, `iron_axe`, `iron_dagger`, `iron_mace`, `ash_spear`, `oak_staff`, `oak_wand`, `hunting_bow`.
Pools: 13 → **12** (Bogen 12 → **11**).

Unverändert sind:
- `data/crafting/affixes/thundering.tres` (Slots 10/11, Gewicht 30, alle Tier-Werte)
- `AffixRoller`
- alle übrigen Affixe und Gewichte
- Basisschaden, Rare-Anzahl und Tier-Verteilung

**Tatsächliche Regel:** Neue Items aus `ItemCreation.generate` (Loot, Grove-Warden-Tabelle, Klassenbelohnung) würfeln
Thundering nur noch, wenn das Modell es in `generation_affixes` führt. Das tut heute **kein** Modell. Thundering entsteht
nur noch über Crafting (`AffixPool`, globale Eligibility) auf den Waffen mit Essenz-Slots.

## 2. Phase A – Begründung

| Frage | Befund |
|---|---|
| 1. Welche Option? | **T1.** T2 bräuchte eine neue Eligibility-Regel im Code, T3 neue Effekte (verboten). T4 widerspricht dem Design |
| 2. Schadet das Entfernen Essenz-Kombinationen? | nein. Die neun Modelle haben **kein** `CraftingProfile`: keine `essence_slots`, kein `essence_insert`. `ItemStats.active_essences` begrenzt auf die Slots des Profils, eine Storm-Wolf-Essenz kann auf ihnen also nie wirken. Die Essenzwaffen `forged_blade`, `forged_greatsword` und `stormcaller_fang` haben keine `generation_affixes`; ihre Thundering-Quelle ist `AffixPool` (alle Affixe nach globaler Regel), und die ist unverändert |
| 3. Kennt ein vorhandener Filter den Kontext? | nein. `AffixDefinition.fits_family` prüft nur Angriffs-Tags (`required_attack_tags`), keine Essenz-Slots. Ein passender Filter wäre neu (T2). Die Pool-Liste ist der vorhandene, enge Hebel pro Modell |
| 4. Unterschied „Waffe mit späterer Essenz“ vs. „essenzlos“? | Den gibt es heute nicht. Eine Instanz behält ihre `definition_id`, und keines der neun Modelle kann je Essenzen aufnehmen. Alle Standardwaffen sind dauerhaft essenzlos, alle Essenzwaffen werden nicht generiert |

Kein Konflikt mit freigegebenen Essenz-Kombinationen, deshalb kein Stopp.

## 3. Auswirkungen auf neue Drops (bewusst)

- **Grove-Warden-Rares:** nie mehr Thundering. Vorher waren ≈ 6,5 % aller Rares betroffen (R1 §6).
- **Reguläre Grunt-/Wolf-Waffendrops:** ebenfalls ohne Thundering. Die Gewichte der übrigen Affixe bleiben; die 30 fallen
  aus der Summe, die anderen Identitäten werden also leicht häufiger. `bloodthirsty` hat in diesen Pools keinen
  `element_core`-Partner mehr. Tabellen, Dropchancen, Rarity und Tiers sind unverändert.
- **M4-Klassenbelohnungen** (`ProgressionRules.class_reward_items`: `steel_greatsword`, `oak_staff`, `iron_dagger`, Magic
  ilvl 5) lesen dieselben Pools und würfeln ebenfalls kein Thundering mehr. Am Class-Trials-Code ändert sich nichts. Die
  Suite `class_trials_m4` bleibt grün (sie prüft nur „Affix im Generierungspool“).
- Vier Affixe bleiben für alle zwölf Modelle in jeder Zugreihenfolge erreichbar (erschöpfende Suche, unverändert grün).

## 4. Bestehende Items

Gespeicherte Thundering-Rolls bleiben erhalten. `ItemInstance.from_dict` prüft Affixe nicht gegen `generation_affixes`,
`ItemStats.modifiers` liefert den gespeicherten `shock_damage`-Wert weiter, und es gibt keine Migration oder Bereinigung.
Auf Standardwaffen bleiben diese Rolls so wirkungslos wie vorher.

## 5. Spezialwaffen

`forged_blade`, `forged_greatsword` und `stormcaller_fang`:
- haben Essenz-Slots
- Thundering bleibt unter der globalen Regel eligibel
- mit `storm_wolf` liefert `ItemStats.effects` den `EssenceDischargeEffect`
- `AffixPool` bietet Thundering auf den Forged-Waffen weiter an

Getestet.

## 6. Tests (Efficient Testing 1.1)

`./tools/run_tests.ps1 -Suite "grove_warden_rare_pool,loot_foundation,hollowwood_loot,affix_pool,item_foundation,class_trials_m4"`
→ **78 passed, 0 failed**.

Neu bzw. ersetzt in `tests/unit/test_grove_warden_rare_pool.gd`. Der R1-Befundtest `test_thundering_rolls_on_all_nine_…`
ist ersetzt durch:

| Test | Prüft (Auftragspunkt) |
|---|---|
| `test_standard_weapons_never_roll_thundering` | nicht im Pool, nicht eligibel bei der Generierung, keine spätere Essenz möglich. 2400 Grove-Warden-Rolls und je 1500 Grunt-/Wolf-Rolls (Seed 2021) ohne Thundering (3, 4) |
| `test_storm_wolf_weapons_keep_thundering` | globale Regel und Werte unverändert; Essenzwaffen eligibel, Storm-Wolf-Effekt aktiv, Crafting bietet Thundering an (5) |
| `test_saved_thundering_rolls_stay_unchanged` | gespeicherter Roll, Basis und Round-Trip unverändert, Stat weiter vorhanden (6) |
| bestehende R1-Tests | zwölf Modelle Rare, 3 und 4 Affixe, keine Essenzen, Grunt/Wolf-Tabellen, Keen auf Rüstung/Schild, Tabelle ilvl 20 / Rare / 75-25 / gleichgewichtet (1, 2, 7–10) |

Keine Regressionen. Nicht ausgeführt: Full-Suite, `save` (bekannter Altfehler `test_migration_v3_to_v4` unberührt), Loops,
Arena, Galerie.

## 7. Verbleibende Blocker für R2

Der Thundering-Blocker aus R1 ist **behoben**. Der Grove-Warden-Pool würfelt keine wirkungslosen Affixe mehr; Ausnahme ist
`furious` vor der Klassenwahl (Audit §2, wirkt danach dauerhaft). Offen bleiben:
- die Audit-Entscheidungen E3–E10:
  - Erzeugungszeitpunkt
  - Claim-Ort
  - Altstände
  - Herkunft `found`/`quest_reward`
  - Claim in Trials
  - Meilenstein-Save
  - Rückmeldung/Loot-Feed
- Shield-Klassenbindung (`oak_shield` nur für Warrior, Guardian, Soulbinder)
- Definitions-Rarity von `wanderer_coat` (R1 §5)
