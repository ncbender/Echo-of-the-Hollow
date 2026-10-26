class_name BuffAction
extends SkillAction
## Self buff (Battle Cry, Blood Frenzy, Unbound Fury ...): timed stat modifiers
## through Character runtime stat sources (resolved from scratch - re-casting
## refreshes, never stacks), optional resource gain/heal, paused resource decay
## and an empowered next cast of skills with `empower_tag`.

@export var key: StringName = &"buff"
@export var duration: float = 6.0
@export var stat_modifiers: Array[StatModifier] = []
@export var resource_gain: float = 0.0
## Percent of max health restored.
@export var heal_percent: float = 0.0
## Resource does not decay while the buff lasts.
@export var pause_decay: bool = false
@export var empower_tag: StringName
@export var empower_multiplier: float = 1.0
@export var fx_color: Color = Color(1.0, 0.6, 0.3)


func execute(cast: SkillCast) -> void:
	var runtime := cast.runtime
	if not stat_modifiers.is_empty():
		runtime.add_buff(StringName("buff:%s" % key), duration, stat_modifiers)
	if pause_decay:
		runtime.pause_decay(duration)
	runtime.gain(resource_gain)
	if heal_percent > 0.0:
		var health := cast.player().health
		health.heal(health.max_health * heal_percent / 100.0)
	if empower_tag != &"":
		runtime.empower_next(empower_tag, empower_multiplier)
	var fx: Node2D = AreaStrikeAction.FX_SCRIPT.new()
	fx.set(&"radius", 18.0)
	fx.set(&"color", fx_color)
	cast.spawn(fx, cast.player().global_position)


func describe(_params: SkillParams) -> String:
	var parts: PackedStringArray = []
	if not stat_modifiers.is_empty():
		var mods: PackedStringArray = []
		for modifier in stat_modifiers:
			mods.append(modifier.describe())
		parts.append("%s for %ds" % [", ".join(mods), roundi(duration)])
	if resource_gain > 0.0:
		parts.append("gain %d resource" % roundi(resource_gain))
	if heal_percent > 0.0:
		parts.append("heal %d%% of max health" % roundi(heal_percent))
	if pause_decay:
		parts.append("resource does not decay meanwhile")
	if empower_tag != &"":
		parts.append("your next %s skill deals +%d%% damage" % [empower_tag, roundi((empower_multiplier - 1.0) * 100.0)])
	if parts.is_empty():
		return ""
	var text := "; ".join(parts)
	return text[0].to_upper() + text.substr(1) + "."
