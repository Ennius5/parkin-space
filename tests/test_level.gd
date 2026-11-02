extends TestCase

const LEVEL01 := preload("res://scenes/levels/Level01.tscn")
const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const TEST_SAVE := "user://test_level_save.cfg"

const LEVEL01_POOL := [
	"res://resources/ships/AsteroidJunker.tres",
	"res://resources/ships/ManipulatorDrone.tres",
	"res://resources/ships/Milano.tres",
	"res://resources/ships/Miner.tres",
	"res://resources/ships/Nostrom.tres",
	"res://resources/ships/ReconDrone.tres",
	"res://resources/ships/RecreationalDrone.tres",
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
	assert_true("res://resources/ships/Hammerhead.tres" in pool)
	assert_true("res://resources/ships/Researcher.tres" in pool)
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


# --- Final review fixes ---

func test_final_stayer_tip_counts_on_the_winning_serve() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _first_ship(level)
	level.customer_for(ship).tier = Customer.Tier.SILVER
	level.ledger.served = level.ledger.customers - 1
	level._on_ship_parked(ship, _space_a1(level))
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.WON)
	assert_eq(level.ledger.tips, 15)
	assert_eq(GameState.last_result.get("tips"), 15)
	level.free()
	_restore_state()


func test_final_leaver_tip_counts_on_the_winning_return() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	level.ledger.served = level.ledger.customers - 1
	level.customer_for(ship).request_in = 0.01
	await _physics_frames(3)
	_move(ship, EXIT_POS)
	await _physics_frames(2)
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.WON)
	assert_eq(level.ledger.tips, 15)
	level.free()
	_restore_state()


func test_gold_only_for_ships_that_fit_a_gold_space() -> void:
	var level: Level = load("res://scenes/levels/Level02.tscn").instantiate()
	assert_true(level.gold_allowed(ShipSpec.ShipClass.LIGHT))
	assert_true(level.gold_allowed(ShipSpec.ShipClass.MEDIUM))
	assert_false(level.gold_allowed(ShipSpec.ShipClass.HEAVY))
	level.free()
	var level1: Level = LEVEL01.instantiate()
	assert_false(level1.gold_allowed(ShipSpec.ShipClass.LIGHT))
	level1.free()


func test_next_arrival_waits_for_a_clear_bay() -> void:
	_setup_state()
	var level := await _make_level()
	var ships := level.get_node("Ships")
	var first: Ship = ships.get_child(0)
	level._arrival_timer = 999.0  # arrival time has long come; only the bay holds the next ship back
	await _physics_frames(90)
	assert_eq(ships.get_child_count(), 1, "the first ship still sits in the bay")
	_move(first, OPEN_FLOOR)
	await _physics_frames(30)
	assert_eq(ships.get_child_count(), 1, "the bay has been clear for only half a second")
	await _physics_frames(40)
	assert_eq(ships.get_child_count(), 2)
	level.free()
	_restore_state()


func test_level_has_an_arrival_bay_at_the_entrance() -> void:
	_setup_state()
	var level := await _make_level()
	var bay: ArrivalBay = level.get_node_or_null("ArrivalBay")
	assert_true(bay != null)
	if bay:
		var entrance: Marker2D = level.get_node("Entrance")
		assert_true(bay.global_position.distance_to(entrance.global_position) < 0.5)
		assert_true(absf(bay.global_rotation - entrance.global_rotation) < 0.001)
	level.free()
	_restore_state()


const PLACEHOLDERS := ["light_scout", "medium_shuttle", "heavy_freighter", "sample_scout"]


func test_no_placeholder_ships_in_the_game() -> void:
	for name in PLACEHOLDERS:
		assert_false(ResourceLoader.exists("res://resources/ships/%s.tres" % name), name)
	for path in ["res://scenes/levels/Level01.tscn", "res://scenes/levels/Level02.tscn"]:
		var level: Level = load(path).instantiate()
		for spec in level.customer_queue:
			assert_true(spec.resource_path.begins_with("res://resources/ships/"), spec.resource_path)
		level.free()


## A tiered Level 1 with one radiation zone on open floor and the first ship sitting in it.
func _irradiated_level() -> Level:
	var level := await _make_tiered_level()
	var radiation := Node2D.new()
	radiation.name = "Radiation"
	var zone := RadiationZone.new()
	zone.position = OPEN_FLOOR
	radiation.add_child(zone)
	level.add_child(radiation)
	level._radiation = radiation
	_move(_first_ship(level), OPEN_FLOOR)
	return level


func test_radiation_dents_after_two_seconds_inside() -> void:
	_setup_state()
	var level := await _irradiated_level()
	var ship := _first_ship(level)
	var pay := level.ledger.pay
	level._update_radiation(1.9)
	assert_eq(level.ledger.pay, pay)
	assert_eq(level.customer_for(ship).dents, 0)
	level._update_radiation(0.2)
	assert_eq(level.ledger.pay, pay - Level.RADIATION_DENT_COST)
	assert_eq(level.customer_for(ship).dents, 1)
	level.free()
	_restore_state()


