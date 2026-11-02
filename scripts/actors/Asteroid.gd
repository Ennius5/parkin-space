class_name Asteroid
extends RigidBody2D
## A small rock drifting through the lot. Ships can shove it; hitting it hard dents them.

const MASS := 1.75  # between a light ship (1.0) and a medium one (2.5)

@export var texture: Texture2D
@export var art_scale := 0.6
@export var drift_speed := 25.0

var _outline := PackedVector2Array()


func _ready() -> void:
	mass = MASS
	gravity_scale = 0.0
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = DAMP_MODE_REPLACE
	angular_damp = 0.0
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


## The outline and the centre in global coordinates, like Ship.hull_points().
func hull_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in _outline:
		pts.append(global_transform * p)
	pts.append(global_position)
	return pts
