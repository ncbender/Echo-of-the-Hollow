# Weapon Base Damage 1.1 – Item Instance Scaling & Forged Weapons

Branch `dev/weapon-base-damage-11` (Basis `6e6c51e`, = 1.0). Erweitert `WEAPON_BASE_DAMAGE_1_0.md`; was dort nicht
widerrufen wird, gilt weiter.

## 1. Erzeugungs- und Save-Audit (Phase A)
- **Einziger Laufzeit-Erzeugungsweg** neuer Instanzen: `Inventory.add_item` (Startausrüstung `CharacterFactory`, Rezepte
  `ProfessionService`/`BaseBuilder`, Pickups, Story, Lesbares, Salvage-/Crafting-Rückgaben, Debug F4/F7, Lager über dasselbe
  `Inventory`). Dazu eine Tooltip-Vorschau in `professions_panel.gd`.
- **Keine Neuerzeugung:** Lagertransfer (`StashService._move` → `add_instance`), Laden (`ItemInstance.from_dict`), Ausrüsten.
- **Test-Fixtures:** `ItemInstance.create` bleibt eine reine Identitätsfabrik (ohne Level, ohne Basis); Tests, die Schaden
  prüfen, nutzen `ItemCreation.create`.
- **Item-Level-Quellen:** `CraftingProfile.base_item_level` (forged_*: 12) oder das neue `ItemDefinition.base_item_level`
  (freigegebenes Level für Items ohne Profil; die zehn Referenzwaffen: 1) oder ein vom Aufrufer übergebenes Level
  (`Inventory.add_item(..., item_level)`, heute nur in Tests). Nichts aus dem Charakterlevel, keine neue Loot-Quelle.
  Validierung: Modellwaffen ohne Level 1..100 sind ungültig; Profil + `base_item_level` zugleich ist ungültig.
  **Kein Erzeugungsweg ist blockiert** – alle zwölf Modellwaffen haben eine freigegebene Quelle.
- **Save:** Migrationen sind reine Dictionary-Funktionen ohne Datenbank → Einmalübernahme über eine eingefrorene Tabelle.

## 2. Modell
```
model_factor        = base_weapon_damage(Definition) / B_ref(Erzeugungslevel)      WeaponDamage.model_factor (exakt, nie gerundet)
Instanz-Basis       = B_ref(item_level) × model_factor                             einmalig in ItemCreation.create
D_weapon            = (gespeicherte Basis × Q + Local-Flat) × (1 + Local-% / 100)  WeaponDamage.of
D_attack            = D_weapon × weapon_damage_multiplier                          CombatComponent (unverändert)
```
- `ItemInstance.base_weapon_damage`, gespeichert als `"base_damage"` (nur wenn > 0). Danach nie neu berechnet: Quality, Crafting,
  Ausrüsten/Ablegen, Tasche↔Lager, Speichern/Laden lassen ihn unverändert (getestet, auch mit einem von den Daten abweichenden Wert).
- Quality wirkt nur im effektiven D_weapon, nie auf den Rohwert, globale Stats oder Haltung.
- Fehlt einer Modellwaffe nach dem Laden der Wert (nur bei manipulierten Dateien möglich), meldet `ItemStats.sanitize` eine
  Warnung; es wird nichts nachberechnet.

## 3. Umgestellte Items (12)
| Item | Familie | Item-Level (Quelle) | model_factor | Basis bei Erzeugung |
|---|---|---|---|---|
| iron_sword, steel_greatsword, iron_axe, iron_dagger, iron_mace, ash_spear, oak_staff, oak_wand, hunting_bow | je Familie | 1 (`base_item_level`) | 1.0 | 12 / 22 / 14 / 9 / 15 / 13 / 13 / 10 / 13 |
| militia_sword | one_handed_sword | 1 (`base_item_level`) | 1.05 (12,6 / 12) | 12,6 (globaler +5 % bleibt entfernt) |
| **forged_blade** | one_handed_sword | 12 (Profil) | 14,40 / 13,584 = 1,0600706713780919… | 14,40 |
| **forged_greatsword** | two_handed_sword | 12 (Profil) | 27,39 / 24,904 = 1,0998233215547703… | 27,39 |

