extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")


## A solid 100 x 60 block, standing in for a Kenney sprite.
func _block_texture() -> Texture2D:
	var img := Image.create(100, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _polygon_of(body: Node) -> PackedVector2Array:
	for child in body.get_children():
		if child is CollisionPolygon2D:
			return (child as CollisionPolygon2D).polygon
	return PackedVector2Array()


func _asteroid(pos: Vector2, drift := 0.0) -> Asteroid:
	var rock := Asteroid.new()
	rock.texture = _block_texture()
	rock.drift_speed = drift
	rock.position = pos
	tree.root.add_child(rock)
	return rock


func test_wreck_collides_with_its_sprite_outline() -> void:
	var wreck := Wreck.new()
	wreck.texture = _block_texture()
	tree.root.add_child(wreck)
	var poly := _polygon_of(wreck)
	assert_true(poly.size() >= 3)
	var box := Rect2(poly[0], Vector2.ZERO) if poly.size() > 0 else Rect2()
	for p in poly:
		box = box.expand(p)
	assert_true(box.size.x > 60.0, "width %s" % box.size.x)
	wreck.queue_free()


func test_asteroid_is_shoveable_and_drifts() -> void:
	var rock := _asteroid(Vector2(300, 300), 25.0)
	assert_eq(rock.mass, Asteroid.MASS)
	assert_true(_polygon_of(rock).size() >= 3)
	assert_almost(rock.linear_velocity.length(), 25.0, 0.5)
	rock.queue_free()


func test_asteroid_hull_points_follow_it() -> void:
	var rock := _asteroid(Vector2(500, 400))
	var pts := rock.hull_points()
	assert_true(pts.size() >= 4)
	for p in pts:
		assert_true(p.distance_to(Vector2(500, 400)) < 60.0, str(p))
	assert_eq(pts[pts.size() - 1], Vector2(500, 400))
	rock.queue_free()


func test_ship_hitting_an_asteroid_hard_dents() -> void:
	var rock := _asteroid(Vector2(200, 200))
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec("light_scout")
	ship.position = Vector2(200, 380)
	tree.root.add_child(ship)
	var costs: Array[int] = []
	ship.dented.connect(func(_s: Ship, cost: int) -> void: costs.append(cost))
	ship.linear_velocity = Vector2(0, -400)
	for i in 60:
		await tree.physics_frame
	assert_true(costs.size() >= 1, "costs=%s" % [costs])
	ship.queue_free()
	rock.queue_free()
