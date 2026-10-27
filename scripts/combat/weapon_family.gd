class_name WeaponFamily
extends Resource
## A weapon family: its attack definitions and how inputs pick them.
## Two models:
##  * Combat Flow (Weapon Mastery 1.4 / Combat Flow 1.5, player families): attacks
##    are nodes of a combo-path tree (AttackDefinition.combo_input), unlocked by
##    the family's mastery level through `combo_paths`.
##  * legacy tree (enemies): root_light / root_heavy and next_light / next_heavy.

## MELEE (also staves and wands): LMB = Quick (L), RMB = instant Heavy (H).
## BOW: LMB = Quick Shot (L), LMB while RMB is held = Precision Shot (P).
enum InputScheme { MELEE, BOW }

@export var id: StringName
@export var display_name: String
@export var root_light: StringName
@export var root_heavy: StringName
@export var attacks: Array[AttackDefinition] = []

@export_group("Combat Flow")
@export var input_scheme: InputScheme = InputScheme.MELEE
## Unlockable complete paths (and the bow's Flowing Draw). Non-empty = Combat Flow family.
@export var combo_paths: Array[ComboPathDefinition] = []

@export_group("Presentation")
## Placeholder-visual hints only; gameplay never reads these.
@export var display_color: Color = Color("e8e3d0")
@export var visual_blade_length: float = 14.0

@export_group("Defense")
## Block/parry behaviour on Shift while this family is wielded (null = no defense).
@export var defense_profile: DefenseProfile

var _by_id: Dictionary = {}
var _by_input: Dictionary = {}


func get_attack(attack_id: StringName) -> AttackDefinition:
	if _by_id.size() != attacks.size():
		_rebuild_index()
	return _by_id.get(attack_id)


func get_root(input: AttackDefinition.InputType) -> AttackDefinition:
	return get_attack(root_light if input == AttackDefinition.InputType.LIGHT else root_heavy)


func uses_flow() -> bool:
	return not combo_paths.is_empty()


func is_bow() -> bool:
	return input_scheme == InputScheme.BOW


## Attack node for an input sequence ("L", "LLH", "PLP"), or null.
func node(sequence: String) -> AttackDefinition:
	if _by_id.size() != attacks.size():
		_rebuild_index()
	return _by_input.get(sequence)


## True when `sequence` may run at mastery `level`: a single input is always a
## base attack; a longer one needs an unlocked complete path that begins with it.
func allows(sequence: String, level: int) -> bool:
	if sequence.length() <= 1:
		return node(sequence) != null
	for path in combo_paths:
		if path.kind == ComboPathDefinition.Kind.PATH and path.unlock_level <= level and path.inputs.begins_with(sequence):
			return node(sequence) != null
	return false


## Mastery level that unlocks the bow's Flowing Draw (0 = this family has none).
func flowing_draw_level() -> int:
	for path in combo_paths:
		if path.kind == ComboPathDefinition.Kind.FLOWING_DRAW:
			return path.unlock_level
	return 0


func unlocked_paths(level: int) -> Array[ComboPathDefinition]:
	var result: Array[ComboPathDefinition] = []
	for path in combo_paths:
		if path.unlock_level <= level:
			result.append(path)
	return result


## The path that ends exactly at `sequence`, or null.
func path_ending(sequence: String) -> ComboPathDefinition:
	for path in combo_paths:
		if path.kind == ComboPathDefinition.Kind.PATH and path.inputs == sequence:
			return path
	return null


