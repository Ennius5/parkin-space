extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")


func _ship(pos: Vector2) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec("light_scout")
	ship.position = pos
	ship.freeze = true
	tree.root.add_child(ship)
	return ship


func test_touches_any_part_of_a_ship() -> void:
	var bay := ArrivalBay.new()
	bay.position = Vector2(300, 300)
	tree.root.add_child(bay)
	var ship := _ship(Vector2(300, 300))
	assert_true(bay.touches(ship))
	ship.position = Vector2(300, 300 + ArrivalBay.SIZE.y / 2 + 20)  # centre outside, nose still inside
	assert_true(bay.touches(ship))
	ship.position = Vector2(300, 700)
	assert_false(bay.touches(ship))
	ship.queue_free()
	bay.queue_free()


func test_bay_fits_the_biggest_space() -> void:
	var heavy: Vector2 = ParkingRules.SPACE_SIZES[ShipSpec.ShipClass.HEAVY]
	assert_true(ArrivalBay.SIZE.x >= heavy.x and ArrivalBay.SIZE.y >= heavy.y)
