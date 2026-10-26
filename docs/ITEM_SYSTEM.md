# Item-System

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Definition vs. Instanz ✅
| `ItemDefinition` (Resource, `data/items/`) | `ItemInstance` (Laufzeit, gespeichert) |
|---|---|
| stabile `id`, Name, Beschreibung | `instance_id` (64-Bit-Zufall, `itm_…`), unveränderlich |
| `category`: Weapon, Armor, Jewelry, Trinket, Material, Consumable, Quest | `definition_id` |
| `rarity`: Normal, Magic, Rare, Epic, Legendary, Unique, Set | `quantity` |
| `max_stack`, `slot_kind`, `weapon_family_id` | `affixes` (gewürfelt: affix, tier, stat, Wert) ✅ |
| `base_stats`, `effects`, `set_id` | `item_level`, `quality`, `material_id` ✅ |
| `required_class_ids` ✅, `required_class_level` 🔧, `tags` | `essences` (≤ 2), `sockets`, `evolution` (stage, xp, path) ✅ |
| `crafting` (`CraftingProfile`, null = nicht craftbar) ✅ | `progress` (freie Daten, geparkte Einträge), `revision` ✅ |

Der Crafting-Zustand gehört zur Instanz. Er wird so gespeichert, wie er gewürfelt wurde, und nie
neu berechnet. Was ein ausgerüstetes Item beiträgt, liefert zentral `ItemStats`:
- Basiswerte × Qualität
- Affixe
- Materialprägung
- Sockel
- Essenzen und Resonanz
- Evolution

Details stehen in `CRAFTING_DESIGN.md`.

Ausrüstbare Items stapeln nie (validiert). Datenprüfung in `ItemDefinition.validate()` und
`GameDatabase.validate()` (unbekannte Familien/Sets/Items).

## Inventar ✅ (`Inventory`)
- Slot-Inventar, Kapazität 40 (Regeln), jede Instanz/jeder Stapel = 1 Slot. Ausnahme seit UI/UX Polish 1.1:
  Währung (`ItemDefinition.is_currency`, Gold) bleibt als Stapel im Inventar (Save-Format unverändert,
  keine Migration), belegt aber keinen Taschenplatz und erscheint in der UI als Gold-Zähler.
- Schnelles Ausrüsten (Rechtsklick) wählt den Slot über `CharacterEquipment.quick_slot`: erster freier
  passender Slot (Ring 1 vor Ring 2, Main Hand vor Off Hand bei Dual Wield), sonst der erste (Ersatz).
  Ablegen braucht keinen freien Platz, weil ausgerüstete Items ohnehin im Inventar liegen.
- `add_item` füllt erst Stapel, dann neue Slots – **alles oder nichts**.
- `remove_quantity` (über Stapel, atomar), `take`, `set_quantity` (1..max_stack), `remove_instance`,
  `find(instance_id)`, `count`, `room_for`, `transfer_to` (Ziel wird vorher geprüft).
- Garantien (`integrity_errors()`): keine doppelten IDs, keine Mengen ≤ 0 oder > max_stack, keine
  unbekannten Definitionen, Kapazität eingehalten. Zufalls-Fuzztest mit 500 Operationen.
- Ausgerüstete Items **bleiben im Inventar** (Ausrüstung referenziert nur) → zählen zur Kapazität.

## Welt ✅
- `ItemPickup`: Berühren → Inventar; bei vollem Inventar bleibt es liegen (nie Verlust).
- Platzierte Pickups haben `persistent_id`; nach dem Aufheben setzt ein Welt-Flag fest, dass sie nicht
  wieder erscheinen (verhindert Duplikation durch Neuladen/Laden – im Playtest gefunden und behoben).
- Gegner-Drops (`EnemyConfig.drops`) sind flüchtige Pickups.

## UI ✅
**I** öffnet Inventar + Ausrüstung: Raster (Seltenheitsfarbe, Menge, `[E]` = ausgerüstet), Details,
Aktionen (Ausrüsten, Off-hand, Ring 1/2, Ablegen, Verwerfen). Debug **F7**: ein Exemplar jedes
ausrüstbaren Items + Baumaterial.

## Testitems (handgestaltet, 28 + Crafting)
Waffen: Iron Sword, Militia Sword (Magic), Steel Greatsword, **Echo Blade (Legendary)**,
**Crushing Oath (Unique)** · Schild: Oak Shield · Rüstung für alle Slots inkl. Warlord's Greathelm
(nur Krieger) · Set „Hollow Warden“ (Helm, Mail, Greaves) · Ringe, Amulett, Trinket · Materialien
(Iron Ore, Timber, Hollow Essence) · Minor Potion (Consumable, 🔧 noch ohne Benutzen-Aktion) · Old Key (Quest).
Crafting Foundation 0.1: Basen **Forged Blade**, **Forged Greatsword**, evolvierend **Stormcaller Fang**;
Materialien Bloodsteel Ingot, Storm Ore, Frost Glass; Währungen Imprint Shard, Transmutation Core,
Focus Catalyst, Socket Chisel, Forge Crystal, Awakening Stone, Essence Siphon; Essenzen Storm Wolf,
Stone Golem; Einlagen Garnet, Rune of Impact. Crushing Oath hat ein begrenztes Crafting-Profil.
Debug **F4**: Crafting-Kit.

## Offen
⬜ Loot-Generator mit Affix-Rolls (Crafting-Rolls ✅), ⬜ Verbrauchsgüter benutzen, ⬜ Sortieren/Stapel
teilen in der UI. Essenzen, Sockel, Evolution ✅ (`CRAFTING_DESIGN.md`).
