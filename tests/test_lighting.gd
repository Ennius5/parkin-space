extends TestCase

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const LEVELS := ["res://scenes/levels/Level01.tscn", "res://scenes/levels/Level02.tscn", "res://scenes/levels/Level03.tscn", "res://scenes/levels/Level04.tscn"]


func _is_unlit(item: CanvasItem) -> bool:
	var m := item.material as CanvasItemMaterial
	return m != null and m.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED


func _floodlights(level: Node) -> Array[Floodlight]:
	var lights: Array[Floodlight] = []
	for child in level.get_node("Floodlights").get_children():
		lights.append(child as Floodlight)
	return lights


func test_space_beyond_the_lot_is_black() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"), Color.BLACK)


func test_floodlight_reaches_its_radius() -> void:
	var flood := Floodlight.new()
	flood.radius = 300.0
	tree.root.add_child(flood)
	assert_true(flood.texture != null)
	assert_almost(flood.texture_scale * Lighting.TEXTURE_SIZE / 2.0, 300.0, 0.01)
	flood.queue_free()


func test_steady_floodlight_never_flickers() -> void:
	var flood := Floodlight.new()
	flood.strength = 1.5
	for i in 200:
		assert_eq(flood.energy_at(i * 0.05), 1.5)
	flood.free()


func test_flickering_floodlight_dips_now_and_then() -> void:
	var flood := Floodlight.new()
	flood.strength = 1.5
	flood.flicker = true
	var dips := 0
	for i in 400:  # 20 s
		var e := flood.energy_at(i * 0.05)
		assert_true(e >= 0.0 and e <= 1.5)
		if e < 1.0:
			dips += 1
	assert_true(dips > 0, "it dips")
	assert_true(dips < 200, "but is mostly on: %d" % dips)
	flood.free()


func test_ships_carry_a_headlight_and_a_glow() -> void:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec("light_scout")
	ship.freeze = true
	tree.root.add_child(ship)
	var head := ship.get_node_or_null("Headlight") as PointLight2D
	var glow := ship.get_node_or_null("Glow") as PointLight2D
	assert_true(head != null and glow != null)
	if head and glow:
		assert_true(head.position.y < 0.0, "the headlight shines ahead")
		assert_almost(glow.texture_scale, maxf(ship.spec.hull_size.x, ship.spec.hull_size.y) / Lighting.TEXTURE_SIZE * Ship.GLOW_SCALE, 0.001)
	assert_true(_is_unlit(ship.get_node("Badge")), "the tier coin is always readable")
	assert_true(_is_unlit(ship.get_node("RequestGlow")), "the wanted-back glow is always readable")
	ship.queue_free()


func test_markers_ignore_the_dark() -> void:
	var space: ParkingSpace = load("res://scenes/actors/ParkingSpace.tscn").instantiate()
	var exit: ExitPad = load("res://scenes/actors/ExitPad.tscn").instantiate()
	var zone := RadiationZone.new()
	var bay := ArrivalBay.new()
	for item: CanvasItem in [space, exit, zone, bay]:
		tree.root.add_child(item)
		assert_true(_is_unlit(item), item.get_class())
		item.queue_free()


func test_every_level_is_dark() -> void:
	for path in LEVELS:
		var level: Level = load(path).instantiate()
		level.change_scene_on_end = false
		tree.root.add_child(level)
		await tree.process_frame
		var dark := level.get_node_or_null("Darkness") as CanvasModulate
		assert_true(dark != null and dark.color == Color.BLACK, path)
		level.free()


func test_floodlights_light_every_space() -> void:
	for path in LEVELS:
		var level: Level = load(path).instantiate()
		var lights := _floodlights(level)
		assert_true(lights.size() >= 4, "%s has floodlights" % path)
		for space: ParkingSpace in level.get_node("Spaces").get_children():
			var lit := false
			for flood in lights:
				lit = lit or flood.position.distance_to(space.position) <= flood.radius * 0.75
			assert_true(lit, "%s %s is under a floodlight" % [path, space.label])
		level.free()


func test_level01_has_strong_floodlights_and_two_flicker() -> void:
	var level: Level = load(LEVELS[0]).instantiate()
	var flickering := 0
	for flood in _floodlights(level):
		assert_true(flood.strength >= 1.8, "strong")
		if flood.flicker:
			flickering += 1
	assert_eq(flickering, 2)
	level.free()
