class_name ParkTracker
extends RefCounted
## Tracks how long a ship has stayed parked; reports once when the hold time is reached.

var _held := 0.0
var _fired := false


## Returns true exactly once, when `ok` has held for ParkingRules.HOLD_SECONDS.
func update(delta: float, ok: bool) -> bool:
	if not ok:
		_held = 0.0
		return false
	_held += delta
	if _held >= ParkingRules.HOLD_SECONDS and not _fired:
		_fired = true
		return true
	return false
