class_name NetSession
extends Node
## One LAN duel connection over ENet: host or join, version handshake, join timeout
## and a silence watchdog. The autoload `Net` is one instance; tests make their own,
## each under a root with its own SceneMultiplayer.

signal connected  ## both sides, after the version handshake succeeds
signal join_failed(reason: String)  ## guest only: timeout or version mismatch
signal rival_left  ## the other side disconnected, went silent or left the match
signal rival_rematch  ## the rival asked for a rematch

const PORT := 24557
const PROTOCOL_VERSION := 2  # bump whenever any RPC (here or on NetSync) is added, removed or renamed
const JOIN_TIMEOUT := 5.0
const SILENCE_LIMIT := 3.0
const KEEPALIVE_INTERVAL := 0.5
const MSG_UNREACHABLE := "Cannot reach host. Check that you are on the same Wi-Fi."
const MSG_VERSION := "Your rival has a different version of the game."

var port := PORT  # tests may change it
var join_timeout := JOIN_TIMEOUT  # tests may lower it
var silence_limit := SILENCE_LIMIT  # tests may lower it
var duel_minutes := 3  # the host's choice, sent in the handshake
var rival_wants_rematch := false  # the rival asked for a rematch since the last match started

var _peer: ENetMultiplayerPeer
var _api: MultiplayerAPI  # the API the peer was set on
var _is_host := false
var _joining := false  # guest: waiting for welcome or reject
var _connected := false  # handshake done
var _rival_id := 0
var _join_elapsed := 0.0
var _silence := 0.0
var _keepalive := 0.0


func _ready() -> void:
	set_process(false)  # idle until host() or join()


func _exit_tree() -> void:
	close()


## Starts listening for one guest on `port`.
func host() -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		return err
	_is_host = true
	_open(peer)
	return OK


## Connects to a host at `ip`; emits connected or join_failed.
func join(ip: String) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	_is_host = false
	_joining = true
	_join_elapsed = 0.0
	_open(peer)
	return OK


## Frees the peer and resets state. Safe to call repeatedly; never emits rival_left.
func close() -> void:
	if _peer == null:
		return
	if _api != null:
		_api.peer_connected.disconnect(_on_peer_connected)
		_api.peer_disconnected.disconnect(_on_peer_disconnected)
		_api.connected_to_server.disconnect(_on_connected_to_server)
		_api.connection_failed.disconnect(_on_connection_failed)
		_api.server_disconnected.disconnect(_on_server_disconnected)
		if _api.multiplayer_peer == _peer:
			_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer.close()
	_peer = null
	_api = null
	_is_host = false
	_joining = false
	_connected = false
	_rival_id = 0
	rival_wants_rematch = false
	set_process(false)


func is_host() -> bool:
	return _is_host


## The connected rival's peer id (1 on a guest), or 0 before the handshake.
func rival_id() -> int:
	return _rival_id


## True while a peer is open (listening, joining or connected).
func is_active() -> bool:
	return _peer != null


## The first private IPv4 address (192.168/16, 10/8, 172.16/12), else "".
static func private_ip(addresses: PackedStringArray) -> String:
	for a in addresses:
		var parts := a.split(".")
		if parts.size() != 4 or not a.is_valid_ip_address():
			continue
		var b0 := parts[0].to_int()
		var b1 := parts[1].to_int()
		if (b0 == 192 and b1 == 168) or b0 == 10 or (b0 == 172 and b1 >= 16 and b1 <= 31):
			return a
	return ""


## The LAN address of the best real adapter (Wi-Fi/Ethernet preferred), skipping
## virtual/VPN adapters. Takes IP.get_local_interfaces() entries; "" if none fit.
static func pick_lan_ip(interfaces: Array) -> String:
	const SKIP := ["vmware", "vmnet", "virtualbox", "vbox", "hyper-v", "vethernet", "wsl",
		"docker", "radmin", "hamachi", "zerotier", "tailscale", "vpn", "tap-", "tun", "loopback", "bluetooth"]
	const PREFER := ["wi-fi", "wifi", "wlan", "wireless", "ethernet", "en0", "eth"]
	var fallback := ""
	for itf in interfaces:
		var label := (str(itf.get("name", "")) + " " + str(itf.get("friendly", ""))).to_lower()
		var skip := false
		for s in SKIP:
			if label.contains(s):
				skip = true
				break
		if skip:
			continue
		var ip := private_ip(itf.get("addresses", PackedStringArray()))
		if ip == "":
			continue
		for p in PREFER:
			if label.contains(p):
				return ip
		if fallback == "":
			fallback = ip
	return fallback


