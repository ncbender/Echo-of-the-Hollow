class_name Stats
extends RefCounted
## Stable stat ids. Final value = (sum of flat) * (1 + sum of percent / 100).

const MAX_HEALTH := &"max_health"
## Percent bonus on outgoing hit damage.
const PHYSICAL_DAMAGE := &"physical_damage"
## Incoming damage reduction: armor / (armor + ARMOR_CONSTANT).
const ARMOR := &"armor"
## Percent chance (0..100) for a critical hit (x CRIT_MULTIPLIER damage).
const CRIT_CHANCE := &"crit_chance"
## Percent faster attack phases (Class Foundation 0.2): CombatComponent.attack_speed
## = 1 + value / 100, clamped by ProgressionRules.attack_speed_min/max.
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
## Class Foundation 0.2 - statuses (docs/SKILL_SYSTEM.md):
## Percent chance that a weapon hit applies Bleeding.
const BLEED_CHANCE := &"bleed_chance"
## Percent bonus on bleeding damage applied by the character.
const BLEED_DAMAGE := &"bleed_damage"
## Percent chance that a weapon hit applies Chill.
const CHILL_CHANCE := &"chill_chance"
## Class Foundation 0.2 - skills:
## Percent bonus on skill hit damage.
const SKILL_DAMAGE := &"skill_damage"
## Percent shorter skill cooldowns (capped at 50).
const COOLDOWN_REDUCTION := &"cooldown_reduction"
## Percent lower class resource costs of skills (capped at 50).
const RESOURCE_EFFICIENCY := &"resource_efficiency"
## Flat bonus on the class resource maximum.
const MAX_RESOURCE := &"max_resource"

const ALL: Array[StringName] = [MAX_HEALTH, PHYSICAL_DAMAGE, ARMOR, CRIT_CHANCE, ATTACK_SPEED, POISE_DAMAGE,
	CRIT_DAMAGE, FINISHER_POWER, KNOCKBACK_POWER, RESOURCE_GAIN, LIFE_ON_HIT, SHOCK_DAMAGE,
	BLEED_CHANCE, BLEED_DAMAGE, CHILL_CHANCE, SKILL_DAMAGE, COOLDOWN_REDUCTION, RESOURCE_EFFICIENCY, MAX_RESOURCE]
const ARMOR_CONSTANT := 100.0
const CRIT_MULTIPLIER := 1.5
const NAMES := {
	MAX_HEALTH: "Max Health", PHYSICAL_DAMAGE: "Physical Damage %", ARMOR: "Armor",
	CRIT_CHANCE: "Crit Chance %", ATTACK_SPEED: "Attack Speed %", POISE_DAMAGE: "Poise Damage %",
	CRIT_DAMAGE: "Crit Damage %", FINISHER_POWER: "Heavy Finisher Power %", KNOCKBACK_POWER: "Knockback %",
	RESOURCE_GAIN: "Resource Gain %", LIFE_ON_HIT: "Life on Hit", SHOCK_DAMAGE: "Shock Damage %",
	BLEED_CHANCE: "Bleed Chance %", BLEED_DAMAGE: "Bleed Damage %", CHILL_CHANCE: "Chill Chance %",
	SKILL_DAMAGE: "Skill Damage %", COOLDOWN_REDUCTION: "Cooldown Reduction %",
	RESOURCE_EFFICIENCY: "Resource Efficiency %", MAX_RESOURCE: "Max Class Resource",
}


static func display_name(stat: StringName) -> String:
	return NAMES.get(stat, String(stat))
