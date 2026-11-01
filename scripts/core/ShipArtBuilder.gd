class_name ShipArtBuilder
extends RefCounted
## Turns a ship's pixel-art layers into ship data: traced outline, centre of mass and thrusters.
## The marker layer uses exact colours; see docs/GDD.md §10 "Ship art pipeline".
## One art pixel is ART_SCALE x ART_SCALE game pixels. The nose points up.

const ART_SCALE := 2

enum Kind { ENGINE, RETRO, SIDE, ROTATION, COM }

const KIND_COLORS := {
	Kind.ENGINE: Color8(255, 0, 0),
	Kind.RETRO: Color8(0, 0, 255),
	Kind.SIDE: Color8(0, 255, 0),
	Kind.ROTATION: Color8(255, 255, 0),
	Kind.COM: Color8(255, 0, 255),
}

const TWIST_WARN_SHARE := 0.5  # warn when strafing turns the ship this hard compared to rotating

## Force per button (torque for rotation) shared by that button's thrusters, and mass, per class.
const BUDGETS := {
	ShipSpec.ShipClass.LIGHT: {"fwd": 260.0, "back": 180.0, "strafe": 180.0, "torque": 900.0, "mass": 1.0},
	ShipSpec.ShipClass.MEDIUM: {"fwd": 650.0, "back": 220.0, "strafe": 380.0, "torque": 3200.0, "mass": 2.5},
	ShipSpec.ShipClass.HEAVY: {"fwd": 1000.0, "back": 400.0, "strafe": 650.0, "torque": 9000.0, "mass": 6.0},
}


static func build(base: Image, markers: Image, ship_class: ShipSpec.ShipClass) -> Dictionary:
	var b := base.duplicate() as Image
	var m := markers.duplicate() as Image
	b.convert(Image.FORMAT_RGBA8)
	m.convert(Image.FORMAT_RGBA8)
	var size := Vector2(b.get_size())
	var warnings := PackedStringArray()
	var errors := PackedStringArray()
	var budget: Dictionary = BUDGETS[ship_class]

	var found := _clusters(m, warnings)
	var com := _opaque_centroid(b)
	if found[Kind.COM].size() > 0:
		com = found[Kind.COM][0]["center"]
		if found[Kind.COM].size() > 1:
			warnings.append("more than one centre-of-mass marker; using the first")
	var com_local := _to_local(com, size)

	# Each candidate: {pos: local Vector2, dir: Vector2, action: String, pixels: int}
	var groups := {}
	for c in found[Kind.ENGINE]:
		_add(groups, "thrust_forward", _to_local(c["center"], size), Vector2(0, -1), c["pixels"])
	for c in found[Kind.RETRO]:
		_add(groups, "thrust_back", _to_local(c["center"], size), Vector2(0, 1), c["pixels"])
	for c in found[Kind.SIDE]:
		var dir := _push_from_outline(b, c["center"], warnings)
		_add(groups, "strafe_right" if dir.x > 0.0 else "strafe_left", _to_local(c["center"], size), dir, c["pixels"])
	for c in found[Kind.ROTATION]:
		var dir := _push_from_outline(b, c["center"], warnings)
		var pos := _to_local(c["center"], size)
		var torque := (pos - com_local).cross(dir)
		if absf(torque) < 0.01:
			warnings.append("rotation thruster at art pixel %s is on the centre of mass row; skipped" % _pixel_text(c["center"]))
			continue
		_add(groups, "rotate_right" if torque > 0.0 else "rotate_left", pos, dir, c["pixels"])

	var labels := {
		"thrust_forward": "Fwd (red)", "thrust_back": "Back (blue)",
		"strafe_left": "Left strafe (green on the right side)", "strafe_right": "Right strafe (green on the left side)",
		"rotate_left": "Rot L (yellow)", "rotate_right": "Rot R (yellow)",
	}
	for action in labels:
		if not groups.has(action):
			errors.append("no thrusters for %s" % labels[action])

	var thrusters: Array[ThrusterSpec] = []
	for action in groups:
		var list: Array = groups[action]
		var per_pixel := 0.0
		if action.begins_with("rotate"):
			var lever_sum := 0.0
			for t in list:
				lever_sum += t["pixels"] * absf((t["pos"] - com_local).cross(t["dir"]))
			per_pixel = budget["torque"] / lever_sum
		else:
			var pixel_sum := 0
			for t in list:
				pixel_sum += t["pixels"]
			var key := "fwd" if action == "thrust_forward" else "back" if action == "thrust_back" else "strafe"
			per_pixel = budget[key] / pixel_sum
		for t in list:
			var spec := ThrusterSpec.new()
			spec.position = t["pos"]
			spec.direction = t["dir"]
			spec.force = per_pixel * t["pixels"]
			spec.actions = PackedStringArray([action])
			thrusters.append(spec)

	var com_art_y := com_local.y / ART_SCALE + size.y / 2.0
	var com_row := "art row %d" % int(floor(com_art_y))
	if is_equal_approx(com_art_y, roundf(com_art_y)):  # centre of mass sits on the line between two rows
		com_row = "the line between art rows %d and %d" % [int(com_art_y) - 1, int(com_art_y)]
	for action in ["strafe_left", "strafe_right"]:
		var twist := 0.0
		for t in thrusters:
			if t.actions.has(action):
				twist += t.torque_about(com_local)
		if absf(twist) > budget["torque"] * TWIST_WARN_SHARE:
			warnings.append("%s turns the ship %d%% as hard as rotating; move the green markers closer to %s (the centre of mass)"
					% [action.replace("_", " "), roundi(absf(twist) / budget["torque"] * 100.0), com_row])

	return {
		"hull_size": size * ART_SCALE,
		"hull_polygon": _outline(b, size, warnings),
		"center_of_mass": com_local,
		"inertia": _inertia(b, size, com_local, budget["mass"]),
		"mass": budget["mass"],
		"thrusters": thrusters,
		"warnings": warnings,
		"errors": errors,
	}


