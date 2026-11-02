extends TestCase


func test_outline_of_a_solid_rectangle_is_centred_and_scaled() -> void:
	var img := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var poly := SpriteOutline.outline(ImageTexture.create_from_image(img), 2.0)
	assert_true(poly.size() >= 4)
	if poly.is_empty():
		return
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	assert_true(box.position.distance_to(Vector2(-20, -10)) < 2.5, str(box))
	assert_true(box.end.distance_to(Vector2(20, 10)) < 2.5, str(box))
