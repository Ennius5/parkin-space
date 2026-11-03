extends TestCase
## Fixes from the first playtest: the red lot edge, the return countdown and the "tap, don't hold" tip.

const LEVEL01 := preload("res://scenes/levels/Level01.tscn")
const TEST_SAVE := "user://test_playtest_fixes_save.cfg"

var _real_save_path: String


func _setup_state() -> void:
	_real_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE
	GameState.reset_progress()
	GameState.last_result = {}


func _restore_state() -> void:
	GameState.save_path = _real_save_path
	GameState.load_progress()


func _make_level(path := "res://scenes/levels/Level01.tscn") -> Level:
	var level: Level = load(path).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


# --- Lot edge ---

func test_lot_edge_sits_on_the_inner_faces_of_the_walls() -> void:
	var level: Level = LEVEL01.instantiate()
	assert_eq(LotEdge.inner_rect(level.get_node("Walls")), Rect2(0, 0, 2400, 1400))
	level.free()


func test_lot_edge_glow_rises_as_the_ship_nears_a_wall() -> void:
	assert_almost(LotEdge.glow_for(LotEdge.NEAR), 0.0, 0.001)
	assert_almost(LotEdge.glow_for(LotEdge.NEAR * 2.0), 0.0, 0.001)
	assert_almost(LotEdge.glow_for(LotEdge.NEAR / 2.0), 0.5, 0.001)
	assert_almost(LotEdge.glow_for(0.0), 1.0, 0.001)
	assert_almost(LotEdge.glow_for(-10.0), 1.0, 0.001)


func test_clearance_is_the_closest_hull_point_to_any_wall() -> void:
	var rect := Rect2(0, 0, 2400, 1400)
	var points := PackedVector2Array([Vector2(500, 700), Vector2(30, 700), Vector2(600, 1390)])
	assert_almost(LotEdge.clearance(rect, points), 10.0, 0.001)


func test_every_lot_has_a_dim_edge_that_lights_up_near_the_driven_ship() -> void:
	_setup_state()
	var level := await _make_level()
	var edge := level.get_node_or_null("LotEdge") as LotEdge
	assert_true(edge != null, "lot edge added")
	assert_eq(edge.rect, Rect2(0, 0, 2400, 1400))
	await _frames(3)
	assert_almost(edge.glow, 0.0, 0.01, "dim while nobody drives")
	var ship: Ship = level.get_node("Ships").get_child(0)
	ship.freeze = true
	ship.global_position = Vector2(1200, 700)
	level.select_ship(ship)
	await _frames(3)
	assert_almost(edge.glow, 0.0, 0.01, "dim in the middle of the lot")
	var lowest := -INF
	for p in ship.hull_points():
		lowest = maxf(lowest, p.y)
	ship.global_position += Vector2(0, 1395.0 - lowest)  # nose 5 px off the bottom wall
	await _frames(40)
	assert_true(edge.glow > 0.9, "bright against the bottom wall: %s" % edge.glow)
	level.release_ship()
	await _frames(40)
	assert_true(edge.glow < 0.1, "fades once released: %s" % edge.glow)
	level.free()
	_restore_state()


func test_duel_lot_has_the_edge_too() -> void:
	var level: Level = load("res://scenes/levels/Duel.tscn").instantiate()
	var rect := LotEdge.inner_rect(level.get_node("Walls"))
	assert_true(rect.size.x > 1000 and rect.size.y > 600, "duel inner rect %s" % rect)
	level.free()


# --- Return countdown ---

func test_return_countdown_text() -> void:
	var c := Customer.new()
	assert_eq(c.return_countdown(), "", "no return scheduled")
	c.request_in = 12.3
	assert_eq(c.return_countdown(), "↩ 0:13")
	c.request_in = 75.0
	assert_eq(c.return_countdown(), "↩ 1:15")
	c.requested = true
	assert_eq(c.return_countdown(), "", "already asked for: the glow takes over")


func test_waiting_text_only_when_idle_with_a_return_coming() -> void:
	assert_eq(Level.waiting_text(true, 12.3), "Waiting for customers to return – next in 0:13")
	assert_eq(Level.waiting_text(false, 12.3), "", "something to do")
	assert_eq(Level.waiting_text(true, -1.0), "", "no return coming")


func test_hud_shows_waiting_line_when_every_ship_is_parked_and_one_will_leave() -> void:
	_setup_state()
	var level := await _make_level("res://scenes/levels/Level02.tscn")
	var hud: HUD = level.get_node("HUD")
	var ship: Ship = level.get_node("Ships").get_child(0)
	var c := level.customer_for(ship)
	c.wants_retrieval = true
	var space: ParkingSpace = level.get_node("Spaces").get_child(0)
	for s: ParkingSpace in level.get_node("Spaces").get_children():
		if ParkingRules.fits_class(ship.spec.ship_class, s.space_class):
			space = s
			break
	ship.freeze = true
	ship.global_position = space.global_position
	ship.global_rotation = space.global_rotation
	level._on_ship_parked(ship, space)
	level._arrival_timer = -999.0  # hold the next arrival back
	await _physics_frames(3)
	assert_true(c.request_in > 0.0, "a return is scheduled")
	assert_true(ship.show_return_timer, "the parked ship shows its countdown")
	assert_true(hud.status_text().begins_with("Waiting for customers to return – next in "), hud.status_text())
	assert_true(level.spawn_next_customer() != null, "next customer arrives")
	await _physics_frames(3)
	assert_eq(hud.status_text(), "", "an arrival to park: no waiting line")
	level.free()
	_restore_state()


func test_duel_ships_do_not_show_the_return_timer() -> void:
	var level: Level = load("res://scenes/levels/Duel.tscn").instantiate()
	assert_false(level.show_return_countdowns)
	level.free()


# --- Guide tip ---

func test_controls_page_ends_with_the_yellow_tap_tip() -> void:
	var rows: Array = Guide.page_data()[0]["rows"]
	var last: Array = rows[rows.size() - 1]
	assert_true((last[1] as String).begins_with("It is better to tap the controls rather than holding them."), last[1])
	assert_true((last[1] as String).contains("We're not racing ships here, rookie, we're parking them!"))
	assert_true((last[1] as String).ends_with("Let the momentum do the work!"))
	assert_eq(last[2], Guide.TIP_COLOR)
	assert_true(Guide.TIP_COLOR.r > 0.9 and Guide.TIP_COLOR.g > 0.8 and Guide.TIP_COLOR.b < 0.4, "yellow")
