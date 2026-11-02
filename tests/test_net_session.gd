extends TestCase

const LOOP_PORT := 24600
const DEAD_PORT := 24699  # nothing listens here
const FRAMES := 120


## A root node with its own SceneMultiplayer and a NetSession child at <root>/Session.
func _side(root_name: String, port: int) -> NetSession:
	var root := Node.new()
	root.name = root_name
	tree.root.add_child(root)
	tree.set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var s := NetSession.new()
	s.name = "Session"
	s.port = port
	root.add_child(s)
	return s


func _cleanup(sessions: Array[NetSession]) -> void:
	for s in sessions:
		s.close()
	for s in sessions:
		var root := s.get_parent()
		tree.set_multiplayer(null, root.get_path())
		root.free()


## Awaits process frames until cond is true or the budget runs out.
func _wait(cond: Callable, frames := FRAMES) -> bool:
	for i in frames:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


## Awaits process frames until cond is true or the wall-clock budget runs out.
func _wait_seconds(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


## Records a session's signals into a dictionary.
func _watch(s: NetSession) -> Dictionary:
	var ev := {"connected": false, "failed": "", "left": false}
	s.connected.connect(func() -> void: ev.connected = true)
	s.join_failed.connect(func(reason: String) -> void: ev.failed = reason)
	s.rival_left.connect(func() -> void: ev.left = true)
	return ev


func test_pick_lan_ip_skips_virtual_adapters() -> void:
	var mixed: Array = [
		{"name": "ethernet_32", "friendly": "VMware Network Adapter VMnet8", "addresses": PackedStringArray(["192.168.200.1"])},
		{"name": "radmin", "friendly": "Radmin VPN", "addresses": PackedStringArray(["26.5.116.168"])},
		{"name": "wireless_1", "friendly": "Wi-Fi", "addresses": PackedStringArray(["fe80::1", "192.168.18.226"])},
	]
	assert_eq(NetSession.pick_lan_ip(mixed), "192.168.18.226")
	var vm_only: Array = [{"name": "vmnet1", "friendly": "x", "addresses": PackedStringArray(["192.168.200.1"])}]
	assert_eq(NetSession.pick_lan_ip(vm_only), "")
	var eth: Array = [{"name": "eth0", "friendly": "Ethernet", "addresses": PackedStringArray(["10.0.0.4"])}]
	assert_eq(NetSession.pick_lan_ip(eth), "10.0.0.4")


func test_private_ip_filter() -> void:
	assert_eq(NetSession.private_ip(PackedStringArray(["127.0.0.1", "fe80::1", "192.168.1.7"])), "192.168.1.7")
	assert_eq(NetSession.private_ip(PackedStringArray(["10.0.0.4"])), "10.0.0.4")
	assert_eq(NetSession.private_ip(PackedStringArray(["172.20.1.1"])), "172.20.1.1")
	assert_eq(NetSession.private_ip(PackedStringArray(["172.40.1.1", "8.8.8.8"])), "")


func test_loopback_connects() -> void:
	var host := _side("H", LOOP_PORT)
	var guest := _side("G", LOOP_PORT)
	var he := _watch(host)
	var ge := _watch(guest)
	host.duel_minutes = 7
	assert_eq(host.host(), OK)
	assert_eq(guest.join("127.0.0.1"), OK)
	var ok: bool = await _wait(func() -> bool: return he.connected and ge.connected)
	assert_true(ok, "both connected")
	assert_true(host.is_host())
	assert_false(guest.is_host())
	assert_true(host.is_active() and guest.is_active())
	assert_eq(guest.duel_minutes, 7)
	assert_eq(ge.failed, "")
	_cleanup([host, guest] as Array[NetSession])


func test_join_timeout() -> void:
	var guest := _side("G", DEAD_PORT)
	var ge := _watch(guest)
	guest.join_timeout = 0.3
	assert_eq(guest.join("127.0.0.1"), OK)
	var ok: bool = await _wait_seconds(func() -> bool: return ge.failed != "", 3.0)
	assert_true(ok, "join failed in time")
	assert_eq(ge.failed, "Cannot reach host. Check that you are on the same Wi-Fi.")
	assert_false(ge.connected)
	assert_false(guest.is_active())
	_cleanup([guest] as Array[NetSession])


func test_rival_left_on_close() -> void:
	var host := _side("H", LOOP_PORT)
	var guest := _side("G", LOOP_PORT)
	var he := _watch(host)
	var ge := _watch(guest)
	host.host()
	guest.join("127.0.0.1")
	var ok: bool = await _wait(func() -> bool: return he.connected and ge.connected)
	assert_true(ok, "connected first")
	guest.close()
	guest.close()  # safe twice
	var left: bool = await _wait(func() -> bool: return he.left)
	assert_true(left, "host saw the rival leave")
	assert_false(ge.left, "the side that closed does not get rival_left")
	assert_false(host.is_active())
	_cleanup([host, guest] as Array[NetSession])


func test_rematch_and_leave_reach_the_rival() -> void:
	var host := _side("H", LOOP_PORT + 2)
	var guest := _side("G", LOOP_PORT + 2)
	var he := _watch(host)
	var ge := _watch(guest)
	assert_eq(host.host(), OK)
	assert_eq(guest.join("127.0.0.1"), OK)
	var ok: bool = await _wait(func() -> bool: return he.connected and ge.connected)
	assert_true(ok, "both connected")
	if not ok:
		_cleanup([host, guest] as Array[NetSession])
		return
	guest.ask_rematch()
	var asked: bool = await _wait(func() -> bool: return host.rival_wants_rematch)
	assert_true(asked, "the host heard the rematch request")
	assert_false(guest.rival_wants_rematch)
	guest.leave()
	assert_false(guest.is_active(), "leaving closes this side")
	assert_false(ge.left, "the leaver gets no rival_left")
	var gone: bool = await _wait_seconds(func() -> bool: return he.left, 2.0)
	assert_true(gone, "the host got rival_left")
	assert_false(host.rival_wants_rematch, "cleared on close")
	_cleanup([host, guest] as Array[NetSession])


func test_handshake_rpcs_keep_the_lowest_ids() -> void:
	# Godot numbers a node's RPCs by method name in sorted order, so these four must sort first:
	# then a build with a different PROTOCOL_VERSION can still hello, reject and ping.
	var s := NetSession.new()
	var config: Variant = s.get_script().get_rpc_config()
	var names: Array = []
	if config is Dictionary:
		for key: Variant in (config as Dictionary).keys():
			names.append(String(key))  # Godot sorts them alphabetically (StringNames don't sort so)
	names.sort()
	assert_true(names.size() >= 4, str(names))
	if names.size() >= 4:
		assert_eq(names.slice(0, 4), ["_hello", "_ping", "_reject", "_welcome"])
	assert_eq(NetSession.PROTOCOL_VERSION, 3, "bumped when the RPC set changed")
	s.free()
