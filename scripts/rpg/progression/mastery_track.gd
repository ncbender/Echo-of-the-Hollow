class_name MasteryTrack
extends Resource
## Data-driven level curve and rewards of one weapon family's mastery.

@export var family_id: StringName
@export var max_level: int = 20
## XP from level n to n+1 = round(xp_base * xp_growth^(n-1)).
@export var xp_base: int = 100
@export var xp_growth: float = 1.15
@export var unlocks: Array[MasteryUnlock] = []


func xp_to_next(level: int) -> int:
	if level >= max_level:
		return 0
	return roundi(xp_base * pow(xp_growth, level - 1))


func unlocks_up_to(level: int) -> Array[MasteryUnlock]:
	var result: Array[MasteryUnlock] = []
	for unlock in unlocks:
		if unlock.level <= level:
			result.append(unlock)
	return result


## The next reward above `level`, or null.
func next_unlock(level: int) -> MasteryUnlock:
	var best: MasteryUnlock = null
	for unlock in unlocks:
		if unlock.level > level and (best == null or unlock.level < best.level):
			best = unlock
	return best
