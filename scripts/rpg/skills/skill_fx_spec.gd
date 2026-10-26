class_name SkillFxSpec
extends Resource
## Visual feedback of a skill (Combat Defense & Feedback 0.4). Data only: which
## CombatFx plays on cast (at the caster), on every accepted skill hit (at the
## target) and as an aura while the skill's buff lasts. -1 = no effect.
## Never changes gameplay; hit areas stay those of the skill's actions.

@export var cast_style: int = -1
@export var cast_color: Color = Color.WHITE
@export var cast_radius: float = 14.0
@export var impact_style: int = -1
@export var impact_color: Color = Color.WHITE
@export var impact_radius: float = 12.0
## Pulsing aura around the caster while the skill's buff runs (BuffAction).
@export var aura: bool = false
@export var aura_color: Color = Color.WHITE
## Sound cue ids for the combat audio layer (CombatAudio).
@export var cast_sound: StringName
@export var impact_sound: StringName
