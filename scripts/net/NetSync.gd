class_name NetSync
extends Node
## Every match message of a duel, as RPCs on one node (a child of the DuelLevel named "NetSync",
## so the path matches on both phones). Requests from the guest are checked against the
## connected rival and handed to the level; the level decides what they mean.

const SENT_LIMIT := 600  # recorded messages kept while there's no live session

var level: DuelLevel
var session: NetSession
## Messages recorded as [method, args] instead of sent, while the session isn't active
## (tests, or after the rival left). Oldest dropped past SENT_LIMIT.
var sent: Array = []
var guest_bits := 0  # host: the guest's newest buttons, as NetPilot bits


## Sends a match message to the rival, or records it when there's no live session.
func send(method: StringName, args: Array) -> void:
	if session != null and session.is_active():
		var peer := session.rival_id()
		if peer != 0 and peer in multiplayer.get_peers():  # not one that dropped a moment ago
			callv(&"rpc_id", [peer, method] + args)
		return
	sent.append([method, args])
	if sent.size() > SENT_LIMIT:
		sent.pop_front()


## True when the RPC being handled came from the connected rival; that also feeds the watchdog.
func _from_rival() -> bool:
	if session == null or not session.is_active():
		return false
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or sender != session.rival_id():
		return false
	session.heard()
	return true


func _is_host() -> bool:
	return level != null and level.role == DuelLevel.Role.HOST


# --- Guest -> host ---

@rpc("any_peer", "call_remote", "reliable")
func loaded() -> void:
	if _from_rival() and _is_host():
		level.on_guest_loaded()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func input(bits: int) -> void:
	if _from_rival() and _is_host():
		guest_bits = bits


@rpc("any_peer", "call_remote", "reliable")
func select(id: int) -> void:
	if _from_rival() and _is_host():
		_on_select(id)


@rpc("any_peer", "call_remote", "reliable")
func done() -> void:
	if _from_rival() and _is_host():
		_on_done()


## The guest asks for a ship: theirs unless someone already drives it.
func _on_select(id: int) -> void:
	var ship := level.ship_by_id(id)
	if ship:
		level.select_ship(ship, level.valets[1])


## The guest pressed Done: park or let go of their ship.
func _on_done() -> void:
	level.press_done(level.valets[1])


# --- Either way (Task 10 gives these their behaviour) ---

@rpc("any_peer", "call_remote", "reliable")
func rematch() -> void:
	_from_rival()


@rpc("any_peer", "call_remote", "reliable")
func leave() -> void:
	_from_rival()


# --- Host -> guest (handed to the level's GuestMirror) ---

func _is_guest() -> bool:
	return level != null and level.role == DuelLevel.Role.GUEST and level.mirror != null


@rpc("authority", "call_remote", "reliable")
func match_start(match_seed: int, seconds: float, ships: PackedByteArray) -> void:
	if _from_rival() and _is_guest():
		level.mirror.on_match_start(match_seed, seconds, NetProtocol.unpack_ship_list(ships))


@rpc("authority", "call_remote", "reliable")
func go() -> void:
	if _from_rival() and _is_guest():
		level.mirror.on_go()


@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(bytes: PackedByteArray) -> void:
	if _from_rival() and _is_guest():
		level.mirror.on_snapshot(NetProtocol.unpack_snapshot(bytes))


@rpc("authority", "call_remote", "reliable")
func ship_added(bytes: PackedByteArray) -> void:
	if _from_rival() and _is_guest():
		level.mirror.add_ships(NetProtocol.unpack_ship_list(bytes))


@rpc("authority", "call_remote", "reliable")
func ship_removed(id: int) -> void:
	if _from_rival() and _is_guest():
		level.mirror.remove_ship(id)


@rpc("authority", "call_remote", "reliable")
func event(effect: String) -> void:
	if _from_rival() and _is_guest():
		level.mirror.on_event(effect)


@rpc("authority", "call_remote", "reliable")
func match_end(host_score: int, guest_score: int) -> void:
	if _from_rival() and _is_guest():
		level.mirror.on_match_end(host_score, guest_score)
