extends GameplayTestCase
## Combat Defense & Feedback 0.4 D: combat audio - synthesized placeholder cues,
## sounds on real hits (not only casts), block vs parry, one sound per event,
## throttling and quieter busy moments, effects volume persisted in the
## installation settings, cleanup with the map.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const SETTINGS := "user://test_saves/audio_settings.cfg"

var audio: CombatAudio


func before_each() -> void:
	audio = CombatAudio.new()
	add_child(audio)


func after_each() -> void:
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func test_all_cues_synthesize_short_sounds() -> void:
	for cue: StringName in [&"hit_light", &"hit_heavy", &"poise_break", &"block", &"parry", &"guard_break",
			&"warrior_skill", &"arcane_cast", &"arcane_detonate", &"shadow_skill", &"execution", &"unblockable_warn"]:
		var stream := SynthSounds.stream(cue)
		check(stream != null and stream.data.size() > 100, "%s synthesized" % cue)
		if stream != null:
			check(stream.get_length() < 0.5, "%s is short (%.2f s)" % [cue, stream.get_length()])
	check(SynthSounds.stream(&"no_such_cue") == null, "unknown cue -> no sound")


func test_one_sound_per_swing_on_real_hits() -> void:
	spawn_player()
	for y: float in [-10.0, 0.0, 10.0]:
		_dummy(Vector2(22, y))
	await wait_physics(2)
	await tick(light(frame()))
	await tick(frame(), 12)
	check_eq(audio.played.count(&"hit_light"), 1, "a swing hitting three dummies plays one hit sound")
	await tick(frame(), 30)
	await tick(heavy_down(frame()))
	await tick(heavy_up(frame()), 1)
	await tick(frame(), 30)
	check_eq(audio.played.count(&"hit_heavy"), 1, "heavy hit has its own sound")
	var clicks := audio.played.size()
	await tick(light(frame(Vector2.ZERO, Vector2.LEFT)))   # swing into the air
	await tick(frame(), 20)
	check_eq(audio.played.size(), clicks, "no hit sound without a hit")


func test_block_and_parry_sound_different() -> void:
	spawn_player()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(24, 0)
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	await wait_physics(2)
	var swipe := preload("res://data/enemies/grunt_attacks.tres").get_attack(&"grunt_swipe")
	var f := frame()
	f.defend_pressed = true
	f.defend_held = true
	await tick(f)
	player.hurtbox.receive_hit(_hit(enemy, swipe))
	check(&"parry" in audio.played and not &"block" in audio.played, "parry sound")
	await tick(frame(), 40)
	f = frame()
	f.defend_pressed = true
	f.defend_held = true
	await tick(f)
	var hold := frame()
	hold.defend_held = true
	await tick(hold, 15)
	player.hurtbox.receive_hit(_hit(enemy, swipe))
	check(&"block" in audio.played, "block sound")
	check_eq(audio.played.count(&"parry"), 1, "the block did not play the parry sound")
	var breaker := HitData.new()
	breaker.poise_damage = 1000.0
	enemy.hurtbox.receive_hit(breaker)
	check(&"poise_break" in audio.played, "poise break sound")


func _hit(enemy: Enemy, attack: AttackDefinition) -> HitData:
	var hit := HitData.new()
	hit.attacker = enemy
	hit.attack = attack
	hit.damage = attack.damage
	return hit


func test_throttle_limits_and_busy_volume() -> void:
	var played := 0
	for i in 5:
		played += 1 if audio.play_cue(&"hit_light", Vector2.ZERO) else 0
	check_eq(played, 1, "the same cue in the same moment plays once")
	var quiet := []
	for cue: StringName in [&"block", &"parry", &"arcane_cast", &"shadow_skill"]:
		audio.play_cue(cue, Vector2.ZERO)
	for voice in audio.find_children("*", "AudioStreamPlayer2D", true, false):
		if (voice as AudioStreamPlayer2D).playing:
			quiet.append((voice as AudioStreamPlayer2D).volume_db)
	check(quiet.size() == 5 and quiet.max() == 0.0 and quiet.min() < -5.0, "each extra sound is quieter: %s" % [quiet])
	await wait_physics(6)
	var repeats := 0
	for i in 6:
		repeats += 1 if audio.play_cue(&"hit_heavy", Vector2.ZERO) else 0
		await wait_physics(4)
	check(repeats <= CombatAudio.MAX_PER_CUE + 1, "at most %d overlapping copies (%d)" % [CombatAudio.MAX_PER_CUE, repeats])


func test_skill_cast_and_detonation_sounds() -> void:
	var db := GameDatabase.get_default()
	var character := CharacterFactory.create_new(db)
	character.classes.unlock(&"arcanist")
	character.classes.add_xp(&"arcanist", 400)
	character.switch_class(&"arcanist", true)
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	_dummy(Vector2(40, 0))
	await wait_physics(2)
	for slot in [0, 0, 1]:
		var f := frame()
		f.ability_slot = slot
		await tick(f)
		await tick(frame(), 30)
	check(audio.played.count(&"arcane_cast") >= 3, "spell cast sounds")
	check(&"arcane_detonate" in audio.played, "mark detonation sound on the real hit")


func test_volume_setting_persists_and_applies() -> void:
	var settings := UserSettings.new()
	settings.path = SETTINGS
	settings.set_sfx_volume(0.35)
	check_eq(settings.save(), OK, "saved")
	var loaded := UserSettings.load_from(SETTINGS)
	check_near(loaded.sfx_volume, 0.35, 0.001, "effects volume persisted in the settings file")
	loaded.apply_to(get_tree().root)
	var bus := AudioServer.get_bus_index(CombatAudio.BUS)
	check(bus >= 0, "SFX bus exists")
	check_near(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.35, 0.01, "bus volume applied")
	loaded.set_sfx_volume(0.0)
	loaded.apply_to(get_tree().root)
	check(AudioServer.is_bus_mute(bus), "0 %% mutes")
	UserSettings.new().apply_to(get_tree().root)   # back to the default for other tests


func test_audio_lives_with_the_map() -> void:
	var session := SessionState.find(get_tree())
	var previous := session.character
	session.set_character(CharacterFactory.create_new(session.database))
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 120:
		await get_tree().process_frame
		if get_tree().current_scene is GameMap and get_tree().current_scene.is_node_ready():
			break
	var in_map := get_tree().get_nodes_in_group(CombatAudio.GROUP).filter(func(n: Node) -> bool: return n != audio)
	check_eq(in_map.size(), 1, "the map has one combat audio layer")
	get_tree().unload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	in_map = get_tree().get_nodes_in_group(CombatAudio.GROUP).filter(func(n: Node) -> bool: return n != audio)
	check_eq(in_map.size(), 0, "freed with the map (no sounds survive a scene change)")
	session.set_character(previous)
