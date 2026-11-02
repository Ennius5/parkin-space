extends TestCase

const DUEL := "res://scenes/levels/Duel.tscn"
const TEST_SAVE := "user://test_duel_save.cfg"


var _real_save := ""


## Adds a duel to the tree (members such as space pins are only parented in _ready, so a level
## freed outside the tree would leak them).
func _duel(minutes := 3) -> DuelLevel:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	var level: DuelLevel = load(DUEL).instantiate()
	level.minutes = minutes
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done(level: DuelLevel) -> void:
	level.free()
	GameState.save_path = _real_save


## Mean of a pillar's visual polygon, in lot coordinates.
func _centroid(pillar: Node2D) -> Vector2:
	var poly := pillar.get_node("Polygon2D") as Polygon2D
	var sum := Vector2.ZERO
	for p in poly.polygon:
		sum += p
	return pillar.position + sum / poly.polygon.size()


func test_duel_lot_layout() -> void:
	var level := await _duel()
	var spaces := level.get_node("Spaces").get_children()
	assert_eq(spaces.size(), 22)
	var light := 0
	var medium := 0
	var heavy := 0
	var gold := 0
	for space: ParkingSpace in spaces:
		if space.gold:
			gold += 1
			assert_eq(space.space_class, ShipSpec.ShipClass.MEDIUM)
			continue
		match space.space_class:
			ShipSpec.ShipClass.LIGHT: light += 1
			ShipSpec.ShipClass.MEDIUM: medium += 1
			ShipSpec.ShipClass.HEAVY: heavy += 1
	assert_eq(light, 8)
	assert_eq(medium, 8)
	assert_eq(heavy, 4)
	assert_eq(gold, 2)
	for k in range(1, 12):
		var left := level.get_node("Spaces/L%d" % k) as ParkingSpace
		var right := level.get_node("Spaces/R%d" % k) as ParkingSpace
		assert_true(left != null and right != null, "L%d and R%d exist" % [k, k])
		if left == null or right == null:
			continue
		assert_true(left.position.distance_to(Vector2(2400 - right.position.x, right.position.y)) <= 1.0,
				"R%d mirrors L%d" % [k, k])
		assert_eq(left.space_class, right.space_class)
		assert_eq(left.gold, right.gold)
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	assert_true(level.get_node_or_null("Entrance") is Marker2D)
	assert_true(level.get_node("Pillars").get_child_count() >= 5)
	_done(level)


func test_duel_pillars_mirrored() -> void:
	var level := await _duel()
	var centroids: Array[Vector2] = []
	for pillar: Node2D in level.get_node("Pillars").get_children():
		centroids.append(_centroid(pillar))
	for c in centroids:
		var mirrored := Vector2(2400 - c.x, c.y)
		var found := false
		for other in centroids:
			if other.distance_to(mirrored) <= 2.0:
				found = true
		assert_true(found, "pillar at %s has a mirrored partner" % c)
	_done(level)


func test_duel_queue_follows_minutes() -> void:
	var level := await _duel(4)
	assert_eq(level.customer_queue.size(), GameState.duel_customers(4))
	assert_true(level.ledger.endless)
	assert_almost(level.ledger.time_left, 240.0, 0.5)
	_done(level)


## A node's rectangle of the given size, as lot-space corners.
func _corners(node: Node2D, size: Vector2) -> PackedVector2Array:
	var xf := node.transform
	return PackedVector2Array([xf * (-size / 2), xf * Vector2(size.x / 2, -size.y / 2),
			xf * (size / 2), xf * Vector2(-size.x / 2, size.y / 2)])


func _world_polygon(pillar: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in (pillar.get_node("Polygon2D") as Polygon2D).polygon:
		points.append(pillar.position + p)
	return points


func test_duel_pillars_block_straight_route() -> void:
	var level := await _duel()
	var route := PackedVector2Array([level.get_node("Entrance").position, level.get_node("Exit").position])
	var blocked := false
	for pillar: Node2D in level.get_node("Pillars").get_children():
		if not Geometry2D.intersect_polyline_with_polygon(route, _world_polygon(pillar)).is_empty():
			blocked = true
	assert_true(blocked, "a pillar stands between the entrance and the exit")
	_done(level)


func test_duel_layout_clear_of_hud() -> void:
	var level := await _duel()
	var rects := {}  # name -> corners
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		rects[space.name] = _corners(space, space.size())
	rects["bay"] = _corners(level.get_node("Entrance"), ArrivalBay.SIZE)
	rects["exit"] = _corners(level.get_node("Exit"), ExitPad.SIZE)
	for key: String in rects:
		for p: Vector2 in rects[key]:
			assert_true(p.y >= 300.0 - 0.5 and p.y <= 1320.0 + 0.5, "%s stays clear of the HUD (y %.0f)" % [key, p.y])
	_done(level)
