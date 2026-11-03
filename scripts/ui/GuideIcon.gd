class_name GuideIcon
extends Control
## A small picture of one game element for the How to Play guide, drawn with the game's own
## colours and constants so it matches what the player sees on the lot.

const SIZE := Vector2(72, 72)
const SHIP_ROW_SIZE := Vector2(100, 100)  # a ship-page row: every class fills it
const SHIP_SPEC := "res://resources/ships/Milano.tres"
const PAD_LABELS := {
	&"pad_fwd": "Fwd", &"pad_back": "Back", &"pad_left": "Left", &"pad_right": "Right",
	&"pad_rot_l": "Rot L", &"pad_rot_r": "Rot R", &"pad_stop": "STOP", &"pad_stop_spin": "Stop\nSpin",
	&"pad_done": "Done",
}
const KINDS: Array[StringName] = [
	&"ship", &"space_free", &"space_sizes", &"space_ready", &"space_gold", &"dent", &"stars",
	&"coin_bronze", &"coin_silver", &"coin_gold", &"request_glow", &"bay", &"exit",
	&"radiation", &"asteroid", &"black_hole", &"orphan", &"pin", &"move",
	&"wifi", &"ring_host", &"ring_guest", &"pause", &"sound", &"cctv", &"clock",
	&"pad_fwd", &"pad_back", &"pad_left", &"pad_right", &"pad_rot_l", &"pad_rot_r",
	&"pad_stop", &"pad_stop_spin", &"pad_done",
]

@export var kind: StringName = &"ship":
	set(value):
		kind = value
		queue_redraw()

## The ship the `ship` kind draws, in this paint; null = the Milano in a customer's blue.
var spec: ShipSpec:
	set(value):
		spec = value
		custom_minimum_size = SHIP_ROW_SIZE if value else SIZE
		queue_redraw()
var paint: Color = Level.PAINT_COLORS[1]

