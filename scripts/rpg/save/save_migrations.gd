class_name SaveMigrations
extends RefCounted
## Upgrades older save payloads step by step to SaveSystem.VERSION.
##
## How to change the save schema:
##   1. bump SaveSystem.VERSION to N
##   2. add `N - 1: _v{N-1}_to_v{N}` to STEPS and implement the function
##      (pure Dictionary -> Dictionary, no game objects involved)
##   3. add a test that loads a stored version N-1 payload
## Old files are never rewritten in place; they are upgraded in memory and
## saved in the new format on the next save.

const STEPS := {
	# 1: _v1_to_v2,   (first migration will go here)
}


static func migrate(payload: Dictionary, from_version: int, errors: PackedStringArray) -> Variant:
	var data := payload
	var version := from_version
	while version < SaveSystem.VERSION:
		if not STEPS.has(version):
			errors.append("no migration from save version %d" % version)
			return null
		var step: Callable = STEPS[version]
		data = step.call(data)
		version += 1
	return data
