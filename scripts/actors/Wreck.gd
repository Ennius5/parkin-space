class_name Wreck
extends StaticBody2D
## A dead ship fixed in the lot: a solid obstacle shaped like its sprite.

const DARKEN := Color(0.55, 0.55, 0.6)

@export var texture: Texture2D
@export var overlay: Texture2D  # damage marks drawn over the hull
@export var art_scale := 1.4


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * art_scale
	sprite.modulate = DARKEN
	if overlay:
		var marks := Sprite2D.new()
		marks.texture = overlay
		sprite.add_child(marks)
	add_child(sprite)
	var shape := CollisionPolygon2D.new()
	shape.polygon = SpriteOutline.outline(texture, art_scale)
	add_child(shape)