static func _add(groups: Dictionary, action: String, pos: Vector2, dir: Vector2, pixels: int) -> void:
	if not groups.has(action):
		groups[action] = []
	groups[action].append({"pos": pos, "dir": dir, "pixels": pixels})


## Art-pixel coordinates (pixel centres) to ship-local game pixels.
static func _to_local(art: Vector2, size: Vector2) -> Vector2:
	return (art - size / 2.0) * ART_SCALE


static func _pixel_text(art: Vector2) -> String:
	return "(%d, %d)" % [int(art.x), int(art.y)]


static func _kind_of(c: Color) -> int:
	if c.a <= 0.5:
		return -1
	for kind in KIND_COLORS:
		var k: Color = KIND_COLORS[kind]
		if c.r8 == k.r8 and c.g8 == k.g8 and c.b8 == k.b8:
			return kind
	return -2  # opaque but not a marker colour


## Groups touching same-colour marker pixels (4-connected). Returns {Kind: [{center, pixels}]}.
static func _clusters(m: Image, warnings: PackedStringArray) -> Dictionary:
	var w := m.get_width()
	var h := m.get_height()
	var result := {}
	for kind in KIND_COLORS:
		result[kind] = []
	var seen := {}
	var strays := 0
	for y in h:
		for x in w:
			var start := Vector2i(x, y)
			if seen.has(start):
				continue
			var kind := _kind_of(m.get_pixelv(start))
			if kind == -2:
				strays += 1
			if kind < 0:
				continue
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			var total := Vector2.ZERO
			var count := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				total += Vector2(p) + Vector2(0.5, 0.5)
				count += 1
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen.has(q):
						continue
					if _kind_of(m.get_pixelv(q)) == kind:
						seen[q] = true
						stack.append(q)
			result[kind].append({"center": total / count, "pixels": count})
	if strays > 0:
		warnings.append("ignored %d pixel(s) in the thruster layer that are not marker colours" % strays)
	return result


