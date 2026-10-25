class_name TestCase
extends Node
## Minimal test base class used by tests/run_tests.gd.
## Every `test_*` method runs on a fresh instance that is added to the scene tree,
## so tests may await physics frames and instance scenes freely.

const FRAME := 1.0 / 60.0

var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func check(condition: bool, message: String) -> bool:
	if not condition:
		fail(message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	var same_kind := typeof(actual) == typeof(expected) \
		or (_is_number(actual) and _is_number(expected)) \
		or (_is_text(actual) and _is_text(expected))
	if not same_kind or actual != expected:
		fail("%s (expected <%s>, got <%s>)" % [message, str(expected), str(actual)])
		return false
	return true


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> bool:
	if absf(actual - expected) > tolerance:
		fail("%s (expected %.4f ± %.4f, got %.4f)" % [message, expected, tolerance, actual])
		return false
	return true


func wait_physics(frames: int = 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
