class_name Stats
extends RefCounted
## Stable stat ids. Final value = (sum of flat) * (1 + sum of percent / 100).
## Stats marked "prepared" are resolved and displayed but not used by gameplay yet.

const MAX_HEALTH := &"max_health"
## Percent bonus on outgoing hit damage.
const PHYSICAL_DAMAGE := &"physical_damage"
## Incoming damage reduction: armor / (armor + ARMOR_CONSTANT).
const ARMOR := &"armor"
## Percent chance (0..100) for a critical hit (x CRIT_MULTIPLIER damage).
const CRIT_CHANCE := &"crit_chance"
## Prepared: resolved, NOT applied to combat timings (combat feel is fixed for now).
const ATTACK_SPEED := &"attack_speed"
## Percent bonus on outgoing poise damage.
const POISE_DAMAGE := &"poise_damage"

const ALL: Array[StringName] = [MAX_HEALTH, PHYSICAL_DAMAGE, ARMOR, CRIT_CHANCE, ATTACK_SPEED, POISE_DAMAGE]
const ARMOR_CONSTANT := 100.0
const CRIT_MULTIPLIER := 1.5
const NAMES := {
	MAX_HEALTH: "Max Health", PHYSICAL_DAMAGE: "Physical Damage %", ARMOR: "Armor",
	CRIT_CHANCE: "Crit Chance %", ATTACK_SPEED: "Attack Speed %", POISE_DAMAGE: "Poise Damage %",
}


static func display_name(stat: StringName) -> String:
	return NAMES.get(stat, String(stat))
