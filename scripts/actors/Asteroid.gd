class_name Asteroid
extends RigidBody2D
## A small rock drifting through the lot. Ships can shove it; hitting it hard dents them.

const MASS := 1.75  # between a light ship (1.0) and a medium one (2.5)
const MAX_SPEED := 120.0  # a hard shove can't send a rock pinballing around the lot forever
const ROCK_LAYER := 1 | ArrivalBay.ROCK_BARRIER_LAYER  # collides with everything plus the bay's rock wall

@export var texture: Texture2D
@export var art_scale := 0.6
@export var drift_speed := 25.0
@export var max_speed := MAX_SPEED  # Level 4 raises this so a black hole's fling can send rocks flying
@export var drag := 0.0:  # how fast a speeding rock slows back down; 0 = drifts forever
	set(value):
		drag = value
		linear_damp = value

var _outline := PackedVector2Array()


func _ready() -> void:
	mass = MASS
	gravity_scale = 0.0
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = drag
	angular_damp_mode = DAMP_MODE_REPLACE
	angular_damp = 0.0
	collision_mask = ROCK_LAYER
	var bouncy := PhysicsMaterial.new()
	bouncy.bounce = 1.0
	bouncy.friction = 0.0
	physics_material_override = bouncy
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * art_scale
	add_child(sprite)
	_outline = SpriteOutline.outline(texture, art_scale)
	var shape := CollisionPolygon2D.new()
	shape.polygon = _outline
	add_child(shape)
	linear_velocity = Vector2.RIGHT.rotated(randf() * TAU) * drift_speed
	angular_velocity = randf_range(-0.4, 0.4)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(maxf(drift_speed, max_speed))


## The outline and the centre in global coordinates, like Ship.hull_points().
func hull_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in _outline:
		pts.append(global_transform * p)
	pts.append(global_position)
	return pts
