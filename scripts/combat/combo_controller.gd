class_name ComboController
extends RefCounted
## Walks a weapon family's combo tree. Pure logic without nodes; CombatComponent
## decides *when* an attack starts, this class decides *which* one.

signal combo_reset

var weapon: WeaponFamily
## Unlocked requirement ids (weapon mastery etc.) -> true.
var unlocks: Dictionary = {}
## Last attack of the running combo, null when no combo is active.
var current: AttackDefinition
var path: Array[StringName] = []
var window_open: bool = false
var window_left: float = 0.0
## While paused (valid heavy charge) the combo window does not run out.
var paused: bool = false


func set_weapon(new_weapon: WeaponFamily) -> void:
	weapon = new_weapon
	reset()


func is_unlocked(attack: AttackDefinition) -> bool:
	return attack.unlock_requirement == &"" or unlocks.get(attack.unlock_requirement, false)


## The attack the given input would start right now: the follow-up of the current
## combo node if one exists and is unlocked, otherwise the root attack (combo restart).
func resolve(input: AttackDefinition.InputType) -> AttackDefinition:
	if weapon == null:
		return null
	var follow_up := _follow_up(input)
	if follow_up != null:
		return follow_up
	var root := weapon.get_root(input)
	return root if root != null and is_unlocked(root) else null


func commit(attack: AttackDefinition) -> void:
	if current != null and _follow_up(attack.input_type) == attack:
		path.append(attack.id)
	else:
		path.clear()
		path.append(attack.id)
	current = attack
	window_open = false
	window_left = 0.0


func open_window(duration: float) -> void:
	if current == null:
		return
	if duration <= 0.0:
		reset()
		return
	window_open = true
	window_left = duration


func step(delta: float) -> void:
	if not window_open or paused:
		return
	window_left -= delta
	if window_left <= 0.0:
		reset()


func reset() -> void:
	var had_combo := current != null
	current = null
	path.clear()
	window_open = false
	window_left = 0.0
	paused = false
	if had_combo:
		combo_reset.emit()


func _follow_up(input: AttackDefinition.InputType) -> AttackDefinition:
	if current == null:
		return null
	var next_id := current.get_follow_up_id(input)
	if next_id == &"":
		return null
	var attack := weapon.get_attack(next_id)
	return attack if attack != null and is_unlocked(attack) else null
