extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const ACTIONS := ["thrust_forward", "thrust_back", "strafe_left", "strafe_right",
	"rotate_left", "rotate_right", "brake", "stop_rotation"]


func _spawn(spec_name: String, pos := Vector2(200, 400)) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = load("res://resources/ships/%s.tres" % spec_name)
	ship.position = pos
	tree.root.add_child(ship)
	return ship


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func test_applies_spec() -> void:
	var ship := _spawn("medium_shuttle")
	assert_eq(ship.mass, 2.5)
	assert_eq(ship.gravity_scale, 0.0)
	var shape := ship.get_node("CollisionShape2D").shape as RectangleShape2D
	assert_eq(shape.size, Vector2(60, 100))
	ship.queue_free()


func test_forward_thrust_moves_nose_direction() -> void:
	var ship := _spawn("light_scout")
	ship.set_driven(true)
	Input.action_press("thrust_forward")
	await _frames(20)
	_release_all()
	assert_true(ship.linear_velocity.y < -10.0, "vy=%s" % ship.linear_velocity.y)
	assert_true(absf(ship.linear_velocity.x) < 1.0, "vx=%s" % ship.linear_velocity.x)
	ship.queue_free()


func test_ignores_input_when_not_driven() -> void:
	var ship := _spawn("light_scout")
	Input.action_press("thrust_forward")
	await _frames(20)
	_release_all()
	assert_true(ship.linear_velocity.length() < 0.01, "v=%s" % ship.linear_velocity)
	ship.queue_free()


func test_rotate_right_spins_clockwise() -> void:
	var ship := _spawn("light_scout")
	ship.set_driven(true)
	Input.action_press("rotate_right")
	await _frames(20)
	_release_all()
	assert_true(ship.angular_velocity > 0.0, "w=%s" % ship.angular_velocity)
	ship.queue_free()


func test_hull_points_follow_rotation() -> void:
	var ship := _spawn("light_scout", Vector2(100, 100))
	ship.rotation = PI / 2
	var pts := ship.hull_points()
	assert_eq(pts.size(), 5)
	var found := false
	for p in pts:
		if p.distance_to(Vector2(132, 80)) < 0.5:
			found = true
	assert_true(found, "corner (-20,-32) should map to (132,80): %s" % pts)
	ship.queue_free()


