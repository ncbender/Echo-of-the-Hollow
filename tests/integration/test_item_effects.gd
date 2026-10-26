extends GameplayTestCase
## Legendary / unique / set effects: activation, removal, limits, class switch.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const S := EquipSlot.Slot

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


class RecursiveEffect:
	extends ItemEffect
	var calls: int = 0

	func on_hit_landed(hit: HitData, runner: ItemEffectRunner, _key: String) -> void:
		calls += 1
		runner.on_hit_landed(hit)   # tries to re-enter the dispatcher


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	bridge.name = "ProgressionBridge"
	player.add_child(bridge)
	bridge.bind(player, character)


func _equip_new(item_id: StringName, slot: int = -1) -> String:
	var instance_id := character.inventory.add_item(item_id)[0].instance_id
	var error := character.equipment.equip(instance_id, slot)
	check_eq(error, "", "equip %s" % item_id)
	return instance_id


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	dummy.health.max_health = 100000.0
	dummy.health.reset()
	return dummy


func _llh(f: InputFrame) -> void:
	await tick(light(f))
	await tick(f, 12)
	await tick(light(f))
	await tick(f, 12)
	f.heavy_pressed = true
	await tick(f)
	await tick(f, 40)


func _triggers(effect_id: StringName) -> int:
	for entry in bridge.effects.active:
		if entry.effect.effect_id == effect_id:
			return bridge.effects.source_state(entry.key).get("triggers", 0)
	return -1


func test_effect_data_loads_with_subclasses() -> void:
	check(db.get_item(&"echo_blade").effects[0] is EchoShockwaveEffect, "legendary effect type")
	check(db.get_item(&"crushing_oath").effects[0] is ComboModifierEffect, "unique effect type")
	check(db.sets.has(&"hollow_warden"), "set loaded")
	check(db.load_errors.is_empty(), "no database errors: %s" % [db.load_errors])


func test_legendary_triggers_on_heavy_finisher_once_per_swing() -> void:
	_bind()
	var blade := _equip_new(&"echo_blade")
	check(bridge.effects.has_effect(&"echo_shockwave"), "effect active when equipped")
	var first := _dummy(Vector2(24, -8))
	var second := _dummy(Vector2(24, 10))
	var bystander := _dummy(Vector2(-20, 40))   # outside the crush arc, inside shockwave radius
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _llh(f)
	check_eq(_triggers(&"echo_shockwave"), 1, "one trigger although the crush hit two targets")
	check(bystander.hits_taken == 1, "shockwave hit the bystander (hits %d)" % bystander.hits_taken)
	check(first.hits_taken >= 3 and second.hits_taken >= 3, "both crush targets hit")
	# L-L-L ends with a light finisher: not heavy -> no trigger.
	await tick(f, 40)
	for i in 3:
		await tick(light(f))
		await tick(f, 22)
	check_eq(_triggers(&"echo_shockwave"), 1, "light finisher does not trigger")
	character.equipment.unequip(S.MAIN_HAND)
	check(not bridge.effects.has_effect(&"echo_shockwave"), "effect removed on unequip")
	check(character.inventory.has(blade), "blade still owned")


func test_effects_cannot_recurse() -> void:
	var runner := ItemEffectRunner.new()
	var effect := RecursiveEffect.new()
	runner.active.append({"effect": effect, "key": "test"})
	runner.on_hit_landed(HitData.new())
	check_eq(effect.calls, 1, "re-entrant dispatch ignored")


