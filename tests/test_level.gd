extends TestCase

const LEVEL01 := preload("res://scenes/levels/Level01.tscn")
const TEST_SAVE := "user://test_level_save.cfg"

const LEVEL01_POOL := [
	"res://resources/ships/AsteroidJunker.tres",
	"res://resources/ships/ManipulatorDrone.tres",
	"res://resources/ships/Milano.tres",
	"res://resources/ships/Miner.tres",
	"res://resources/ships/Nostrom.tres",
	"res://resources/ships/ReconDrone.tres",
	"res://resources/ships/RecreationalDrone.tres",
	"res://resources/ships/medium_shuttle.tres",
]

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


func _queue_paths(queue: Array[ShipSpec]) -> Array:
	var paths := []
	for spec in queue:
		paths.append(spec.resource_path)
	paths.sort()
	return paths


func _spec(weight: float) -> ShipSpec:
	var spec := ShipSpec.new()
	spec.spawn_weight = weight
	return spec


func test_spawn_weight_defaults_to_one() -> void:
	assert_eq(ShipSpec.new().spawn_weight, 1.0)


func test_draw_customers_gives_count_ships_from_the_pool() -> void:
	var pool: Array[ShipSpec] = [_spec(1.0), _spec(1.0)]
	var drawn := Level.draw_customers(pool, 4, RandomNumberGenerator.new())
	assert_eq(drawn.size(), 4)
	for spec in drawn:
		assert_true(spec in pool)


func test_draw_customers_follows_spawn_weight() -> void:
	var common := _spec(1.0)
	var rare := _spec(0.25)
	var pool: Array[ShipSpec] = [common, rare]
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var drawn := Level.draw_customers(pool, 1000, rng)
	var rare_count := drawn.count(rare)
	assert_true(rare_count > 150 and rare_count < 250, "rare drawn %d of 1000, expected about 200" % rare_count)


func _class_spec(ship_class: ShipSpec.ShipClass) -> ShipSpec:
	var spec := ShipSpec.new()
	spec.ship_class = ship_class
	return spec


func _count_class(specs: Array[ShipSpec], ship_class: ShipSpec.ShipClass) -> int:
	var n := 0
	for spec in specs:
		if spec.ship_class == ship_class:
			n += 1
	return n


func test_draw_never_exceeds_lot() -> void:
	var pool: Array[ShipSpec] = [_class_spec(ShipSpec.ShipClass.HEAVY), _class_spec(ShipSpec.ShipClass.LIGHT)]
	var spaces: Array[int] = [ShipSpec.ShipClass.HEAVY, ShipSpec.ShipClass.LIGHT, ShipSpec.ShipClass.LIGHT]
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var worst := 0
	for i in 200:
		var drawn := Level.draw_customers(pool, 3, rng, spaces)
		assert_eq(drawn.size(), 3)
		worst = maxi(worst, _count_class(drawn, ShipSpec.ShipClass.HEAVY))
	assert_eq(worst, 1)


func test_draw_skips_ships_with_no_space() -> void:
	var pool: Array[ShipSpec] = [_class_spec(ShipSpec.ShipClass.HEAVY), _class_spec(ShipSpec.ShipClass.MEDIUM)]
	var spaces: Array[int] = [ShipSpec.ShipClass.MEDIUM, ShipSpec.ShipClass.MEDIUM]
	var drawn := Level.draw_customers(pool, 2, RandomNumberGenerator.new(), spaces)
	assert_eq(_count_class(drawn, ShipSpec.ShipClass.MEDIUM), 2)
	assert_eq(drawn.size(), 2)


func test_draw_stops_when_nothing_fits() -> void:
	var pool: Array[ShipSpec] = [_class_spec(ShipSpec.ShipClass.HEAVY)]
	var spaces: Array[int] = [ShipSpec.ShipClass.MEDIUM]
	assert_eq(Level.draw_customers(pool, 3, RandomNumberGenerator.new(), spaces).size(), 0)


func test_level01_draws_its_customers_from_the_pool() -> void:
	_setup_state()
	var level := await _make_level()
	assert_eq(level.customer_queue.size(), 4)
	assert_eq(level.ledger.customers, 4)
	for spec in level.customer_queue:
		assert_true(spec.resource_path in LEVEL01_POOL, spec.resource_path)
	level.free()
	_restore_state()


func test_recon_drone_is_rare() -> void:
	var recon: ShipSpec = load("res://resources/ships/ReconDrone.tres")
	assert_eq(recon.spawn_weight, 0.25)


func test_level01_exports() -> void:
	var level: Level = LEVEL01.instantiate()
	assert_eq(level.level_number, 1)
	assert_eq(level.goal_text, "Park 4 ships before the shift ends")
	assert_eq(_queue_paths(level.customer_queue), LEVEL01_POOL)
	assert_eq(level.random_customers, 4)
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


# --- Tiers, retrieval and the exit (Level 2 systems, exercised on the Level 1 layout) ---

const EXIT_SCENE := preload("res://scenes/actors/ExitPad.tscn")
const EXIT_POS := Vector2(2260, 700)
const OPEN_FLOOR := Vector2(400, 1000)  # not in any Level 1 space, nor at the entrance or exit


func _make_tiered_level() -> Level:
	var level: Level = LEVEL01.instantiate()
	level.change_scene_on_end = false
	level.use_tiers = true
	var exit: ExitPad = EXIT_SCENE.instantiate()
	exit.name = "Exit"
	exit.position = EXIT_POS
	level.add_child(exit)
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _first_ship(level: Level) -> Ship:
	return level.get_node("Ships").get_child(0)


func _space_a1(level: Level) -> ParkingSpace:
	return level.get_node("Spaces/A1")