var _ship_spec: ShipSpec
var _ship_outline := PackedVector2Array()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	match kind:
		&"ship":
			_ship(c, _row_ship_length() if spec else 68.0)
		&"space_free":
			_space(Rect2(c - Vector2(24, 32), Vector2(48, 64)), ParkingSpace.FREE_COLOR, "M")
		&"space_sizes":
			_space(Rect2(Vector2(2, 40), Vector2(18, 28)), ParkingSpace.FREE_COLOR, "L", 13)
			_space(Rect2(Vector2(23, 28), Vector2(22, 40)), ParkingSpace.FREE_COLOR, "M", 13)
			_space(Rect2(Vector2(48, 14), Vector2(22, 54)), ParkingSpace.FREE_COLOR, "H", 13)
		&"space_ready":
			var rect := Rect2(c - Vector2(24, 32), Vector2(48, 64))
			_ship(c, 44.0)
			draw_rect(rect, ParkingSpace.READY_COLOR, false, 3.0)
		&"space_gold":
			_space(Rect2(c - Vector2(26, 32), Vector2(52, 64)), ParkingSpace.FREE_COLOR, "M ★", 18)
		&"dent":
			_ship(c + Vector2(-6, 4), 52.0)
			_burst(c + Vector2(16, -16), 14.0, Color(1.0, 0.35, 0.25))
		&"stars":
			_text("★★★", c, 26, Color(1, 0.82, 0.2))
		&"coin_bronze":
			_coin(c, Customer.TIER_COLORS[Customer.Tier.BRONZE])
		&"coin_silver":
			_coin(c, Customer.TIER_COLORS[Customer.Tier.SILVER])
		&"coin_gold":
			_coin(c, Customer.TIER_COLORS[Customer.Tier.GOLD])
		&"request_glow":
			_glow_ship(c, 56.0)
		&"bay":
			_bay(Rect2(c - Vector2(22, 32), Vector2(44, 64)))
		&"exit":
			var rect := Rect2(c - Vector2(30, 32), Vector2(60, 64))
			draw_rect(rect, Color(ExitPad.COLOR, 0.12))
			draw_rect(rect, ExitPad.COLOR, false, 3.0)
			_text("EXIT", c, 16, ExitPad.COLOR)
		&"radiation":
			var col := RadiationZone.COLOR
			draw_circle(c, 32.0, Color(col, 0.2))
			draw_circle(c, 12.0, Color(col, 0.18))
			draw_arc(c, 20.0, 0.0, TAU, 32, Color(col, 0.35), 2.0)
			draw_arc(c, 32.0, 0.0, TAU, 40, Color(col, 0.7), 4.0)
		&"asteroid":
			_asteroid(c, 26.0)
		&"black_hole":
			for i in BlackHole.RING_COLORS.size():
				var r := 18.0 + i * 6.0
				var spin := i * 2.1
				draw_arc(c, r, spin, spin + PI * 1.3, 24, Color(BlackHole.RING_COLORS[i], 0.75), 4.0 - i)
			draw_circle(c, 16.0, Color.BLACK)
			draw_arc(c, 16.0, 0.0, TAU, 32, Color(1.0, 0.7, 0.4, 0.9), 2.0)
		&"orphan":
			_ship(c + Vector2(0, -6), 48.0, Ship.ORPHAN_TINT)
			var coin := Color(0.6, 0.6, 0.6)
			draw_circle(c + Vector2(0, -6), 8.0, coin)
			_text("0:42", c + Vector2(0, 26), 16, coin)
		&"pin":
			var col := Customer.TIER_COLORS[Customer.Tier.SILVER] as Color
			var at := Vector2(c.x - 14, c.y + 4)
			draw_line(at + Vector2(0, -6), at + Vector2(0, 14), col, 3.0)
			draw_circle(at + Vector2(0, -14), 11.0, col)
			draw_arc(at + Vector2(0, -14), 11.0, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
			_text("G4", at + Vector2(30, -8), 20, col)
		&"move":
			_ship(c + Vector2(-12, 0), 48.0)
			var col := HexStyle.CYAN
			draw_line(c + Vector2(10, 0), c + Vector2(32, 0), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(34, 0), c + Vector2(24, -8), c + Vector2(24, 8)]), col)
		&"wifi":
			var base := c + Vector2(0, 20)
			for i in 3:
				draw_arc(base, 12.0 + i * 12.0, -PI * 0.75, -PI * 0.25, 16, HexStyle.CYAN, 4.0)
			draw_circle(base, 4.0, HexStyle.CYAN)
		&"ring_host":
			_ring_ship(c, HexStyle.CYAN)
		&"ring_guest":
			_ring_ship(c, HexStyle.MAGENTA)
		&"pause":
			HexStyle.draw_hex(get_canvas_item(), Rect2(Vector2(4, 12), size - Vector2(8, 24)), HexStyle.CYAN, Color(0.02, 0.06, 0.1, 0.75), 0.35, 3.0)
			_text("II", c, 24, HexStyle.CYAN)
		&"sound":
			var col := HexStyle.CYAN
			draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -8), c + Vector2(-12, -8), c + Vector2(0, -20),
				c + Vector2(0, 20), c + Vector2(-12, 8), c + Vector2(-22, 8)]), col)
			for i in 2:
				draw_arc(c + Vector2(2, 0), 10.0 + i * 10.0, -PI * 0.3, PI * 0.3, 12, col, 3.0)
		&"cctv":
			var screen := Rect2(c - Vector2(30, 22), Vector2(60, 44))
			draw_rect(screen, Color(0.1, 0.12, 0.1))
			for y in range(int(screen.position.y) + 3, int(screen.end.y), 5):
				draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(1, 1, 1, 0.12), 1.0)
			draw_rect(screen, Color(0.8, 0.85, 0.8), false, 2.0)
			draw_circle(screen.position + Vector2(9, 9), 4.0, Color(1, 0.2, 0.2))
			_text("REC", screen.position + Vector2(32, 10), 11, Color(0.9, 0.9, 0.9))
		&"clock":
			var col := HexStyle.CYAN
			draw_arc(c, 28.0, 0.0, TAU, 40, col, 3.0)
			draw_line(c, c + Vector2(0, -18), col, 3.0)
			draw_line(c, c + Vector2(13, 6), col, 3.0)
			draw_circle(c, 3.0, col)
		_:
			if PAD_LABELS.has(kind):
				_pad(PAD_LABELS[kind])


# --- pieces ---

## The ship as on the lot (hull, paint, lights), scaled so its longest side is `length`.
## An orphan (tinted) has no paint or lights, as in the game.
func _ship(center: Vector2, length: float, tint := Color.WHITE) -> void:
	var ship := ship_spec()
	if ship == null or ship.texture == null:
		draw_rect(Rect2(center - Vector2(length * 0.3, length * 0.5), Vector2(length * 0.6, length)), tint)
		return
	var tex := ship.texture
	var s := length / maxf(tex.get_width(), tex.get_height())
	var rect := Rect2(center - tex.get_size() * s / 2.0, tex.get_size() * s)
	draw_texture_rect(tex, rect, false, tint)
	if tint != Color.WHITE:
		return
	if ship.paint_texture:
		draw_texture_rect(ship.paint_texture, rect, false, paint)
	if ship.lights_texture:
		draw_texture_rect(ship.lights_texture, rect, false)