func test_leaving_radiation_resets_the_timer() -> void:
	_setup_state()
	var level := await _irradiated_level()
	var ship := _first_ship(level)
	level._update_radiation(1.5)
	_move(ship, OPEN_FLOOR + Vector2(600, 0))
	level._update_radiation(0.1)
	_move(ship, OPEN_FLOOR)
	level._update_radiation(1.5)
	assert_eq(level.customer_for(ship).dents, 0, "the timer restarted on leaving")
	level._update_radiation(0.6)
	assert_eq(level.customer_for(ship).dents, 1)
	level.free()
	_restore_state()


func test_radiation_dents_keep_coming_every_two_seconds() -> void:
	_setup_state()
	var level := await _irradiated_level()
	var ship := _first_ship(level)
	var pay := level.ledger.pay
	for i in 61:
		level._update_radiation(0.1)
	assert_eq(level.customer_for(ship).dents, 3)
	assert_eq(level.ledger.pay, pay - 3 * Level.RADIATION_DENT_COST)
	level.free()
	_restore_state()


func test_returned_ship_leaves_no_radiation_entry() -> void:
	_setup_state()
	var level := await _irradiated_level()
	level._update_radiation(1.0)
	level._return(_first_ship(level))  # handed over at the exit: the ship leaves the lot
	await tree.process_frame
	level._update_radiation(1.5)
	assert_true(level._radiation_time.is_empty())
	level.free()
	_restore_state()


func test_level01_has_no_radiation() -> void:
	_setup_state()
	var level := await _make_level()
	assert_true(level._radiation == null)
	await _physics_frames(60)
	assert_true(level._radiation_time.is_empty())
	level.free()
	_restore_state()