Andere Level folgen der Kurve, z. B. forged_blade ilvl 1 → 12,72; ilvl 30 → 17,15; forged_greatsword ilvl 1 → 24,20.
Alle Level-1-Referenztreffer (Quick/Heavy, Precision, Thousand Cuts, Forks, Flowing Draw) bleiben exakt wie in 1.0.

**Forged (V3):** globales `physical_damage` (+6 / +10) entfernt, globales `poise_damage` (+4 / +8) bleibt global und wird von
Quality nicht mehr verstärkt. Profil, 4 Affixplätze, 2 Essenzen, 2 Sockel, Imprint, Quality, Reforge unverändert. Gespeicherte
Sharpened-Affixe bleiben GLOBAL.

**Vorher/Nachher Forged** (Basistreffer, ohne andere Stats):
| | Quick Q0 | Heavy Q0 | Quick Q20 | Heavy Q20 |
|---|---|---|---|---|
| forged_blade vorher (12 bzw. 26 × (1 + 6 % × Q)) | 12,72 | 27,56 | 12,79 | 27,72 |
| forged_blade nachher | **14,40** | **31,20** | **15,84** | **34,32** |
| forged_greatsword vorher (22 bzw. 48 × (1 + 10 % × Q)) | 24,20 | 52,80 | 24,42 | 53,28 |
| forged_greatsword nachher | **27,39** | **59,76** | **30,13** | **65,74** |
Waffentreffer steigen um +13,2 % (Blade) bzw. +13,2 % (Greatsword) bei Q0 – das ist der freigegebene V3-Effekt (Referenz
bei ilvl 12 + Bonus lokal statt Referenz bei ilvl 1 + Bonus global).

**Unverändert:** stormcaller_fang, crushing_oath, echo_blade (V2 später) – Kompatibilitätsgrenze aus 1.0, globale Boni und Quality wie bisher.

## 4. Striking
Ganzzahliger Prozentfaktor je Tier (T5 3–6, T4 5–9, T3 8–12, T2 11–16, T1 15–22; Schwellen 1/10/25/45/70), einmalig
`flat = B_ref(item_level) × Faktor / 100` aus der **Familienreferenz** (nicht Modellfaktor, nicht Quality). Gespeichert:
`"flat"` (Double, keine Rundung) und `"share"` (Faktor). Beim Laden nie neu gewürfelt. Tooltip: eine Nachkommastelle
(„+0.9 Weapon Damage (local)“). Tempered Blade unverändert.
**Pools:** LOCAL-Affixe werden von **keinem** Pool angeboten (1.0 bot sie auf Modellwaffen an; durch die Forged-Umstellung wären
sie sonst auf Forged Blade/Greatsword würfelbar geworden – laut Auftrag keine zusätzlichen Pools). Berechnung, Speicherung und
Anzeige funktionieren.

## 5. Save v12
- `SaveSystem.VERSION` 11 → **12**, Migration `_v11_to_v12` (Tasche, Lager, Waisen): Modellwaffen ohne `base_damage` erhalten
  den Wert aus der eingefrorenen Tabelle `SaveMigrations.V12_WEAPON_MODELS` und ihrem gespeicherten ilvl (fehlt: 1).
  Vorhandene Werte werden nie ersetzt; Affixe, Quality, Spezialwaffen, Materialien unverändert. Ein Test prüft, dass die
  Tabelle den freigegebenen Daten entspricht.
- **Folgen für v11-Stände:** forged_* verlieren ihren globalen `physical_damage`-Basisbonus und erhalten die lokale Basis
  (ilvl 12 → 14,40 / 27,39); militia_sword erhält 12,6. Ein v12-Save ist für ältere Builds „neuer“ und wird dort abgelehnt.
