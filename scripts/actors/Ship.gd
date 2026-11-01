class_name Ship
extends RigidBody2D
## A customer's spaceship: a mass pushed by the thrusters in its spec. Zero gravity.
## Each held input action fires its thrusters at their hull positions. The nose points local -Y.

signal dented(ship: Ship, cost: int)
signal selected(ship: Ship)

const DRIVE_ACTIONS := ["thrust_forward", "thrust_back", "strafe_left", "strafe_right", "rotate_left", "rotate_right"]
const ROTATE_ACTIONS: PackedStringArray = ["rotate_left", "rotate_right"]
const CLASS_COLORS := {
	ShipSpec.ShipClass.LIGHT: Color(0.35, 0.85, 0.95),
	ShipSpec.ShipClass.MEDIUM: Color(0.98, 0.85, 0.3),
	ShipSpec.ShipClass.HEAVY: Color(0.98, 0.55, 0.25),
}

@export var spec: ShipSpec
var paint_color := Color.WHITE  # set before the ship enters the tree

var is_driven: bool = false
var is_parked: bool = false
var firing := PackedInt32Array()  # indices into spec.thrusters that fired this physics frame

var _prev_velocity := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _paint: Sprite2D = $Paint
@onready var _lights: Sprite2D = $Lights
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _drive_camera: Camera2D = $DriveCamera


func _ready() -> void:
	mass = spec.mass
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec.center_of_mass
	if spec.inertia > 0.0:
		inertia = spec.inertia
	gravity_scale = 0.0
	# No damping at all: ships drift and spin until the pilot brakes.
	linear_damp_mode = DAMP_MODE_REPLACE
	angular_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	input_pickable = true
	var rect := RectangleShape2D.new()
	rect.size = spec.hull_size
	_collision.shape = rect
	if spec.hull_polygon.size() >= 3:
		var outline := CollisionPolygon2D.new()
		outline.polygon = spec.hull_polygon
		add_child(outline)
		_collision.disabled = true
	_show_layer(_sprite, spec.texture)
	_show_layer(_paint, spec.paint_texture)
	_paint.modulate = paint_color
	_show_layer(_lights, spec.lights_texture)
	body_entered.connect(_on_body_entered)


func _show_layer(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.visible = texture != null
	if texture:
		sprite.texture = texture
		sprite.scale = spec.hull_size / texture.get_size()


func _process(_delta: float) -> void:
	if _lights.visible:
		_lights.modulate.a = lights_level()


## Lights: full while driven, a slow blink while waiting for a valet, dim once parked.
func lights_level() -> float:
	if is_parked:
		return 0.25
	if is_driven:
		return 1.0
	return 0.65 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * PI)


func _physics_process(_delta: float) -> void:
	_prev_velocity = linear_velocity
	var was_firing := firing
	firing = PackedInt32Array()
	if is_driven:
		_fire_thrusters()
	if firing != was_firing:
		queue_redraw()


func _fire_thrusters() -> void:
	var held := PackedStringArray()
	for action in DRIVE_ACTIONS:
		if Input.is_action_pressed(action):
			held.append(action)
	var braking := Input.is_action_pressed("brake") and linear_velocity.length() > 0.5
	var stopping_spin := Input.is_action_pressed("stop_rotation") and absf(angular_velocity) > 0.01
	var against_drift := _local_against_drift()
	var spin_sign := -signf(angular_velocity)
	for i in spec.thrusters.size():
		var t := spec.thrusters[i]
		if t.fires_for(held):
			apply_force(global_transform.basis_xform(t.push()), global_transform.basis_xform(t.position))
			firing.append(i)
		elif braking and t.push_along(against_drift) > 0.0:
			firing.append(i)  # brake thrusters only show a flame; _integrate_forces does the braking
		elif stopping_spin and t.fires_for(ROTATE_ACTIONS) and t.torque_about(spec.center_of_mass) * spin_sign > 0.0:
			firing.append(i)


## STOP gets its strength from the thrusters that oppose the drift; Stop Spin from the rotation
## thrusters that oppose the spin. Both change velocity directly so they never add spin or side force.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_driven:
		return
	if Input.is_action_pressed("brake") and state.linear_velocity.length() > 0.0:
		var against := global_transform.basis_xform_inv(-state.linear_velocity).normalized()
		var brake_force := 0.0
		for t in spec.thrusters:
			brake_force += t.push_along(against)
		state.linear_velocity = state.linear_velocity.move_toward(Vector2.ZERO, brake_force / mass * state.step)
	if Input.is_action_pressed("stop_rotation") and state.angular_velocity != 0.0:
		var spin_sign := -signf(state.angular_velocity)
		var spin_torque := 0.0
		for t in spec.thrusters:
			if t.fires_for(ROTATE_ACTIONS):
				spin_torque += maxf(0.0, t.torque_about(spec.center_of_mass) * spin_sign)
		state.angular_velocity = move_toward(state.angular_velocity, 0.0, spin_torque * state.inverse_inertia * state.step)


## Unit vector in ship-local space pointing against the current drift (zero when still).
func _local_against_drift() -> Vector2:
	return global_transform.basis_xform_inv(-linear_velocity).normalized()


func set_driven(on: bool) -> void:
	is_driven = on
	if on:
		_drive_camera.make_current()


func set_parked() -> void:
	is_parked = true
	is_driven = false
	set_deferred("freeze", true)
	modulate = Color(1, 1, 1, 0.7)


## Outline (or hull corners) and centre in global coordinates, used for parking checks.
func hull_points() -> PackedVector2Array:
	var h := spec.hull_size / 2
	var local := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2.ZERO]
	if spec.hull_polygon.size() >= 3:
		local = Array(spec.hull_polygon) + [Vector2.ZERO]
	var pts := PackedVector2Array()
	for p in local:
		pts.append(global_transform * p)
	return pts


func _draw() -> void:
	if spec == null:
		return
	if spec.texture == null:
		_draw_placeholder_hull()
	for i in firing:
		_draw_flame(spec.thrusters[i])


## Exhaust points away from the push; bigger thrusters get longer flames.
func _draw_flame(t: ThrusterSpec) -> void:
	var back := -t.direction.normalized()
	var side := back.orthogonal()
	var length := clampf(t.force / 10.0, 12.0, 28.0)
	var width := length * 0.3
	draw_colored_polygon(PackedVector2Array([
		t.position + side * width, t.position + back * length, t.position - side * width,
	]), Color(1.0, 0.5, 0.1, 0.9))
	draw_colored_polygon(PackedVector2Array([
		t.position + side * width * 0.5, t.position + back * length * 0.55, t.position - side * width * 0.5,
	]), Color(1.0, 0.95, 0.5))


func _draw_placeholder_hull() -> void:
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
