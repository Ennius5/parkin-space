extends SceneTree
## Checks ship data inside an exported pack, where resources load differently than in the editor.
## Usage: godot --headless --path . --export-pack "Android" <dir>/check.pck
##        cd <dir> && godot --headless --main-pack check.pck -s res://tools/check_export_pack.gd

func _init() -> void:
	var problems := 0
	var ships := PackedStringArray()
	for file in DirAccess.get_files_at("res://resources/ships/"):
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			ships.append(file.trim_suffix(".remap").get_basename())
	if ships.is_empty():
		print("FAIL no ship resources found")
		problems += 1
	for ship_name in ships:
		var spec := load("res://resources/ships/%s.tres" % ship_name) as ShipSpec
		if spec == null or spec.thrusters.is_empty():
			print("FAIL %s: no thrusters" % ship_name)
			problems += 1
			continue
		for i in spec.thrusters.size():
			if spec.thrusters[i].actions.is_empty():
				print("FAIL %s thruster %d: no actions" % [ship_name, i])
				problems += 1
	print("EXPORT CHECK PASSED" if problems == 0 else "EXPORT CHECK FAILED")
	quit(problems)
