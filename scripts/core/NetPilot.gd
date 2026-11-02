class_name NetPilot
extends ShipPilot
## Buttons arriving over the network, packed one bit per action.

const ACTIONS: Array[StringName] = [&"thrust_forward", &"thrust_back", &"strafe_left", &"strafe_right",
	&"rotate_left", &"rotate_right", &"brake", &"stop_rotation"]  # Ship.DRIVE_ACTIONS, then brake and stop_rotation

var bits: int = 0


func is_pressed(action: StringName) -> bool:
	var i := ACTIONS.find(StringName(action))
	return i >= 0 and (bits >> i) & 1 == 1


## Packs the local Input state into bits.
static func bits_from_input() -> int:
	var packed := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			packed |= 1 << i
	return packed
