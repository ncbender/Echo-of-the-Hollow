class_name WeaponFamily
extends Resource
## A weapon family: its attack definitions and the combo-tree roots per input.

@export var id: StringName
@export var display_name: String
@export var root_light: StringName
@export var root_heavy: StringName
@export var attacks: Array[AttackDefinition] = []

@export_group("Presentation")
## Placeholder-visual hints only; gameplay never reads these.
@export var display_color: Color = Color("e8e3d0")
@export var visual_blade_length: float = 14.0

var _by_id: Dictionary = {}


func get_attack(attack_id: StringName) -> AttackDefinition:
	if _by_id.size() != attacks.size():
		_rebuild_index()
	return _by_id.get(attack_id)


func get_root(input: AttackDefinition.InputType) -> AttackDefinition:
	return get_attack(root_light if input == AttackDefinition.InputType.LIGHT else root_heavy)


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
		if attack.input_type == AttackDefinition.InputType.HEAVY and attack.charge_profile == null:
			errors.append("%s: heavy attack %s has no charge profile" % [id, attack.id])
		if attack.startup < 0.0 or attack.active <= 0.0 or attack.recovery < 0.0:
			errors.append("%s: %s has invalid phase timings" % [id, attack.id])
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
	for attack in attacks:
		if attack != null:
			_by_id[attack.id] = attack
