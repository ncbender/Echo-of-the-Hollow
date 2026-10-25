class_name TestErrorCounter
extends Logger
## Counts engine/script errors and warnings so a test that hits a runtime error
## fails instead of silently returning early.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [text, file, line, function])
	_mutex.unlock()


func take_errors() -> PackedStringArray:
	_mutex.lock()
	var result := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return result