## Parks the first ship in A1 as a silver customer who wants the ship back.
func _park_silver_leaver(level: Level) -> Ship:
	var ship := _first_ship(level)
	var c := level.customer_for(ship)
	c.tier = Customer.Tier.SILVER
	c.wants_retrieval = true
	var space := _space_a1(level)
	ship.global_position = space.global_position
	ship.global_rotation = space.global_rotation
	level._on_ship_parked(ship, space)
	return ship


func _move(ship: Ship, pos: Vector2) -> void:
	ship.freeze = true
	ship.global_position = pos


func test_level1_has_no_tiers_or_retrievals() -> void:
	_setup_state()
	var level := await _make_level()
	var c := level.customer_for(_first_ship(level))
	assert_eq(c.tier, Customer.Tier.NONE)
	assert_false(c.wants_retrieval)
	level.free()
	_restore_state()


func test_stayer_pays_fee_and_tip_on_parking() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _first_ship(level)
	level.customer_for(ship).tier = Customer.Tier.SILVER
	level._on_ship_parked(ship, _space_a1(level))
	assert_eq(level.ledger.earned, 35)
	assert_eq(level.ledger.served, 1)
	level.free()
	_restore_state()


func test_leaver_pays_fee_then_requests() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	var c := level.customer_for(ship)
	assert_eq(level.ledger.earned, 20)
	assert_eq(level.ledger.served, 0)
	assert_true(c.request_in >= 20.0 and c.request_in <= 40.0, "request_in %f" % c.request_in)
	c.request_in = 0.01
	await _physics_frames(3)
	assert_true(c.requested)
	assert_false(ship.is_parked)
	await _physics_frames(90)  # longer than the 1 s parking hold, still sitting in its space
	assert_false(ship.is_parked)
	assert_eq(level.ledger.served, 0)
	level.free()
	_restore_state()


func test_space_frees_after_ship_leaves() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	level.customer_for(ship).request_in = 0.01
	await _physics_frames(3)
	assert_eq(_space_a1(level).occupant, ship)
	_move(ship, OPEN_FLOOR)
	await _physics_frames(2)
	assert_eq(_space_a1(level).occupant, null)
	level.free()
	_restore_state()


func test_return_at_exit_serves_and_despawns() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	level.customer_for(ship).request_in = 0.01
	await _physics_frames(3)
	level.select_ship(ship)
	assert_eq(level.driven_ship, ship)
	_move(ship, EXIT_POS)
	await _physics_frames(2)
	assert_eq(level.ledger.served, 1)
	assert_eq(level.ledger.earned, 35)
	assert_eq(level.ledger.tips, 15)
	assert_eq(level.driven_ship, null)
	assert_false(is_instance_valid(ship) and ship.is_inside_tree())
	assert_eq(_space_a1(level).occupant, null)
	level.free()
	_restore_state()


func test_waiting_counts_until_parked_and_after_request() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _first_ship(level)
	var c := level.customer_for(ship)
	await _physics_frames(10)
	assert_true(c.wait > 0.1, "wait %f" % c.wait)
	ship = _park_silver_leaver(level)
	var parked_wait := c.wait
	await _physics_frames(10)
	assert_eq(c.wait, parked_wait)
	c.request_in = 0.01
	await _physics_frames(10)
	assert_true(c.wait > parked_wait + 0.1)
	level.free()
	_restore_state()


func test_dents_count_on_the_customer() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _first_ship(level)
	level._on_ship_dented(ship, 5)
	assert_eq(level.customer_for(ship).dents, 1)
	level.free()
	_restore_state()


func test_timeout_with_pending_request_loses_cleanly() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	_park_silver_leaver(level)
	level.ledger.time_left = 0.05
	await _physics_frames(10)
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.TIMEOUT)
	assert_eq(GameState.last_result.get("reason"), "timeout")
	assert_true(GameState.last_result.has("tips"))
	level.free()
	_restore_state()


func test_level02_layout() -> void:
	assert_true(GameState.has_level_scene(2))
	if not GameState.has_level_scene(2):
		return
	var level: Level = load("res://scenes/levels/Level02.tscn").instantiate()
	var counts := {}
	var gold := 0
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		counts[space.space_class] = counts.get(space.space_class, 0) + 1
		if space.gold:
			gold += 1
			assert_true(space.position.x > 1400, "gold space at %s" % space.position)
	assert_eq(counts, {ShipSpec.ShipClass.HEAVY: 3, ShipSpec.ShipClass.MEDIUM: 5, ShipSpec.ShipClass.LIGHT: 2})
	assert_eq(gold, 2)
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	assert_eq(level.level_number, 2)
	assert_eq(level.goal_text, "Serve 6 customers")
	assert_eq(level.random_customers, 6)
	assert_eq(level.shift_seconds, 180.0)
	assert_eq(level.base_pay, 100)
	assert_eq(level.silver_target, 240)
	assert_eq(level.gold_target, 280)
	assert_eq(level.arrival_interval, 10.0)
	assert_true(level.use_tiers)
	assert_eq(level.retrieval_count, 2)
	var pool := _queue_paths(level.customer_queue)
	for path in LEVEL01_POOL:
		assert_true(path in pool, path)
	assert_true("res://resources/ships/AgriShip.tres" in pool)
	assert_true("res://resources/ships/heavy_freighter.tres" in pool)
	level.free()


func test_level02_runs_a_shift() -> void:
	_setup_state()
	var level: Level = load("res://scenes/levels/Level02.tscn").instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	assert_eq(level.customer_queue.size(), 6)
	assert_eq(level.ledger.customers, 6)
	var leavers := 0
	for i in 6:
		if i in level._retrieval_indexes:
			leavers += 1
	assert_eq(leavers, 2)
	level.free()
	_restore_state()
