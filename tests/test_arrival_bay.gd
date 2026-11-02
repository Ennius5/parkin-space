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


func test_asteroid_in_the_bay_blocks_it() -> void:
	var bay := ArrivalBay.new()
	bay.position = Vector2(300, 300)
	tree.root.add_child(bay)
	var img := Image.create(100, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var rock := Asteroid.new()
	rock.texture = ImageTexture.create_from_image(img)
	rock.drift_speed = 0.0
	rock.freeze = true
	rock.position = Vector2(300, 300)
	tree.root.add_child(rock)
	var bodies: Array[Node] = [rock]
	assert_false(bay.is_clear(bodies))
	rock.position = Vector2(300, 700)
	assert_true(bay.is_clear(bodies))
	rock.queue_free()
	bay.queue_free()
