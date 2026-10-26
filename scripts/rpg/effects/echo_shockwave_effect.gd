class_name EchoShockwaveEffect
extends ItemEffect
## Legendary event effect: when a HEAVY FINISHER (attack tagged with all
## `required_tags`) hits, an echo shockwave damages every other enemy hurtbox
## around the struck target. Limits: once per swing (attack instance) and an
## internal cooldown. Shockwave hits go straight to the hurtboxes, so they can
## never re-trigger item effects or give XP.

const FX_SCRIPT: GDScript = preload("res://scripts/fx/shockwave_fx.gd")

@export var required_tags: Array[StringName] = [&"heavy", &"finisher"]
@export var radius: float = 52.0
## Fraction of the triggering hit's damage dealt by the shockwave.
@export var damage_ratio: float = 0.4
@export var poise_damage: float = 10.0
## Knockback distance in px (same model as attacks, see KnockbackMotion).
@export var knockback_distance: float = 5.0
@export var cooldown: float = 0.5


func on_hit_landed(hit: HitData, runner: ItemEffectRunner, source_key: String) -> void:
	for tag in required_tags:
		if not tag in hit.tags:
			return
	var data := runner.source_state(source_key)
	if data.get("last_swing", -1) == hit.attack_instance_id:
		return   # several targets of one swing trigger it only once
	if runner.time < data.get("ready_at", 0.0):
		return
	data["last_swing"] = hit.attack_instance_id
	data["ready_at"] = runner.time + cooldown
	data["triggers"] = data.get("triggers", 0) + 1
	var center := hit.position
	var struck: int = 0
	for hurtbox in runner.query_hurtboxes(center, radius):
		if hurtbox.get_entity() == hit.target:
			continue
		var echo := HitData.new()
		echo.attacker = hit.attacker
		echo.attack = hit.attack
		echo.attack_instance_id = hit.attack_instance_id
		echo.damage = hit.damage * damage_ratio
		echo.poise_damage = poise_damage
		echo.knockback = (hurtbox.global_position - center).normalized() * knockback_distance
		echo.position = hurtbox.global_position
		echo.tags.append(&"echo_shockwave")
		if hurtbox.receive_hit(echo):
			struck += 1
	data["last_struck"] = struck
	var fx: Node2D = FX_SCRIPT.new()
	fx.set(&"radius", radius)
	runner.spawn_fx(fx, center)
