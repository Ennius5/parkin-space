extends SceneTree
## Builds resources/ships/<name>.tres from the pixel-art layers in art/ships/<light|medium|heavy>/.
## Run --import first so new PNGs have textures, then:
##   godot --headless --path . -s res://tools/build_ships.gd
## Exit code = number of ships with errors (those ships are not written).

const ART_DIR := "res://art/ships/"
const OUT_DIR := "res://resources/ships/"
const CLASSES := {
	"light": ShipSpec.ShipClass.LIGHT,
	"medium": ShipSpec.ShipClass.MEDIUM,
	"heavy": ShipSpec.ShipClass.HEAVY,
}
const MAX_CANVAS := {
	ShipSpec.ShipClass.LIGHT: Vector2i(20, 32),
	ShipSpec.ShipClass.MEDIUM: Vector2i(30, 50),
	ShipSpec.ShipClass.HEAVY: Vector2i(44, 80),
}
const LAYER_SUFFIXES := ["_paint", "_lights", "_thrusters"]


func _init() -> void:
	var failed := 0
	var built := 0
	for folder in CLASSES:
		var dir: String = ART_DIR + folder + "/"
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".png"):
				continue
			var ship_name := file.get_basename()
			if LAYER_SUFFIXES.any(func(s: String) -> bool: return ship_name.ends_with(s)):
				continue
			if _build_ship(dir, ship_name, CLASSES[folder]):
				built += 1
			else:
				failed += 1
	print("\nBuilt %d ship(s), %d with errors." % [built, failed])
	quit(failed)


func _image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _build_ship(dir: String, ship_name: String, ship_class: ShipSpec.ShipClass) -> bool:
	print("\n== %s (%s)" % [ship_name, ShipSpec.ShipClass.keys()[ship_class].to_lower()])
	var base := _image(dir + ship_name + ".png")
	var markers := _image(dir + ship_name + "_thrusters.png")
	var errors := PackedStringArray()
	if markers == null:
		errors.append("missing %s_thrusters.png" % ship_name)
	var size := base.get_size()
	var limit: Vector2i = MAX_CANVAS[ship_class]
	if size.x > limit.x or size.y > limit.y:
		errors.append("canvas %dx%d is bigger than the %dx%d maximum for this class" % [size.x, size.y, limit.x, limit.y])
	for suffix in LAYER_SUFFIXES:
		var layer := _image(dir + ship_name + suffix + ".png")
		if layer and layer.get_size() != size:
			errors.append("%s%s.png is %dx%d but the base is %dx%d" % [ship_name, suffix, layer.get_width(), layer.get_height(), size.x, size.y])
	var result := {}
	if errors.is_empty():
		result = ShipArtBuilder.build(base, markers, ship_class)
		errors.append_array(result["errors"])
		for w in result["warnings"]:
			print("  warning: ", w)
	if not errors.is_empty():
		for e in errors:
			print("  ERROR: ", e)
		print("  not written")
		return false

	var out_path := OUT_DIR + ship_name + ".tres"
	var spec: ShipSpec = load(out_path) if ResourceLoader.exists(out_path) else ShipSpec.new()
	if spec.display_name == "":
		spec.display_name = ship_name.replace("_", " ").capitalize()
	spec.ship_class = ship_class
	spec.mass = result["mass"]
	spec.hull_size = result["hull_size"]
	spec.hull_polygon = result["hull_polygon"]
	spec.center_of_mass = result["center_of_mass"]
	spec.inertia = result["inertia"]
	spec.thrusters = result["thrusters"]
	spec.texture = load(dir + ship_name + ".png")
	spec.paint_texture = load(dir + ship_name + "_paint.png") if FileAccess.file_exists(dir + ship_name + "_paint.png") else null
	spec.lights_texture = load(dir + ship_name + "_lights.png") if FileAccess.file_exists(dir + ship_name + "_lights.png") else null
	var err := ResourceSaver.save(spec, out_path)
	if err != OK:
		print("  ERROR: could not save %s (%s)" % [out_path, error_string(err)])
		return false
	_report(spec)
	print("  wrote ", out_path)
	return true


## What each button does to this ship, so quirks are visible before flying it.
func _report(spec: ShipSpec) -> void:
	var com_art := spec.center_of_mass / ShipArtBuilder.ART_SCALE + spec.hull_size / ShipArtBuilder.ART_SCALE / 2.0
	print("  centre of mass at art pixel (%.1f, %.1f)" % [com_art.x, com_art.y])
	var labels := {
		"thrust_forward": "Fwd", "thrust_back": "Back", "strafe_left": "Left", "strafe_right": "Right",
		"rotate_left": "Rot L", "rotate_right": "Rot R",
	}
	for action in labels:
		var force := Vector2.ZERO
		var torque := 0.0
		for t in spec.thrusters:
			if t.actions.has(action):
				force += t.push()
				torque += t.torque_about(spec.center_of_mass)
		var note := ""
		if action.begins_with("rotate"):
			if force.length() > 1.0:
				note = "  (also pushes the ship %s)" % _dir_word(force)
		elif absf(torque) > 1.0:
			note = "  (also turns %s, torque %d)" % ["right" if torque > 0.0 else "left", int(torque)]
		print("  %-6s force %4d%s" % [labels[action], int(force.length()), note])


func _dir_word(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "back" if v.y > 0.0 else "forward"
