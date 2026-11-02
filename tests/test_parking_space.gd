extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const SPACE_SCENE := preload("res://scenes/actors/ParkingSpace.tscn")

var _nodes: Array[Node] = []


func _space(space_class: ShipSpec.ShipClass, pos := Vector2(300, 300)) -> ParkingSpace:
	var space: ParkingSpace = SPACE_SCENE.instantiate()
	space.space_class = space_class
	space.position = pos
	tree.root.add_child(space)
	_nodes.append(space)
	return space


func _ship(spec_name: String, pos := Vector2(300, 300), frozen := true) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec(spec_name)
	ship.position = pos
	ship.freeze = frozen
	tree.root.add_child(ship)
	_nodes.append(ship)
	return ship


func _cleanup() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()


func test_centered_still_ship_passes() -> void:
	var space := _space(ShipSpec.ShipClass.MEDIUM)
	assert_true(space.check(_ship("medium_shuttle")))
	_cleanup()


func test_light_ship_in_heavy_space_passes() -> void:
	var space := _space(ShipSpec.ShipClass.HEAVY)
	assert_true(space.check(_ship("light_scout")))
	_cleanup()


func test_heavy_ship_in_light_space_fails() -> void:
	var space := _space(ShipSpec.ShipClass.LIGHT)
	assert_false(space.check(_ship("heavy_freighter")))
	_cleanup()


func test_claimed_space_rejects_second_ship() -> void:
	var space := _space(ShipSpec.ShipClass.MEDIUM)
	var ship_a := _ship("medium_shuttle")
	space.claim(ship_a)
	assert_eq(space.occupant, ship_a)
	assert_false(space.check(_ship("light_scout")))
	_cleanup()


func test_moving_ship_fails() -> void:
	var space := _space(ShipSpec.ShipClass.MEDIUM)
	var ship := _ship("light_scout", Vector2(300, 300), false)
	ship.linear_velocity = Vector2(30, 0)
	assert_false(space.check(ship))
	_cleanup()


func test_size_matches_class() -> void:
	var space := _space(ShipSpec.ShipClass.HEAVY)
	assert_eq(space.size(), Vector2(124, 196))
	_cleanup()


func test_gold_space_flag_and_release() -> void:
	var space := _space(ShipSpec.ShipClass.MEDIUM)
	space.gold = true
	var ship := _ship("medium_shuttle")
	space.claim(ship)
	assert_eq(space.occupant, ship)
	space.release()
	assert_eq(space.occupant, null)
	_cleanup()


func test_touches_partial_overlap() -> void:
	var space := _space(ShipSpec.ShipClass.MEDIUM)
	var ship := _ship("medium_shuttle", Vector2(300, 300 + 100))  # spans y 350-450; the space ends at 366
	assert_true(space.touches(ship))
	assert_false(space.check(ship))
	ship.position = Vector2(300, 900)
	assert_false(space.touches(ship))
	_cleanup()


func test_pin_shows_and_clears() -> void:
	var space: ParkingSpace = load("res://scenes/actors/ParkingSpace.tscn").instantiate()
	tree.root.add_child(space)
	space.set_pin(Color.GOLD)
	assert_true(space.pin_color.a > 0.0)
	space.clear_pin()
	assert_eq(space.pin_color.a, 0.0)
	space.queue_free()


func test_pin_sits_outside_the_space_above_ships() -> void:
	var space: ParkingSpace = load("res://scenes/actors/ParkingSpace.tscn").instantiate()
	tree.root.add_child(space)
	space.set_pin(Color.GOLD)
	var pin := space.get_node_or_null("Pin") as Node2D
	assert_true(pin != null)
	if pin:
		assert_true(pin.z_index > 0, "drawn above parked ships")
		assert_false(Rect2(-space.size() / 2, space.size()).has_point(pin.position), "outside the space, not under its occupant")
	space.queue_free()
