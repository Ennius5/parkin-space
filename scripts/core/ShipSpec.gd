class_name ShipSpec
extends Resource
## Handling and size data for one ship type. Saved as .tres in res://resources/ships/.

enum ShipClass { LIGHT, MEDIUM, HEAVY }

@export var ship_class: ShipClass = ShipClass.LIGHT
@export var display_name: String = ""
@export var mass: float = 1.0
@export var hull_size: Vector2 = Vector2(40, 64)  # width x length in pixels, nose at -Y
@export var center_of_mass: Vector2 = Vector2.ZERO  # pixels from the hull centre
@export var thrusters: Array[ThrusterSpec] = []
@export var texture: Texture2D  # null = placeholder drawing