## Returns human-readable data errors; empty when the combo tree is consistent.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen := {}
	for attack in attacks:
		if attack == null:
			errors.append("%s: null attack entry" % id)
			continue
		if attack.id == &"":
			errors.append("%s: attack without id" % id)
		elif seen.has(attack.id):
			errors.append("%s: duplicate attack id %s" % [id, attack.id])
		else:
			seen[attack.id] = attack
		if attack.weapon_family_id != id:
			errors.append("%s: %s belongs to family %s" % [id, attack.id, attack.weapon_family_id])
		if not uses_flow() and attack.input_type == AttackDefinition.InputType.HEAVY and attack.charge_profile == null:
			errors.append("%s: heavy attack %s has no charge profile" % [id, attack.id])
		if attack.startup < 0.0 or attack.active <= 0.0 or attack.recovery < 0.0:
			errors.append("%s: %s has invalid phase timings" % [id, attack.id])
	if uses_flow():
		_validate_flow(errors)
		return errors
	if root_light == &"" and root_heavy == &"":
		errors.append("%s: needs at least one root attack" % id)
	_check_link(errors, seen, root_light, AttackDefinition.InputType.LIGHT, "root_light", true)
	_check_link(errors, seen, root_heavy, AttackDefinition.InputType.HEAVY, "root_heavy", true)
	for attack in attacks:
		if attack == null:
			continue
		_check_link(errors, seen, attack.next_light, AttackDefinition.InputType.LIGHT, "%s.next_light" % attack.id, true)
		_check_link(errors, seen, attack.next_heavy, AttackDefinition.InputType.HEAVY, "%s.next_heavy" % attack.id, true)
	return errors


func _validate_flow(errors: PackedStringArray) -> void:
	var symbols := "LP" if is_bow() else "LH"
	var inputs := {}
	for attack in attacks:
		if attack == null:
			continue
		if not attack.is_flow():
			errors.append("%s: %s has no combo_input" % [id, attack.id])
			continue
		if inputs.has(attack.combo_input):
			errors.append("%s: two attacks for input %s" % [id, attack.combo_input])
		inputs[attack.combo_input] = attack
		for symbol in attack.combo_input:
			if not symbol in symbols:
				errors.append("%s: %s uses input %s" % [id, attack.id, symbol])
		if attack.charge_profile != null:
			errors.append("%s: %s is charged (Combat Flow heavies are instant)" % [id, attack.id])
		if attack.max_hits_per_target < 1:
			errors.append("%s: %s needs a hit limit" % [id, attack.id])
		var used := attack.combo_input.length() == 1
		for path in combo_paths:
			used = used or (path.kind == ComboPathDefinition.Kind.PATH and path.inputs.begins_with(attack.combo_input))
		if not used:
			errors.append("%s: %s (%s) is on no path" % [id, attack.id, attack.combo_input])
	for symbol in symbols:
		if not inputs.has(symbol):
			errors.append("%s: no base attack for %s" % [id, symbol])
	for path in combo_paths:
		if path == null:
			errors.append("%s: null combo path" % id)
			continue
		if path.display_name == "":
			errors.append("%s: path %s without name" % [id, path.inputs])
		if path.kind == ComboPathDefinition.Kind.FLOWING_DRAW:
			if not is_bow():
				errors.append("%s: Flowing Draw on a non-bow family" % id)
			continue
		if path.inputs.length() < 2:
			errors.append("%s: path %s is shorter than two inputs" % [id, path.inputs])
		for length in range(1, path.inputs.length() + 1):
			if not inputs.has(path.inputs.left(length)):
				errors.append("%s: path %s has no attack for %s" % [id, path.display_name, path.inputs.left(length)])
		var finisher: AttackDefinition = inputs.get(path.inputs)
		if finisher != null and finisher.display_name != path.display_name:
			errors.append("%s: end node %s is named %s, path is %s" % [id, path.inputs, finisher.display_name, path.display_name])


func _check_link(errors: PackedStringArray, seen: Dictionary, target: StringName,
		input: AttackDefinition.InputType, label: String, optional: bool = false) -> void:
	if target == &"":
		if not optional:
			errors.append("%s: %s is empty" % [id, label])
		return
	var attack: AttackDefinition = seen.get(target)
	if attack == null:
		errors.append("%s: %s points to unknown attack %s" % [id, label, target])
	elif attack.input_type != input:
		errors.append("%s: %s points to %s with wrong input type" % [id, label, target])


func _rebuild_index() -> void:
	_by_id.clear()
	_by_input.clear()
	for attack in attacks:
		if attack != null:
			_by_id[attack.id] = attack
			if attack.combo_input != "":
				_by_input[attack.combo_input] = attack
