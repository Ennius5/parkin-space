extends TestCase

const PICKER_SCENE := preload("res://scenes/ui/ShipPicker.tscn")
const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")


func _ship(spec_name: String, paint: Color, pos: Vector2) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = load("res://resources/ships/%s.tres" % spec_name)
	ship.paint_color = paint
	ship.position = pos
	ship.freeze = true
	tree.root.add_child(ship)
	return ship


func test_rows_show_number_name_class_and_paint() -> void:
	var picker: ShipPicker = PICKER_SCENE.instantiate()
	tree.root.add_child(picker)
	var a := _ship("ManipulatorDrone", Color.RED, Vector2(300, 300))
	var b := _ship("medium_shuttle", Color.BLUE, Vector2(360, 300))
	var ships: Array[Ship] = [a, b]
	picker.open(ships, Vector2(320, 300))
	assert_true(picker.is_open())
	var rows := picker.rows()
	assert_eq(rows.size(), 2)
	if rows.size() == 2:
		assert_true(rows[0].text.contains("1") and rows[0].text.contains("Manipulator Drone") and rows[0].text.contains("L"), rows[0].text)
		assert_true(rows[1].text.contains("2") and rows[1].text.contains("Shuttle") and rows[1].text.contains("M"), rows[1].text)
		assert_eq(picker.swatch_color(0), Color.RED)
	picker.queue_free()
	a.queue_free()
	b.queue_free()


func test_pressing_a_row_emits_picked() -> void:
	var picker: ShipPicker = PICKER_SCENE.instantiate()
	tree.root.add_child(picker)
	var a := _ship("light_scout", Color.RED, Vector2(300, 300))
	var b := _ship("light_scout", Color.GREEN, Vector2(360, 300))
	var ships: Array[Ship] = [a, b]
	var got: Array[Ship] = []
	picker.picked.connect(func(s: Ship) -> void: got.append(s))
	picker.open(ships, Vector2(320, 300))
	picker.rows()[1].pressed.emit()
	assert_eq(got, [b] as Array[Ship])
	picker.queue_free()
	a.queue_free()
	b.queue_free()


func test_panel_stays_on_screen() -> void:
	var picker: ShipPicker = PICKER_SCENE.instantiate()
	tree.root.add_child(picker)
	var a := _ship("light_scout", Color.RED, Vector2(300, 300))
	var b := _ship("light_scout", Color.GREEN, Vector2(360, 300))
	var ships: Array[Ship] = [a, b]
	var view := Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
	picker.open(ships, view.size - Vector2(5, 5))  # bottom-right corner
	await tree.process_frame
	var rect := picker.panel_rect()
	assert_true(view.encloses(rect), "panel %s inside %s" % [rect, view])
	picker.close()
	assert_false(picker.is_open())
	picker.queue_free()
	a.queue_free()
	b.queue_free()


func test_badges_spread_out_and_panel_clears_them() -> void:
	var picker: ShipPicker = PICKER_SCENE.instantiate()
	tree.root.add_child(picker)
	var a := _ship("light_scout", Color.RED, Vector2(400, 300))
	var b := _ship("light_scout", Color.GREEN, Vector2(402, 300))  # almost on top of each other
	var c := _ship("light_scout", Color.BLUE, Vector2(404, 300))
	var ships: Array[Ship] = [a, b, c]
	var tap := a.get_global_transform_with_canvas().origin
	picker.open(ships, tap)
	await tree.process_frame
	var spots := picker.badge_spots()
	assert_eq(spots.size(), 3)
	for i in 3:
		for j in range(i + 1, 3):
			assert_true(spots[i].distance_to(spots[j]) > ShipPicker.BADGE_RADIUS * 2.0, "badges %d and %d overlap" % [i, j])
	var rect := picker.panel_rect()
	for s in spots:
		assert_false(rect.grow(ShipPicker.BADGE_RADIUS).has_point(s), "panel covers badge at %s" % s)
	picker.queue_free()
	a.queue_free()
	b.queue_free()
	c.queue_free()


func test_picker_row_shows_tier_coin() -> void:
	var picker: ShipPicker = PICKER_SCENE.instantiate()
	tree.root.add_child(picker)
	var a := _ship("light_scout", Color.RED, Vector2(300, 300))
	var b := _ship("light_scout", Color.GREEN, Vector2(360, 300))
	var gold := Customer.new()
	gold.tier = Customer.Tier.GOLD
	a.customer = gold
	var ships: Array[Ship] = [a, b]
	picker.open(ships, Vector2(320, 300))
	assert_eq(picker.coin_color(0), Color(1, 0.82, 0.2))
	assert_eq(picker.coin_color(1), Color.TRANSPARENT)
	picker.queue_free()
	a.queue_free()
	b.queue_free()
