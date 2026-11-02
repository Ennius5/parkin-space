class_name Floodlight
extends PointLight2D
## A lamp over the lot. In the dark it's the only way to see the floor, ships and rocks around it.
## A flickering one cuts out briefly now and then.

@export var radius := 350.0  # how far the light reaches, in pixels
@export var strength := 1.8
@export var flicker := false


func _ready() -> void:
	texture = Lighting.round_texture()
	texture_scale = radius * 2.0 / Lighting.TEXTURE_SIZE
	color = Color.from_hsv(randf_range(0.34, 0.66), 0.45, 1.0)  # a new shade of green to blue each shift
	energy = strength


func _process(_delta: float) -> void:
	if flicker:
		energy = energy_at(Time.get_ticks_msec() / 1000.0)


## Brightness at a moment in time. Steady lamps always shine at full strength; flickering ones
## stutter for a moment every few seconds, each lamp to its own rhythm.
func energy_at(t: float) -> float:
	if not flicker:
		return strength
	var offset := position.x * 0.013 + position.y * 0.007
	var cycle := fmod(t + offset, 4.0)
	if cycle < 0.35:
		return strength * (0.1 if sin(cycle * 90.0) > 0.0 else 0.6)
	return strength
