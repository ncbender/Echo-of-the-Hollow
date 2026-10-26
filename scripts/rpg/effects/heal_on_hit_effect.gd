class_name HealOnHitEffect
extends ItemEffect
## Event effect: hits of attacks carrying `required_tag` heal the wearer.
## Rate limited by an internal cooldown.

@export var required_tag: StringName = &"finisher"
@export var heal_amount: float = 3.0
@export var cooldown: float = 1.0


func on_hit_landed(hit: HitData, runner: ItemEffectRunner, source_key: String) -> void:
	if not required_tag in hit.tags or runner.player == null:
		return
	var data := runner.source_state(source_key)
	if runner.time < data.get("ready_at", 0.0):
		return
	data["ready_at"] = runner.time + cooldown
	data["triggers"] = data.get("triggers", 0) + 1
	runner.player.health.heal(heal_amount)
