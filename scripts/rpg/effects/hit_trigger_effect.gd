class_name HitTriggerEffect
extends ItemEffect
## Talent/item effect: when a dispatched hit matches `condition`, react once:
## gain class resource, heal, apply statuses, reduce cooldowns, consume a status
## for extra damage, and/or release a burst around the target. Amounts scale
## with the rank (power). Limits: chance, internal cooldown, once per swing/cast,
## and every hit it creates is TRIGGERED at depth + 1 (the runner never
## dispatches beyond MAX_TRIGGER_DEPTH - no chains).

const FX_SCRIPT: GDScript = preload("res://scripts/fx/shockwave_fx.gd")

@export var condition: HitCondition
@export_range(0.0, 1.0) var chance: float = 1.0
@export var cooldown: float = 0.0
## Only the first matching hit of one swing / cast counts.
@export var once_per_swing: bool = false

@export_group("Per Rank")
@export var resource_gain: float = 0.0
@export var heal_flat: float = 0.0
## Heal this fraction of the hit's damage.
@export var heal_ratio: float = 0.0
@export var statuses: Array[SkillStatusSpec] = []
## Status stacks scale with the rank.
@export var stacks_per_rank: bool = false
@export var cooldown_reduction: float = 0.0
## &"" = all skills.
@export var cooldown_skill: StringName

@export_group("Consume")
## Consumes this status on the target (when it has >= consume_min_stacks) for
## consume_damage_per_stack damage per stack (per rank).
@export var consume_status: StringName
@export var consume_min_stacks: int = 1
@export var consume_damage_per_stack: float = 0.0
@export var consume_damage_type: StringName = &"physical"

@export_group("Burst")
@export var burst_radius: float = 0.0
## Fraction of the triggering hit's damage (per rank).
@export var burst_damage_ratio: float = 0.0
@export var burst_poise: float = 0.0
@export var burst_knockback: float = 0.0
@export var burst_statuses: Array[SkillStatusSpec] = []
@export var burst_includes_target: bool = false
@export var fx_color: Color = Color(1.0, 0.7, 0.4)


func on_hit_landed(hit: HitData, runner: ItemEffectRunner, source_key: String) -> void:
	if condition != null and not condition.matches(hit, runner):
		return
	var data := runner.source_state(source_key)
	if runner.time < data.get("ready_at", -1.0):
		return
	if once_per_swing and data.get("last_swing", 0) == hit.attack_instance_id and hit.attack_instance_id != 0:
		return
	if chance < 1.0 and runner.rng.randf() >= chance:
		return
	data["ready_at"] = runner.time + cooldown
	data["last_swing"] = hit.attack_instance_id
	data["triggers"] = data.get("triggers", 0) + 1
	var power := runner.power(source_key)
	if resource_gain > 0.0:
		runner.gain_resource(resource_gain * power)
	var heal := heal_flat * power + hit.damage * heal_ratio * power
	if heal > 0.0 and runner.player != null:
		runner.player.health.heal(heal)
	for spec in statuses:
		runner.apply_status(hit.target, spec.status_id, spec.power, spec.stacks * (roundi(power) if stacks_per_rank else 1))
	if cooldown_reduction > 0.0:
		runner.reduce_cooldown(cooldown_skill, cooldown_reduction * power)
	if consume_status != &"":
		_consume(hit, runner, power)
	if burst_radius > 0.0:
		_burst(hit, runner, power)


func _consume(hit: HitData, runner: ItemEffectRunner, power: float) -> void:
	var status := StatusComponent.of(hit.target)
	if status == null or status.stacks(consume_status) < consume_min_stacks:
		return
	var hurtbox := hit.target.get_node_or_null("Hurtbox") as Hurtbox
	var stacks := status.consume(consume_status)
	if hurtbox == null or stacks <= 0:
		return
	var rupture := _triggered(hit, hurtbox)
	rupture.damage = stacks * consume_damage_per_stack * power
	rupture.damage_type = consume_damage_type
	rupture.tags.append(StringName("rupture_%s" % consume_status))
	if hurtbox.receive_hit(rupture):
		runner.dispatch_hit(rupture)


func _burst(hit: HitData, runner: ItemEffectRunner, power: float) -> void:
	for hurtbox in runner.query_hurtboxes(hit.position, burst_radius):
		if not burst_includes_target and hurtbox.get_entity() == hit.target:
			continue
		var wave := _triggered(hit, hurtbox)
		wave.damage = hit.damage * burst_damage_ratio * power
		wave.poise_damage = burst_poise
		wave.knockback = (hurtbox.global_position - hit.position).normalized() * burst_knockback
		wave.tags.append(effect_id)
		if hurtbox.receive_hit(wave):
			for spec in burst_statuses:
				runner.apply_status(wave.target, spec.status_id, spec.power, spec.stacks)
			runner.dispatch_hit(wave)
	var fx: Node2D = FX_SCRIPT.new()
	fx.set(&"radius", burst_radius)
	fx.set(&"color", fx_color)
	runner.spawn_fx(fx, hit.position)


func _triggered(hit: HitData, hurtbox: Hurtbox) -> HitData:
	var result := HitData.new()
	result.source = HitData.Source.TRIGGERED
	result.depth = hit.depth + 1
	result.attacker = hit.attacker
	result.target = hurtbox.get_entity()
	result.attack_instance_id = hit.attack_instance_id
	result.position = hurtbox.global_position
	result.damage_type = hit.damage_type
	return result
