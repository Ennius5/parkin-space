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
const READY_COLOR := Color(1.0, 0.6, 0.15)  # the driven ship may park here: press Done

@export var space_class: ShipSpec.ShipClass = ShipSpec.ShipClass.MEDIUM
@export var label: String = ""
@export var gold := false  # gold customers only tip when parked in a gold space

var occupant: Ship = null
var ready_for: Ship = null  # the driven ship that would park here if Done were pressed now
var pin_color := Color(0, 0, 0, 0)  # a special request marker; transparent = none

var _pulse := 0.0
var _pin := Node2D.new()



func _ready() -> void:
	material = Lighting.unlit()  # a marking, always readable in the dark
	_pin.name = "Pin"
	_pin.z_index = 5  # above parked ships, which would hide it
	_pin.material = Lighting.unlit()
	_pin.position = Vector2(0, -(size().y / 2 + 26))  # just past the space's end, in the lane
	_pin.draw.connect(_draw_pin)
	add_child(_pin)


func size() -> Vector2:
	return ParkingRules.SPACE_SIZES[space_class]


## True if the ship is fully inside this space (free, or already held for this ship), fits its
## class, and has come to rest.
func check(ship: Ship) -> bool:
	return ParkingRules.can_credit(
		ship.spec.ship_class,
		space_class,
		occupant != null and occupant != ship,
		ParkingRules.points_inside(ship.hull_points(), global_transform, size()),
		ParkingRules.is_settled(ship.linear_velocity.length(), ship.angular_velocity),
	)


func claim(ship: Ship) -> void:
	occupant = ship
	queue_redraw()


func release() -> void:
	occupant = null
	queue_redraw()


## True while any part of the ship is still inside the space.
func touches(ship: Ship) -> bool:
	var to_local := global_transform.affine_inverse()
	var rect := Rect2(-size() / 2, size())
	for p in ship.hull_points():
		if rect.has_point(to_local * p):
			return true
	return false


func _process(delta: float) -> void:
	if occupant == null:
		_pulse = fmod(_pulse + delta, 1.0)
	queue_redraw()  # the label re-levels as the camera turns
	_pin.rotation = 0.0
	_pin.rotation = Upright.angle(_pin)


func _draw() -> void:
	var s := size()
	var color := TAKEN_COLOR
	if ready_for != null:
		color = READY_COLOR
	elif occupant == null:
		color = FREE_COLOR
		color.a = lerpf(0.4, 1.0, 0.5 + 0.5 * cos(_pulse * TAU))
	draw_rect(Rect2(-s / 2, s), color, false, 3.0)
	var font := ThemeDB.fallback_font
	var text := "%s %s" % [CLASS_LETTERS[space_class], label]
	if gold:
		text += " ★"
	var font_size := 22 if space_class == ShipSpec.ShipClass.LIGHT else 28  # light spaces are narrow
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_set_transform(Vector2.ZERO, label_angle())  # level on screen, whatever the space's or camera's turn
	draw_string(font, Vector2(-text_size.x / 2, font_size / 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	draw_set_transform(Vector2.ZERO, 0.0)



## Marks this space as the one a customer asked for.
func set_pin(c: Color) -> void:
	pin_color = c
	_pin.queue_redraw()


func clear_pin() -> void:
	pin_color = Color(0, 0, 0, 0)
	_pin.queue_redraw()


## A map pin with the space's label, so a request customer can find it at a glance.
func _draw_pin() -> void:
	if pin_color.a <= 0.0:
		return
	_pin.draw_line(Vector2(0, -6), Vector2(0, 12), pin_color, 3.0)
	_pin.draw_circle(Vector2(0, -14), 12.0, pin_color)
	_pin.draw_arc(Vector2(0, -14), 12.0, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
	_pin.draw_string(ThemeDB.fallback_font, Vector2(16, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, pin_color)


## The turn that makes this node's text read level on screen.
func label_angle() -> float:
	return Upright.angle(self)
