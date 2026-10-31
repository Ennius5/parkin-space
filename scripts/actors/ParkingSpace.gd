class_name ParkingSpace
extends Node2D
## A valid parking space: a pulsing green rectangle sized for its ship class.

const CLASS_LETTERS := {
	ShipSpec.ShipClass.LIGHT: "L",
	ShipSpec.ShipClass.MEDIUM: "M",
	ShipSpec.ShipClass.HEAVY: "H",
}
const FREE_COLOR := Color(0.3, 1.0, 0.45)
const TAKEN_COLOR := Color(1, 1, 1, 0.6)

@export var space_class: ShipSpec.ShipClass = ShipSpec.ShipClass.MEDIUM
@export var label: String = ""

var occupant: Ship = null

var _pulse := 0.0


func size() -> Vector2:
	return ParkingRules.SPACE_SIZES[space_class]


## True if the ship is fully inside this free space, fits its class, and has come to rest.
func check(ship: Ship) -> bool:
	return ParkingRules.can_credit(
		ship.spec.ship_class,
		space_class,
		occupant != null,
		ParkingRules.points_inside(ship.hull_points(), global_transform, size()),
		ParkingRules.is_settled(ship.linear_velocity.length(), ship.angular_velocity),
	)


func claim(ship: Ship) -> void:
	occupant = ship
	queue_redraw()


func _process(delta: float) -> void:
	if occupant == null:
		_pulse = fmod(_pulse + delta, 1.0)
		queue_redraw()


func _draw() -> void:
	var s := size()
	var color := TAKEN_COLOR
	if occupant == null:
		color = FREE_COLOR
		color.a = lerpf(0.4, 1.0, 0.5 + 0.5 * cos(_pulse * TAU))
	draw_rect(Rect2(-s / 2, s), color, false, 3.0)
	var font := ThemeDB.fallback_font
	var text := "%s %s" % [CLASS_LETTERS[space_class], label]
	var font_size := 28
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2, font_size / 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
