extends SceneTree
## Builds the app icons from the Manipulator Drone sprite: the drone (base, orange paint, lights)
## scaled up with nearest filtering, centred in a glowing cyan hexagon on the game's dark navy.
## Run: godot --headless --path . -s res://tools/make_app_icon.gd

const ART := "res://art/ships/light/ManipulatorDrone/ManipulatorDrone"
const OUT := "res://assets/icon/"
const NAVY := Color(0.03, 0.05, 0.1)
const HEX_FILL := Color(0.035, 0.085, 0.14)
const CYAN := Color(0.25, 0.95, 1.0)  # HexStyle.CYAN
const PAINT := Color(0.95, 0.5, 0.15)  # Level.PAINT_COLORS[5], orange


func _init() -> void:
	var drone := _drone()
	# size, drone scale, hex circumradius (fraction of size), opaque background
	_save(_tile(512, drone, 10, 0.44, true), "icon_512.png")
	_save(_tile(192, drone, 4, 0.44, true), "icon_192.png")
	_save(_tile(432, drone, 6, 0.315, false), "adaptive_fg_432.png")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(NAVY)
	_save(bg, "adaptive_bg_432.png")
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## The drone as on the lot: hull, paint multiplied by the paint colour, lights added on top.
func _drone() -> Image:
	var img := _load(ART + ".png")
	var paint := _load(ART + "_paint.png")
	var lights := _load(ART + "_lights.png")
	for y in paint.get_height():
		for x in paint.get_width():
			var p := paint.get_pixel(x, y)
			paint.set_pixel(x, y, Color(p.r * PAINT.r, p.g * PAINT.g, p.b * PAINT.b, p.a))
	img.blend_rect(paint, Rect2i(Vector2i.ZERO, paint.get_size()), Vector2i.ZERO)
	for y in img.get_height():
		for x in img.get_width():
			var l := lights.get_pixel(x, y)
			if l.a <= 0.0:
				continue
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r + l.r * l.a, 1.0), minf(c.g + l.g * l.a, 1.0),
				minf(c.b + l.b * l.a, 1.0), maxf(c.a, l.a)))
	return img


## A square tile: navy (or transparent) background, a neon hexagon (pointed left and right, like
## the game's buttons) and the drone scaled by an integer factor in the middle.
func _tile(size: int, drone: Image, scale: int, radius: float, opaque: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := radius * size
	var apothem := r * sqrt(3.0) / 2.0
	var line := maxf(2.0, size / 96.0)  # core line width
	var glow := size / 40.0
	var normals := [Vector2(0, 1), Vector2.from_angle(PI / 6.0), Vector2.from_angle(5.0 * PI / 6.0)]
	var centre := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - centre
			var d := -INF  # signed distance to the hexagon's edge, negative inside
			for n: Vector2 in normals:
				d = maxf(d, absf(p.dot(n)) - apothem)
			var core := clampf(line / 2.0 + 0.75 - absf(d), 0.0, 1.0)
			var halo := exp(-absf(d) / glow) * 0.55
			var c := HEX_FILL if d < 0.0 else NAVY
			var a := 1.0
			if not opaque and d >= 0.0:
				c = CYAN  # outside the hexagon only the glow shows, over transparency
				a = 0.0
			c = c.lerp(CYAN, halo)
			a = maxf(a, halo)
			c = c.lerp(CYAN.lerp(Color.WHITE, 0.35), core)
			a = maxf(a, core)
			img.set_pixel(x, y, Color(c, a))
	var big := drone.duplicate() as Image
	big.resize(drone.get_width() * scale, drone.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var at := (Vector2i(size, size) - big.get_size()) / 2
	img.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), at)
	return img


func _save(img: Image, file: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(OUT + file))
	print("%s: %s" % [file, error_string(err)])