- **Genauigkeit:** Der Payload-Text wird jetzt mit voller Präzision (17 Stellen) geschrieben. Godots JSON-Parser rundet
  17-stellige Zahlen nicht immer korrekt; nach Save/Load ist der Wert bis auf das letzte Bit gleich (Abweichung ≤ 1e-15
  relativ, getestet mit Toleranz 1e-12) und wird nie neu berechnet.
- Keine echten Saves oder `settings.cfg` berührt.

## 6. Physische Skills (nur Bericht, keine Kompensation)
Physische Skills (Standardtyp physical): blade_fan, blade_rush, death_mark, execution, expose_weakness, furious_strike,
shadow_strike, shadowstep, smoke_veil, warbreaker, whirlwind. Sie nutzen globales `physical_damage`. Mit ausgerüsteter
| Waffe | Skillschaden gegenüber vorher (Q0) | bei Q20 vorher |
|---|---|---|
| forged_blade | ÷ 1,06 (−5,7 %) | vorher +6,6 % |
| forged_greatsword | ÷ 1,10 (−9,1 %) | vorher +11 % |
| militia_sword (seit 1.0) | ÷ 1,05 (−4,8 %) | – |
Globales Sharpened, Imprints, Sockel und Talente wirken unverändert weiter auf Skills.

## 7. Tests
`test_weapon_base_damage` (23 Tests, 8 neu für 1.1): Forged vorher/nachher + Quality 20, Quality ändert globales Poise/
Physical nicht, physische Skills (Abweichung), Erzeugung mit zwei Item-Leveln (forged 12/30, axe 1/50), Basis unverändert über
Quality/Ausrüsten/Lager/Save-Load (Striking-Flat inklusive), Tooltip, v11→v12-Migration, echter Treffer forged_greatsword 27,39.
Alle neun Familien Quick/Heavy, militia, Tempered Blade + Striking, Spezialwaffen aus 1.0 weiter enthalten.
Mutationsprobe (Basiszuweisung in `ItemCreation` abgeschaltet) → 9 Tests rot.
Angepasst: `test_item_foundation`, `test_sockets_quality` (Forged-Quality nur auf die Basis), `test_crafting_save` (Version),
`test_save_foundation`, `test_prologue` (v12 ergänzt `base_damage` in Alt-Payloads).

Lauf: weapon_base_damage, item_foundation, affix_pool, crafting_stats, sockets_quality, crafting_ops, crafting_save, essences,
evolution, forge_ui, save, save_foundation, stash, stash_ui, equipment, inventory, inventory_ui, salvage, item_effects,
professions, combat_data, weapon_families, hits, bow, defense, combat_flow_player, mastery, weapon_switch, skills –
**261 bestanden, 0 fehlgeschlagen**. `check_project.ps1`: OK.
- `test_prologue` wurde angepasst, aber laut Auftrag **nicht ausgeführt** (Prolog-Suite).
- `crafting_loop::test_crafting_vertical_slice` schlägt fehl (Discharge/Rune im Arenakampf) – **vorbestehend**: identisch auf
  `6e6c51e` (1.0) und `e0575f4` (vor 1.0) in einem separaten Worktree reproduziert; nicht Teil dieser Arbeit.

## 8. Blocker und offene Fragen
1. Aktivierung von Tempered Blade/Striking in Augment/Reforge (welche Waffen, Gewichte) – offen, daher in keinem Pool.
2. Spezialwaffen V2 (stormcaller_fang, crushing_oath, echo_blade) – beschlossen, nicht umgesetzt.
3. Forged-Treffer +13,2 % und physische Skills −5,7/−9,1 % – Balance-Folgen des freigegebenen V3, nicht nachjustiert.
4. Künftige Loot-Level-Quellen: nur über den explizit übergebenen Parameter vorbereitet, keine Quelle angelegt.
5. Vorbestehender Fehler `test_crafting_vertical_slice` (siehe §7).