func test_asteroid_in_the_bay_holds_the_next_arrival() -> void:
	_setup_state()
	var level := await _make_level()
	var ships := level.get_node("Ships")
	var asteroids := Node2D.new()
	asteroids.name = "Asteroids"
	level.add_child(asteroids)
	level._asteroids = asteroids
	var img := Image.create(100, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var rock := Asteroid.new()
	rock.texture = ImageTexture.create_from_image(img)
	rock.drift_speed = 0.0
	rock.freeze = true
	asteroids.add_child(rock)
	rock.global_position = level.get_node("ArrivalBay").global_position
	_move(_first_ship(level), OPEN_FLOOR)
	level._arrival_timer = 999.0
	await _physics_frames(90)
	assert_eq(ships.get_child_count(), 1, "a rock sits in the bay")
	rock.global_position = OPEN_FLOOR + Vector2(600, 0)
	await _physics_frames(70)
	assert_eq(ships.get_child_count(), 2)
	level.free()
	_restore_state()


# --- Level 3 ---

const LEVEL03_PATH := "res://scenes/levels/Level03.tscn"


func test_level03_layout() -> void:
	assert_true(GameState.has_level_scene(3))
	if not GameState.has_level_scene(3):
		return
	var level: Level = load(LEVEL03_PATH).instantiate()
	var counts := {}
	var gold: Array[String] = []
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		counts[space.space_class] = counts.get(space.space_class, 0) + 1
		if space.gold:
			gold.append(space.label)
	gold.sort()
	assert_eq(counts, {ShipSpec.ShipClass.HEAVY: 2, ShipSpec.ShipClass.MEDIUM: 5, ShipSpec.ShipClass.LIGHT: 2})
	assert_eq(gold, ["C1", "C2"] as Array[String])
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	assert_eq(level.get_node("Radiation").get_child_count(), 3)
	for zone in level.get_node("Radiation").get_children():
		assert_true(zone is RadiationZone)
	assert_true(level.get_node("Wrecks").get_child_count() >= 3)
	assert_true(level.get_node("Asteroids").get_child_count() >= 7)
	for rock: Asteroid in level.get_node("Asteroids").get_children():
		assert_true(rock.art_scale >= 1.0, "%s is a big rock" % rock.name)
	assert_eq(level.level_number, 3)
	assert_eq(level.goal_text, "Serve 7 customers")
	assert_eq(level.random_customers, 7)
	assert_eq(level.base_pay, 100)
	assert_eq(level.silver_target, 260)
	assert_eq(level.gold_target, 300)
	assert_eq(level.arrival_interval, 10.0)
	assert_true(level.use_tiers)
	assert_eq(level.retrieval_count, 2)
	var pool := _queue_paths(level.customer_queue)
	for file in DirAccess.get_files_at("res://resources/ships/"):
		if file.ends_with(".tres"):
			assert_true("res://resources/ships/" + file in pool, file)
	level.free()


## True when a circle reaches into a rectangle of `size` centred on `xform`.
func _circle_hits_rect(centre: Vector2, radius: float, xform: Transform2D, size: Vector2) -> bool:
	var local := xform.affine_inverse() * centre
	return local.distance_to(local.clamp(-size / 2, size / 2)) <= radius


func test_level03_zones_and_wrecks_stay_off_spaces() -> void:
	if not GameState.has_level_scene(3):
		return
	var level: Level = load(LEVEL03_PATH).instantiate()
	var keep_clear := []  # [name, transform, size]
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		keep_clear.append([space.label, space.transform, space.size()])
	keep_clear.append(["bay", (level.get_node("Entrance") as Node2D).transform, ArrivalBay.SIZE])
	keep_clear.append(["exit", (level.get_node("Exit") as Node2D).transform, ExitPad.SIZE])
	var circles := []  # [name, centre, radius]
	for zone: RadiationZone in level.get_node("Radiation").get_children():
		circles.append([zone.name, zone.position, zone.radius])
	for wreck: Wreck in level.get_node("Wrecks").get_children():
		var reach := 0.0
		for p in SpriteOutline.outline(wreck.texture, wreck.art_scale):
			reach = maxf(reach, p.length())
		circles.append([wreck.name, wreck.position, reach])
	for c in circles:
		for k in keep_clear:
			assert_false(_circle_hits_rect(c[1], c[2], k[1], k[2]), "%s overlaps %s" % [c[0], k[0]])
	level.free()


func test_level03_runs_a_shift() -> void:
	_setup_state()
	var level: Level = load(LEVEL03_PATH).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	assert_eq(level.customer_queue.size(), 7)
	assert_eq(level.ledger.customers, 7)
	await _physics_frames(120)
	assert_true(level.get_node("Ships").get_child_count() >= 1)
	level.free()
	_restore_state()



# --- Difficulty ---

func test_shift_length_comes_from_the_difficulty() -> void:
	_setup_state()
	var real: int = GameState.difficulty
	for d: int in [GameState.Difficulty.EASY, GameState.Difficulty.NORMAL, GameState.Difficulty.HARD]:
		GameState.difficulty = d
		var level := await _make_level()
		assert_almost(level.ledger.time_left, GameState.SHIFT_SECONDS[d], 0.5, "difficulty %d" % d)  # a frame or two has ticked
		level.free()
	GameState.difficulty = real
	_restore_state()


func test_result_names_the_difficulty() -> void:
	_setup_state()
	var real: int = GameState.difficulty
	GameState.difficulty = GameState.Difficulty.HARD
	var level := await _make_level()
	level.end_level()
	assert_eq(GameState.last_result.get("difficulty"), "Hard")
	level.free()
	GameState.difficulty = real
	_restore_state()


# --- Requested ships glow ---

func test_requested_ship_glows() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	assert_false(ship.is_glowing(), "a parked ship doesn't glow")
	level._request(ship)
	assert_true(ship.is_glowing(), "a ship whose owner wants it back glows")
	level.free()
	_restore_state()


func test_glow_stops_once_the_ship_is_selected() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_leaver(level)
	level._request(ship)
	assert_true(ship.is_glowing())
	level.select_ship(ship)
	assert_true(level.driven_ship == ship)
	assert_false(ship.is_glowing(), "picking the ship up dismisses the glow")
	level.release_ship()
	assert_false(ship.is_glowing(), "and it stays off after letting go")
	level.free()
	_restore_state()


# --- Black hole ---

func _add_hole(level: Level) -> BlackHole:
	var hole := BlackHole.new()
	hole.name = "BlackHole"
	hole.position = OPEN_FLOOR + Vector2(400, 0)
	level.add_child(hole)
	level._black_hole = hole
	return hole


func test_free_ship_drifts_towards_the_hole() -> void:
	_setup_state()
	var level := await _make_level()
	_add_hole(level)
	var ship := _first_ship(level)
	level.select_ship(ship)
	level.release_ship()  # driven once: from now on it feels the pull
	_move(ship, OPEN_FLOOR)
	ship.linear_velocity = Vector2.ZERO
	ship.freeze = false
	await _physics_frames(30)
	assert_true(ship.linear_velocity.x > 0.0, "v=%s" % ship.linear_velocity)
	level.free()
	_restore_state()


func test_parked_ships_feel_no_pull() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	_add_hole(level)
	var ship := _park_silver_leaver(level)
	await tree.physics_frame
	var at := ship.global_position
	await _physics_frames(30)
	assert_true(ship.global_position.distance_to(at) < 0.01)
	level.free()
	_restore_state()


# --- Orphaned ships ---

## A tiered Level 1 with an exit and a fixed customer list; its first ship is moved out of the way.
func _orphan_level(queue_names: Array) -> Level:
	var level: Level = LEVEL01.instantiate()
	level.change_scene_on_end = false
	level.use_tiers = true
	level.random_customers = 0
	var queue: Array[ShipSpec] = []
	for n: String in queue_names:
		queue.append(ship_spec(n))
	level.customer_queue = queue
	var exit: ExitPad = EXIT_SCENE.instantiate()
	exit.name = "Exit"
	exit.position = EXIT_POS
	level.add_child(exit)
	tree.root.add_child(level)
	await tree.process_frame
	_move(_first_ship(level), OPEN_FLOOR)
	return level


func _space_held_by(level: Level, ship: Ship) -> ParkingSpace:
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		if space.occupant == ship:
			return space
	return null


func test_orphan_times_fall_in_the_window() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var times := Level.orphan_times(rng, 2, 300.0)
		assert_eq(times.size(), 2)
		for t in times:
			assert_true(t >= 75.0 and t <= 180.0, str(t))


func test_orphan_takes_an_allowed_free_space() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	assert_true(orphan != null)
	if orphan:
		assert_true(orphan.orphan != null and orphan.is_parked)
		var space := _space_held_by(level, orphan)
		assert_true(space != null)
		if space:
			assert_true(ParkingRules.fits_class(orphan.spec.ship_class, space.space_class))
	level.free()
	_restore_state()


func test_orphan_never_blocks_the_shift() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout", "light_scout", "medium_shuttle", "medium_shuttle", "medium_shuttle", "medium_shuttle"])
	assert_true(level._spawn_orphan() == null, "all 6 spaces are needed by customers")
	level.free()
	_restore_state()


func test_orphan_waits_for_a_free_space() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var blocker := _first_ship(level)
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		space.claim(blocker)
	level._orphans_due = [0.0] as Array[float]
	level._update_orphans(0.1)
	assert_eq(level.get_node("Ships").get_child_count(), 1, "nowhere to put it yet")
	_space_a1(level).release()
	level._update_orphans(0.5)
	level._update_orphans(0.5)
	level._update_orphans(0.1)
	var held := _space_a1(level).occupant
	assert_true(held != null and held.orphan != null, "it took A1 once A1 was free")
	level.free()
	_restore_state()


func test_parked_orphan_can_be_driven() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	level.select_ship(orphan)
	assert_true(level.driven_ship == orphan)
	assert_false(orphan.is_parked)
	level.free()
	_restore_state()


func test_orphan_ejected_after_countdown_pays_bonus() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	var served := level.ledger.served
	orphan.orphan.time_left = 0.0
	orphan.unpark()
	_move(orphan, EXIT_POS)
	level._update_orphans(0.1)
	assert_false(orphan in level.get_node("Ships").get_children())
	assert_eq(level.ledger.bonuses, Orphan.BONUS)
	assert_eq(level.ledger.served, served)
	level.free()
	_restore_state()


func test_orphan_ejected_early_costs_pay() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	var pay := level.ledger.pay
	orphan.unpark()
	_move(orphan, EXIT_POS)
	level._update_orphans(0.1)
	assert_eq(level.ledger.pay, pay - Orphan.EARLY_COST)
	assert_eq(level.ledger.bonuses, 0)
	assert_eq(level.ledger.served, 0)
	level.free()
	_restore_state()


func test_orphan_ejected_while_driven_releases_it() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	level.select_ship(orphan)
	_move(orphan, EXIT_POS)
	level._update_orphans(0.1)
	assert_true(level.driven_ship == null)
	level.free()
	_restore_state()


func test_orphan_reparks_without_counting() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	var orphan := level._spawn_orphan()
	var space := _space_held_by(level, orphan)
	level.select_ship(orphan)
	level.release_ship()
	_move(orphan, space.global_position)
	orphan.global_rotation = space.global_rotation
	orphan.freeze = false
	orphan.linear_velocity = Vector2.ZERO
	await _physics_frames(90)
	assert_true(orphan.is_parked, "an orphan left in a space settles back into it")
	assert_eq(level.ledger.served, 0, "but it's never a served customer")
	level.free()
	_restore_state()


func test_shift_wins_with_an_orphan_present() -> void:
	_setup_state()
	var level := await _orphan_level(["light_scout"])
	level._spawn_orphan()
	var ship := _first_ship(level)
	level._on_ship_parked(ship, level.get_node("Spaces/B1"))
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.WON)
	level.free()
	_restore_state()


