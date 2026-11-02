extends TestCase


func test_pull_grows_closer_in() -> void:
	assert_almost(BlackHole.pull_at(300.0), 20.0, 0.01)
	assert_almost(BlackHole.pull_at(950.0), 1.994, 0.05)
	assert_eq(BlackHole.pull_at(150.0), 80.0)
	assert_eq(BlackHole.pull_at(40.0), 80.0)


func test_pull_is_capped_and_safe_at_the_centre() -> void:
	assert_eq(BlackHole.pull_at(0.0), 80.0)
	var hole := BlackHole.new()
	hole.position = Vector2(500, 500)
	tree.root.add_child(hole)
	assert_eq(hole.pull_on(Vector2(500, 500)), Vector2.ZERO)
	assert_true(hole.pull_on(Vector2(800, 500)).distance_to(Vector2(-20, 0)) < 0.01)
	hole.queue_free()


func test_core_is_not_solid() -> void:
	var hole := BlackHole.new()
	tree.root.add_child(hole)
	for child in hole.get_children():
		assert_false(child is CollisionShape2D or child is CollisionPolygon2D, "ships pass into the core")
	hole.queue_free()


func test_hole_ignores_the_dark() -> void:
	var hole := BlackHole.new()
	tree.root.add_child(hole)
	var m := hole.material as CanvasItemMaterial
	assert_true(m != null and m.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
	hole.queue_free()
