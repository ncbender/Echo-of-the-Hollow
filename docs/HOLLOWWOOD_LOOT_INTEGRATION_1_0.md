# Hollowwood Loot Integration 1.0 – Grunt & Wolf Equipment Drops

Branch `dev/hollowwood-loot-integration-10` (Basis `3c5fd08`, Loot Foundation 1.0). Erstmals entstehen im regulären
Spiel Normal- und Magic-Ausrüstungsitems: Die drei wiederholbaren Quellen sind an `ItemCreation.generate` und den
gemeinsamen `AffixRoller` angebunden. Keine Quests, kein Gold, keine Händler, kein Crafting-Umbau, keine neuen
Gegner/Spawns, keine Save-Änderung.

## 1. Hook- und Pickup-Audit (Phase A)

| Quelle | Lebenszyklus | Hook | Risiko doppelter Drops |
|---|---|---|---|
| Grunt-Gruppe `GruntA/B/C` (Whisper Forest) | in der Szene platziert, ohne `persistent_id`, kommt bei jedem Kartenladen wieder | `Enemy.defeated` (aus `Health.died` → `Enemy._on_died`) → `GameMap._spawn_drops` | `_spawn_drops` hatte keinen eigenen Schutz gegen ein zweites `defeated` |
| `road_side_wolves` (Old Road), `shrine_side_wolves` (Whispering Stone) | `Encounter` mit `persistent = false`; startet im Radius, kommt pro Kartenbesuch wieder | `Encounter._finish` (nur solange `running`) | `_on_enemy_defeated` zählte ein wiederholtes Signal desselben Wolfs doppelt → vorzeitiges Ende möglich |
| Pickup | `ItemPickup` (transient für Gegnerdrops) gab nur `item_id`/`quantity` an `Inventory.add_item` | – | Instanzdaten wären beim Aufheben neu erzeugt worden → **musste erweitert werden** |

Feste Drops: Grunt 1 `hollow_essence`, 2 `iron_ore`, Gold (`grunt_config.tres`); Wölfe ohne feste Drops.
Transiente Drops bleiben – wie bisher Gold/Material – nur bis zum Kartenwechsel liegen (keine Weltpersistenz neu erfunden).

## 2. Integration (Phasen B/C)

- **`EquipmentLootTable`** (Resource, `scripts/rpg/items/equipment_loot_table.gd`): Chance, Itemmodelle (gleich gewichtet),
  Rarity-Gewichte, Quelllevel ± Spanne, Tier-Tabelle; `validate(db)` prüft Modelle, Rarities und Tier-Abdeckung.
- **`EquipmentLoot.roll(table, db, rng)`**: genau eine Chance-Prüfung, dann Modell → Rarity → Item-Level → `ItemCreation.generate`
  (Herkunft `found`). Kein zweiter Generator, keine zweite Affixgenerierung, keine Neuberechnung der Waffenbasis.
- **Grunts:** `Enemy.equipment_loot` (Export) nur an `GruntA/B/C` gesetzt. `GameMap._spawn_drops` würfelt nach den unveränderten
  festen Drops einmal; Meta `equipment_rolled` verhindert jeden zweiten Wurf derselben Instanz. Grove Warden, Encounter-Gegner
  und Debug-Spawns haben keine Tabelle.
- **Wölfe:** `Encounter.completion_loot` (Export) nur an beiden `SideWolves`. `_finish` würfelt einmal am Ort des zuletzt
  gefallenen Wolfs. `_on_enemy_defeated` zählt jeden Gegner pro Durchlauf nur einmal (`_defeated`), wiederholte Signale nach dem
  Abschluss ändern nichts (`running` ist false). Kein Wurf pro Wolf. Die einmaligen Story-Encounters haben keine Tabelle.
- **Pickup:** `GameMap.spawn_item_pickup(item, at)` legt die erzeugte Instanz in ein `ItemPickup.item`; `try_pick_up` übergibt sie
  per `Inventory.add_instance` unverändert (gleiches Objekt, gleiche ID). Volles Inventar: bleibt liegen (bestehende Meldung),
  Reichweite/Berührung wie bisher, keine automatische Übertragung. Die Raute zeigt die Instanz-Rarity.
- **Zufall:** `GameMap.loot_rng` (pro Karte `randomize()`, in Tests setzbar).
- Save: unverändert **v14**. Liegende Drops werden nicht gespeichert (wie bisher); aufgenommene Items speichern ihre Instanzdaten.
  Laden löst keine Würfe aus (Würfe nur beim Tod bzw. Encounter-Abschluss).

## 3. Tabellen (freigegebene Werte)

