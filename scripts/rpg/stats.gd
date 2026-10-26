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
## Crafting Foundation 0.1 (all hooked into existing mechanics, see docs/CRAFTING_DESIGN.md):
## Percent added to the critical hit multiplier.
const CRIT_DAMAGE := &"crit_damage"
## Percent bonus on damage AND poise damage of heavy finisher hits (tags heavy + finisher).
const FINISHER_POWER := &"finisher_power"
## Percent bonus on the knockback distance of outgoing hits (Combat Polish 0.2 model).
const KNOCKBACK_POWER := &"knockback_power"
## Percent bonus on class resource gain (rage ...).
const RESOURCE_GAIN := &"resource_gain"
## Health restored per accepted hit.
const LIFE_ON_HIT := &"life_on_hit"
## Percent bonus on shock damage (essence discharges).
const SHOCK_DAMAGE := &"shock_damage"

const ALL: Array[StringName] = [MAX_HEALTH, PHYSICAL_DAMAGE, ARMOR, CRIT_CHANCE, ATTACK_SPEED, POISE_DAMAGE,
	CRIT_DAMAGE, FINISHER_POWER, KNOCKBACK_POWER, RESOURCE_GAIN, LIFE_ON_HIT, SHOCK_DAMAGE]
const ARMOR_CONSTANT := 100.0
const CRIT_MULTIPLIER := 1.5
const NAMES := {
	MAX_HEALTH: "Max Health", PHYSICAL_DAMAGE: "Physical Damage %", ARMOR: "Armor",
	CRIT_CHANCE: "Crit Chance %", ATTACK_SPEED: "Attack Speed %", POISE_DAMAGE: "Poise Damage %",
	CRIT_DAMAGE: "Crit Damage %", FINISHER_POWER: "Heavy Finisher Power %", KNOCKBACK_POWER: "Knockback %",
	RESOURCE_GAIN: "Resource Gain %", LIFE_ON_HIT: "Life on Hit", SHOCK_DAMAGE: "Shock Damage %",
}


static func display_name(stat: StringName) -> String:
	return NAMES.get(stat, String(stat))
