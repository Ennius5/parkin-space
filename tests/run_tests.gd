extends Node
## Headless test runner: runs every test_* method in res://tests/test_*.gd.
## Usage: godot --headless --path <project> res://tests/TestRunner.tscn


func _ready() -> void:
	await get_tree().process_frame  # let autoloads finish _ready
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests/"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for m in script.get_script_method_list():
			var method_name := String(m.name)
			if not method_name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = get_tree()
			await t.call(method_name)
			total += 1
			if t.failures.is_empty():
				print("  ok   %s.%s" % [file, method_name])
			else:
				failed += 1
				print("  FAIL %s.%s: %s" % [file, method_name, "; ".join(t.failures)])
	print("%d tests, %d failed" % [total, failed])
	print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
	get_tree().quit(0 if failed == 0 else 1)
