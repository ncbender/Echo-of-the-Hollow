# Item-System

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Definition vs. Instanz ✅
| `ItemDefinition` (Resource, `data/items/`) | `ItemInstance` (Laufzeit, gespeichert) |
|---|---|
| stabile `id`, Name, Beschreibung | `instance_id` (64-Bit-Zufall, `itm_…`), unveränderlich |
| `category`: Weapon, Armor, Jewelry, Trinket, Material, Consumable, Quest | `definition_id` |
| `rarity`: Normal, Magic, Rare, Epic, Legendary, Unique, Set | `quantity` |
| `max_stack`, `slot_kind`, `weapon_family_id` | `affixes` (individuelle Stat-Modifikatoren) ✅ |
| `base_stats`, `effects`, `set_id` | `progress` 🔧, `essence` 🔧, `evolution` 🔧 |
| `required_class_ids` ✅, `required_class_level` 🔧, `tags` | |

Ausrüstbare Items stapeln nie (validiert). Datenprüfung in `ItemDefinition.validate()` und
`GameDatabase.validate()` (unbekannte Familien/Sets/Items).

## Inventar ✅ (`Inventory`)
- Slot-Inventar, Kapazität 40 (Regeln), jede Instanz/jeder Stapel = 1 Slot.
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

## Testitems (handgestaltet, 28)
Waffen: Iron Sword, Militia Sword (Magic), Steel Greatsword, **Echo Blade (Legendary)**,
**Crushing Oath (Unique)** · Schild: Oak Shield · Rüstung für alle Slots inkl. Warlord's Greathelm
(nur Krieger) · Set „Hollow Warden“ (Helm, Mail, Greaves) · Ringe, Amulett, Trinket · Materialien
(Iron Ore, Timber, Hollow Essence) · Minor Potion (Consumable, 🔧 noch ohne Benutzen-Aktion) · Old Key (Quest).

## Offen
⬜ Loot-Generator/Affix-Rolls, ⬜ Verbrauchsgüter benutzen, ⬜ Sortieren/Stapel teilen in der UI,
⬜ Essenzen/Entwicklung (Felder vorbereitet).
