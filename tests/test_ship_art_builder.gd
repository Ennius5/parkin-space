extends TestCase

const RED := Color(1, 0, 0)
const BLUE := Color(0, 0, 1)
const GREEN := Color(0, 1, 0)
const YELLOW := Color(1, 1, 0)
const MAGENTA := Color(1, 0, 1)
const LIGHT := ShipSpec.ShipClass.LIGHT


func _rect_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	return img


func _blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)  # fully transparent


func _mark(img: Image, x: int, y: int, color: Color) -> void:
	img.set_pixel(x, y, color)


## 10x16 hull: one engine, two retros, a side thruster each side, four rotation corners.
func _basic_markers() -> Image:
	var m := _blank(10, 16)
	_mark(m, 5, 15, RED)
	_mark(m, 2, 0, BLUE)
	_mark(m, 7, 0, BLUE)
	_mark(m, 0, 8, GREEN)
	_mark(m, 9, 8, GREEN)
	for p in [Vector2i(0, 2), Vector2i(9, 2), Vector2i(0, 13), Vector2i(9, 13)]:
		_mark(m, p.x, p.y, YELLOW)
	return m


func _find(result: Dictionary, local_pos: Vector2) -> ThrusterSpec:
	for t in result["thrusters"]:
		if t.position.distance_to(local_pos) < 0.01:
			return t
	return null


func _total(result: Dictionary, action: String) -> Dictionary:
	var force := 0.0
	var torque := 0.0
	for t in result["thrusters"]:
		if t.actions.has(action):
			force += t.force
			torque += t.torque_about(result["center_of_mass"])
	return {"force": force, "torque": torque}


func test_basic_layout_directions_and_actions() -> void:
	var r := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	assert_eq(r["errors"].size(), 0, "errors=%s" % r["errors"])
	assert_eq(r["thrusters"].size(), 9)
	var red := _find(r, Vector2(1, 15))
	assert_true(red != null, "red engine")
	if red:
		assert_eq(red.direction, Vector2(0, -1))
		assert_eq(red.actions, PackedStringArray(["thrust_forward"]))
	var blue := _find(r, Vector2(-5, -15))
	assert_true(blue != null and blue.direction == Vector2(0, 1), "blue retro")
	var left_side := _find(r, Vector2(-9, 1))
	assert_true(left_side != null and left_side.direction == Vector2(1, 0), "left side pushes right")
	if left_side:
		assert_eq(left_side.actions, PackedStringArray(["strafe_right"]))
	var right_side := _find(r, Vector2(9, 1))
	assert_true(right_side != null and right_side.actions == PackedStringArray(["strafe_left"]), "right side")
	var front_left := _find(r, Vector2(-9, -11))
	assert_true(front_left != null and front_left.actions == PackedStringArray(["rotate_right"]), "front-left rot")
	var front_right := _find(r, Vector2(9, -11))
	assert_true(front_right != null and front_right.actions == PackedStringArray(["rotate_left"]), "front-right rot")


func test_positions_use_art_scale() -> void:
	var r := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	assert_true(_find(r, Vector2(1, 15)) != null)
	assert_eq(r["hull_size"], Vector2(20, 32))
	assert_eq(r["mass"], 1.0)


func test_budgets_light() -> void:
	var r := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	assert_almost(_total(r, "thrust_forward")["force"], 260.0, 0.5)
	assert_almost(_total(r, "thrust_back")["force"], 180.0, 0.5)
	assert_almost(_total(r, "strafe_right")["force"], 180.0, 0.5)
	assert_almost(_total(r, "rotate_right")["torque"], 900.0, 0.5)
	assert_almost(_total(r, "rotate_left")["torque"], -900.0, 0.5)


func test_bigger_blob_gets_bigger_share() -> void:
	var m := _basic_markers()
	_mark(m, 5, 15, Color(0, 0, 0, 0))
	_mark(m, 2, 15, RED)
	for x in range(6, 9):
		_mark(m, x, 15, RED)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	var small := _find(r, Vector2(-5, 15))
	var big := _find(r, Vector2(5, 15))
	assert_true(small != null and big != null, "both engines found")
	if small and big:
		assert_almost(small.force, 65.0, 0.5)
		assert_almost(big.force, 195.0, 0.5)


func test_com_default_is_opaque_centroid() -> void:
	var base := _blank(14, 16)
	base.fill_rect(Rect2i(0, 0, 10, 16), Color.GRAY)
	base.fill_rect(Rect2i(10, 6, 4, 4), Color.GRAY)
	var m := _blank(14, 16)
	m.blit_rect(_basic_markers(), Rect2i(0, 0, 10, 16), Vector2i.ZERO)
	var r := ShipArtBuilder.build(base, m, LIGHT)
	var com: Vector2 = r["center_of_mass"]
	# Opaque centroid in art px: x = (160*5 + 16*12) / 176 = 5.636; canvas centre x = 7.
	assert_almost(com.x, (5.636 - 7.0) * 2.0, 0.05)
	assert_almost(com.y, 0.0, 0.05)


func test_magenta_overrides_com() -> void:
	var m := _basic_markers()
	_mark(m, 5, 10, MAGENTA)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	assert_eq(r["center_of_mass"], Vector2(1, 5))


