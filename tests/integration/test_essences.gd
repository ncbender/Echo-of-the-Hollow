extends GameplayTestCase
## Crafting phase D: binding, replacing and extracting essences (max two), the
## Storm Wolf discharge, the Stone Golem full-charge poise bonus and their
## Thunderquake resonance in real combat, effect (re)registration and save/load.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const S := EquipSlot.Slot
const SAVE := "user://test_saves/essences.save.json"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var rng := RandomNumberGenerator.new()
var landed: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	rng.seed = 5


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	bridge.name = "ProgressionBridge"
	player.add_child(bridge)
	bridge.bind(player, character)
	player.combat.hit_landed.connect(func(hit: HitData) -> void: landed.append(hit))


func _bind_essence(item: ItemInstance, essence_id: StringName, slot: int = -1) -> CraftingService.Result:
	character.inventory.add_item(db.essences[essence_id].item_id)
	var request := CraftingRequest.make(CraftingOps.ESSENCE_INSERT, item)
	request.essence_id = essence_id
	request.slot_index = slot
	return CraftingService.execute(character, request, rng)


func _blade_with(essences: Array[StringName]) -> ItemInstance:
	var blade := character.inventory.add_item(&"forged_blade")[0]
	for essence_id in essences:
		check(_bind_essence(blade, essence_id).ok, "bound %s" % essence_id)
	return blade


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	dummy.health.max_health = 100000.0
	dummy.health.max_poise = 100000.0
	dummy.health.reset()
	return dummy


## L-L-H with the heavy held for `hold` ticks (50 = full charge at 0.7 s).
func _llh(f: InputFrame, hold: int) -> void:
	await tick(light(f))
	await tick(f, 12)
	await tick(light(f))
	await tick(f, 12)
	await tick(heavy_down(f), hold)
	await tick(heavy_up(f))
	await tick(f, 40)


func _count(effect_id: StringName) -> int:
	var found := 0
	for entry in bridge.effects.active:
		if entry.effect.effect_id == effect_id:
			found += 1
	return found


func _last_hit(attack_id: StringName) -> HitData:
	for index in range(landed.size() - 1, -1, -1):
		if landed[index].attack != null and landed[index].attack.id == attack_id:
			return landed[index]
	return null


func test_bind_two_essences_and_slot_limits() -> void:
	var blade := _blade_with([&"storm_wolf", &"stone_golem"] as Array[StringName])
	check_eq(blade.essences, [&"storm_wolf", &"stone_golem"] as Array[StringName], "two essences bound")
	check_eq(character.inventory.count(&"storm_wolf_essence"), 0, "essence items consumed")
	character.inventory.add_item(&"storm_wolf_essence")
	var request := CraftingRequest.make(CraftingOps.ESSENCE_INSERT, blade)
	request.essence_id = &"storm_wolf"
	check("already bound" in CraftingService.preview(character, request).error, "same essence twice refused")
	blade.essences = [&"stone_golem", &"storm_wolf"] as Array[StringName]   # order irrelevant
	var third := CraftingRequest.make(CraftingOps.ESSENCE_INSERT, blade)
	third.essence_id = &"stone_golem"
	check(not CraftingService.preview(character, third).ok(), "no third slot")
	check(ItemStats.active_essences(blade, db.get_item(&"forged_blade")).size() <= 2, "never more than two active")


func test_replacing_consumes_the_old_essence() -> void:
	var blade := _blade_with([&"storm_wolf", &"stone_golem"] as Array[StringName])
	blade.essences = [&"storm_wolf"] as Array[StringName]
	blade.essences.append(&"stone_golem")
	character.inventory.add_item(&"storm_wolf_essence")
	# replace golem (slot 1) - but storm wolf is already bound: refused
	var request := CraftingRequest.make(CraftingOps.ESSENCE_INSERT, blade)
	request.essence_id = &"storm_wolf"
	request.slot_index = 1
	check(not CraftingService.preview(character, request).ok(), "duplicate even when replacing")
	# remove wolf by extraction-free replacement: put golem into slot 0? also duplicate -> use a fresh blade
	var other := character.inventory.add_item(&"forged_blade")[0]
	check(_bind_essence(other, &"stone_golem").ok, "golem bound")
	request = CraftingRequest.make(CraftingOps.ESSENCE_INSERT, other)
	request.essence_id = &"storm_wolf"
	request.slot_index = 0
	var preview := CraftingService.preview(character, request)
	check(preview.ok() and "consumed" in "\n".join(preview.notes), "player is warned that the old essence is consumed")
	var golems := character.inventory.count(&"stone_golem_essence")
	check(CraftingService.execute(character, request, rng).ok, "replaced")
	check_eq(other.essences, [&"storm_wolf"] as Array[StringName], "slot 0 now storm wolf")
	check_eq(character.inventory.count(&"stone_golem_essence"), golems, "old essence NOT returned")


func test_extraction_returns_the_essence_without_duplication() -> void:
	var blade := _blade_with([&"storm_wolf"] as Array[StringName])
	var request := CraftingRequest.make(CraftingOps.ESSENCE_EXTRACT, blade)
	request.slot_index = 0
	var result := CraftingService.execute(character, request, rng)
	check(not result.ok and "Essence Siphon" in result.error, "needs the rare siphon: %s" % result.error)
	check_eq(blade.essences.size(), 1, "still bound")
	character.inventory.add_item(&"essence_siphon")
	request = CraftingRequest.make(CraftingOps.ESSENCE_EXTRACT, blade)
	request.slot_index = 0
	check(CraftingService.execute(character, request, rng).ok, "extracted")
	check(blade.essences.is_empty(), "slot free")
	check_eq(character.inventory.count(&"storm_wolf_essence"), 1, "exactly one essence back")
	check_eq(character.inventory.count(&"essence_siphon"), 0, "siphon consumed")
	check(character.inventory.find(blade.instance_id) != null, "item not destroyed")


