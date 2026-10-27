class_name EquipSlot
extends RefCounted
## The 15 equipment positions and which item slot kinds may go where.

enum Slot {
	HEAD, SHOULDERS, BACK, CHEST, WRISTS, HANDS, BELT, LEGS, FEET,
	MAIN_HAND, OFF_HAND, RING_1, RING_2, NECK, TRINKET,
}

const NAMES := {
	Slot.HEAD: "Head", Slot.SHOULDERS: "Shoulders", Slot.BACK: "Back", Slot.CHEST: "Chest",
	Slot.WRISTS: "Wrists", Slot.HANDS: "Hands", Slot.BELT: "Belt", Slot.LEGS: "Legs", Slot.FEET: "Feet",
	Slot.MAIN_HAND: "Main Hand", Slot.OFF_HAND: "Off Hand", Slot.RING_1: "Ring 1", Slot.RING_2: "Ring 2",
	Slot.NECK: "Neck", Slot.TRINKET: "Trinket",
}

const _BY_KIND := {
	ItemDefinition.SlotKind.HEAD: [Slot.HEAD],
	ItemDefinition.SlotKind.SHOULDERS: [Slot.SHOULDERS],
	ItemDefinition.SlotKind.BACK: [Slot.BACK],
	ItemDefinition.SlotKind.CHEST: [Slot.CHEST],
	ItemDefinition.SlotKind.WRISTS: [Slot.WRISTS],
	ItemDefinition.SlotKind.HANDS: [Slot.HANDS],
	ItemDefinition.SlotKind.BELT: [Slot.BELT],
	ItemDefinition.SlotKind.LEGS: [Slot.LEGS],
	ItemDefinition.SlotKind.FEET: [Slot.FEET],
	ItemDefinition.SlotKind.ONE_HAND_WEAPON: [Slot.MAIN_HAND],   # one weapon slot (Weapon Mastery 1.4): no weapon in the off hand
	ItemDefinition.SlotKind.TWO_HAND_WEAPON: [Slot.MAIN_HAND],
	ItemDefinition.SlotKind.OFF_HAND: [Slot.OFF_HAND],
	ItemDefinition.SlotKind.SHIELD: [Slot.OFF_HAND],
	ItemDefinition.SlotKind.RING: [Slot.RING_1, Slot.RING_2],
	ItemDefinition.SlotKind.NECK: [Slot.NECK],
	ItemDefinition.SlotKind.TRINKET: [Slot.TRINKET],
}


static func allowed_slots(definition: ItemDefinition) -> Array:
	return _BY_KIND.get(definition.slot_kind, [])


static func display_name(slot: int) -> String:
	return NAMES.get(slot, "?")


static func key_of(slot: int) -> String:
	return Slot.keys()[slot]


## Slot from its saved key, or -1.
static func from_key(key: String) -> int:
	return Slot.keys().find(key)
