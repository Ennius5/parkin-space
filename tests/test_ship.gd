extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const ACTIONS := ["thrust_forward", "thrust_back", "strafe_left", "strafe_right",
	"rotate_left", "rotate_right", "brake", "stop_rotation"]


func _spawn(spec_name: String, pos := Vector2(200, 400)) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec(spec_name)
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
	var spec := ship_spec("light_scout").duplicate() as ShipSpec
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


func test_stop_spin_uses_rotation_thrusters_only() -> void:
	var ship := _spawn("heavy_freighter")
	ship.angular_velocity = 1.0
	ship.set_driven(true)
	Input.action_press("stop_rotation")
	await _frames(3)
	var firing := ship.firing
	_release_all()
	assert_true(firing.size() > 0, "no spin flames")
	for i in firing:
		var actions := ship.spec.thrusters[i].actions
		assert_true(actions.has("rotate_left") or actions.has("rotate_right"), "thruster %d: %s" % [i, actions])
	ship.queue_free()


func test_freighter_is_slow_to_stop_spinning() -> void:
	var ship := _spawn("heavy_freighter")
	ship.angular_velocity = 1.0
	var n := await _frames_until(ship, "stop_rotation",
		func() -> bool: return absf(ship.angular_velocity) < ParkingRules.MAX_PARK_SPIN)
	assert_true(n > 90, "stopped in %d frames" % n)
	ship.queue_free()


func _triangle_spec() -> ShipSpec:
	var spec := ship_spec("light_scout").duplicate() as ShipSpec
	spec.hull_polygon = PackedVector2Array([Vector2(0, -32), Vector2(20, 32), Vector2(-20, 32)])
	return spec


func _spawn_spec(spec: ShipSpec, pos := Vector2(200, 400)) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = spec
	ship.position = pos
	tree.root.add_child(ship)
	return ship


func test_polygon_spec_uses_collision_polygon() -> void:
	var ship := _spawn_spec(_triangle_spec())
	var polys := ship.find_children("*", "CollisionPolygon2D", false, false)
	assert_eq(polys.size(), 1)
	if polys.size() == 1:
		assert_false((polys[0] as CollisionPolygon2D).disabled)
		assert_eq((polys[0] as CollisionPolygon2D).polygon.size(), 3)
	assert_true((ship.get_node("CollisionShape2D") as CollisionShape2D).disabled, "rectangle disabled")
	ship.queue_free()


func test_hull_points_use_polygon() -> void:
	var ship := _spawn_spec(_triangle_spec(), Vector2(100, 100))
	var pts := ship.hull_points()
	assert_eq(pts.size(), 4)
	if pts.size() == 4:
		assert_eq(pts[0], Vector2(100, 68))
		assert_eq(pts[3], Vector2(100, 100))
	ship.queue_free()


func test_paint_color_tints_paint_layer() -> void:
	var spec := ship_spec("light_scout").duplicate() as ShipSpec
	spec.paint_texture = PlaceholderTexture2D.new()
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = spec
	ship.paint_color = Color.RED
	tree.root.add_child(ship)
	var paint := ship.get_node("Paint") as Sprite2D
	assert_true(paint.visible)
	assert_eq(paint.modulate, Color.RED)
	ship.queue_free()
	var plain := _spawn("light_scout")
	assert_false((plain.get_node("Paint") as Sprite2D).visible, "no paint texture → hidden")
	plain.queue_free()


func test_lights_levels() -> void:
	var ship := _spawn("light_scout")
	for i in 20:
		var level := ship.lights_level()
		assert_true(level >= 0.3 and level <= 1.0, "waiting level %s" % level)
		await tree.process_frame
	ship.set_driven(true)
	assert_eq(ship.lights_level(), 1.0)
	ship.set_parked()
	assert_eq(ship.lights_level(), 0.25)
	ship.queue_free()


func test_spec_inertia_applied() -> void:
	var spec := _triangle_spec()
	spec.inertia = 321.0
	var ship := _spawn_spec(spec)
	assert_eq(ship.inertia, 321.0)
	ship.queue_free()


func test_swatch_color_matches_what_is_drawn() -> void:
	var placeholder := _spawn("medium_shuttle")
	placeholder.paint_color = Color.GREEN
	assert_eq(placeholder.swatch_color(), Ship.CLASS_COLORS[ShipSpec.ShipClass.MEDIUM], "placeholder shows its class colour")
	placeholder.queue_free()
	var spec := ship_spec("light_scout").duplicate() as ShipSpec
	spec.paint_texture = PlaceholderTexture2D.new()
	var painted: Ship = SHIP_SCENE.instantiate()
	painted.spec = spec
	painted.paint_color = Color.RED
	tree.root.add_child(painted)
	assert_eq(painted.swatch_color(), Color.RED)
	painted.queue_free()