func test_nozzle_follows_outline() -> void:
	var base := _blank(10, 16)
	base.fill_rect(Rect2i(0, 0, 4, 16), Color.GRAY)  # left column
	base.fill_rect(Rect2i(0, 12, 10, 4), Color.GRAY)  # bottom bar
	var m := _blank(10, 16)
	_mark(m, 3, 4, GREEN)  # right edge of the left column: nearest edge is to its right
	var r := ShipArtBuilder.build(base, m, LIGHT)
	var side := _find(r, Vector2((3.5 - 5.0) * 2.0, (4.5 - 8.0) * 2.0))
	assert_true(side != null, "side thruster found")
	if side:
		assert_eq(side.direction, Vector2(-1, 0))
		assert_eq(side.actions, PackedStringArray(["strafe_left"]))


func test_missing_retro_is_error() -> void:
	var m := _basic_markers()
	_mark(m, 2, 0, Color(0, 0, 0, 0))
	_mark(m, 7, 0, Color(0, 0, 0, 0))
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	assert_eq(r["errors"].size(), 1, "errors=%s" % r["errors"])
	if r["errors"].size() == 1:
		assert_true(r["errors"][0].contains("Back"), r["errors"][0])


func test_yellow_on_com_row_warns() -> void:
	var m := _basic_markers()
	_mark(m, 5, 8, MAGENTA)  # com at row 8, local y = 1
	_mark(m, 0, 8, YELLOW)  # replaces the green there; same row as the com
	_mark(m, 0, 9, GREEN)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	assert_eq(r["errors"].size(), 0, "errors=%s" % r["errors"])
	var joined := " ".join(r["warnings"])
	assert_true(joined.contains("centre of mass"), "warnings=%s" % r["warnings"])
	assert_true(_find(r, Vector2(-9, 1)) == null, "skipped")


func test_polygon_traced() -> void:
	var r := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	var poly: PackedVector2Array = r["hull_polygon"]
	assert_true(poly.size() >= 4, "poly=%s" % poly)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	assert_almost(lo.x, -10.0, 1.0)
	assert_almost(lo.y, -16.0, 1.0)
	assert_almost(hi.x, 10.0, 1.0)
	assert_almost(hi.y, 16.0, 1.0)


func test_stray_colours_warn() -> void:
	var m := _basic_markers()
	_mark(m, 4, 4, Color(0.4, 0.4, 0.4))
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	var joined := " ".join(r["warnings"])
	assert_true(joined.contains("1 pixel"), "warnings=%s" % r["warnings"])


func test_strong_strafe_twist_warns_with_com_row() -> void:
	var m := _basic_markers()
	_mark(m, 0, 8, Color(0, 0, 0, 0))
	_mark(m, 9, 8, Color(0, 0, 0, 0))
	_mark(m, 0, 1, GREEN)  # far ahead of the centre of mass (row 8)
	_mark(m, 9, 1, GREEN)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	var joined := " ".join(r["warnings"])
	assert_true(joined.contains("strafe") and joined.contains("between art rows 7 and 8"), "warnings=%s" % r["warnings"])
	var clean := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	assert_false(" ".join(clean["warnings"]).contains("strafe"), "small twist is fine: %s" % clean["warnings"])


func test_two_by_two_magenta_marks_centre_between_pixels() -> void:
	var m := _basic_markers()
	for p in [Vector2i(4, 7), Vector2i(5, 7), Vector2i(4, 8), Vector2i(5, 8)]:
		_mark(m, p.x, p.y, MAGENTA)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	assert_eq(r["center_of_mass"], Vector2(0, 0), "exact canvas centre")


func test_twist_warning_names_both_rows_when_com_between_rows() -> void:
	var m := _basic_markers()
	_mark(m, 0, 8, Color(0, 0, 0, 0))
	_mark(m, 9, 8, Color(0, 0, 0, 0))
	_mark(m, 0, 1, GREEN)
	_mark(m, 9, 1, GREEN)
	for p in [Vector2i(4, 7), Vector2i(5, 7), Vector2i(4, 8), Vector2i(5, 8)]:
		_mark(m, p.x, p.y, MAGENTA)
	var r := ShipArtBuilder.build(_rect_image(10, 16), m, LIGHT)
	assert_true(" ".join(r["warnings"]).contains("between art rows 7 and 8"), "warnings=%s" % r["warnings"])


func test_inertia_from_pixels() -> void:
	var r := ShipArtBuilder.build(_rect_image(10, 16), _basic_markers(), LIGHT)
	# Solid 20x32 game-px rectangle, mass 1, centred: (20^2 + 32^2) / 12.
	assert_almost(r["inertia"], (400.0 + 1024.0) / 12.0, 0.01)


func test_marker_outside_hull_pushes_toward_hull() -> void:
	var base := _blank(12, 16)
	base.fill_rect(Rect2i(1, 0, 10, 16), Color.GRAY)  # hull with one empty column each side
	var m := _blank(12, 16)
	_mark(m, 11, 8, GREEN)  # just outside the right edge
	var r := ShipArtBuilder.build(base, m, LIGHT)
	var side := _find(r, Vector2((11.5 - 6.0) * 2.0, (8.5 - 8.0) * 2.0))
	assert_true(side != null, "side thruster found")
	if side:
		assert_eq(side.direction, Vector2(-1, 0))
		assert_eq(side.actions, PackedStringArray(["strafe_left"]))
	assert_true(" ".join(r["warnings"]).contains("transparent"), "warnings=%s" % r["warnings"])


func test_corner_only_islands_warn_about_corners() -> void:
	var base := _blank(10, 16)
	base.fill_rect(Rect2i(0, 0, 5, 8), Color.GRAY)
	base.fill_rect(Rect2i(5, 8, 5, 8), Color.GRAY)  # touches the first block only at a corner
	var r := ShipArtBuilder.build(base, _blank(10, 16), LIGHT)
	assert_true(" ".join(r["warnings"]).contains("corner"), "warnings=%s" % r["warnings"])
