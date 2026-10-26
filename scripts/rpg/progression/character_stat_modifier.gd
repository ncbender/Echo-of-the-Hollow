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
	var crit: float = stats.get(Stats.CRIT_CHANCE, 0.0)
	if crit > 0.0 and rng.randf() * 100.0 < crit:
		hit.damage *= Stats.CRIT_MULTIPLIER
		hit.tags.append(&"crit")
