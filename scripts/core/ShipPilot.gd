class_name ShipPilot
extends RefCounted
## Where a ship reads its buttons from. The base pilot presses nothing.


## Whether the given action is held right now.
func is_pressed(_action: StringName) -> bool:
	return false
