class_name ParkingRules
extends RefCounted
## Pure rules for when a ship counts as parked in a space.

const MAX_PARK_SPEED := 10.0  # px/s
const MAX_PARK_SPIN := 0.2  # rad/s
const HOLD_SECONDS := 1.0
const SPACE_SIZES := {
	ShipSpec.ShipClass.LIGHT: Vector2(64, 96),
	ShipSpec.ShipClass.MEDIUM: Vector2(88, 132),
	ShipSpec.ShipClass.HEAVY: Vector2(124, 196),
}


## A ship fits a space of its own class or larger.
static func fits_class(ship_class: int, space_class: int) -> bool:
	return ship_class <= space_class


## True if every global point lies inside the space rectangle centred on space_xform's origin.
static func points_inside(points: PackedVector2Array, space_xform: Transform2D, space_size: Vector2) -> bool:
	var to_local := space_xform.affine_inverse()
	var rect := Rect2(-space_size / 2, space_size)
	for p in points:
		if not rect.has_point(to_local * p):
			return false
	return true


static func is_settled(linear_speed: float, angular_speed: float) -> bool:
	return linear_speed < MAX_PARK_SPEED and absf(angular_speed) < MAX_PARK_SPIN


static func can_credit(ship_class: int, space_class: int, occupied: bool, points_ok: bool, settled: bool) -> bool:
	return fits_class(ship_class, space_class) and not occupied and points_ok and settled
