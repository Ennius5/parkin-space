extends TestCase


func test_fits_own_class_or_larger() -> void:
	assert_true(ParkingRules.fits_class(0, 0))
	assert_true(ParkingRules.fits_class(0, 2))
	assert_true(ParkingRules.fits_class(1, 2))
	assert_false(ParkingRules.fits_class(2, 1))
	assert_false(ParkingRules.fits_class(1, 0))


func test_points_inside_rotated_space() -> void:
	var xform := Transform2D(PI / 4, Vector2(500, 300))
	var size := Vector2(88, 132)
	var center := Vector2(500, 300)
	var inside := PackedVector2Array([center, center + Vector2(0, -50).rotated(PI / 4)])
	assert_true(ParkingRules.points_inside(inside, xform, size))
	var outside := inside.duplicate()
	outside.append(center + Vector2(0, -80).rotated(PI / 4))
	assert_false(ParkingRules.points_inside(outside, xform, size))


func test_half_in_is_not_inside() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 60)])
	assert_false(ParkingRules.points_inside(pts, Transform2D.IDENTITY, Vector2(64, 96)))


func test_settled_thresholds() -> void:
	assert_true(ParkingRules.is_settled(9.9, 0.19))
	assert_false(ParkingRules.is_settled(10.1, 0.0))
	assert_false(ParkingRules.is_settled(0.0, -0.3))


func test_occupied_or_too_small_never_credits() -> void:
	assert_false(ParkingRules.can_credit(0, 1, true, true, true))
	assert_false(ParkingRules.can_credit(2, 1, false, true, true))
	assert_true(ParkingRules.can_credit(1, 1, false, true, true))


func test_tracker_needs_full_hold() -> void:
	var t := ParkTracker.new()
	assert_false(t.update(0.5, true))
	assert_true(t.update(0.6, true))
	assert_false(t.update(0.5, true), "fires only once")


func test_tracker_resets_when_leaving() -> void:
	var t := ParkTracker.new()
	assert_false(t.update(0.9, true))
	assert_false(t.update(0.016, false))
	assert_false(t.update(0.5, true))


func test_spec_resources_load() -> void:
	var expected := {
		"light_scout": [ShipSpec.ShipClass.LIGHT, Vector2(40, 64)],
		"medium_shuttle": [ShipSpec.ShipClass.MEDIUM, Vector2(60, 100)],
		"heavy_freighter": [ShipSpec.ShipClass.HEAVY, Vector2(90, 160)],
	}
	for key in expected:
		var spec := load("res://resources/ships/%s.tres" % key) as ShipSpec
		assert_true(spec != null, key)
		if spec:
			assert_eq(spec.ship_class, expected[key][0], key)
			assert_eq(spec.hull_size, expected[key][1], key)


func test_fits_lot_counts_bigger_spaces() -> void:
	var L := ShipSpec.ShipClass.LIGHT
	var M := ShipSpec.ShipClass.MEDIUM
	var H := ShipSpec.ShipClass.HEAVY
	assert_true(ParkingRules.fits_lot([H, M] as Array[int], [H, M] as Array[int]))
	assert_true(ParkingRules.fits_lot([M, M] as Array[int], [H, M] as Array[int]))
	assert_false(ParkingRules.fits_lot([H, H] as Array[int], [H, M] as Array[int]))
	assert_false(ParkingRules.fits_lot([L, L, L] as Array[int], [M, L] as Array[int]))
