class_name DuelArrivals
extends RefCounted
## The duel's two arrival bays (0 = left, 1 = right) working through one BaySlots list. Each bay
## keeps its own slot index, interval timer and clear timer. A bay is due when it has stayed clear
## for ARRIVAL_CLEAR_SECONDS and either its interval has passed or it is behind the other bay,
## which lets a camped bay catch up. No bay ever skips a slot. DuelLevel does the spawning.

const BAY_INTERVAL := 10.0  # seconds between a bay's arrivals while it keeps pace
const BAYS := 2

var slots: Array = []  # BaySlots.build entries: [left, right]
var bays: Array[ArrivalBay] = []  # the markings whose clearness counts, by bay

var _index := PackedInt32Array([0, 0])
var _since_arrival := PackedFloat32Array([0.0, 0.0])
var _clear_for := PackedFloat32Array([0.0, 0.0])


func _init(slot_list: Array = []) -> void:
	slots = slot_list


## Every ship in the list, left then right per slot: the duel's whole customer queue.
func all_specs() -> Array[ShipSpec]:
	var specs: Array[ShipSpec] = []
	for pair: Array in slots:
		for entry: Dictionary in pair:
			specs.append(entry.spec)
	return specs


## How many slots this bay has spawned.
func index(bay: int) -> int:
	return _index[bay]


## This bay's next slot entry ({spec, tier, bronze_tips}), or {} once it has spawned them all.
func next_slot(bay: int) -> Dictionary:
	return slots[_index[bay]][bay] if _index[bay] < slots.size() else {}


## The bay whose next arrival comes first: the one further behind, left on a tie.
func next_bay() -> int:
	return 1 if _index[1] < _index[0] else 0


func behind(bay: int) -> bool:
	return _index[bay] < _index[1 - bay]


## Runs both bays' timers; in_the_way are the bodies that keep a bay from being clear.
func tick(delta: float, in_the_way: Array[Node]) -> void:
	for bay in mini(BAYS, bays.size()):
		_since_arrival[bay] += delta
		_clear_for[bay] = _clear_for[bay] + delta if bays[bay].is_clear(in_the_way) else 0.0


## True when this bay should spawn its next slot now.
func due(bay: int) -> bool:
	if _clear_for[bay] < Level.ARRIVAL_CLEAR_SECONDS or next_slot(bay).is_empty():
		return false
	return behind(bay) or _since_arrival[bay] >= BAY_INTERVAL


## The bay's next slot has arrived: on to the one after, with both timers from zero.
func spawned(bay: int) -> void:
	_index[bay] += 1
	_since_arrival[bay] = 0.0
	_clear_for[bay] = 0.0