func _wall_above(ship: Ship, gap: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	col.shape = rect
	wall.add_child(col)
	wall.position = ship.position + Vector2(0, -ship.spec.hull_size.y / 2 - gap - 10)
	tree.root.add_child(wall)
	return wall


func _ram_wall(speed: float) -> Array[int]:
	var ship := _spawn("light_scout")
	var wall := _wall_above(ship, 20.0)
	var costs: Array[int] = []
	ship.dented.connect(func(_s: Ship, cost: int) -> void: costs.append(cost))
	ship.linear_velocity = Vector2(0, -speed)
	await _frames(40)
	ship.queue_free()
	wall.queue_free()
	return costs


func test_hard_impact_emits_dent() -> void:
	var costs := await _ram_wall(300.0)
	assert_eq(costs.size(), 1, "costs=%s" % [costs])
	if costs.size() == 1:
		assert_almost(costs[0], ShiftLedger.dent_cost(300.0), 5.0)


func test_ship_to_ship_collision_charged_once() -> void:
	var mover := _spawn("medium_shuttle", Vector2(200, 400))
	var idle := _spawn("medium_shuttle", Vector2(200, 400 - 100 - 20))
	var costs: Array[int] = []
	var record := func(_s: Ship, cost: int) -> void: costs.append(cost)
	mover.dented.connect(record)
	idle.dented.connect(record)
	mover.linear_velocity = Vector2(0, -260)
	await _frames(40)
	assert_eq(costs.size(), 1, "costs=%s" % [costs])
	if costs.size() == 1:
		assert_almost(costs[0], ShiftLedger.dent_cost(260.0), 5.0)
	mover.queue_free()
	idle.queue_free()


func test_no_damping_keeps_drift_and_spin() -> void:
	var ship := _spawn("light_scout")
	ship.linear_velocity = Vector2(100, 0)
	ship.angular_velocity = 1.0
	await _frames(60)
	assert_almost(ship.linear_velocity.length(), 100.0, 0.5)
	assert_almost(ship.angular_velocity, 1.0, 0.01)
	ship.queue_free()


func _frames_until(ship: Ship, action: String, done: Callable, limit := 300) -> int:
	ship.set_driven(true)
	Input.action_press(action)
	var n := 0
	while not done.call() and n < limit:
		await tree.physics_frame
		n += 1
	_release_all()
	return n


func test_brake_stops_drift_to_parking_speed() -> void:
	var ship := _spawn("light_scout")
	ship.linear_velocity = Vector2(150, -80)
	var n := await _frames_until(ship, "brake",
		func() -> bool: return ship.linear_velocity.length() < ParkingRules.MAX_PARK_SPEED)
	assert_true(n < 300, "never stopped")
	await _frames(10)
	assert_true(ship.linear_velocity.length() < ParkingRules.MAX_PARK_SPEED, "stays stopped")
	ship.queue_free()


func test_stop_rotation_stops_spin() -> void:
	var ship := _spawn("light_scout")
	ship.angular_velocity = -2.0
	var n := await _frames_until(ship, "stop_rotation",
		func() -> bool: return absf(ship.angular_velocity) < ParkingRules.MAX_PARK_SPIN)
	assert_true(n < 300, "never stopped spinning")
	ship.queue_free()


func test_heavy_ship_brakes_slower_than_light() -> void:
	var light := _spawn("light_scout", Vector2(200, 300))
	light.linear_velocity = Vector2(200, 0)
	var light_frames := await _frames_until(light, "brake",
		func() -> bool: return light.linear_velocity.length() < ParkingRules.MAX_PARK_SPEED)
	light.queue_free()
	var heavy := _spawn("heavy_freighter", Vector2(200, 600))
	heavy.linear_velocity = Vector2(200, 0)
	var heavy_frames := await _frames_until(heavy, "brake",
		func() -> bool: return heavy.linear_velocity.length() < ParkingRules.MAX_PARK_SPEED)
	heavy.queue_free()
	assert_true(heavy_frames > light_frames, "heavy %d vs light %d frames" % [heavy_frames, light_frames])


func test_brake_ignored_when_not_driven() -> void:
	var ship := _spawn("light_scout")
	ship.linear_velocity = Vector2(100, 0)
	Input.action_press("brake")
	await _frames(30)
	_release_all()
	assert_almost(ship.linear_velocity.length(), 100.0, 0.5)
	ship.queue_free()


func test_soft_bump_no_dent() -> void:
	var costs := await _ram_wall(80.0)
	assert_eq(costs.size(), 0, "costs=%s" % [costs])


func test_center_of_mass_from_spec() -> void:
	var ship := _spawn("heavy_freighter")
	assert_eq(ship.center_of_mass_mode, RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM)
	assert_eq(ship.center_of_mass, Vector2(0, 20))
	ship.queue_free()


func test_off_centre_thruster_spins_ship() -> void:
	var spec := (load("res://resources/ships/light_scout.tres") as ShipSpec).duplicate() as ShipSpec
	var t := ThrusterSpec.new()
	t.position = Vector2(10, 30)
	t.direction = Vector2(0, -1)
	t.force = 100.0
	t.actions = PackedStringArray(["thrust_forward"])
	var only: Array[ThrusterSpec] = [t]
	spec.thrusters = only
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = spec
	ship.position = Vector2(200, 400)
	tree.root.add_child(ship)
	ship.set_driven(true)
	Input.action_press("thrust_forward")
	await _frames(20)
	_release_all()
	assert_true(ship.angular_velocity < 0.0, "w=%s" % ship.angular_velocity)
	assert_true(ship.linear_velocity.y < 0.0, "v=%s" % ship.linear_velocity)
	ship.queue_free()


func test_thruster_fires_only_for_its_actions() -> void:
	var ship := _spawn("light_scout")
	ship.set_driven(true)
	Input.action_press("strafe_right")
	await _frames(10)
	var firing := ship.firing
	_release_all()
	assert_true(firing.size() > 0, "nothing fired")
	for i in firing:
		assert_true(ship.spec.thrusters[i].actions.has("strafe_right"), "thruster %d" % i)
	assert_true(ship.linear_velocity.x > 0.0, "v=%s" % ship.linear_velocity)
	ship.queue_free()


func _frames_to_brake(spec_name: String, velocity: Vector2) -> int:
	var ship := _spawn(spec_name)
	ship.linear_velocity = velocity
	var n := await _frames_until(ship, "brake",
		func() -> bool: return ship.linear_velocity.length() < ParkingRules.MAX_PARK_SPEED)
	ship.queue_free()
	return n


func test_weak_retro_brakes_forward_slower_than_sideways() -> void:
	var forward := await _frames_to_brake("medium_shuttle", Vector2(0, -150))
	var sideways := await _frames_to_brake("medium_shuttle", Vector2(150, 0))
	assert_true(forward > sideways, "forward %d vs sideways %d frames" % [forward, sideways])


func test_brake_flames_oppose_drift() -> void:
	var ship := _spawn("light_scout")
	ship.linear_velocity = Vector2(0, -150)
	ship.set_driven(true)
	Input.action_press("brake")
	await _frames(3)
	var firing := ship.firing
	_release_all()
	assert_true(firing.size() > 0, "no brake flames")
	for i in firing:
		assert_true(ship.spec.thrusters[i].push_along(Vector2(0, 1)) > 0.0, "thruster %d" % i)
	ship.queue_free()


func test_brake_at_rest_is_quiet() -> void:
	var ship := _spawn("light_scout")
	ship.set_driven(true)
	Input.action_press("brake")
	Input.action_press("stop_rotation")
	await _frames(10)
	var firing := ship.firing
	_release_all()
	assert_eq(firing.size(), 0, "firing=%s" % firing)
	assert_eq(ship.linear_velocity, Vector2.ZERO)
	assert_eq(ship.angular_velocity, 0.0)
	ship.queue_free()


func test_not_driven_never_fires() -> void:
	var ship := _spawn("light_scout")
	Input.action_press("thrust_forward")
	await _frames(5)
	var firing := ship.firing
	_release_all()
	assert_eq(firing.size(), 0)
	ship.queue_free()