func test_level_without_orphans_rolls_none() -> void:
	_setup_state()
	var level := await _make_level()
	assert_true(level._orphans_due.is_empty())
	level.free()
	_restore_state()



# --- Level 4 ---

const LEVEL04_PATH := "res://scenes/levels/Level04.tscn"


func test_level04_layout() -> void:
	assert_true(GameState.has_level_scene(4))
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	var counts := {}
	var gold: Array[String] = []
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		counts[space.space_class] = counts.get(space.space_class, 0) + 1
		if space.gold:
			gold.append(space.label)
	gold.sort()
	assert_eq(counts, {ShipSpec.ShipClass.HEAVY: 3, ShipSpec.ShipClass.MEDIUM: 5, ShipSpec.ShipClass.LIGHT: 3})
	assert_eq(gold, ["G1", "G2"] as Array[String])
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	var hole := level.get_node_or_null("BlackHole") as BlackHole
	assert_true(hole != null and hole.position == Vector2(1200, 700))
	assert_eq(level.level_number, 4)
	assert_eq(level.goal_text, "Serve 7 customers")
	assert_eq(level.random_customers, 7)
	assert_eq(level.base_pay, 100)
	assert_eq(level.silver_target, 280)
	assert_eq(level.gold_target, 330)
	assert_eq(level.arrival_interval, 10.0)
	assert_true(level.use_tiers)
	assert_eq(level.retrieval_count, 2)
	assert_eq(level.orphan_count, 2)
	var pool := _queue_paths(level.customer_queue)
	for file in DirAccess.get_files_at("res://resources/ships/"):
		if file.ends_with(".tres"):
			assert_true("res://resources/ships/" + file in pool, file)
	level.free()