func test_unique_modifies_only_its_finisher() -> void:
	_bind()
	var crush := SWORD.get_attack(&"sword_llh_crush")
	var base_reach := player.combat.get_reach(crush, 0)
	var light_reach := player.combat.get_reach(SWORD.get_attack(&"sword_light_1"), 0)
	_equip_new(&"crushing_oath")
	check_near(player.combat.get_reach(crush, 0), base_reach * 1.25, 0.001, "crush reach +25%")
	check_near(player.combat.get_reach(SWORD.get_attack(&"sword_light_1"), 0), light_reach, 0.001, "other attacks unchanged")
	check_eq(crush.reach, 42.0, "shared AttackDefinition data untouched")
	var target := _dummy(Vector2(24, 0))
	await wait_physics(2)
	var hits_seen: Array[HitData] = []
	player.combat.hit_landed.connect(func(h: HitData) -> void: hits_seen.append(h))
	await _llh(frame(Vector2.ZERO, Vector2.RIGHT))
	var crush_hit: HitData = null
	for hit in hits_seen:
		if hit.attack.id == &"sword_llh_crush":
			crush_hit = hit
	if check(crush_hit != null, "crush landed"):
		check_near(crush_hit.poise_damage, crush.poise_damage * 1.5, 0.01, "poise +50% on the crush")
		check(&"crushing_oath" in crush_hit.tags, "tagged by the unique")
	check_eq(target.hits_taken, 3, "no extra/competing attack created")
	character.equipment.unequip(S.MAIN_HAND)
	check_near(player.combat.get_reach(crush, 0), base_reach, 0.001, "reach restored after unequip")


func test_set_thresholds_and_removal() -> void:
	_bind()
	var base_hp := character.get_stat(Stats.MAX_HEALTH)
	var base_dmg := character.get_stat(Stats.PHYSICAL_DAMAGE)
	var helm := _equip_new(&"warden_helm")
	check_eq(character.active_set_bonuses().size(), 0, "1 piece: no bonus")
	var mail := _equip_new(&"warden_mail")
	check_eq(character.active_set_bonuses().size(), 1, "2 pieces: first bonus")
	# helm replaced the cap (-3 armor irrelevant for HP); mail replaced the coat (-10 HP).
	check_eq(character.get_stat(Stats.MAX_HEALTH), base_hp - 10.0 + 20.0, "2-piece health bonus")
	_equip_new(&"warden_greaves")
	check_eq(character.active_set_bonuses().size(), 2, "3 pieces: both bonuses")
	check_eq(character.get_stat(Stats.PHYSICAL_DAMAGE), base_dmg + 10.0, "3-piece damage bonus")
	check(bridge.effects.has_effect(&"wardens_resolve"), "3-piece event effect active")
	for i in 10:
		character.equipment.unequip(S.LEGS)
		character.equipment.equip(character.inventory.items().filter(func(it: ItemInstance) -> bool: return it.definition_id == &"warden_greaves")[0].instance_id)
	check_eq(character.get_stat(Stats.PHYSICAL_DAMAGE), base_dmg + 10.0, "no double application after re-equips")
	character.equipment.unequip(S.LEGS)
	check(not bridge.effects.has_effect(&"wardens_resolve"), "3-piece effect gone")
	check_eq(character.get_stat(Stats.PHYSICAL_DAMAGE), base_dmg, "3-piece stats gone")
	character.equipment.unequip(character.equipment.active_loadout().slot_of(mail))
	check_eq(character.active_set_bonuses().size(), 0, "1 piece left: no bonus")
	check(character.equipment.is_equipped(helm), "helm still equipped")


func test_set_heal_effect_is_rate_limited() -> void:
	_bind()
	for item_id: StringName in [&"warden_helm", &"warden_mail", &"warden_greaves"]:
		_equip_new(item_id)
	_dummy(Vector2(22, 0))
	await wait_physics(2)
	player.health.health = 50.0
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	for i in 3:
		await tick(light(f))
		await tick(f, 22)
	check_eq(_triggers(&"wardens_resolve"), 1, "light finisher healed once")
	check_near(player.health.health, 53.0, 0.01, "healed 3 HP")


func test_class_switch_updates_effects_and_modifiers() -> void:
	_bind()
	character.classes.unlock(&"warrior")   # warrior loadout copied BEFORE the unique is equipped
	_equip_new(&"crushing_oath")
	var count := func() -> int:
		return player.combat.modifiers.filter(func(m: AttackModifier) -> bool: return m is ComboModifierEffect.TargetedModifier).size()
	check_eq(count.call(), 1, "unique modifier installed once")
	character.switch_class(&"warrior", true)
	check_eq(count.call(), 0, "warrior loadout has no unique -> modifier removed")
	character.switch_class(&"basic_adventurer", true)
	check_eq(count.call(), 1, "back again, still exactly one")
	for i in 5:
		bridge.rebuild_effects()
	check_eq(count.call(), 1, "rebuilding never duplicates")
