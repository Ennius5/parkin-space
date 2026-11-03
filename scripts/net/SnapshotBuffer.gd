class_name SnapshotBuffer
extends RefCounted
## Guest-side buffer: renders the host's snapshots RENDER_DELAY seconds in the past, interpolated.

const RENDER_DELAY := 0.1
const MAX_KEPT := 10

var _snaps: Array[Dictionary] = []
var _times: Array[float] = []


## Stores a snapshot received at at_sec (seconds, any monotonic clock).
func push(s: Dictionary, at_sec: float) -> void:
	_snaps.append(s.duplicate(true))
	_times.append(at_sec)
	while _snaps.size() > MAX_KEPT:
		_snaps.pop_front()
		_times.pop_front()


## Number of snapshots held.
func size() -> int:
	return _snaps.size()


## State at now_sec - RENDER_DELAY; the newest snapshot when starved. Empty if nothing pushed.
func sample(now_sec: float) -> Dictionary:
	if _snaps.is_empty():
		return {}
	var last := _snaps.size() - 1
	var t := now_sec - RENDER_DELAY
	if _snaps.size() < 2 or t >= _times[last]:
		return _snaps[last].duplicate(true)
	if t <= _times[0]:
		return _snaps[0].duplicate(true)
	var i := 1
	while _times[i] < t:
		i += 1
	var older := _snaps[i - 1]
	var newer := _snaps[i]
	var span := _times[i] - _times[i - 1]
	var w := 0.0 if span <= 0.0 else (t - _times[i - 1]) / span
	var out := newer.duplicate(true)
	var old_by_id := {}
	for ship: Dictionary in older.ships:
		old_by_id[ship.id] = ship
	for ship: Dictionary in out.ships:
		if old_by_id.has(ship.id):
			var o: Dictionary = old_by_id[ship.id]
			ship.pos = (o.pos as Vector2).lerp(ship.pos, w)
			ship.rot = lerp_angle(float(o.rot), float(ship.rot), w)
	return out