func test_level04_spaces_stay_clear() -> void:
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	var hole: Node2D = level.get_node("BlackHole")
	var bay_xform := (level.get_node("Entrance") as Node2D).transform
	var exit_xform := (level.get_node("Exit") as Node2D).transform
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		assert_false(_circle_hits_rect(hole.position, 150.0, space.transform, space.size()), "%s is out of the strongest pull" % space.label)
		var corners := []
		var h := space.size() / 2
		for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2.ZERO]:
			corners.append(space.transform * c)
		for p: Vector2 in corners:
			assert_false(Rect2(-ArrivalBay.SIZE / 2, ArrivalBay.SIZE).has_point(bay_xform.affine_inverse() * p), "%s clear of the bay" % space.label)
			assert_false(Rect2(-ExitPad.SIZE / 2, ExitPad.SIZE).has_point(exit_xform.affine_inverse() * p), "%s clear of the exit" % space.label)
	level.free()


func test_level04_runs_a_shift() -> void:
	_setup_state()
	var level: Level = load(LEVEL04_PATH).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	assert_eq(level.customer_queue.size(), 7)
	assert_eq(level._orphans_due.size(), 2)
	await _physics_frames(120)
	assert_true(level.get_node("Ships").get_child_count() >= 1)
	level.free()
	_restore_state()


func test_level04_spaces_clear_the_hud() -> void:
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		var h := space.size() / 2
		for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
			var p: Vector2 = space.transform * c
			assert_true(p.y >= 220.0, "%s reaches y %d, under the HUD's pay and goal lines" % [space.label, p.y])
	level.free()



func test_orphans_on_hard_leave_time_to_collect() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 50:
		for t in Level.orphan_times(rng, 2, 150.0):
			assert_true(t >= 37.5 and t <= 150.0 - Orphan.COUNTDOWN - Level.ORPHAN_EJECT_SECONDS, str(t))


func test_level04_every_space_parks_a_resting_ship() -> void:
	_setup_state()
	var level: Level = load(LEVEL04_PATH).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	level._orphans_due.clear()
	level.ledger.customers = 100  # serving these test ships must not end the shift
	var names := {ShipSpec.ShipClass.LIGHT: "light_scout", ShipSpec.ShipClass.MEDIUM: "medium_shuttle", ShipSpec.ShipClass.HEAVY: "heavy_freighter"}
	var placed := {}
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		var ship: Ship = SHIP_SCENE.instantiate()
		ship.spec = ship_spec(names[space.space_class])
		ship.global_position = space.global_position
		ship.rotation = space.global_rotation
		level.get_node("Ships").add_child(ship)
		placed[space.label] = ship
	await _physics_frames(120)
	for label: String in placed:
		assert_true((placed[label] as Ship).is_parked, "a ship left at rest in %s parks" % label)
	level.free()
	_restore_state()



func test_waiting_arrival_feels_no_pull_until_driven() -> void:
	_setup_state()
	var level := await _make_level()
	_add_hole(level)
	var ship := _first_ship(level)
	_move(ship, OPEN_FLOOR)
	ship.freeze = false
	ship.linear_velocity = Vector2.ZERO
	await _physics_frames(30)
	assert_true(ship.linear_velocity.length() < 0.01, "untouched, it stays put: v=%s" % ship.linear_velocity)
	level.select_ship(ship)
	level.release_ship()
	await _physics_frames(30)
	assert_true(ship.linear_velocity.x > 0.0, "after driving it, the pull takes it")
	level.free()
	_restore_state()


func test_requested_ship_feels_no_pull_until_picked_up() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	_add_hole(level)
	var ship := _park_silver_leaver(level)
	level._request(ship)
	await _physics_frames(5)
	var at := ship.global_position
	await _physics_frames(30)
	assert_true(ship.global_position.distance_to(at) < 0.01, "waits where it was parked")
	level.free()
	_restore_state()



func _driven_ship_at(level: Level, pos: Vector2, velocity: Vector2) -> Ship:
	var ship := _first_ship(level)
	level.select_ship(ship)
	level.release_ship()
	_move(ship, pos)
	ship.freeze = false
	ship.linear_velocity = velocity
	ship.angular_velocity = 0.0
	return ship


