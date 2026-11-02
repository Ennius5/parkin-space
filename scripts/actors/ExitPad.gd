class_name ExitPad
extends Node2D
## The gate where customers collect their ship. A requested ship driven onto it is handed over.

const SIZE := Vector2(140, 220)
const COLOR := Color(1, 0.82, 0.2)



func _ready() -> void:
	material = Lighting.unlit()  # a marking, always readable in the dark

func contains(point: Vector2) -> bool:
	return Rect2(-SIZE / 2, SIZE).has_point(to_local(point))


func _draw() -> void:
	var rect := Rect2(-SIZE / 2, SIZE)
	draw_rect(rect, Color(COLOR, 0.12))
	draw_rect(rect, COLOR, false, 4.0)
	var font := ThemeDB.fallback_font
	var font_size := 34
	var text_size := font.get_string_size("EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2, font_size / 3.0), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR)
