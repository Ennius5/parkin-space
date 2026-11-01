extends TestCase

const LEVEL01 := preload("res://scenes/levels/Level01.tscn")
const TEST_SAVE := "user://test_level_save.cfg"

var _real_save_path: String


func _setup_state() -> void:
	_real_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE
	GameState.reset_progress()
	GameState.last_result = {}


func _restore_state() -> void:
	GameState.save_path = _real_save_path
	GameState.load_progress()


func _make_level() -> Level:
	var level: Level = LEVEL01.instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func test_level01_exports() -> void:
	var level: Level = LEVEL01.instantiate()
	assert_eq(level.level_number, 1)
	assert_eq(level.goal_text, "Park 4 ships before the shift ends")
	assert_eq(level.customer_queue.size(), 4)
	var classes := []
	for spec in level.customer_queue:
		classes.append(spec.ship_class)
	assert_eq(classes, [ShipSpec.ShipClass.LIGHT, ShipSpec.ShipClass.MEDIUM, ShipSpec.ShipClass.LIGHT, ShipSpec.ShipClass.MEDIUM])
	assert_eq(level.shift_seconds, 180.0)
	assert_eq(level.base_pay, 100)
	assert_eq(level.silver_target, 150)
	assert_eq(level.gold_target, 170)
	level.free()


func test_first_customer_spawns_at_start() -> void:
	_setup_state()
	var level := await _make_level()
	var ships := level.get_node("Ships").get_children()
	assert_eq(ships.size(), 1)
	if ships.size() == 1:
		assert_true((ships[0] as Ship).global_position.distance_to(level.get_node("Entrance").global_position) < 1.0)
	level.queue_free()
	_restore_state()


func test_select_and_release() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.select_ship(ship)
	assert_true(ship.is_driven)
	assert_eq(level.driven_ship, ship)
	level.release_ship()
	assert_false(ship.is_driven)
	assert_eq(level.driven_ship, null)
	level.queue_free()
	_restore_state()


func test_parking_all_customers_wins_and_unlocks() -> void:
	_setup_state()
	var level := await _make_level()
	var spaces := level.get_node("Spaces").get_children()
	var ships: Array[Ship] = [level.get_node("Ships").get_child(0)]
	for i in 3:
		ships.append(level.spawn_next_customer())
	for i in ships.size():
		ships[i].set_parked()
		level._on_ship_parked(ships[i], spaces[i])
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.WON)
	assert_eq(GameState.last_result.get("won"), true)
	assert_eq(GameState.last_result.get("reason"), "won")
	assert_true(GameState.is_unlocked(2))
	level.queue_free()
	_restore_state()


func test_no_more_customers_after_queue_ends() -> void:
	_setup_state()
	var level := await _make_level()
	for i in 3:
		level.spawn_next_customer()
	assert_eq(level.spawn_next_customer(), null)
	assert_eq(level.get_node("Ships").get_child_count(), 4)
	level.queue_free()
	_restore_state()


func test_firing_records_loss_without_unlock() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	level._on_ship_dented(ship, 100)
	assert_eq(GameState.last_result.get("reason"), "fired")
	assert_eq(GameState.last_result.get("stars"), 0)
	assert_false(GameState.is_unlocked(2))
	level.queue_free()
	_restore_state()


func test_ship_resting_in_space_gets_parked() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	var space: ParkingSpace = level.get_node("Spaces/A1")
	ship.global_position = space.global_position
	ship.rotation = space.global_rotation
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0
	for i in 40:
		await tree.physics_frame
	assert_eq(level.ledger.served, 0, "not credited before the 1 s hold")
	for i in 40:
		await tree.physics_frame
	assert_eq(level.ledger.served, 1)
	assert_eq(space.occupant, ship)
	assert_true(ship.is_parked)
	level.queue_free()
	_restore_state()


func test_tap_right_after_done_does_not_select() -> void:
	_setup_state()
	var level := await _make_level()
	var first: Ship = level.get_node("Ships").get_child(0)
	var second := level.spawn_next_customer()
	second.global_position += Vector2(0, 300)  # don't overlap the first ship at the entrance
	level.select_ship(first)
	level.release_ship()
	level.select_ship(second)  # same touch that pressed Done
	assert_eq(level.driven_ship, null)
	# Wait on real time: the code measures wall-clock ms, and scene timers can run ahead of it headless.
	var released_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - released_at < Level.RESELECT_DELAY_MS + 50:
		await tree.process_frame
	level.select_ship(second)
	assert_eq(level.driven_ship, second, "later taps select normally")
	level.queue_free()
	_restore_state()


