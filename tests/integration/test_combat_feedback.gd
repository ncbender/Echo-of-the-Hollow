extends GameplayTestCase
## Combat Defense & Feedback 0.4 C-E: skill VFX are data (every class skill has
## a SkillFxSpec), effects appear on real casts/hits and always clean up (no
## leaks after their lifetime, auras end with the buff, class change or death),
## status markers and poise breaks have feedback, parries show no "0".

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		character.classes.unlock(class_id)
		character.classes.add_xp(class_id, 1500)   # level ~11: all base skills


func _bind(class_id: StringName) -> void:
	character.switch_class(class_id, true)
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)


func _fx(style: int = -1) -> Array:
	return find_children("*", "CombatFx", true, false).filter(func(fx: CombatFx) -> bool:
		return style < 0 or fx.style == style)


func _cast(skill_id: StringName, wait: int = 3) -> void:
	var f := frame()
	f.ability_slot = character.builds.get_build().slot_of(skill_id)
	check(f.ability_slot >= 0, "%s slotted" % skill_id)
	await tick(f)
	await tick(frame(), wait)


func test_every_class_skill_has_feedback_data() -> void:
	for skill: SkillDefinition in db.skills.values():
		if skill.class_id in [&"warrior", &"arcanist", &"shadowrunner"]:
			check(skill.fx != null and (skill.fx.cast_style >= 0 or skill.fx.impact_style >= 0 or skill.fx.aura),
				"%s has visual feedback" % skill.id)
	for status_id: StringName in [&"arcane_mark", &"weak_point", &"bleeding", &"chill"]:
		check(db.statuses[status_id].marker > 0, "%s has a body marker" % status_id)
	check(db.statuses[&"arcane_mark"].marker != db.statuses[&"weak_point"].marker, "arcane marks and weak points look different")


func test_cast_and_impact_effects_spawn_and_clean_up() -> void:
	_bind(&"arcanist")
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(50, 0)
	add_child(dummy)
	await wait_physics(2)
	await _cast(&"arcane_bolt", 1)
	check(not _fx(CombatFx.Style.GLYPH).is_empty(), "spell cast glyph")
	await tick(frame(), 15)
	check(not _fx(CombatFx.Style.STAR).is_empty(), "impact star on the target")
	await tick(frame(), 12)
	await _cast(&"arcane_bolt", 15)
	await _cast(&"mana_pulse", 2)
	check(_fx(CombatFx.Style.STAR).size() >= 1 and _fx(CombatFx.Style.RING).size() >= 1, "detonation burst (star + ring)")
	await tick(frame(), 60)
	check_eq(_fx().size(), 0, "every effect freed itself (no leaks)")


func test_aura_ends_with_buff_class_change_and_death() -> void:
	_bind(&"warrior")
	await wait_physics(2)
	await _cast(&"battle_cry")
	check_eq(_fx(CombatFx.Style.AURA).size(), 1, "Battle Cry aura while the buff runs")
	await tick(frame(), seconds_to_ticks(8.2))
	check_eq(_fx(CombatFx.Style.AURA).size(), 0, "aura ends with the buff")
	bridge.class_runtime.cooldowns.clear()
	await _cast(&"battle_cry")
	character.switch_class(&"arcanist", true)
	await tick(frame(), 2)
	check_eq(_fx(CombatFx.Style.AURA).size(), 0, "class change ends the aura")
	character.switch_class(&"shadowrunner", true)
	await tick(frame(), 2)
	await wait_physics(1)
	await _cast(&"shadowstep", 1)   # no target: refused, no effect
	check_eq(_fx(CombatFx.Style.AFTERIMAGE).size(), 0, "a refused gap closer leaves no afterimages")
	character.switch_class(&"warrior", true)
	bridge.class_runtime.cooldowns.clear()
	await _cast(&"battle_cry")
	var lethal := HitData.new()
	lethal.damage = 100000.0
	player.hurtbox.receive_hit(lethal)
	await tick(frame(), 2)
	check_eq(_fx(CombatFx.Style.AURA).size(), 0, "death ends the aura")


func test_gap_closer_afterimages_and_execution_finisher() -> void:
	_bind(&"shadowrunner")
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(90, 0)
	add_child(dummy)
	await wait_physics(2)
	bridge.class_runtime.pool.gain(100.0)
	await _cast(&"shadowstep", 1)
	check(_fx(CombatFx.Style.AFTERIMAGE).size() >= 2, "Shadowstep leaves afterimages")
	await tick(frame(), 20)
	check(StatusComponent.of(dummy).has(&"weak_point"), "weak point on arrival")
	await _cast(&"execution", 4)
	check(not _fx(CombatFx.Style.CROSS).is_empty(), "execution cross slash")
	check(not _fx(CombatFx.Style.STAR).is_empty(), "weak point consumption burst")


func test_poise_break_and_parry_feedback() -> void:
	spawn_player()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(24, 0)
	enemy.target = player
	add_child(enemy)
	await wait_physics(2)
	var breaker := HitData.new()
	breaker.poise_damage = 1000.0
	enemy.hurtbox.receive_hit(breaker)
	await tick(frame(), 1)
	var words := _fx(CombatFx.Style.TEXT).map(func(fx: CombatFx) -> String: return fx.text)
	check("BREAK" in words, "poise break shows BREAK: %s" % [words])
	var numbers_before := find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/fx/damage_number.gd")).size()
	var f := frame()
	f.defend_pressed = true
	f.defend_held = true
	await tick(f)
	var swipe := HitData.new()
	swipe.attacker = enemy
	swipe.attack = preload("res://data/enemies/grunt_attacks.tres").get_attack(&"grunt_swipe")
	swipe.damage = 12.0
	player.hurtbox.receive_hit(swipe)
	await tick(frame(), 1)
	words = _fx(CombatFx.Style.TEXT).map(func(fx: CombatFx) -> String: return fx.text)
	check("PARRY" in words, "parry shows PARRY")
	var numbers_after := get_tree().current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/fx/damage_number.gd")).size() if get_tree().current_scene != null else numbers_before
	check(numbers_after <= numbers_before, "no damage number for a parried hit")