## This device's Wi-Fi address to show when hosting.
func local_ip() -> String:
	var ip := pick_lan_ip(IP.get_local_interfaces())
	if ip == "":
		ip = private_ip(IP.get_local_addresses())
	return ip


## Resets the silence watchdog; called for every message from the rival.
func heard() -> void:
	_silence = 0.0


func _open(peer: ENetMultiplayerPeer) -> void:
	_peer = peer
	_api = multiplayer
	_api.multiplayer_peer = peer
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_api.connected_to_server.connect(_on_connected_to_server)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)
	set_process(true)


func _process(delta: float) -> void:
	if _joining:
		_join_elapsed += delta
		if _join_elapsed >= join_timeout:
			_fail_join(MSG_UNREACHABLE)
		return
	if not _connected:
		return
	_silence += delta
	if _silence >= silence_limit:
		_lose_rival()
		return
	_keepalive += delta
	if _keepalive >= KEEPALIVE_INTERVAL:
		_keepalive = 0.0
		_ping.rpc_id(_rival_id)


## Handlers run inside the multiplayer poll, so they defer these two (the peer is
## swapped out in close()); the guards drop a call that arrives after a close().
func _fail_join(reason: String) -> void:
	if not _joining:
		return
	close()
	join_failed.emit(reason)


func _lose_rival() -> void:
	if not _connected:
		return
	close()
	rival_left.emit()


func _start_match(rival: int) -> void:
	_rival_id = rival
	rival_wants_rematch = false
	_joining = false
	_connected = true
	_silence = 0.0
	_keepalive = 0.0
	connected.emit()


func _on_peer_connected(_id: int) -> void:
	pass  # the host waits for _hello


func _on_peer_disconnected(id: int) -> void:
	if _is_host and _connected and id == _rival_id:
		_lose_rival.call_deferred()
	# a guest that never finished the handshake just frees the slot; keep listening


func _on_connected_to_server() -> void:
	_hello.rpc_id(1, PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	if _joining:
		_fail_join.call_deferred(MSG_UNREACHABLE)


func _on_server_disconnected() -> void:
	if _connected:
		_lose_rival.call_deferred()
	elif _joining:
		_fail_join.call_deferred(MSG_UNREACHABLE)


# RPC ids follow the sorted method names. The handshake RPCs (_hello, _ping, _reject, _welcome)
# must keep the lowest ids so a build with another PROTOCOL_VERSION can still be told so: any
# new RPC on this node is named to sort after _welcome (prefix _x_). See test_net_session.

@rpc("any_peer", "reliable")
func _hello(version: int) -> void:
	if not _is_host or _connected:
		return
	var sender := _api.get_remote_sender_id()
	if version != PROTOCOL_VERSION:
		_reject.rpc_id(sender)
		_peer.get_peer(sender).peer_disconnect_later()  # after the reject is delivered
		return
	_welcome.rpc_id(sender, duel_minutes)
	_start_match(sender)


@rpc("authority", "reliable")
func _welcome(minutes: int) -> void:
	if not _joining:
		return
	duel_minutes = minutes
	_start_match(1)


@rpc("authority", "reliable")
func _reject() -> void:
	if _joining:
		_fail_join.call_deferred(MSG_VERSION)


## Asks the rival for a rematch. These two live here, not on the duel's NetSync, because the
## result screen outlives the duel scene.
func ask_rematch() -> void:
	if _connected:
		_x_rematch.rpc_id(_rival_id)


## Tells the rival this side is leaving, then closes. The rival gets rival_left.
func leave() -> void:
	if _connected and _rival_id in _api.get_peers():
		_x_leave.rpc_id(_rival_id)
		_peer.host.flush()  # send it before close() drops the peer
	close()


@rpc("any_peer", "reliable")
func _x_rematch() -> void:
	if not _connected or _api.get_remote_sender_id() != _rival_id:
		return
	heard()
	rival_wants_rematch = true
	rival_rematch.emit()


@rpc("any_peer", "reliable")
func _x_leave() -> void:
	if _connected and _api.get_remote_sender_id() == _rival_id:
		_lose_rival.call_deferred()


@rpc("any_peer", "unreliable")
func _ping() -> void:
	heard()  # keep-alive while no match messages flow
