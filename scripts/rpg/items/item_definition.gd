class_name ItemDefinition
extends Resource
## Static data of an item type. Runtime copies are ItemInstance objects.

enum Category { WEAPON, ARMOR, JEWELRY, TRINKET, MATERIAL, CONSUMABLE, QUEST }
enum Rarity { NORMAL, MAGIC, RARE, EPIC, LEGENDARY, UNIQUE, SET }
## Armor Mastery 1.0: material class of an armour piece (NONE = not armour,
## or not clearly one of the four - then it adds no burden and no mastery).
enum ArmorType { NONE, CLOTH, LEATHER, MAIL, PLATE }
enum SlotKind {
	NONE, HEAD, SHOULDERS, BACK, CHEST, WRISTS, HANDS, BELT, LEGS, FEET,
	ONE_HAND_WEAPON, TWO_HAND_WEAPON, OFF_HAND, SHIELD, RING, NECK, TRINKET,
}

const RARITY_COLORS := {
	Rarity.NORMAL: Color("d8d4c8"), Rarity.MAGIC: Color("6fa8ff"), Rarity.RARE: Color("f2d14b"),
	Rarity.EPIC: Color("b46cff"), Rarity.LEGENDARY: Color("ff9a3c"), Rarity.UNIQUE: Color("e0c38a"),
	Rarity.SET: Color("5fd38a"),
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.MATERIAL
@export var rarity: Rarity = Rarity.NORMAL
@export var max_stack: int = 1
## Currency (gold): kept in the inventory like any stack (save format unchanged),
## but shown as a wallet counter and it takes no bag slot.
@export var is_currency: bool = false
## Recipe item: using it teaches this profession recipe (ProfessionService.learn_from_item).
@export var teaches_recipe_id: StringName

@export_group("Economy")
## Base Item Value (Loot Economy 1.0): sell value = base value x rarity factor
## (rules.rarity_sell_factors). 0 = no value designed yet - the item cannot be sold.
@export var base_value: int = 0
## Unique and Set items keep their own value (never derived from rarity); 0 = never sold.
@export var special_sell_value: int = 0

@export_group("Equipment")
@export var slot_kind: SlotKind = SlotKind.NONE
@export var armor_type: ArmorType = ArmorType.NONE
## Combat weapon family used when equipped in the main hand.
@export var weapon_family_id: StringName
@export var base_stats: Array[StatModifier] = []
## Event-driven effects and combo modifiers (legendary / unique).
@export var effects: Array[ItemEffect] = []
@export var set_id: StringName

@export_group("Requirements")
## Classes allowed to equip this item (empty = all).
@export var required_class_ids: Array[StringName] = []
## Prepared, not enforced yet.
@export var required_class_level: int = 0

@export_group("Defense")
## Shields: block/parry profile used on Shift while equipped in the off hand
## (overrides the weapon's profile).
@export var defense_profile: DefenseProfile

@export_group("Consumable")
## Special potion: its timed buff (ConsumableService). Null for everything else.
@export var potion_effect: PotionEffectDefinition

@export_group("Crafting")
## Crafting capabilities (null = not craftable). See docs/CRAFTING_DESIGN.md.
@export var crafting: CraftingProfile

@export_group("")
@export var tags: Array[StringName] = []


func is_stackable() -> bool:
	return max_stack > 1


func is_equippable() -> bool:
	return slot_kind != SlotKind.NONE


func is_weapon() -> bool:
	return slot_kind == SlotKind.ONE_HAND_WEAPON or slot_kind == SlotKind.TWO_HAND_WEAPON


## Item Foundation 1.0: weapons and armour allow LOCAL and GLOBAL affixes; rings and
## amulets only GLOBAL. Off hand and trinket are not decided yet and stay GLOBAL only.
static func allows_local_affixes(kind: SlotKind) -> bool:
	return kind in [SlotKind.ONE_HAND_WEAPON, SlotKind.TWO_HAND_WEAPON, SlotKind.HEAD, SlotKind.SHOULDERS,
		SlotKind.BACK, SlotKind.CHEST, SlotKind.WRISTS, SlotKind.HANDS, SlotKind.BELT, SlotKind.LEGS,
		SlotKind.FEET, SlotKind.SHIELD]


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("item without id (%s)" % resource_path)
	if max_stack < 1:
		errors.append("item %s: max_stack < 1" % id)
	if is_equippable() and max_stack != 1:
		errors.append("item %s: equippable items must not stack" % id)
	if is_weapon() and weapon_family_id == &"":
		errors.append("item %s: weapon without weapon_family_id" % id)
	for effect in effects:
		if effect == null:
			errors.append("item %s: null effect" % id)
	if crafting != null:
		if not is_equippable():
			errors.append("item %s: only equippable items can be craftable" % id)
		errors.append_array(crafting.validate(id))
		for operation in crafting.allowed_operations:
			if not operation in CraftingOps.ALL:
				errors.append("item %s: unknown crafting operation %s" % [id, operation])
	return errors
