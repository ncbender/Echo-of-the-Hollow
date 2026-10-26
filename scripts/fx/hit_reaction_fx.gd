class_name HitReactionFx
extends Node2D
## Visual hit reaction for any entity with a Hurtbox: flash amount, shake/knock
## offset and floating damage numbers. Views read `flash` and `offset`.
## Purely cosmetic; never changes gameplay state.

const DAMAGE_NUMBER: GDScript = preload("res://scripts/fx/damage_number.gd")
## Non-physical damage reads by colour (status ticks, skills, essences).
const DAMAGE_TYPE_COLORS := {
	&"bleed": Color("e04050"), &"shock": Color("8fd0ff"), &"arcane": Color("c58cff"),
	&"frost": Color("a8e6f0"), &"shadow": Color("b9a6e8"),
}

@export var hurtbox: Hurtbox
@export var flash_time: float = 0.12
@export var max_offset: float = 5.0
## Fixed damage-number colour (alpha 0 = colour by attack type and charge tier).
@export var number_color: Color = Color(0, 0, 0, 0)

## 0..1, how strongly the entity should flash white.
var flash: float = 0.0
## Visual displacement from knockback/shake in local space.
var offset: Vector2 = Vector2.ZERO
var _offset_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	if hurtbox != null:
		hurtbox.hit_received.connect(_on_hit_received)


func _on_hit_received(hit: HitData) -> void:
	flash = 1.0
	# knockback is a distance in px since Combat Polish 0.2 (was a speed-like value; /25 -> /5
	# keeps the old look for sword light hits).
	var push := hit.knockback.normalized() * minf(max_offset, 2.0 + hit.knockback.length() / 5.0)
	_offset_velocity += push * 30.0
	if hit.damage > 0.0:   # parries and poise-only answers show no "0"
		_spawn_number(hit)


func _spawn_number(hit: HitData) -> void:
	var number: Node2D = DAMAGE_NUMBER.new()
	number.text = str(roundi(hit.damage))
	number.color = _number_color(hit)
	number.global_position = global_position + Vector2(randf_range(-4, 4), -18)
	var world := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(number)


func _number_color(hit: HitData) -> Color:
	if number_color.a > 0.0:
		return number_color
	if DAMAGE_TYPE_COLORS.has(hit.damage_type):
		return DAMAGE_TYPE_COLORS[hit.damage_type]
	if hit.charge_tier >= 2:
		return Color("ffd84a")
	if hit.charge_tier == 1:
		return Color("ff9a3c")
	if hit.attack != null and hit.attack.input_type == AttackDefinition.InputType.HEAVY:
		return Color("ffc2a0")
	return Color("f4f0e6")


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta / flash_time)
	# Damped spring back to rest.
	_offset_velocity += -offset * 400.0 * delta
	_offset_velocity *= exp(-14.0 * delta)
	offset += _offset_velocity * delta
	offset = offset.limit_length(max_offset)
