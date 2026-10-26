class_name ArmorMasteryRules
extends Resource
## Armor Mastery 1.0 values (docs/ARMOR_MASTERY.md). The burden table, tiers,
## slot weights and milestones are the designed values; the XP amounts and the
## level curve are PROVISIONAL (not designed yet, no playtest).

## Counted armour slots (only these carry burden and mastery): EquipSlot.Slot.
const SLOTS: Array[int] = [EquipSlot.Slot.HEAD, EquipSlot.Slot.CHEST, EquipSlot.Slot.HANDS, EquipSlot.Slot.LEGS, EquipSlot.Slot.FEET]
const TYPES: Array[int] = [ItemDefinition.ArmorType.CLOTH, ItemDefinition.ArmorType.LEATHER, ItemDefinition.ArmorType.MAIL, ItemDefinition.ArmorType.PLATE]

## Burden points per slot (order of SLOTS) for Cloth, Leather, Mail, Plate.
@export var burden_cloth: PackedInt32Array = PackedInt32Array([1, 3, 1, 2, 1])
@export var burden_leather: PackedInt32Array = PackedInt32Array([2, 5, 2, 4, 2])
@export var burden_mail: PackedInt32Array = PackedInt32Array([3, 8, 3, 6, 4])
@export var burden_plate: PackedInt32Array = PackedInt32Array([5, 13, 5, 10, 6])
## Tier starts: Balanced from 15, Burdened from 26, Heavy from 38 (Light below).
@export var tier_starts: PackedInt32Array = PackedInt32Array([15, 26, 38])
## Per tier (Light, Balanced, Burdened, Heavy): % slower walking, % longer attack recovery.
@export var tier_move_penalty: PackedFloat32Array = PackedFloat32Array([0.0, 2.0, 5.0, 8.0])
@export var tier_recovery_penalty: PackedFloat32Array = PackedFloat32Array([0.0, 2.0, 5.0, 8.0])
## Share of mastery XP and of milestone bonuses per slot (order of SLOTS).
@export var slot_weights: PackedFloat32Array = PackedFloat32Array([0.15, 0.40, 0.10, 0.25, 0.10])
@export var max_level: int = 20

@export_group("XP (provisional)")
## XP for level n -> n+1: round(xp_base * xp_growth^(n-1)).
@export var xp_base: float = 100.0
@export var xp_growth: float = 1.15
## A successful block or parry of a real enemy attack (once per attack).
@export var xp_per_defense: float = 3.0
## Most defense XP one enemy can give (no farming one weak enemy).
@export var defense_xp_cap_per_enemy: float = 15.0

## Milestones: [armor type, level, stat, value at full coverage]. Iron
## Discipline (plate 20) lowers the burden walking penalty instead of a stat.
const IRON_DISCIPLINE := &"iron_discipline"
const MILESTONES := [
	[ItemDefinition.ArmorType.CLOTH, 5, Stats.MAGIC_RESISTANCE, 2.0],
	[ItemDefinition.ArmorType.CLOTH, 10, Stats.SKILL_RECOVERY_SPEED, 2.0],
	[ItemDefinition.ArmorType.CLOTH, 15, Stats.MAGIC_RESISTANCE, 2.0],
	[ItemDefinition.ArmorType.CLOTH, 20, Stats.SKILL_RECOVERY_SPEED, 2.0],
	[ItemDefinition.ArmorType.LEATHER, 5, Stats.MOVE_SPEED, 1.0],
	[ItemDefinition.ArmorType.LEATHER, 10, Stats.ATTACK_RECOVERY_SPEED, 2.0],
	[ItemDefinition.ArmorType.LEATHER, 15, Stats.MOVE_SPEED, 1.0],
	[ItemDefinition.ArmorType.LEATHER, 20, Stats.ATTACK_RECOVERY_SPEED, 2.0],
	[ItemDefinition.ArmorType.MAIL, 5, Stats.POISE, 3.0],
	[ItemDefinition.ArmorType.MAIL, 10, Stats.BLOCK_EFFICIENCY, 2.0],
	[ItemDefinition.ArmorType.MAIL, 15, Stats.POISE, 3.0],
	[ItemDefinition.ArmorType.MAIL, 20, Stats.BLOCK_EFFICIENCY, 2.0],
	[ItemDefinition.ArmorType.PLATE, 5, Stats.POISE, 2.0],
	[ItemDefinition.ArmorType.PLATE, 10, Stats.PHYSICAL_RESISTANCE, 1.0],
	[ItemDefinition.ArmorType.PLATE, 15, Stats.POISE, 2.0],
	[ItemDefinition.ArmorType.PLATE, 20, IRON_DISCIPLINE, 1.0],
]


func burden_of(type: int, slot_index: int) -> int:
	var table: PackedInt32Array = {ItemDefinition.ArmorType.CLOTH: burden_cloth, ItemDefinition.ArmorType.LEATHER: burden_leather,
		ItemDefinition.ArmorType.MAIL: burden_mail, ItemDefinition.ArmorType.PLATE: burden_plate}.get(type, PackedInt32Array())
	return table[slot_index] if slot_index < table.size() else 0


func xp_to_next(level: int) -> int:
	return 0 if level >= max_level else roundi(xp_base * pow(xp_growth, level - 1))
