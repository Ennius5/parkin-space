extends Node
## Headless test runner: runs every test_* method in res://tests/test_*.gd.
## Usage: godot --headless --path <project> res://tests/TestRunner.tscn


## Records engine and script errors so a test that crashes mid-way counts as failed.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	await get_tree().process_frame  # let autoloads finish _ready
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests/"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("  FAIL %s: script failed to load" % file)
			continue
		for m in script.get_script_method_list():
			var method_name := String(m.name)
			if not method_name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = get_tree()
			catcher.errors.clear()
			await t.call(method_name)
			for e in catcher.errors:
				t.failures.append("engine error: " + e)
			total += 1
			if t.failures.is_empty():
				print("  ok   %s.%s" % [file, method_name])
			else:
				failed += 1
				print("  FAIL %s.%s: %s" % [file, method_name, "; ".join(t.failures)])
	print("%d tests, %d failed" % [total, failed])
	print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
	get_tree().quit(0 if failed == 0 else 1)
