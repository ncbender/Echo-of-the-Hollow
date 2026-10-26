extends GameplayTestCase
## Class Foundation D: Arcanist vertical slice with the real data - mana costs and
## regeneration, projectiles along the mouse aim, Arcane Marks and their
## detonation, Rune Sigil empowerment, Frostbind + Chill, mods, talents, several
## targets, save/load.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const SAVE := "user://test_saves/arcanist.save.json"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var dispatched: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(&"arcanist")
	character.switch_class(&"arcanist", true)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	bridge.stat_modifier.rng.seed = 3
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void: dispatched.append(hit))


func _level(level: int) -> void:
	var definition := db.get_class_def(&"arcanist")
	var needed := -character.classes.get_xp(&"arcanist")
	for l in range(character.classes.get_level(&"arcanist"), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(&"arcanist", needed)


func _talents(talents: Dictionary) -> void:
	var errors := TalentService.validate_allocation(db, &"arcanist", character.classes.get_level(&"arcanist"), talents)
	check(errors.is_empty(), "test allocation valid: %s" % [errors])
	character.builds.get_build(&"arcanist").talents = talents.duplicate()
	SkillBook.auto_fill(character, &"arcanist")
	character.builds.notify(&"arcanist")


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _cast(skill_id: StringName, aim: Vector2 = Vector2.RIGHT, wait: int = 30) -> void:
	var slot := character.builds.get_build(&"arcanist").slot_of(skill_id)
	check(slot >= 0, "%s is slotted" % skill_id)
	var f := frame(Vector2.ZERO, aim)
	f.ability_slot = slot
	await tick(f)
	await tick(frame(Vector2.ZERO, aim), wait)


func _hits(skill_id: StringName, target: Node = null) -> Array:
	return dispatched.filter(func(h: HitData) -> bool: return h.skill_id == skill_id and (target == null or h.target == target))


func test_arcanist_data() -> void:
	var definition := db.get_class_def(&"arcanist")
	check(definition != null and definition.playable, "arcanist defined and playable")
	check_eq(definition.resource.id, &"mana", "uses mana")
	check(db.statuses.has(&"arcane_mark"), "arcane mark status")
	var skills := db.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == &"arcanist")
	check(skills.size() >= 6, "six+ arcanist skills (%d)" % skills.size())
	for tree_id in definition.talent_tree_ids:
		check(db.talent_trees[tree_id].validate(db.rules.talent_rules()).is_empty(), "%s valid" % tree_id)
	check(db.load_errors.is_empty(), "no load errors: %s" % [db.load_errors])


func test_mana_cost_and_regeneration() -> void:
	_bind()
	await wait_physics(2)
	var mana := bridge.class_runtime.pool
	check_eq(mana.value, 100.0, "starts with full mana")
	await _cast(&"arcane_bolt", Vector2.RIGHT, 0)
	check_near(mana.value, 92.0, 0.2, "Arcane Bolt costs 8 mana")
	await tick(frame(), 60)
	check_near(mana.value, 100.0, 0.2, "8 mana/s regeneration refills it")


func test_bolts_follow_the_mouse_and_mark() -> void:
	_bind()
	var right := _dummy(Vector2(70, 0))
	var up := _dummy(Vector2(0, -70))
	await wait_physics(2)
	await _cast(&"arcane_bolt", Vector2.UP)
	check_eq(_hits(&"arcane_bolt", up).size(), 1, "bolt flies towards the aim (up)")
	check_eq(_hits(&"arcane_bolt", right).size(), 0, "nothing to the right")
	check_eq(StatusComponent.of(up).stacks(&"arcane_mark"), 1, "Arcane Mark applied")


func test_marks_detonate_with_mana_pulse() -> void:
	_level(3)
	_bind()
	var dummy := _dummy(Vector2(40, 0))
	var other := _dummy(Vector2(-30, 0))
	await wait_physics(2)
	await _cast(&"arcane_bolt")
	await tick(frame(), 12)
	await _cast(&"arcane_bolt")
	var status := StatusComponent.of(dummy)
	check_eq(status.stacks(&"arcane_mark"), 2, "two marks")
	await _cast(&"mana_pulse", Vector2.RIGHT, 5)
	var pulse := _hits(&"mana_pulse", dummy)
	check_eq(pulse.size(), 1, "pulse hit the marked dummy")
	if not pulse.is_empty():
		check(&"consumed_arcane_mark" in pulse[0].tags, "marks detonated")
		var base: float = db.skills[&"mana_pulse"].actions[0].hit.damage
		check_near(pulse[0].damage, (base + 2 * 12.0) * 1.05, 0.01, "+12 per mark (+5% class skill damage)")
	check_eq(status.stacks(&"arcane_mark"), 0, "marks consumed")
	check_eq(_hits(&"mana_pulse", other).size(), 1, "pulse also hits the target behind (several targets)")


