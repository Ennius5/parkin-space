extends TestCase
## World text (space labels, ARRIVALS, EXIT, ship badges) always reads level on screen.

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")


func _screen_angle(item: CanvasItem) -> float:
	return item.get_global_transform_with_canvas().get_rotation()


## A world with a camera turned by camera_angle, so on-screen angles include the camera's turn.
func _world(camera_angle: float) -> Node2D:
	var world := Node2D.new()
	tree.root.add_child(world)
	var cam := Camera2D.new()
	cam.ignore_rotation = false
	cam.rotation = camera_angle
	world.add_child(cam)
	cam.make_current()
	return world


func test_upright_cancels_rotation() -> void:
	var world := _world(0.0)
	var n := Node2D.new()
	n.rotation = PI / 2
	world.add_child(n)
	await tree.process_frame
	assert_almost(Upright.angle(n), -PI / 2, 0.001)
	world.free()


func test_space_label_reads_level() -> void:
	for cam_angle in [0.0, 1.0]:
		var world := _world(cam_angle)
		var space: ParkingSpace = load("res://scenes/actors/ParkingSpace.tscn").instantiate()
		space.rotation = PI / 2
		world.add_child(space)
		await tree.process_frame
		assert_almost(wrapf(_screen_angle(space) + space.label_angle(), -PI, PI), 0.0, 0.001, "camera %s" % cam_angle)
		space.set_pin(Color.GOLD)
		await tree.process_frame
		assert_almost(wrapf(_screen_angle(space.get_node("Pin")), -PI, PI), 0.0, 0.001, "pin, camera %s" % cam_angle)
		world.free()


func test_bay_and_exit_labels_read_level() -> void:
	var world := _world(0.7)
	var bay := ArrivalBay.new()
	bay.rotation = PI / 2
	world.add_child(bay)
	var exit: ExitPad = load("res://scenes/actors/ExitPad.tscn").instantiate()
	world.add_child(exit)
	await tree.process_frame
	assert_almost(wrapf(_screen_angle(bay) + bay.label_angle(), -PI, PI), 0.0, 0.001)
	assert_almost(wrapf(_screen_angle(exit) + exit.label_angle(), -PI, PI), 0.0, 0.001)
	world.free()


func test_ship_badge_reads_level_under_a_turning_camera() -> void:
	var world := _world(1.2)
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = ship_spec("light_scout")
	ship.freeze = true
	ship.rotation = 0.5
	world.add_child(ship)
	await tree.process_frame
	await tree.process_frame
	assert_almost(wrapf(_screen_angle(ship.get_node("Badge")), -PI, PI), 0.0, 0.001)
	world.free()