func test_unique_and_non_weapons_cannot_take_essences() -> void:
	var oath := character.inventory.add_item(&"crushing_oath")[0]
	character.inventory.add_item(&"storm_wolf_essence")
	var request := CraftingRequest.make(CraftingOps.ESSENCE_INSERT, oath)
	request.essence_id = &"storm_wolf"
	check("protected" in CraftingService.preview(character, request).error, "unique core protected")
	check_eq(character.inventory.count(&"storm_wolf_essence"), 1, "nothing consumed")


func test_effects_follow_equipment_and_class_without_duplicates() -> void:
	_bind()
	var blade := _blade_with([&"storm_wolf", &"stone_golem"] as Array[StringName])
	check_eq(_count(&"storm_wolf_discharge"), 0, "inactive while not equipped")
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	check_eq(_count(&"storm_wolf_discharge"), 1, "discharge active")
	check_eq(_count(&"stone_golem_crush"), 1, "golem active")
	check_eq(_count(&"thunder_quake"), 1, "resonance active with both essences")
	for i in 3:
		bridge.rebuild_effects()
	check_eq(_count(&"thunder_quake"), 1, "rebuilds never duplicate")
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	check_eq(_count(&"storm_wolf_discharge"), 1, "warrior inherited the loadout")
	character.equipment.unequip(S.MAIN_HAND)
	check_eq(_count(&"storm_wolf_discharge"), 0, "unequipped in the warrior loadout: inactive")
	character.switch_class(&"basic_adventurer", true)
	check_eq(_count(&"storm_wolf_discharge"), 1, "adventurer loadout still has it")


func test_storm_wolf_discharge_in_combat() -> void:
	_bind()
	var blade := _blade_with([&"storm_wolf"] as Array[StringName])
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	var target := _dummy(Vector2(24, -6))
	var neighbour := _dummy(Vector2(40, 22))   # outside the crush arc, inside the discharge radius
	await wait_physics(2)
	var neighbour_hits := [0]
	neighbour.hurtbox.hit_received.connect(func(hit: HitData) -> void:
		if &"discharge" in hit.tags:
			neighbour_hits[0] += 1)
	await _llh(frame(Vector2.ZERO, Vector2.RIGHT), 1)
	var shared := bridge.effects.shared_state(&"storm_wolf_discharge")
	check_eq(shared.get("triggers", 0), 1, "one discharge per heavy finisher swing")
	check(neighbour_hits[0] == 1, "neighbour struck by the discharge once")
	check(bridge.effects.has_mark(neighbour, &"charged"), "struck enemies are charged")
	check(target.hits_taken >= 3, "combo itself still lands (%d)" % target.hits_taken)


func test_stone_golem_boosts_fully_charged_finishers_only() -> void:
	_bind()
	var plain := character.inventory.add_item(&"forged_blade")[0]
	character.equipment.equip(plain.instance_id, S.MAIN_HAND)
	_dummy(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _llh(f, 50)
	var without := _last_hit(&"sword_llh_crush")
	var golem := _blade_with([&"stone_golem"] as Array[StringName])
	character.equipment.equip(golem.instance_id, S.MAIN_HAND)
	await tick(f, 60)
	await _llh(f, 50)
	var with_golem := _last_hit(&"sword_llh_crush")
	if not check(without != null and with_golem != null, "both finishers landed"):
		return
	check_eq(with_golem.charge_tier, 2, "fully charged")
	check_near(with_golem.poise_damage / without.poise_damage, 1.6, 0.01, "+60 % poise on full charge")
	await tick(f, 60)
	await _llh(f, 1)
	var uncharged := _last_hit(&"sword_llh_crush")
	check(not &"stone_golem_crush" in uncharged.tags, "uncharged finisher not boosted")


func test_thunderquake_resonance_changes_combat() -> void:
	_bind()
	var blade := _blade_with([&"storm_wolf", &"stone_golem"] as Array[StringName])
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	var target := _dummy(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _llh(f, 1)   # discharge charges the target
	check(bridge.effects.has_mark(target, &"charged"), "target charged by the finisher's discharge")
	await tick(f, 20)
	await tick(light(f))
	await tick(f, 20)
	var follow_up := _last_hit(&"sword_light_1")
	if not check(follow_up != null, "follow-up landed"):
		return
	check(&"thunder_quake" in follow_up.tags, "resonance applied to the next hit")
	var base := SWORD.get_attack(&"sword_light_1").poise_damage * (1.0 + character.get_stat(Stats.POISE_DAMAGE) / 100.0)
	check_near(follow_up.poise_damage, base * 1.5, 0.01, "+50 % poise")
	check(not bridge.effects.has_mark(target, &"charged"), "mark consumed once")
	await tick(light(f))
	await tick(f, 20)
	check(not &"thunder_quake" in _last_hit(&"sword_light_2").tags, "no second bonus without a new discharge")


func test_essences_survive_save_load_and_rebuild_once() -> void:
	var blade := _blade_with([&"storm_wolf", &"stone_golem"] as Array[StringName])
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	character = SaveSystem.load_from(SAVE, db).character
	check_eq(character.inventory.find(blade.instance_id).essences, [&"storm_wolf", &"stone_golem"] as Array[StringName], "essences restored")
	_bind()
	check_eq(_count(&"thunder_quake"), 1, "resonance rebuilt exactly once after load")