func test_ship_reaching_the_core_is_flung_spinning() -> void:
	_setup_state()
	var level := await _make_level()
	var hole := _add_hole(level)
	var ship := _driven_ship_at(level, hole.position, Vector2(100, 0))
	await _physics_frames(2)
	assert_true(ship.linear_velocity.length() >= BlackHole.FLING_SPEED * 0.9, "v=%s" % ship.linear_velocity)
	assert_true(ship.linear_velocity.x > 0.0, "out the far side, the way it was going")
	assert_true(absf(ship.angular_velocity) >= BlackHole.FLING_SPIN * 0.9, "spinning: %s" % ship.angular_velocity)
	level.free()
	_restore_state()


func test_flung_ship_is_not_flung_again_at_once() -> void:
	_setup_state()
	var level := await _make_level()
	var hole := _add_hole(level)
	var ship := _driven_ship_at(level, hole.position, Vector2(100, 0))
	await _physics_frames(2)
	_move(ship, hole.position)
	ship.freeze = false
	ship.linear_velocity = Vector2(0, 50)
	await _physics_frames(2)
	assert_true(ship.linear_velocity.length() < BlackHole.FLING_SPEED * 0.5, "no second fling within a second")
	level.free()
	_restore_state()


## A Level 1 with a black hole and one resting rock (allowed up to fling speed) under "Asteroids".
func _hole_and_rock(level: Level, offset: Vector2) -> Asteroid:
	var hole := _add_hole(level)
	var rocks := Node2D.new()
	rocks.name = "Asteroids"
	level.add_child(rocks)
	level._asteroids = rocks
	var img := Image.create(100, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var rock := Asteroid.new()
	rock.texture = ImageTexture.create_from_image(img)
	rock.drift_speed = 0.0
	rock.max_speed = BlackHole.FLING_SPEED
	rock.position = hole.position + offset
	rocks.add_child(rock)
	rock.angular_velocity = 0.0
	return rock


func test_asteroid_is_pulled_towards_the_hole() -> void:
	_setup_state()
	var level := await _make_level()
	var rock := _hole_and_rock(level, Vector2(200, 0))
	await _physics_frames(30)
	assert_true(rock.linear_velocity.x < 0.0, "v=%s" % rock.linear_velocity)
	level.free()
	_restore_state()


func test_asteroid_reaching_the_core_is_flung() -> void:
	_setup_state()
	var level := await _make_level()
	var rock := _hole_and_rock(level, Vector2.ZERO)
	rock.linear_velocity = Vector2(50, 0)
	await _physics_frames(2)
	assert_true(rock.linear_velocity.length() >= BlackHole.FLING_SPEED * 0.9, "v=%s" % rock.linear_velocity)
	level.free()
	_restore_state()


func test_level04_has_asteroids_clear_of_spaces() -> void:
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	var rocks := level.get_node_or_null("Asteroids")
	assert_true(rocks != null and rocks.get_child_count() >= 5)
	if rocks:
		var keep_clear := []
		for space: ParkingSpace in level.get_node("Spaces").get_children():
			keep_clear.append([space.label, space.transform, space.size()])
		keep_clear.append(["bay", (level.get_node("Entrance") as Node2D).transform, ArrivalBay.SIZE])
		keep_clear.append(["exit", (level.get_node("Exit") as Node2D).transform, ExitPad.SIZE])
		for rock: Asteroid in rocks.get_children():
			var reach := 0.0
			for p in SpriteOutline.outline(rock.texture, rock.art_scale):
				reach = maxf(reach, p.length())
			for k in keep_clear:
				assert_false(_circle_hits_rect(rock.position, reach, k[1], k[2]), "%s starts on %s" % [rock.name, k[0]])
	level.free()



func test_level04_rocks_can_fly_and_slow_down() -> void:
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	for rock: Asteroid in level.get_node("Asteroids").get_children():
		assert_eq(rock.max_speed, BlackHole.FLING_SPEED, "%s can be flung at full speed" % rock.name)
		assert_true(rock.drag > 0.0, "%s slows back to a drift" % rock.name)
	level.free()


func test_level04_boulders_stay_clear() -> void:
	if not GameState.has_level_scene(4):
		return
	var level: Level = load(LEVEL04_PATH).instantiate()
	var boulders := level.get_node_or_null("Boulders")
	assert_true(boulders != null and boulders.get_child_count() >= 4)
	if boulders:
		var hole: Node2D = level.get_node("BlackHole")
		var keep_clear := []
		for space: ParkingSpace in level.get_node("Spaces").get_children():
			keep_clear.append([space.label, space.transform, space.size()])
		keep_clear.append(["bay", (level.get_node("Entrance") as Node2D).transform, ArrivalBay.SIZE])
		keep_clear.append(["exit", (level.get_node("Exit") as Node2D).transform, ExitPad.SIZE])
		for boulder: Wreck in boulders.get_children():
			var reach := 0.0
			for p in SpriteOutline.outline(boulder.texture, boulder.art_scale):
				reach = maxf(reach, p.length())
			assert_true(reach >= 80.0, "%s is big" % boulder.name)
			assert_true(boulder.position.distance_to(hole.position) - reach > 150.0, "%s is out of the strongest pull" % boulder.name)
			for k in keep_clear:
				assert_false(_circle_hits_rect(boulder.position, reach, k[1], k[2]), "%s overlaps %s" % [boulder.name, k[0]])
			for rock: Asteroid in level.get_node("Asteroids").get_children():
				assert_true(rock.position.distance_to(boulder.position) > reach + 60.0, "%s starts clear of %s" % [rock.name, boulder.name])
	level.free()


# --- Moving parked ships ---

func _moving_level() -> Level:
	var level: Level = LEVEL01.instantiate()
	level.change_scene_on_end = false
	level.use_tiers = true
	level.allow_moving_parked = true
	var exit: ExitPad = EXIT_SCENE.instantiate()
	exit.name = "Exit"
	exit.position = EXIT_POS
	level.add_child(exit)
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _park_silver_stayer(level: Level) -> Ship:
	var ship := _first_ship(level)
	level.customer_for(ship).tier = Customer.Tier.SILVER
	var space := _space_a1(level)
	ship.global_position = space.global_position
	ship.global_rotation = space.global_rotation
	level._on_ship_parked(ship, space)
	return ship


func test_parked_ship_can_be_moved_when_allowed() -> void:
	_setup_state()
	var level := await _moving_level()
	var ship := _park_silver_stayer(level)
	level.select_ship(ship)
	assert_true(level.driven_ship == ship)
	assert_false(ship.is_parked)
	_move(ship, OPEN_FLOOR)
	level._update_customers(0.1)
	assert_true(_space_a1(level).occupant == null, "A1 frees up once the ship has left it")
	level.free()
	_restore_state()


func test_reparking_never_serves_twice() -> void:
	_setup_state()
	var level := await _moving_level()
	var ship := _park_silver_stayer(level)
	assert_eq(level.ledger.served, 1)
	level.ledger.customers = 2  # one more serve would win the shift
	var earned := level.ledger.earned
	level.select_ship(ship)
	_move(ship, OPEN_FLOOR)
	level._update_customers(0.1)
	var a2: ParkingSpace = level.get_node("Spaces/A2")
	level._on_ship_parked(ship, a2)
	assert_eq(level.ledger.served, 1, "moved, not served again")
	assert_eq(level.ledger.earned, earned, "no second fee or tip")
	assert_eq(level.ledger.outcome, ShiftLedger.Outcome.PLAYING)
	assert_true(ship.is_parked and a2.occupant == ship)
	level.free()
	_restore_state()


func test_moved_leaver_still_asks_for_its_ship() -> void:
	_setup_state()
	var level := await _moving_level()
	var ship := _park_silver_leaver(level)
	var c := level.customer_for(ship)
	level.select_ship(ship)
	_move(ship, OPEN_FLOOR)
	level._update_customers(0.1)
	var waiting := c.request_in
	level._on_ship_parked(ship, level.get_node("Spaces/A2"))
	assert_eq(c.request_in, waiting, "re-parking leaves the countdown alone")
	assert_true(waiting >= 0.0)
	level._update_customers(waiting + 0.1)
	assert_true(c.requested)
	level.free()
	_restore_state()


func test_parked_ships_stay_put_where_not_allowed() -> void:
	_setup_state()
	var level := await _make_tiered_level()
	var ship := _park_silver_stayer(level)
	level.select_ship(ship)
	assert_true(level.driven_ship == null)
	assert_false(ship in level.ships_near_world(ship.global_position, 50.0))
	level.free()
	_restore_state()


# --- Special requests ---

func _request_level() -> Level:
	var level: Level = LEVEL01.instantiate()
	level.change_scene_on_end = false
	level.use_tiers = true
	level.random_customers = 0
	level.retrieval_count = 2
	level.request_count = 3
	var queue: Array[ShipSpec] = []
	for i in 6:
		queue.append(ship_spec("light_scout"))
	level.customer_queue = queue
	var exit: ExitPad = EXIT_SCENE.instantiate()
	exit.name = "Exit"
	exit.position = EXIT_POS
	level.add_child(exit)
	tree.root.add_child(level)
	await tree.process_frame
	return level


## The first ship as a silver stayer who asked for B1.
func _b1_requester(level: Level) -> Ship:
	var ship := _first_ship(level)
	var c := level.customer_for(ship)
	c.tier = Customer.Tier.SILVER
	c.wants_retrieval = false
	c.wants_space = "B1"
	(level.get_node("Spaces/B1") as ParkingSpace).set_pin(c.color())
	return ship


func test_requests_never_overlap_retrievals() -> void:
	_setup_state()
	var level := await _request_level()
	assert_eq(level._request_indexes.size(), 3)
	for i in level._request_indexes:
		assert_false(i in level._retrieval_indexes, "position %d both requests and leaves" % i)
	level.free()
	_restore_state()


func test_request_prefers_an_occupied_fitting_space() -> void:
	_setup_state()
	var level := await _request_level()
	var a1 := _space_a1(level)
	a1.claim(_first_ship(level))
	for i in 20:
		assert_true(level._pick_request_space(ShipSpec.ShipClass.LIGHT) == a1)
	a1.release()
	for i in 20:
		var space := level._pick_request_space(ShipSpec.ShipClass.HEAVY)
		assert_true(space == null or ParkingRules.fits_class(ShipSpec.ShipClass.HEAVY, space.space_class))
		var light := level._pick_request_space(ShipSpec.ShipClass.LIGHT)
		assert_true(light != null and ParkingRules.fits_class(ShipSpec.ShipClass.LIGHT, light.space_class))
	level.free()
	_restore_state()


func test_request_in_named_space_pays_bonus_and_tip() -> void:
	_setup_state()
	var level := await _request_level()
	var ship := _b1_requester(level)
	var b1: ParkingSpace = level.get_node("Spaces/B1")
	level._on_ship_parked(ship, b1)
	assert_eq(level.ledger.bonuses, Level.REQUEST_BONUS)
	assert_eq(level.ledger.tips, 15)
	assert_eq(level.ledger.served, 1)
	assert_eq(b1.pin_color.a, 0.0, "the pin goes once they've parked")
	level.free()
	_restore_state()


func test_request_parked_elsewhere_pays_fee_only() -> void:
	_setup_state()
	var level := await _request_level()
	var ship := _b1_requester(level)
	var earned := level.ledger.earned
	level._on_ship_parked(ship, level.get_node("Spaces/A2"))
	assert_eq(level.ledger.bonuses, 0)
	assert_eq(level.ledger.tips, 0)
	assert_eq(level.ledger.earned - earned, ShiftLedger.PARK_FEE)
	assert_eq(level.ledger.served, 1)
	assert_eq((level.get_node("Spaces/B1") as ParkingSpace).pin_color.a, 0.0)
	level.free()
	_restore_state()



# --- Level 5 ---

const LEVEL05_PATH := "res://scenes/levels/Level05.tscn"


func test_level05_layout() -> void:
	assert_true(GameState.has_level_scene(5))
	if not GameState.has_level_scene(5):
		return
	var level: Level = load(LEVEL05_PATH).instantiate()
	var counts := {}
	var gold: Array[String] = []
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		counts[space.space_class] = counts.get(space.space_class, 0) + 1
		if space.gold:
			gold.append(space.label)
	gold.sort()
	assert_eq(counts, {ShipSpec.ShipClass.HEAVY: 3, ShipSpec.ShipClass.MEDIUM: 6, ShipSpec.ShipClass.LIGHT: 3})
	assert_eq(gold, ["G1", "G2", "G3", "G4", "G5", "G6"] as Array[String])
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	for hazard in ["BlackHole", "Radiation", "Asteroids", "Boulders"]:
		assert_true(level.get_node_or_null(hazard) == null, "no %s in the lounge" % hazard)
	assert_eq(level.level_number, 5)
	assert_eq(level.goal_text, "Serve 9 customers")
	assert_eq(level.random_customers, 9)
	assert_eq(level.base_pay, 100)
	assert_eq(level.silver_target, 360)
	assert_eq(level.gold_target, 420)
	assert_eq(level.arrival_interval, 6.0)
	assert_true(level.use_tiers)
	assert_eq(level.tier_weights, {Customer.Tier.GOLD: 60, Customer.Tier.SILVER: 30, Customer.Tier.BRONZE: 10})
	assert_eq(level.retrieval_count, 2)
	assert_eq(level.request_count, 3)
	assert_true(level.allow_moving_parked)
	var pool := _queue_paths(level.customer_queue)
	for file in DirAccess.get_files_at("res://resources/ships/"):
		if file.ends_with(".tres"):
			assert_true("res://resources/ships/" + file in pool, file)
	level.free()


func test_level05_spaces_clear_hud_bay_and_exit() -> void:
	if not GameState.has_level_scene(5):
		return
	var level: Level = load(LEVEL05_PATH).instantiate()
	var bay_xform := (level.get_node("Entrance") as Node2D).transform
	var exit_xform := (level.get_node("Exit") as Node2D).transform
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		var h := space.size() / 2
		for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
			var p: Vector2 = space.transform * c
			assert_true(p.y >= 220.0, "%s reaches under the HUD" % space.label)
			assert_false(Rect2(-ArrivalBay.SIZE / 2, ArrivalBay.SIZE).has_point(bay_xform.affine_inverse() * p), "%s clear of the bay" % space.label)
			assert_false(Rect2(-ExitPad.SIZE / 2, ExitPad.SIZE).has_point(exit_xform.affine_inverse() * p), "%s clear of the exit" % space.label)
	level.free()


func test_level05_runs_a_shift() -> void:
	_setup_state()
	var level: Level = load(LEVEL05_PATH).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	assert_eq(level.customer_queue.size(), 9)
	assert_eq(level._request_indexes.size(), 3)
	await _physics_frames(120)
	assert_true(level.get_node("Ships").get_child_count() >= 1)
	level.free()
	_restore_state()