func test_unpark_restores_ship() -> void:
	var ship := _spawn("light_scout")
	ship.set_parked()
	await _frames(2)
	ship.unpark()
	await _frames(2)
	assert_false(ship.is_parked)
	assert_false(ship.freeze)
	assert_eq(ship.modulate, Color.WHITE)
	ship.queue_free()


func test_badge_stays_upright_at_the_lower_left() -> void:
	var ship := _spawn("light_scout")
	var c := Customer.new()
	c.tier = Customer.Tier.GOLD
	ship.customer = c
	ship.rotation = 1.2
	await tree.process_frame
	await tree.process_frame  # process_frame fires before _process runs
	var badge: Node2D = ship.get_node("Badge")
	assert_true(absf(badge.global_rotation) < 0.001, "badge rotation %f" % badge.global_rotation)
	assert_true(badge.global_position.y > ship.global_position.y, "below the ship")
	assert_true(badge.global_position.x < ship.global_position.x, "and to its left")
	ship.queue_free()


func test_faster_driven_ship_pays() -> void:
	var fast := _spawn("light_scout")
	var slow := _spawn("light_scout", Vector2(600, 400))
	fast.is_driven = true
	slow.is_driven = true
	fast._prev_velocity = Vector2(300, 0)
	slow._prev_velocity = Vector2(50, 0)
	assert_true(fast._pays_for_collision_with(slow))
	assert_false(slow._pays_for_collision_with(fast))
	slow._prev_velocity = Vector2(300, 0)  # tie: lower instance id pays
	var low_first := fast.get_instance_id() < slow.get_instance_id()
	assert_eq(fast._pays_for_collision_with(slow), low_first)
	assert_eq(slow._pays_for_collision_with(fast), not low_first)
	fast.is_driven = false
	slow.is_driven = false
	fast.queue_free()
	slow.queue_free()


func test_net_pilot_drives_ship() -> void:
	var ship := _spawn("light_scout")
	var pilot := NetPilot.new()
	pilot.bits = 1 << NetPilot.ACTIONS.find(StringName(Ship.DRIVE_ACTIONS[0]))
	ship.pilot = pilot
	ship.set_driven(true, false)
	await _frames(10)
	assert_true(ship.linear_velocity.length() > 0.0, "net bits thrust the ship")
	ship.queue_free()


func test_remote_drive_keeps_camera() -> void:
	var cam := Camera2D.new()
	tree.root.add_child(cam)
	cam.make_current()
	var ship := _spawn("light_scout")
	ship.set_driven(true, false)
	assert_true(cam.is_current(), "remote drive leaves the camera alone")
	ship.set_driven(false, false)
	ship.queue_free()
	cam.queue_free()


func test_bits_round_trip() -> void:
	assert_true(NetPilot.ACTIONS.size() <= 16)
	var pilot := NetPilot.new()
	pilot.bits = 1 << NetPilot.ACTIONS.find(&"brake")
	assert_true(pilot.is_pressed(&"brake"))
	for a in NetPilot.ACTIONS:
		if a != &"brake":
			assert_false(pilot.is_pressed(a), str(a))


## Gives a ship a mark and a velocity, then takes the start-of-step snapshot a physics frame would.
func _marked(spec_name: String, pos: Vector2, mark: int, velocity: Vector2) -> Ship:
	var ship := _spawn(spec_name, pos)
	ship.last_driver = mark
	ship.linear_velocity = velocity
	ship._physics_process(0.0)
	return ship


func test_driven_ship_marks_struck_ship() -> void:
	var a := _spawn("light_scout", Vector2(-3000, -3000))
	var b := _spawn("light_scout", Vector2(-2000, -3000))
	a.set_driven(true, false)
	a.last_driver = 1
	b.blame_from(a)
	assert_eq(b.last_driver, 1, "the struck ship carries the driver's mark")
	a.blame_from(b)
	assert_eq(a.last_driver, 1, "a driven ship keeps its own mark")
	a.set_driven(false, false)
	a.queue_free()
	b.queue_free()


