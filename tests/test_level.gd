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
