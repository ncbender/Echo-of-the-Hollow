extends GameplayTestCase
## Weapon Mastery 1.4: exactly one weapon slot and no quick swap. The weapon
## changes only through the equipment (inventory), never mid-attack; a change
## ends the combo and its buffer; each family uses its own attack definitions.

const GREATSWORD: WeaponFamily = preload("res://data/weapons/two_handed_sword.tres")

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	super.before_each()
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	started_attacks.clear()
	hits.clear()


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	track_player_attacks()


func _equip(item_id: StringName) -> void:
	var instance := character.inventory.add_item(item_id)[0]
	check_eq(character.equipment.equip(instance.instance_id), "", "equip %s" % item_id)


func test_no_quick_swap_input_exists() -> void:
	_bind()
	var f := frame()
	check(not "weapon_slot" in f, "the input frame has no weapon slot")
	f.flask_pressed = true
	await tick(f)
	check_eq(player.combat.weapon.id, &"one_handed_sword", "key 1 (flask) never switches the weapon")


func test_switch_through_equipment_waits_for_neutral_and_resets_the_chain() -> void:
	character.mastery.add_xp(&"one_handed_sword", 120)   # level 2: L-L-L
	_bind()
	var f := frame()
	await tick(light(f))
	var guard := 0
	while player.combat.attack_clock() < player.combat.accept_from() and guard < 60:
		await tick(f)
		guard += 1
	await tick(light(frame()))
	check_eq(player.combat.buffered, "LL", "a combo step is buffered")
	_equip(&"steel_greatsword")
	check_eq(player.combat.weapon.id, &"one_handed_sword", "no weapon change mid-attack")
	guard = 0
	while player.combat.weapon.id != &"two_handed_sword" and guard < 120:
		await tick(f)
		guard += 1
	check_eq(player.combat.weapon.id, &"two_handed_sword", "the greatsword arrives once the chain is over")
	check_eq(player.combat.buffered, "", "the change cleared the buffer")
	check_eq(player.combat.mastery_level, character.mastery.get_level(&"two_handed_sword"), "gates follow the new family's own mastery")
	await perform_path("L")
	check_eq(started_attacks.back(), GREATSWORD.node("L").id, "greatsword quick from its own definitions")


func test_every_family_uses_its_own_definitions() -> void:
	_bind()
	for item_id: StringName in [&"iron_dagger", &"iron_axe", &"iron_mace", &"oak_wand", &"ash_spear", &"oak_staff", &"hunting_bow", &"steel_greatsword", &"iron_sword"]:
		_equip(item_id)
		await tick(frame(), 2)
		var family_id := (db.get_item(item_id) as ItemDefinition).weapon_family_id
		check_eq(player.combat.weapon.id, family_id, "%s wields %s" % [item_id, family_id])
		started_attacks.clear()
		await perform_path("L")
		check_eq(started_attacks.size(), 1, "%s: one quick attack" % family_id)
		if not started_attacks.is_empty():
			check_eq((db.weapons[family_id] as WeaponFamily).get_attack(started_attacks[0]).weapon_family_id, family_id, "%s: attack from its family" % family_id)


func test_greatsword_reaches_further_than_the_sword() -> void:
	_bind()
	add_target(Vector2(44, 0), 6.0)   # beyond sword reach (30 + 6), within greatsword (44)
	await wait_physics(2)
	await perform_path("L")
	check_eq(hits.size(), 0, "sword quick misses at 44 px")
	_equip(&"steel_greatsword")
	await tick(frame(), 2)
	await perform_path("L")
	check_eq(hits.size(), 1, "greatsword quick hits at 44 px")
