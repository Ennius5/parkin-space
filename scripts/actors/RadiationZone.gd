class_name RadiationZone
extends Node2D
## A glowing patch of radiation. Level dents any ship that stays inside it.

const COLOR := Color(0.3, 1.0, 0.3)
const PULSE_SECONDS := 1.6
const RINGS := 3

@export var radius := 110.0



func _ready() -> void:
	material = Lighting.unlit()  # a marking, always readable in the dark

func touches(ship: Ship) -> bool:
	for p in ship.hull_points():
		if p.distance_to(global_position) <= radius:
			return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


## A breathing glow with rings rippling outwards. Only the look pulses; the damage radius stays put.
func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var breath := 0.5 + 0.5 * sin(t * TAU / PULSE_SECONDS)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.12 + 0.14 * breath))
	draw_circle(Vector2.ZERO, radius * (0.35 + 0.15 * breath), Color(COLOR, 0.1 + 0.1 * breath))
	for i in RINGS:
		var phase := fmod(t / PULSE_SECONDS + float(i) / RINGS, 1.0)
		draw_arc(Vector2.ZERO, radius * phase, 0.0, TAU, 48, Color(COLOR, 0.45 * (1.0 - phase)), 3.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.35 + 0.45 * breath), 3.0 + 3.0 * breath)
