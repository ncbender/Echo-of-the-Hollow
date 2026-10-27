extends Node
## Combat feel test (docs/COMBAT_FEEL_TEST.md): runs next to the existing test
## arena and only changes the TEST character through the real systems:
##   T  next weapon (One-Handed Sword -> Dagger -> Greatsword -> Bow), equipped
##      through the inventory like in the game (no new swap mechanic)
##   Y  mastery of these four families: level 1 <-> level 20 (all paths)
## Targets: one single training dummy (left) and a group of three (right).
## No combat values, animations or rules are changed.

const FAMILIES: Array[StringName] = [&"one_handed_sword", &"dagger", &"two_handed_sword", &"bow"]
const ITEMS := {&"one_handed_sword": &"iron_sword", &"dagger": &"iron_dagger", &"two_handed_sword": &"steel_greatsword", &"bow": &"hunting_bow"}
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const SINGLE := Vector2(-90, 10)
const GROUP: Array[Vector2] = [Vector2(100, 0), Vector2(122, -16), Vector2(122, 16)]

var session: SessionState
var weapon_index: int = 0
var mastery_level: int = 1
var _arena: Node
var _label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_label = UiTheme.styled("", &"SmallLabel")
	_label.position = Vector2(16, 16)
	layer.add_child(_label)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene is GameMap and scene != _arena and (scene as GameMap).is_node_ready():
		_arena = scene
		_setup_arena()   # first start and after F5 (arena reload)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_T:
		next_weapon()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_Y:
		set_mastery(20 if mastery_level == 1 else 1)
		get_viewport().set_input_as_handled()


## Equips the next of the four test weapons from the test character's bag.
func next_weapon() -> void:
	weapon_index = (weapon_index + 1) % FAMILIES.size()
	equip(FAMILIES[weapon_index])


func equip(family_id: StringName) -> void:
	weapon_index = FAMILIES.find(family_id)
	var character := session.get_character()
	var item_id: StringName = ITEMS[family_id]
	if character.inventory.count(item_id) == 0:
		character.inventory.add_item(item_id)
	for item in character.inventory.items():
		if item.definition_id == item_id:
			character.equipment.equip(item.instance_id, EquipSlot.Slot.MAIN_HAND)
			return


## Mastery of the four families to `level` (WeaponMastery restore API; the
## bridge then gates the combo paths as in the game).
func set_mastery(level: int) -> void:
	mastery_level = level
	var character := session.get_character()
	var data := character.mastery.to_dict()
	for family_id in FAMILIES:
		data[String(family_id)] = {"level": level, "xp": 0}
	character.mastery.from_dict(data, PackedStringArray())
	var map := _arena as GameMap
	if map != null and map.bridge != null:
		map.bridge.refresh_unlocks()


func player() -> Player:
	return (_arena as GameMap).player if _arena is GameMap else null


## One single target on the left, a group of three on the right (the arena's
## own dummies, moved; scene file unchanged). Dummies never die.
func _setup_arena() -> void:
	var dummies := _arena.get_node_or_null("Dummies")
	if dummies == null:
		return
	var placed: Array[Node2D] = []
	for child in dummies.get_children():
		placed.append(child as Node2D)
	while placed.size() < 4:
		var extra: Node2D = DUMMY_SCENE.instantiate()
		dummies.add_child(extra)
		placed.append(extra)
	var spots: Array[Vector2] = [SINGLE]
	spots.append_array(GROUP)
	for index in placed.size():
		var dummy := placed[index]
		dummy.visible = index < spots.size()
		dummy.process_mode = Node.PROCESS_MODE_INHERIT if index < spots.size() else Node.PROCESS_MODE_DISABLED
		if index < spots.size():
			dummy.position = spots[index]
			var health := dummy.get(&"health") as HealthComponent
			if health != null:
				health.max_health = 100000.0
				health.reset()
	equip(FAMILIES[weapon_index])
	set_mastery(mastery_level)


func _refresh_label() -> void:
	var p := player()
	if p == null or _label == null:
		return
	var character := session.get_character()
	var points := ArmorMasteryService.burden(character)
	var tier := ArmorMasteryService.tier(points, ArmorMasteryService.rules(character))
	var weapon := p.combat.weapon
	_label.text = "COMBAT FEEL TEST (test character, never saved to your slots)\n" \
		+ "Weapon: %s   Mastery: %d   Burden: %s (%d)   Chain: %s\n" % [weapon.display_name if weapon != null else "-",
			p.combat.mastery_level, ArmorMasteryService.TIER_NAMES[tier], points, p.combat.chain if p.combat.chain != "" else "-"] \
		+ "[T] next weapon   [Y] mastery 1 / 20   [F1] hitboxes   [F2] spawn grunt   [F5] reset arena   [F12] debug overlay\n" \
		+ "LMB quick  RMB heavy (bow: hold RMB = Precision Stance, LMB = Precision Shot; hold LMB from mastery 10 = Flowing Draw)  Space dash  Shift block/parry"
