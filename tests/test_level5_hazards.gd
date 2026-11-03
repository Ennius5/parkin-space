extends TestCase
## Level 5's underground-lot hazards: square pillars, radiation in the lanes and a wall hiding the exit.

const LEVEL05 := "res://scenes/levels/Level05.tscn"
const PILLAR_SIZE := Vector2(80, 80)
const CLEARANCE := 40.0  # the least room left between a pillar and any marking on the floor
const ROUTE_WIDTH := 250.0  # room a heavy ship needs to get around the exit wall
const LIT_REACH := 300.0  # a lamp shows solid things clearly up to about here
const TEST_SAVE := "user://test_level5_save.cfg"

var _real_save_path: String


func _body_rect(body: StaticBody2D) -> Rect2:
	var shape := body.get_node("CollisionShape2D") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	return Rect2(body.position - size / 2.0, size)


func _space_rect(space: ParkingSpace) -> Rect2:
	var s := space.size()
	return Rect2(space.position - Vector2(s.y, s.x) / 2.0, Vector2(s.y, s.x))  # every space here lies sideways


func _markings(level: Level) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		rects.append(_space_rect(space))
	rects.append(Rect2(level.get_node("Exit").position - ExitPad.SIZE / 2.0, ExitPad.SIZE))
	rects.append(Rect2(level.get_node("Entrance").position - ArrivalBay.SIZE / 2.0, ArrivalBay.SIZE))
	return rects


func test_level05_has_twelve_square_pillars_clear_of_every_marking() -> void:
	var level: Level = load(LEVEL05).instantiate()
	var pillars := level.get_node("Pillars").get_children()
	assert_eq(pillars.size(), 12)
	for pillar: StaticBody2D in pillars:
		var rect := _body_rect(pillar)
		assert_eq(rect.size, PILLAR_SIZE, pillar.name)
		assert_true(pillar.get_node_or_null("Look") is Polygon2D, "%s can be seen" % pillar.name)
		for marking in _markings(level):
			assert_false(rect.grow(CLEARANCE).intersects(marking), "%s crowds %s" % [pillar.name, marking])
	level.free()


func test_level05_radiation_never_touches_a_marking() -> void:
	var level: Level = load(LEVEL05).instantiate()
	var zones := level.get_node("Radiation").get_children()
	assert_eq(zones.size(), 3)
	for zone: RadiationZone in zones:
		for marking in _markings(level):
			var nearest := zone.position.clamp(marking.position, marking.end)
			assert_true(nearest.distance_to(zone.position) > zone.radius, "%s touches %s" % [zone.name, marking])
	level.free()


func test_level05_exit_cannot_be_reached_in_a_straight_line_from_the_gold_row() -> void:
	var level: Level = load(LEVEL05).instantiate()
	var wall := _body_rect(level.get_node("ExitWall"))
	var exit: Vector2 = level.get_node("Exit").position
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		var blocked := false
		for i in 201:
			blocked = blocked or wall.has_point(space.position.lerp(exit, i / 200.0))
		assert_true(blocked, "%s sees the exit" % space.label)
	level.free()


func test_level05_exit_wall_leaves_a_way_around_both_ends() -> void:
	var level: Level = load(LEVEL05).instantiate()
	var wall := _body_rect(level.get_node("ExitWall"))
	var lot := LotEdge.inner_rect(level.get_node("Walls"))
	assert_true(wall.position.y - lot.position.y >= ROUTE_WIDTH, "top route %s" % wall)
	assert_true(lot.end.y - wall.end.y >= ROUTE_WIDTH, "bottom route %s" % wall)
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		assert_true(wall.position.x - _space_rect(space).end.x >= ROUTE_WIDTH - 20.0, "lane beside %s" % space.label)
	level.free()


func test_level05_pillar_stops_and_dents_a_fast_ship() -> void:
	_real_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE
	GameState.reset_progress()
	var level: Level = load(LEVEL05).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	var ship: Ship = level.get_node("Ships").get_child(0)
	var dents := [0]
	ship.dented.connect(func(_s: Ship, _cost: int) -> void: dents[0] += 1)
	var pillar := level.get_node("Pillars").get_child(0) as StaticBody2D
	ship.freeze = false
	ship.global_position = pillar.position - Vector2(220, 0)
	ship.global_rotation = PI / 2.0
	ship.linear_velocity = Vector2(500, 0)
	for i in 60:
		await tree.physics_frame
	assert_true(ship.global_position.x < pillar.position.x, "stopped short: %s" % ship.global_position)
	assert_true(dents[0] > 0, "the hit dented it")
	level.free()
	GameState.save_path = _real_save_path
	GameState.load_progress()


func test_level05_every_pillar_and_wall_end_sits_under_a_lamp() -> void:
	var level: Level = load(LEVEL05).instantiate()
	var spots: Array[Vector2] = []
	for pillar: StaticBody2D in level.get_node("Pillars").get_children():
		spots.append(pillar.position)
	var wall := _body_rect(level.get_node("ExitWall"))
	spots.append(Vector2(wall.get_center().x, wall.position.y))
	spots.append(Vector2(wall.get_center().x, wall.end.y))
	for spot in spots:
		var nearest := INF
		for lamp: Floodlight in level.get_node("Floodlights").get_children():
			nearest = minf(nearest, lamp.position.distance_to(spot))
		assert_true(nearest <= LIT_REACH, "%s is in the dark (%s from a lamp)" % [spot, nearest])
	level.free()