| | Grunt (`data/loot/hollow_grunt_equipment.tres`) | Wölfe (`data/loot/hollowwood_wolves_equipment.tres`) |
|---|---|---|
| Ereignis | jeder getötete Grunt der Gruppe | jede abgeschlossene Begegnung (beide Gruppen) |
| Chance | 7 % | 15 % |
| Rarity | Normal 75 / Magic 25 | Normal 60 / Magic 40 |
| Item-Level | 5 ± 2 → 3–7 gleichverteilt | 10 ± 2 → 8–12 gleichverteilt |
| Modelle (gleich gewichtet) | iron_sword, iron_axe, iron_dagger, iron_mace, ash_spear, leather_cap, wanderer_coat | steel_greatsword, oak_staff, oak_wand, hunting_bow, oak_shield |
| Tiers | `hollowwood_early_tiers`: ilvl 1–9 nur T5; 10–24 T5 75 / T4 25 | dto. |

Affixe/Eligibility unverändert aus Loot Foundation 1.0 (Gewichte 100/90/80/30, LOCAL 100, Armored aus, Rüstung/Schild nur
Furious/Guarded/Vital, seit Grove Warden Rare R1 zusätzlich Keen, Bogen ohne Executioner). Magic 1/2/3 = 40/40/20; Normal 0 Affixe.

## 4. Tests (Phase D)

Neu `tests/integration/test_hollowwood_loot.gd` (10 Tests, feste Seeds):
- Tabellenwerte und Validierung; Dropchance 7 % / 15 % (20 000 Ereignisse, Toleranz ≈ 3,5 σ).
- Pools mit garantiertem Drop (3000 je Quelle): alle Modelle erreichbar, je 1/n ± 2,5 %; Magic 25 % / 40 % ± 3 %;
  nur Normal/Magic; Item-Level nur 3–7 bzw. 8–12 (alle fünf Grunt-Level kommen vor); eine Instanz, Herkunft `found`.
- Affixe: Normal ohne Affixe; Magic 1/2/3 ≈ 40/40/20 (± 3,5 %); ilvl 3–9 nur T5; ilvl 10–12 nur T5/T4 mit T4 25 % ± 4 %;
  keine Duplikate/Ausschlüsse, kein LOCAL auf Rüstung/Schild, nur erlaubte IDs.
- Echte Karten: Grunt-Tod → feste Drops exakt wie Config + genau ein Equipment-Drop; zweiter `_spawn_drops`-Aufruf → kein
  weiterer; Warden/Debug-Spawn ohne Tabelle. Old Road: erster Wolf → kein Drop, wiederholtes Signal zählt nicht doppelt,
  Abschluss → genau ein Drop, wiederholter Callback → nichts; Whispering Stone mit derselben Tabelle, Story-Encounters ohne.
- Pickup: volles Inventar → bleibt liegen; Aufheben übergibt dasselbe Objekt; `to_dict` (Basis, Rarity, Level, Affixe,
  Striking-Flat) identisch; Save/Load identisch, kein zusätzliches Item.
- Crafting-Regression: Forged Blade ilvl 12 → T5 75 % / T4 25 %, dieselben 11 GLOBAL-Affixe; Keen-T4 in 0,1-Schritten.

Mutationsprobe: Meta-Guard in `_spawn_drops` bzw. Dedupe in `Encounter` entfernt → je ein Test rot; zurückgesetzt.

Lauf: hollowwood_loot, pickup, enemy, hollowwood, loot_foundation, affix_pool, crafting_ops, inventory, save –
**85 bestanden, 0 fehlgeschlagen**; `tools/check_project.ps1` OK. Nicht gelaufen (Policy): Vollsuite, Prolog-Suites
(`old_road`, `prologue`, `story`), Haven-Loop, Klassen, Crafting-Loop, Galerie, Playtests, echte Saves.

## 5. Offen / Hinweise

- Der HUD-Loot-Feed (`item_received(item_id, quantity)`) zeigt Farbe/Wort der **Definitions**-Rarity; ein Magic-Drop
  erscheint dort als Normal (Tooltip, Inventar und Weltraute zeigen die Instanz-Rarity). Umstellung = Signaländerung, offen.
- `Encounter`-Dedupe wirkt auf alle Encounters (auch Prolog); es verhindert nur Doppelzählung desselben Gegners. Prolog-Suites
  liefen laut Policy nicht.
- Doppelte `defeated`-Signale würden die **festen** Drops weiterhin doppelt erzeugen (bestehendes Verhalten, bewusst nicht
  geändert; `Health` sendet `died` regulär einmal).
- Verkaufswert/Salvage weiterhin nach Definitions-Rarity (siehe Loot Foundation 1.0, §9).

## 6. Ausdrücklich unverändert

Feste Gegnerdrops (Gold, Hollow Essence, Eisenerz), alle anderen Gegner und Encounters, Grove Warden, Respawn-/Wiederholungslogik,
Quest-Rewards, Gold-Werte, Händler, Truhen/Weltobjekte, Crafting (UI, Rezepte, Operationen, Garantien), Affixe, Gewichte,
Tier-Tabellen, Combat-Timings, Klassen, Save-Version (v14).
