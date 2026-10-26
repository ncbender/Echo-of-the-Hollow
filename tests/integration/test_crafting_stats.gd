extends GameplayTestCase
## Crafting phase B: rolled affixes and the material imprint reach the character
## stats and the real hit pipeline (CharacterStatModifier on the CombatComponent).

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")

var db: GameDatabase


func before_each() -> void:
	db = GameDatabase.get_default()


func test_affixes_and_imprint_resolve_into_stats() -> void:
	var character := CharacterFactory.create_new(db)
	var blade := character.inventory.add_item(&"forged_blade")[0]
	blade.material_id = &"frost_glass"
	blade.affixes.append({"affix": "cruel", "tier": 3, "stat": "crit_damage", "flat": 12.0, "percent": 0.0})
	var before := character.get_stat(Stats.POISE_DAMAGE)
	check_eq(character.equipment.equip(blade.instance_id, EquipSlot.Slot.MAIN_HAND), "", "equipped")
	check_near(character.get_stat(Stats.CRIT_DAMAGE), 12.0, 0.001, "affix stat")
	check_near(character.get_stat(Stats.POISE_DAMAGE) - before, 4.0 + 8.0, 0.001, "base poise 4 + frost glass imprint 8")
	check_near(character.get_stat(Stats.KNOCKBACK_POWER), 10.0, 0.001, "imprint knockback")
	character.equipment.unequip(EquipSlot.Slot.MAIN_HAND)
	check_near(character.get_stat(Stats.CRIT_DAMAGE), 0.0, 0.001, "nothing left after unequip")


func test_hit_modifier_applies_new_stats_once() -> void:
	var modifier := CharacterStatModifier.new()
	modifier.stats = {Stats.FINISHER_POWER: 20.0, Stats.KNOCKBACK_POWER: 50.0, Stats.CRIT_CHANCE: 100.0, Stats.CRIT_DAMAGE: 50.0}
	var finisher := HitData.new()
	finisher.damage = 10.0
	finisher.poise_damage = 10.0
	finisher.knockback = Vector2(30, 0)
	finisher.tags = [&"heavy", &"finisher"] as Array[StringName]
	modifier.modify_hit(finisher)
	check_near(finisher.damage, 10.0 * 1.2 * 2.0, 0.001, "finisher +20 %, crit x(1.5 + 0.5)")
	check_near(finisher.poise_damage, 12.0, 0.001, "finisher power on poise")
	check_near(finisher.knockback.x, 45.0, 0.001, "knockback distance +50 %")
	var light := HitData.new()
	light.damage = 10.0
	light.poise_damage = 10.0
	light.tags = [&"finisher"] as Array[StringName]
	modifier.modify_hit(light)
	check_near(light.poise_damage, 10.0, 0.001, "light finisher is not a heavy finisher")


func test_knockback_affix_moves_enemy_further_in_combat() -> void:
	spawn_player()
	var modifier := CharacterStatModifier.new()
	modifier.stats = {Stats.KNOCKBACK_POWER: 50.0}
	player.combat.modifiers.append(modifier)
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(24, 0)
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	add_child(enemy)
	await wait_physics(2)
	var start := enemy.global_position.x
	await tick(light(frame(Vector2.ZERO, Vector2.RIGHT)))
	await tick(frame(), 60)
	check_near(enemy.global_position.x - start, 6.0 * 1.5, 0.3, "sword light 6 px -> 9 px with +50 % knockback")
