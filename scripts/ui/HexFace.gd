class_name HexFace
extends Node2D
## The neon hexagon drawn behind a driving-pad TouchScreenButton: cyan, magenta while held.

var size := Vector2(120, 120)
var lit := false


## Puts a face on the button, behind its label, and follows its presses.
static func attach(button: TouchScreenButton) -> HexFace:
	var face := HexFace.new()
	face.name = "HexFace"
	face.size = button.texture_normal.get_size()
	button.add_child(face)
	button.move_child(face, 0)
	button.pressed.connect(face.set_lit.bind(true))
	button.released.connect(face.set_lit.bind(false))
	var blank := Image.create(int(face.size.x), int(face.size.y), false, Image.FORMAT_RGBA8)
	button.texture_normal = ImageTexture.create_from_image(blank)  # same touch area, nothing drawn
	button.texture_pressed = null
	return face


func set_lit(on: bool) -> void:
	lit = on
	queue_redraw()


func _draw() -> void:
	var outline := HexStyle.MAGENTA if lit else HexStyle.CYAN
	var body := Color(outline, 0.28) if lit else Color(0.02, 0.06, 0.1, 0.6)
	HexStyle.draw_hex(get_canvas_item(), Rect2(Vector2(6, 6), size - Vector2(12, 12)), outline, body, 0.6 if lit else 0.35, 3.0)