## Centre of the opaque base pixels, in art-pixel coordinates.
static func _opaque_centroid(b: Image) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for y in b.get_height():
		for x in b.get_width():
			if b.get_pixel(x, y).a > 0.5:
				total += Vector2(x + 0.5, y + 0.5)
				count += 1
	return total / count if count > 0 else Vector2(b.get_size()) / 2.0


## A side or rotation thruster's nozzle faces the nearest edge of the outline along its row;
## the thruster pushes the other way. Ties face left. A marker drawn on a transparent pixel
## (just outside the hull) pushes toward the nearest hull pixel on its row.
static func _push_from_outline(b: Image, art: Vector2, warnings: PackedStringArray) -> Vector2:
	var row := clampi(int(floor(art.y)), 0, b.get_height() - 1)
	var col := clampi(int(floor(art.x)), 0, b.get_width() - 1)
	if b.get_pixel(col, row).a <= 0.5:
		return _push_toward_hull(b, col, row, warnings)
	var left := 0
	var x := col
	while x >= 0 and b.get_pixel(x, row).a > 0.5:
		left += 1
		x -= 1
	var right := 0
	x = col
	while x < b.get_width() and b.get_pixel(x, row).a > 0.5:
		right += 1
		x += 1
	return Vector2(1, 0) if left <= right else Vector2(-1, 0)


static func _push_toward_hull(b: Image, col: int, row: int, warnings: PackedStringArray) -> Vector2:
	var to_left := -1
	for x in range(col - 1, -1, -1):
		if b.get_pixel(x, row).a > 0.5:
			to_left = col - x
			break
	var to_right := -1
	for x in range(col + 1, b.get_width()):
		if b.get_pixel(x, row).a > 0.5:
			to_right = x - col
			break
	var dir: Vector2
	if to_left < 0 and to_right < 0:
		dir = Vector2(1, 0) if col < b.get_width() / 2 else Vector2(-1, 0)  # nozzle faces the nearer canvas edge
	elif to_right < 0 or (to_left >= 0 and to_left <= to_right):
		dir = Vector2(-1, 0)
	else:
		dir = Vector2(1, 0)
	warnings.append("marker at art pixel (%d, %d) is on a transparent pixel; treated as a nozzle pushing %s"
			% [col, row, "left" if dir.x < 0.0 else "right"])
	return dir


## Moment of inertia of the opaque pixels (each a square of ART_SCALE game px) about the centre of mass.
## Godot's automatic inertia for traced polygons depends on how they split into convex pieces.
static func _inertia(b: Image, size: Vector2, com: Vector2, mass: float) -> float:
	var points := PackedVector2Array()
	for y in b.get_height():
		for x in b.get_width():
			if b.get_pixel(x, y).a > 0.5:
				points.append(_to_local(Vector2(x + 0.5, y + 0.5), size))
	if points.is_empty():
		return 0.0
	var each := mass / points.size()
	var square := ART_SCALE * ART_SCALE / 6.0  # a square's own inertia per unit mass: side^2 / 6
	var total := 0.0
	for p in points:
		total += each * ((p - com).length_squared() + square)
	return total


## Largest traced outline of the opaque pixels, in ship-local game pixels.
static func _outline(b: Image, size: Vector2, warnings: PackedStringArray) -> PackedVector2Array:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(b, 0.5)
	var polys := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, b.get_size()), 0.5)
	if polys.is_empty():
		warnings.append("base art has no opaque pixels; using a rectangle")
		return PackedVector2Array()
	if polys.size() > 1:
		warnings.append(("base art has %d separate parts; only the largest collides. Pixels touching only at a corner "
				+ "count as separate: join parts with a pixel that shares an edge") % polys.size())
	var best: PackedVector2Array = polys[0]
	for p in polys:
		if absf(_area(p)) > absf(_area(best)):
			best = p
	var out := PackedVector2Array()
	for p in best:
		out.append((p - size / 2.0) * ART_SCALE)
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0
