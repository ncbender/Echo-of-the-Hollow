class_name ComboIcons
extends RefCounted
## Skills & Talents UX 2.0 Phase 1 (docs/SKILLS_TALENTS_UX_2_0.md): the combo entries of a weapon family and
## their icon ids, read from the data only (WeaponFamily, ComboPathDefinition, AttackDefinition) - the art is
## shared by every family whose combo does the same action (combos/<form>_<inputs>[_<effect>], see
## tools/ui_art/generate_core_ui_assets.py). Pure lookups: nothing here changes a combo or an attack.

## Below this hit-sector angle an arc hit reads as a thrust (spear 30-40 degrees, every arc weapon 90+).
const THRUST_ARC := 60.0
## The key of the bow's Flowing Draw (a path without an input sequence).
const FLOWING_DRAW := "flowing_draw"


## sweep / thrust / bolt / arrow - how the family's quick attack hits.
static func form_of(family: WeaponFamily) -> String:
	if family.is_bow():
		return "arrow"
	var base := family.node("L")
	if base != null and base.projectile_speed > 0.0:
		return "bolt"
	if base != null and base.arc_degrees < THRUST_ARC:
		return "thrust"
	return "sweep"


## Art id of the combo whose input sequence is `sequence` ("L", "LLH"; FLOWING_DRAW for the bow's hold).
static func icon_id(family: WeaponFamily, sequence: String) -> StringName:
	if sequence == FLOWING_DRAW:
		return StringName("combos/%s_%s" % [form_of(family), FLOWING_DRAW])
	return StringName("combos/%s_%s%s" % [form_of(family), sequence.to_lower(), _effect(family.node(sequence))])


## The finishing attack's own effect, only where its data has one.
static func _effect(attack: AttackDefinition) -> String:
	if attack == null:
		return ""
	if attack.lunge_distance > 0.0:
		if is_zero_approx(attack.lunge_angle):
			return "_lunge"
		return "_sidestep_r" if attack.lunge_angle > 0.0 else "_sidestep_l"
	if attack.max_hits_per_target > 1:
		return "_x%d" % attack.max_hits_per_target
	if attack.projectile_count > 1:
		return "_twin"
	return ""


## Every combo of `family` for the Weapons tab, base attacks first, then the paths by unlock level:
## [{"key", "sequence" (or FLOWING_DRAW), "name", "level", "description", "attack" (finishing node or null)}].
static func entries(family: WeaponFamily) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["L", "P" if family.is_bow() else "H"]:
		var base := family.node(key)
		if base != null:
			result.append({"key": key, "sequence": key, "name": base.display_name, "level": 1, "description": "", "attack": base})
	var paths := family.combo_paths.duplicate()
	paths.sort_custom(func(a: ComboPathDefinition, b: ComboPathDefinition) -> bool: return a.unlock_level < b.unlock_level)
	for path: ComboPathDefinition in paths:
		var draw := path.kind == ComboPathDefinition.Kind.FLOWING_DRAW
		var sequence := FLOWING_DRAW if draw else path.inputs
		result.append({"key": sequence, "sequence": sequence, "name": path.display_name, "level": path.unlock_level,
			"description": path.description, "attack": null if draw else family.node(path.inputs), "label": path.input_label()})
	return result


## "L-L-H" / "Hold LMB" for an entry.
static func input_label(entry: Dictionary) -> String:
	return entry.get("label", "-".join(PackedStringArray(Array(String(entry.sequence).split("", false)))))
