class_name ArrivalBay
extends Node2D
## The marked area at the entrance where customers arrive. The next ship only arrives once
## no part of any ship or asteroid has been inside it for a moment. Sized for the biggest ship.

const SIZE := Vector2(140, 220)  # local Y is the arriving ship's length
const COLOR := Color(0.6, 0.65, 0.75, 0.5)
const ROCK_BARRIER_LAYER := 2  # physics layer only asteroids collide with: ships pass, rocks bounce off


## An invisible wall over the bay that keeps drifting rocks out, so they can never stall arrivals.
func _ready() -> void:
	material = Lighting.unlit()  # a marking, always readable in the dark
	var wall := StaticBody2D.new()
	wall.collision_layer = ROCK_BARRIER_LAYER
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE + Vector2(16, 16)  # a margin: rocks sink a few px into a wall before bouncing
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


## True when any part of a ship or asteroid is inside the bay.
func touches(body: Node2D) -> bool:
	var points := PackedVector2Array()
	if body is Ship:
		points = (body as Ship).hull_points()
	elif body is Asteroid:
		points = (body as Asteroid).hull_points()
	var rect := Rect2(-SIZE / 2, SIZE)
	for p in points:
		if rect.has_point(to_local(p)):
			return true
	return false


func is_clear(bodies: Array[Node]) -> bool:
	for body: Node2D in bodies:
		if touches(body):
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
	draw_set_transform(_label_anchor(), label_angle())
	draw_string(font, Vector2(-text_size.x / 2, font_size / 3.0), "ARRIVALS", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COLOR)
	draw_set_transform(Vector2.ZERO, 0.0)


func _process(_delta: float) -> void:
	queue_redraw()  # the label re-levels as the camera turns


## Just above the bay as it appears on screen, whichever way the bay and camera are turned.
func _label_anchor() -> Vector2:
	var turn := -label_angle()
	var half_height := 0.5 * (absf(SIZE.x * sin(turn)) + absf(SIZE.y * cos(turn)))
	return Vector2(0, -(half_height + 14.0)).rotated(label_angle())


## The turn that makes this node's text read level on screen.
func label_angle() -> float:
	return Upright.angle(self)
