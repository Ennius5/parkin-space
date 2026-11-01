extends TestCase

const SHIPS := ["light_scout", "medium_shuttle", "heavy_freighter"]


func _thruster(pos: Vector2, dir: Vector2, force: float, actions: PackedStringArray = []) -> ThrusterSpec:
	var t := ThrusterSpec.new()
	t.position = pos
	t.direction = dir
	t.force = force
	t.actions = actions
	return t


## Net force and torque of every thruster that fires for one action.
func _sum(spec: ShipSpec, action: String) -> Dictionary:
	var force := Vector2.ZERO
	var torque := 0.0
	for t in spec.thrusters:
		if t.fires_for(PackedStringArray([action])):
			force += t.push()
			torque += t.torque_about(spec.center_of_mass)
	return {"force": force, "torque": torque}


func test_torque_about_origin() -> void:
	var t := _thruster(Vector2(-20, -28), Vector2(1, 0), 16.0)
	assert_almost(t.torque_about(Vector2.ZERO), 448.0, 0.01)


func test_torque_about_offset_com() -> void:
	var t := _thruster(Vector2(-20, -28), Vector2(1, 0), 16.0)
	assert_almost(t.torque_about(Vector2(0, 20)), 768.0, 0.01)


func test_push_along() -> void:
	var t := _thruster(Vector2.ZERO, Vector2(0, 1), 90.0)
	assert_almost(t.push_along(Vector2(0, 1)), 90.0, 0.01)
	assert_almost(t.push_along(Vector2(0, -1)), 0.0, 0.01)
	assert_almost(t.push_along(Vector2(1, 0)), 0.0, 0.01)
	var sloppy := _thruster(Vector2.ZERO, Vector2(0, 5), 90.0)
	assert_almost(sloppy.push_along(Vector2(0, 1)), 90.0, 0.01, "direction is normalised")
	assert_almost(sloppy.push().length(), 90.0, 0.01)


func test_fires_for() -> void:
	var t := _thruster(Vector2.ZERO, Vector2(0, 1), 90.0, ["thrust_back"])
	assert_true(t.fires_for(PackedStringArray(["thrust_back", "rotate_left"])))
	assert_false(t.fires_for(PackedStringArray(["thrust_forward"])))


func test_layout_quirks() -> void:
	for ship_name in SHIPS:
		var spec := load("res://resources/ships/%s.tres" % ship_name) as ShipSpec
		assert_true(spec.thrusters.size() > 0, ship_name)
		var fwd := _sum(spec, "thrust_forward")
		assert_true(fwd["force"].y < 0.0, "%s forward pushes nose-first" % ship_name)
		assert_almost(fwd["torque"], 0.0, 0.01, "%s forward is balanced" % ship_name)
		assert_true(_sum(spec, "rotate_right")["torque"] > 0.0, ship_name)
		assert_true(_sum(spec, "rotate_left")["torque"] < 0.0, ship_name)
		var strafe_torque: float = _sum(spec, "strafe_right")["torque"]
		if ship_name == "light_scout":
			assert_almost(strafe_torque, 0.0, 0.01, "scout strafes cleanly")
		else:
			assert_true(absf(strafe_torque) > 100.0, "%s strafe twists: %s" % [ship_name, strafe_torque])
	var shuttle := load("res://resources/ships/medium_shuttle.tres") as ShipSpec
	var back: float = _sum(shuttle, "thrust_back")["force"].length()
	var forward: float = _sum(shuttle, "thrust_forward")["force"].length()
	assert_true(back < 0.4 * forward, "shuttle retro is weak: %s vs %s" % [back, forward])
	var freighter := load("res://resources/ships/heavy_freighter.tres") as ShipSpec
	assert_eq(freighter.center_of_mass, Vector2(0, 20))
