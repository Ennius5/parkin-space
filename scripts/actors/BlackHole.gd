class_name BlackHole
extends StaticBody2D
## A small black hole. Its solid core blocks ships like the island; its pull drags every free ship
## towards it, gently from afar and hard up close, but never harder than a ship can thrust.

const PULL_K := 1_800_000.0  # pull = PULL_K / distance², so 20 px/s² at 300 px
const MAX_PULL := 80.0  # px/s², reached at 150 px; below every ship's forward thrust
const CORE_RADIUS := 60.0
const RING_COLORS: Array[Color] = [Color(1.0, 0.55, 0.2), Color(0.8, 0.3, 1.0), Color(1.0, 0.8, 0.4)]


## Acceleration towards the hole at a distance from its centre, in px/s².
static func pull_at(distance: float) -> float:
	if distance <= 0.0:
		return MAX_PULL
	return minf(MAX_PULL, PULL_K / (distance * distance))


## The acceleration a body at this point feels, pointing at the hole's centre.
func pull_on(point: Vector2) -> Vector2:
	var to_hole := global_position - point
	if to_hole.is_zero_approx():
		return Vector2.ZERO
	return to_hole.normalized() * pull_at(to_hole.length())


func _ready() -> void:
	material = Lighting.unlit()  # always visible in the dark
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CORE_RADIUS
	shape.shape = circle
	add_child(shape)
	var glow := PointLight2D.new()
	glow.texture = Lighting.round_texture()
	glow.texture_scale = 3.0
	glow.color = Color(0.6, 0.3, 1.0)
	glow.energy = 0.8
	add_child(glow)


func _process(_delta: float) -> void:
	queue_redraw()


## A swirling accretion ring around a black core.
func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in RING_COLORS.size():
		var r := CORE_RADIUS * (1.15 + 0.25 * i)
		var spin := t * (1.6 - 0.4 * i) + i * 2.1
		draw_arc(Vector2.ZERO, r, spin, spin + PI * 1.3, 40, Color(RING_COLORS[i], 0.75), 6.0 - i)
	draw_circle(Vector2.ZERO, CORE_RADIUS, Color.BLACK)
	draw_arc(Vector2.ZERO, CORE_RADIUS, 0.0, TAU, 48, Color(1.0, 0.7, 0.4, 0.9), 2.0)
