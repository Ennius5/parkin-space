class_name ArrivalBay
extends Node2D
## The marked area at the entrance where customers arrive. The next ship only arrives once
## no part of any ship has been inside it for a moment. Sized for the biggest ship.

const SIZE := Vector2(140, 220)  # local Y is the arriving ship's length
const COLOR := Color(0.6, 0.65, 0.75, 0.5)


func touches(ship: Ship) -> bool:
	var rect := Rect2(-SIZE / 2, SIZE)
	for p in ship.hull_points():
		if rect.has_point(to_local(p)):
			return true
	return false


func is_clear(ships: Array[Node]) -> bool:
	for ship: Ship in ships:
		if touches(ship):
			return false
	return true


func _draw() -> void:
	var rect := Rect2(-SIZE / 2, SIZE)
	draw_rect(rect, Color(COLOR, 0.08))
	draw_dashed_line(rect.position, rect.position + Vector2(SIZE.x, 0), COLOR, 3.0, 12.0)
	draw_dashed_line(rect.position + Vector2(0, SIZE.y), rect.end, COLOR, 3.0, 12.0)
	draw_dashed_line(rect.position, rect.position + Vector2(0, SIZE.y), COLOR, 3.0, 12.0)
	draw_dashed_line(rect.position + Vector2(SIZE.x, 0), rect.end, COLOR, 3.0, 12.0)
	var font := ThemeDB.fallback_font
	var font_size := 22
	var text_size := font.get_string_size("ARRIVALS", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2, SIZE.y / 2 - 10), "ARRIVALS", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR)
