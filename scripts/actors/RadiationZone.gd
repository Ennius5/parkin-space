class_name RadiationZone
extends Node2D
## A glowing patch of radiation. Level dents any ship that stays inside it.

const COLOR := Color(0.3, 1.0, 0.3)

@export var radius := 110.0


func touches(ship: Ship) -> bool:
	for p in ship.hull_points():
		if p.distance_to(global_position) <= radius:
			return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.3 + 0.4 * pulse), 4.0)