func test_rune_sigil_empowers_next_spell_and_detonates() -> void:
	_level(8)
	_bind()
	SkillBook.assign_slot(character, &"arcanist", 3, &"rune_sigil", true)
	var dummy := _dummy(Vector2(50, 0))
	await wait_physics(2)
	await _cast(&"rune_sigil", Vector2.RIGHT, 20)
	check_near(bridge.class_runtime.empowered.get(&"spell", 1.0), 1.3, 0.001, "next spell empowered")
	await _cast(&"arcane_bolt", Vector2.RIGHT, 20)
	var bolt := _hits(&"arcane_bolt", dummy)
	if check(not bolt.is_empty(), "bolt hit"):
		check_near(bolt[0].damage, 14.0 * 1.3 * 1.05, 0.01, "empowered bolt: +30%")
	check(not bridge.class_runtime.empowered.has(&"spell"), "empowerment consumed once")
	await tick(frame(), seconds_to_ticks(3.8))
	var sigil := _hits(&"rune_sigil", dummy)
	check(sigil.size() >= 3, "sigil pulses marked the dummy (%d hits)" % sigil.size())
	check(sigil.any(func(h: HitData) -> bool: return &"consumed_arcane_mark" in h.tags), "sigil detonated the marks when it faded")


func test_frostbind_chills_and_rewards_chill() -> void:
	_level(5)
	_bind()
	var dummy := _dummy(Vector2(60, 0))
	await wait_physics(2)
	await _cast(&"frostbind")
	check_eq(StatusComponent.of(dummy).stacks(&"chill"), 2, "two chill stacks")
	bridge.class_runtime.cooldowns.clear()
	await _cast(&"frostbind")
	var hits := _hits(&"frostbind", dummy)
	if check(hits.size() == 2, "two frostbind hits"):
		check_near(hits[1].damage, hits[0].damage * 1.4, 0.01, "+40% against chilled targets")
		check(&"vs_chill" in hits[1].tags, "bonus tagged")


func test_split_bolt_mod_and_talent_unlocked_double_mark() -> void:
	_level(12)
	_bind()
	check_eq(SkillBook.set_mod(character, &"arcanist", &"arcane_bolt", SkillModDefinition.Slot.FORM, &"bolt_split", true), "", "Split Bolt at level 4+")
	check(SkillBook.set_mod(character, &"arcanist", &"arcane_bolt", SkillModDefinition.Slot.RESONANCE, &"bolt_double_mark", true) != "", "Double Mark needs its talent")
	_talents({&"arc_rm_lore": 1, &"arc_rm_inscribed": 2})
	check(SkillBook.set_mod(character, &"arcanist", &"arcane_bolt", SkillModDefinition.Slot.RESONANCE, &"bolt_double_mark", true).contains("cannot be combined"),
		"Double Mark and Split Bolt are incompatible")
	for y: float in [-16.0, 0.0, 16.0]:
		_dummy(Vector2(80, y))
	await wait_physics(2)
	await _cast(&"arcane_bolt")
	var targets := {}
	for hit in _hits(&"arcane_bolt"):
		targets[hit.target] = true
	check(targets.size() >= 2, "split bolts hit several targets (%d)" % targets.size())


func test_runemaster_unlocks_arcane_rift() -> void:
	_level(20)
	_bind()
	var talents := {&"arc_rm_inscribed": 5, &"arc_rm_rift": 1}
	_talents(talents)
	check(SkillBook.is_skill_available(character, &"arcanist", &"arcane_rift"), "rift unlocked")
	check_eq(SkillBook.assign_slot(character, &"arcanist", 2, &"arcane_rift", true), "", "rift slotted at the station (all four slots were full)")
	var dummy := _dummy(Vector2(70, 0))
	await wait_physics(2)
	await _cast(&"arcane_rift", Vector2.RIGHT, seconds_to_ticks(2.6))
	check(_hits(&"arcane_rift", dummy).size() >= 5, "rift pulses (%d)" % _hits(&"arcane_rift", dummy).size())
	check_eq(StatusComponent.of(dummy).stacks(&"arcane_mark"), 3, "rift marks up to 3 stacks")


func test_save_load_keeps_build() -> void:
	_level(15)
	_talents({&"arc_ew_focus": 5, &"arc_ew_attune": 1})
	SkillBook.set_mod(character, &"arcanist", &"arcane_bolt", SkillModDefinition.Slot.RESONANCE, &"bolt_siphon", true)
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok(), "loaded")
	check_eq(loaded.character.builds.get_build(&"arcanist").to_dict(), character.builds.get_build(&"arcanist").to_dict(), "arcanist build identical")
	check_eq(loaded.character.classes.active_class_id, &"arcanist", "still an arcanist")
	check_eq(loaded.character.get_stat(Stats.CHILL_CHANCE), 20.0, "talent stats after load")
