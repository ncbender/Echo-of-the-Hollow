class_name ProgressionRules
extends Resource
## XP tuning for class progression and character rules. PRELIMINARY values;
## the progression speed is not balanced yet (docs/PROGRESSION_SYSTEM.md).
## Weapon mastery XP comes only from kills, split by contribution
## (CombatRewardTracker, EnemyConfig.mastery_xp_reward).

@export_group("Character")
## Stats every character has regardless of class and gear.
@export var character_base_stats: Array[StatModifier] = [StatModifier.make(Stats.MAX_HEALTH, 100.0)]
## Class that a new character starts with (the prologue later replaces this choice).
@export var starting_class_id: StringName = &"basic_adventurer"
## Combat weapon family used while no weapon is equipped (placeholder until unarmed combat exists).
@export var fallback_weapon_family: StringName = &"one_handed_sword"

@export_group("Combat Stats")
## Bounds of the attack speed multiplier (1 + Attack Speed % / 100). Items, talents
## and skill buffs all add to the one Attack Speed stat; the result is clamped here.
@export var attack_speed_min: float = 0.75
@export var attack_speed_max: float = 1.4
## Status ids applied by the Bleed Chance / Chill Chance stats on weapon hits.
@export var bleed_status_id: StringName = &"bleeding"
@export var chill_status_id: StringName = &"chill"

@export_group("Talents")
## Talent tiers, points, slots and respec costs (data/progression/talent_rules.tres).
@export var talents: TalentRules
## Armor Mastery 1.0 values (burden, tiers, weights, milestones, provisional XP).
@export var armor_mastery: ArmorMasteryRules

@export_group("Prologue")
## Classes tried in the prologue; exactly one of them is chosen permanently.
@export var prologue_class_ids: Array[StringName] = [&"warrior", &"arcanist", &"shadowrunner"]
@export var prologue_map_id: StringName = &"prologue"
## Maps on which class trials (echoes) may run; leaving them ends a trial. Class
## Trials 2.0 M3: the three trial grounds (+ the developer grounds), no longer the
## Whispering Stone - returning to the altar ends a trial that is still running.
@export var trial_map_ids: Array[StringName] = [&"broken_bastion", &"shattered_sanctum", &"veiled_passage", &"prologue"]
## Class Trials 2.0 M4 (docs/CLASS_TRIALS_2_0_M4.md): the class reward of the one
## prologue choice - prologue class id -> weapon model (item id), generated once
## through ItemCreation.generate with this rarity, item level and tier table.
@export var class_reward_items: Dictionary = {&"warrior": &"steel_greatsword", &"arcanist": &"oak_staff", &"shadowrunner": &"iron_dagger"}
@export var class_reward_rarity: ItemDefinition.Rarity = ItemDefinition.Rarity.MAGIC
@export var class_reward_item_level: int = 5
@export var class_reward_tier_weights: AffixTierWeights
## Where a new journey begins (the Old Road south of Haven).
@export var new_game_map_id: StringName = &"old_road"
@export var new_game_spawn_id: StringName = &"default"

@export_group("Inventory")
@export var inventory_capacity: int = 40
## Haven stash (StashService, docs/STASH.md): slots of the Equipment Chest and the
## Collection Vault; the Material Vault has no slot limit. A restored stash ruin
## (Old Storehouse) adds the bonus - capacity only grows, nothing is ever pushed out.
@export var stash_equipment_slots: int = 60
@export var stash_collection_slots: int = 40
@export var stash_restored_equipment_bonus: int = 60
@export var stash_restored_collection_bonus: int = 40
## Items every new character starts with (ids from data/items).
@export var starting_items: Array[ItemCost] = []

@export_group("Hearth Flask & Potions")
## Hearth Flask (a character feature, not an item). Charges at upgrade level 0
## and the charges each capacity upgrade adds; costs are gold (provisional).
@export var flask_base_charges: int = 2
@export var flask_capacity_costs: PackedInt32Array = PackedInt32Array([150, 450, 1100, 2400])
## Share of max health healed per charge: index = potency upgrade level (0 = base).
@export var flask_potency_heal: PackedFloat32Array = PackedFloat32Array([0.30, 0.40, 0.50, 0.60, 0.70])
@export var flask_potency_costs: PackedInt32Array = PackedInt32Array([200, 550, 1300, 2800])
## Drinking the flask: seconds until the heal lands, movement share meanwhile.
@export var flask_drink_time: float = 1.1
@export var drink_move_multiplier: float = 0.45
## Special potions: drink time and the shared cooldown from a successful drink.
## The movement share while drinking is the flask's (no own value designed).
@export var potion_drink_time: float = 0.7
@export var potion_cooldown: float = 30.0

@export_group("Economy")
## Sell value factor per rarity (index = ItemDefinition.Rarity: Normal, Magic, Rare,
## Epic, Legendary). Provisional. Unique and Set use special_sell_value instead.
@export var rarity_sell_factors: PackedFloat32Array = PackedFloat32Array([1.0, 1.6, 2.5, 4.0, 7.0])

@export_group("Salvaging")
## Share of an item base's raw materials returned by salvaging, per rarity
## (index = ItemDefinition.Rarity: Normal, Magic, Rare, Epic, Legendary) as
## (min %, max %). Provisional balance (Item Integrity 1.0). Unique and Set
## items are never salvaged.
@export var salvage_return_percent: PackedVector2Array = PackedVector2Array([Vector2(20, 30), Vector2(20, 30), Vector2(25, 35), Vector2(25, 35), Vector2(30, 40)])

@export_group("Crafting")
## Loot Foundation 1.0: affix tier draw of the crafting pool (AffixPool). Uses the approved early
## Hollowwood table (item level 1-24); higher item levels are not configured (no tier is drawn).
@export var crafting_tier_weights: AffixTierWeights

@export_group("Class XP")
## Class XP for an accepted hit on a non-training target.
@export var class_xp_per_hit: int = 1


func talent_rules() -> TalentRules:
	if talents == null:
		talents = TalentRules.new()
	return talents


func armor_rules() -> ArmorMasteryRules:
	if armor_mastery == null:
		armor_mastery = ArmorMasteryRules.new()
	return armor_mastery