func test_ship_selection_ignored_while_driving() -> void:
	_setup_state()
	var level := await _make_level()
	var first: Ship = level.get_node("Ships").get_child(0)
	var second := level.spawn_next_customer()
	level.select_ship(first)
	level.select_ship(second)
	assert_eq(level.driven_ship, first)
	level.queue_free()
	_restore_state()


func test_customers_get_a_paint_color() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	assert_true(Level.PAINT_COLORS.has(ship.paint_color), "paint=%s" % ship.paint_color)
	level.queue_free()
	_restore_state()


func _screen_pos(node: Node2D) -> Vector2:
	return node.get_global_transform_with_canvas().origin


## Level with two waiting ships 60 px apart, away from the entrance.
func _level_with_two_ships() -> Array:
	var level := await _make_level()
	var first: Ship = level.get_node("Ships").get_child(0)
	var second := level.spawn_next_customer()
	first.global_position = Vector2(900, 900)
	second.global_position = Vector2(960, 900)
	await tree.process_frame
	return [level, first, second]


func test_ships_near_lists_nearest_first() -> void:
	_setup_state()
	var setup := await _level_with_two_ships()
	var level: Level = setup[0]
	var near: Array[Ship] = level.ships_near_world(Vector2(955, 900), level.pick_radius_world())
	assert_eq(near.size(), 2)
	if near.size() == 2:
		assert_eq(near[0], setup[2], "second is nearest")
		assert_eq(near[1], setup[1])
	level.queue_free()
	_restore_state()


func test_parked_ships_never_listed() -> void:
	_setup_state()
	var setup := await _level_with_two_ships()
	var level: Level = setup[0]
	(setup[1] as Ship).set_parked()
	var near: Array[Ship] = level.ships_near_world(Vector2(930, 900), level.pick_radius_world())
	assert_eq(near, [setup[2]] as Array[Ship])
	level.queue_free()
	_restore_state()


func test_pick_radius_is_fixed_on_screen() -> void:
	_setup_state()
	var level := await _make_level()
	var camera: Camera2D = level.get_node("LotCamera")
	camera.zoom = Vector2(0.5, 0.5)
	assert_almost(level.pick_radius_world(), Level.PICK_RADIUS_SCREEN / 0.5, 0.01)
	camera.zoom = Vector2(0.25, 0.25)
	assert_almost(level.pick_radius_world(), Level.PICK_RADIUS_SCREEN / 0.25, 0.01)
	level.queue_free()
	_restore_state()


func test_tap_near_one_ship_selects_it() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.handle_lot_tap(_screen_pos(ship) + Vector2(20, 0))
	assert_eq(level.driven_ship, ship)
	level.queue_free()
	_restore_state()


func test_tap_near_nothing_does_nothing() -> void:
	_setup_state()
	var level := await _make_level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.handle_lot_tap(_screen_pos(ship) + Vector2(400, 0))
	assert_eq(level.driven_ship, null)
	assert_false((level.get_node("ShipPicker") as ShipPicker).is_open())
	level.queue_free()
	_restore_state()


func test_tap_near_two_ships_opens_picker_and_pick_drives() -> void:
	_setup_state()
	var setup := await _level_with_two_ships()
	var level: Level = setup[0]
	var picker := level.get_node("ShipPicker") as ShipPicker
	level.handle_lot_tap(_screen_pos(setup[1]))
	assert_eq(level.driven_ship, null, "a choice opens the list instead")
	assert_true(picker.is_open())
	assert_eq(picker.ships.size(), 2)
	picker.picked.emit(setup[2])
	assert_eq(level.driven_ship, setup[2])
	assert_false(picker.is_open(), "list closes after picking")
	level.queue_free()
	_restore_state()


func test_tap_ignored_while_driving() -> void:
	_setup_state()
	var setup := await _level_with_two_ships()
	var level: Level = setup[0]
	level.select_ship(setup[1])
	level.handle_lot_tap(_screen_pos(setup[2]))
	assert_eq(level.driven_ship, setup[1])
	assert_false((level.get_node("ShipPicker") as ShipPicker).is_open())
	level.queue_free()
	_restore_state()
