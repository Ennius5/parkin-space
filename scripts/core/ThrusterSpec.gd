class_name ThrusterSpec
extends Resource
## One thruster on a ship's hull. Positions are in pixels from the hull centre, nose at -Y.
## Godot's y axis points down, so a positive torque turns the ship clockwise.

@export var position: Vector2 = Vector2.ZERO
@export var direction: Vector2 = Vector2.UP  # the way it pushes the ship; normalised before use
@export var force: float = 100.0
@export var actions: PackedStringArray = []  # Input Map actions that fire it


## Force vector in ship-local space.
func push() -> Vector2:
	return direction.normalized() * force


func torque_about(com: Vector2) -> float:
	return (position - com).cross(push())


## How much of this thruster's force pushes along the unit vector dir (never negative).
func push_along(dir: Vector2) -> float:
	return maxf(0.0, direction.normalized().dot(dir)) * force


func fires_for(held: PackedStringArray) -> bool:
	for action in actions:
		if held.has(action):
			return true
	return false