func test_blame_chain_order_independent() -> void:
	for reverse in [false, true]:
		var x := _marked("light_scout", Vector2(-3000, -5000), 1, Vector2(300, 0))
		var y := _marked("light_scout", Vector2(-2000, -5000), 0, Vector2(10, 0))
		if reverse:
			y.blame_from(x)
			x.blame_from(y)
		else:
			x.blame_from(y)
			y.blame_from(x)
		assert_eq(y.last_driver, 1, "the struck ship takes the hitter's mark (reverse=%s)" % reverse)
		assert_eq(x.last_driver, 1, "the hitter keeps its mark (reverse=%s)" % reverse)
		x.queue_free()
		y.queue_free()


func test_parking_clears_blame() -> void:
	var a := _spawn("light_scout", Vector2(-3000, -3000))
	var b := _spawn("light_scout", Vector2(-2000, -3000))
	b.last_driver = 0
	b.set_parked()
	assert_eq(b.last_driver, -1, "parking clears the mark")
	a.set_driven(true, false)
	a.last_driver = 1
	b.blame_from(a)
	assert_eq(b.last_driver, -1, "a parked ship never takes a mark")
	a.set_driven(false, false)
	a.queue_free()
	b.queue_free()


## Runs both ships' contact handlers (in either order) and returns the ships that reported a dent.
func _collide(a: Ship, b: Ship, reverse: bool) -> Array[Ship]:
	var payers: Array[Ship] = []
	var record := func(s: Ship, _cost: int) -> void: payers.append(s)
	a.dented.connect(record)
	b.dented.connect(record)
	if reverse:
		b._on_body_entered(a)
		a._on_body_entered(b)
	else:
		a._on_body_entered(b)
		b._on_body_entered(a)
	return payers


## An undriven ship k carrying mark k_mark at k_speed meets a ship driven by valet 0 at d_speed.
## Returns [payers, k's mark after], for one handler order.
func _knock_into_driven(k_mark: int, k_speed: float, d_speed: float, reverse: bool) -> Array:
	var k := _marked("light_scout", Vector2(-3000, -7000), k_mark, Vector2(k_speed, 0))
	var d := _marked("light_scout", Vector2(-2000, -7000), 0, Vector2(d_speed, 0))
	d.set_driven(true, false)
	var payers := _collide(k, d, reverse)
	var who := []
	for s in payers:
		who.append("K" if s == k else "D")
	var mark := k.last_driver
	d.set_driven(false, false)
	k.queue_free()
	d.queue_free()
	return [who, mark]


func test_knocked_ship_into_driven_rival_charges_rammer() -> void:
	for reverse in [false, true]:
		var r := _knock_into_driven(1, 300.0, 0.0, reverse)
		assert_eq(r[0], ["K"], "the knocked rammer pays, not the driven victim (reverse=%s)" % reverse)
		assert_eq(r[1], 1, "it keeps the rammer's mark (reverse=%s)" % reverse)


func test_slower_knocked_ship_driven_pays() -> void:
	for reverse in [false, true]:
		var r := _knock_into_driven(1, 0.0, 300.0, reverse)
		assert_eq(r[0], ["D"], "a driven ship that does the hitting pays (reverse=%s)" % reverse)
		assert_eq(r[1], 0, "and marks the struck ship (reverse=%s)" % reverse)


func test_same_valet_mark_driven_pays() -> void:
	for reverse in [false, true]:
		var r := _knock_into_driven(0, 300.0, 0.0, reverse)
		assert_eq(r[0], ["D"], "a ship marked by the driver's own valet: the driver pays (reverse=%s)" % reverse)


func test_unmarked_or_equal_speed_leaves_marks() -> void:
	for reverse in [false, true]:
		var x := _marked("light_scout", Vector2(-3000, -9000), -1, Vector2(300, 0))
		var y := _marked("light_scout", Vector2(-2000, -9000), 0, Vector2(10, 0))
		var p := _marked("light_scout", Vector2(-3000, -11000), 1, Vector2(100, 0))
		var q := _marked("light_scout", Vector2(-2000, -11000), 0, Vector2(0, 100))
		var pairs := [[x, y], [p, q]]
		for pair in pairs:
			var a: Ship = pair[1] if reverse else pair[0]
			var b: Ship = pair[0] if reverse else pair[1]
			a.blame_from(b)
			b.blame_from(a)
		assert_eq([x.last_driver, y.last_driver], [-1, 0], "an unmarked hitter passes nothing on (reverse=%s)" % reverse)
		assert_eq([p.last_driver, q.last_driver], [1, 0], "equal speeds pass nothing on (reverse=%s)" % reverse)
		for s in [x, y, p, q]:
			s.queue_free()
