class_name ComboPathDefinition
extends Resource
## One unlockable combo path of a weapon family (Weapon Mastery 1.4). `inputs`
## is the complete input sequence ("LLH"; bows use L and P). A prefix may only be
## continued when at least one unlocked complete path begins with it.

enum Kind { PATH, FLOWING_DRAW }

@export var inputs: String = ""
@export var unlock_level: int = 2
## English name shown to the player (exact names from the design).
@export var display_name: String
@export_multiline var description: String
## FLOWING_DRAW: the bow's hold-to-fire sequence (no input sequence).
@export var kind: Kind = Kind.PATH


## "L-L-H" for the UI, "Hold LMB" for Flowing Draw.
func input_label() -> String:
	if kind == Kind.FLOWING_DRAW:
		return "Hold LMB"
	return "-".join(PackedStringArray(Array(inputs.split("", false))))
