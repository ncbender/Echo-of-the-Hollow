extends SceneTree
## Headless test runner.
##
## Usage (see tools/run_tests.ps1):
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- --suite=dash,combo
## Without --suite every test file runs. A suite name matches tests/**/test_<name>.gd.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]

var _error_counter := TestErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_error_counter)
	_run.call_deferred()


func _run() -> void:
	var suites := _requested_suites()
	var files := _collect_files(suites)
	if files.is_empty():
		printerr("No test files matched suites: %s" % [suites])
		quit(2)
		return

	var passed := 0
	var failed: PackedStringArray = []
	var started := Time.get_ticks_msec()
	for path in files:
		print("\n== %s" % path.get_file())
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: could not load" % path)
			continue
		for method_name in _test_methods(script):
			var test: TestCase = script.new()
			root.add_child(test)
			_error_counter.take_errors()
			await test.call(&"before_each")
			await test.call(method_name)
			await test.call(&"after_each")
			for error in _error_counter.take_errors():
				test.fail("engine error: " + error)
			if test.failures.is_empty():
				passed += 1
				print("  PASS %s" % method_name)
			else:
				failed.append("%s::%s" % [path.get_file(), method_name])
				print("  FAIL %s" % method_name)
				for message in test.failures:
					print("       - " + message)
			test.queue_free()
			Engine.time_scale = 1.0
			await process_frame

	print("\n%d passed, %d failed (%d ms)" % [passed, failed.size(), Time.get_ticks_msec() - started])
	for name in failed:
		print("  failed: " + name)
	quit(1 if not failed.is_empty() else 0)


func _requested_suites() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			return arg.trim_prefix("--suite=").split(",", false)
	return PackedStringArray()


func _collect_files(suites: PackedStringArray) -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in TEST_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			var suite := file.trim_prefix("test_").trim_suffix(".gd")
			if suites.is_empty() or suite in suites:
				files.append(dir_path.path_join(file))
	return files


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method in script.get_script_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_") and not method_name in names:
			names.append(method_name)
	return names
