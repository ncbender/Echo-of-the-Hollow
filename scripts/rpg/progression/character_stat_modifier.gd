class_name CharacterStatModifier
extends AttackModifier
## Applies the character's resolved offensive stats to every outgoing hit through
## the existing AttackModifier hook (no parallel damage logic).
## Default character stats are neutral (0 %), so base combat balance is unchanged.

var stats: Dictionary = {}
var rng := RandomNumberGenerator.new()


func modify_hit(hit: HitData) -> void:
	hit.damage *= 1.0 + stats.get(Stats.PHYSICAL_DAMAGE, 0.0) / 100.0
	hit.poise_damage *= 1.0 + stats.get(Stats.POISE_DAMAGE, 0.0) / 100.0
	if &"heavy" in hit.tags and &"finisher" in hit.tags:
		var finisher: float = 1.0 + stats.get(Stats.FINISHER_POWER, 0.0) / 100.0
		hit.damage *= finisher
		hit.poise_damage *= finisher
	# Distance-based knockback (KnockbackMotion): scaled once here, the receiver
	# applies its resistance once - no other multiplier is involved.
	hit.knockback *= 1.0 + stats.get(Stats.KNOCKBACK_POWER, 0.0) / 100.0
	var crit: float = stats.get(Stats.CRIT_CHANCE, 0.0)
	if crit > 0.0 and rng.randf() * 100.0 < crit:
		hit.damage *= Stats.CRIT_MULTIPLIER + stats.get(Stats.CRIT_DAMAGE, 0.0) / 100.0
		hit.tags.append(&"crit")
