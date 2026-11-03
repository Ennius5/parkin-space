class_name LocalPilot
extends ShipPilot
## Reads the buttons on this device.


func is_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)