## The longest side of a ship-row ship: the biggest quarter-step scale that fits (light 3x, medium 2x,
## heavy 1.25x), so pixels stay as even as they can.
func _row_ship_length() -> float:
	var tex := spec.texture
	if tex == null:
		return SHIP_ROW_SIZE.y
	var longest := maxf(tex.get_width(), tex.get_height())
	return longest * maxf(0.25, floorf(SHIP_ROW_SIZE.y / longest * 4.0) / 4.0)


func ship_spec() -> ShipSpec:
	if spec:
		return spec
	if _ship_spec == null:
		_ship_spec = load(SHIP_SPEC) as ShipSpec
	return _ship_spec


func ship_texture() -> Texture2D:
	var ship := ship_spec()
	return ship.texture if ship else null


## A ship whose owner wants it back: its outline glows in Ship.GLOW_COLOR, as on the lot.
func _glow_ship(center: Vector2, length: float) -> void:
	var tex := ship_texture()
	if tex:
		if _ship_outline.is_empty():
			_ship_outline = SpriteOutline.outline(tex, 1.0)
		var s := length / maxf(tex.get_width(), tex.get_height())
		var closed := PackedVector2Array()
		for p in _ship_outline:
			closed.append(center + p * s)
		if not closed.is_empty():
			closed.append(closed[0])
			draw_polyline(closed, Color(Ship.GLOW_COLOR, 0.3), 10.0, true)
			draw_polyline(closed, Color(Ship.GLOW_COLOR, 0.65), 4.0, true)
	_ship(center, length)


func _ring_ship(center: Vector2, ring: Color) -> void:
	_ship(center, 50.0)
	draw_arc(center, 31.0, 0.0, TAU, 40, ring, Ship.RING_WIDTH)


func _space(rect: Rect2, color: Color, letter: String, font_size := 22) -> void:
	draw_rect(rect, color, false, 3.0)
	_text(letter, rect.get_center(), font_size, color)


func _coin(center: Vector2, color: Color) -> void:
	draw_circle(center, 18.0, color)
	draw_arc(center, 18.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 3.0)
	_text("₵", center, 20, Color(0, 0, 0, 0.55))


func _bay(rect: Rect2) -> void:
	var col := ArrivalBay.COLOR
	var bright := Color(col, 1.0)
	draw_rect(rect, Color(col, 0.08))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], bright, 2.0, 6.0)
	_ship(rect.get_center(), 40.0)


func _asteroid(center: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	var bumps := [1.0, 0.8, 0.95, 0.75, 1.0, 0.85, 0.9, 0.7, 0.95]
	for i in bumps.size():
		pts.append(center + Vector2.from_angle(TAU * i / bumps.size()) * radius * float(bumps[i]))
	draw_colored_polygon(pts, Color(0.45, 0.4, 0.36))
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(0.7, 0.64, 0.58), 2.0, true)
	draw_circle(center + Vector2(-7, -5), 5.0, Color(0.35, 0.31, 0.28))
	draw_circle(center + Vector2(8, 7), 3.5, Color(0.35, 0.31, 0.28))


func _burst(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2.from_angle(TAU * i / 16.0) * r)
	draw_colored_polygon(pts, color)


## A driving-pad button: a neon hex with its label, like HexFace on the pad.
func _pad(label: String) -> void:
	HexStyle.draw_hex(get_canvas_item(), Rect2(Vector2(4, 4), size - Vector2(8, 8)), HexStyle.CYAN, Color(0.02, 0.06, 0.1, 0.75), 0.35, 2.5)
	var lines := label.split("\n")
	var font_size := 17 if lines.size() == 1 and label.length() <= 4 else 14
	var step := font_size + 1.0
	var top := size.y / 2.0 - step * (lines.size() - 1) / 2.0
	for i in lines.size():
		_text(lines[i], Vector2(size.x / 2.0, top + step * i), font_size, HexStyle.CYAN)


## Text centred on a point.
func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	draw_string(font, Vector2(center.x - w / 2.0, center.y + (ascent - descent) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
