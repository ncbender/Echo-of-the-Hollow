class_name HitReaction
extends RefCounted
## Reaction types a hit can request from its target. Ordered by severity, so a
## larger value always means a stronger reaction.

enum Type { NONE, FLINCH, INTERRUPT, KNOCKBACK, STUN }


static func name_of(type: int) -> String:
	return Type.keys()[clampi(type, 0, Type.size() - 1)]
