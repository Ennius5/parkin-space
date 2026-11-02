extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")


func test_zone_touches_any_part_of_a_ship() -> void:
	var zone := RadiationZone.new()
	zone.position = Vector2(300, 300)
	zone.radius = 110.0
	tree.root.add_child(zone)
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec("light_scout")
	ship.freeze = true
	ship.position = Vector2(300, 300)
	tree.root.add_child(ship)
	assert_true(zone.touches(ship))
	ship.position = Vector2(300, 300 + 110 + 20)  # centre outside, nose (32 px ahead) still inside
	assert_true(zone.touches(ship))
	ship.position = Vector2(800, 300)
	assert_false(zone.touches(ship))
	ship.queue_free()
	zone.queue_free()
