extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const ACTIONS := ["thrust_forward", "thrust_back", "strafe_left", "strafe_right", "rotate_left", "rotate_right"]


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


func test_soft_bump_no_dent() -> void:
	var costs := await _ram_wall(80.0)
	assert_eq(costs.size(), 0, "costs=%s" % [costs])
