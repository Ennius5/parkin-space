class_name Ship
extends RigidBody2D
## A customer's spaceship. Zero gravity; the player drives it with thruster input actions.
## The nose points local -Y.

signal dented(ship: Ship, cost: int)
signal selected(ship: Ship)

const CLASS_COLORS := {
	ShipSpec.ShipClass.LIGHT: Color(0.35, 0.85, 0.95),
	ShipSpec.ShipClass.MEDIUM: Color(0.98, 0.85, 0.3),
	ShipSpec.ShipClass.HEAVY: Color(0.98, 0.55, 0.25),
}

@export var spec: ShipSpec

var is_driven: bool = false
var is_parked: bool = false

var _prev_velocity := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _drive_camera: Camera2D = $DriveCamera


func _ready() -> void:
	mass = spec.mass
	gravity_scale = 0.0
	linear_damp = 0.3
	angular_damp = 2.0
	contact_monitor = true
	max_contacts_reported = 4
	input_pickable = true
	var rect := RectangleShape2D.new()
	rect.size = spec.hull_size
	_collision.shape = rect
	if spec.texture:
		_sprite.texture = spec.texture
		_sprite.scale = spec.hull_size / spec.texture.get_size()
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_prev_velocity = linear_velocity
	if not is_driven:
		return
	var forward := -global_transform.y.normalized()
	var right := global_transform.x.normalized()
	apply_central_force(forward * Input.get_axis("thrust_back", "thrust_forward") * spec.thrust)
	apply_central_force(right * Input.get_axis("strafe_left", "strafe_right") * spec.strafe_thrust)
	apply_torque(Input.get_axis("rotate_left", "rotate_right") * spec.torque)


func set_driven(on: bool) -> void:
	is_driven = on
	if on:
		_drive_camera.make_current()


func set_parked() -> void:
	is_parked = true
	is_driven = false
	set_deferred("freeze", true)
	modulate = Color(1, 1, 1, 0.7)


## Hull corners and centre in global coordinates, used for parking checks.
func hull_points() -> PackedVector2Array:
	var h := spec.hull_size / 2
	var local := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2.ZERO]
	var pts := PackedVector2Array()
	for p in local:
		pts.append(global_transform * p)
	return pts


func _draw() -> void:
	if spec == null or spec.texture:
		return
	var h := spec.hull_size / 2
	draw_rect(Rect2(-h, spec.hull_size), CLASS_COLORS[spec.ship_class])
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -h.y + 4), Vector2(h.x * 0.5, -h.y + h.y * 0.4), Vector2(-h.x * 0.5, -h.y + h.y * 0.4),
	]), Color.WHITE)


func _on_body_entered(other: Node) -> void:
	if is_parked:
		return
	var other_velocity := Vector2.ZERO
	if other is Ship:
		var other_ship := other as Ship
		if not _pays_for_collision_with(other_ship):
			return
		other_velocity = other_ship._prev_velocity  # pre-impact on both sides, so both agree
	elif other is RigidBody2D:
		other_velocity = (other as RigidBody2D).linear_velocity
	var cost := ShiftLedger.dent_cost((_prev_velocity - other_velocity).length())
	if cost > 0:
		dented.emit(self, cost)


## Exactly one ship pays for a ship-to-ship collision: the driven one, else the one with the lower id.
func _pays_for_collision_with(other: Ship) -> bool:
	if other.is_parked:
		return true  # parked ships never report collisions
	if is_driven != other.is_driven:
		return is_driven
	return get_instance_id() < other.get_instance_id()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if tapped or clicked:
		selected.emit(self)
