extends TestCase


func _snap(x: float, tick: int = 1) -> Dictionary:
	return {
		"tick": tick, "time_left": 42.5,
		"scores": PackedInt32Array([3, 7]),
		"lit": PackedInt32Array([-1, 0, 1, -1]),
		"ships": [
			{"id": 0, "pos": Vector2(x, 20.0), "rot": 0.5, "driver": 0, "parked": false, "glowing": true, "firing": 5},
		],
	}


func test_snapshot_round_trip() -> void:
	var s := _snap(12.25)
	s.ships.append({"id": 9, "pos": Vector2(-300.5, 88.0), "rot": -2.0, "driver": -1, "parked": true, "glowing": false, "firing": 0})
	s.ships[0].driver = 1
	var u: Dictionary = NetProtocol.unpack_snapshot(NetProtocol.pack_snapshot(s))
	assert_eq(u.tick, 1)
	assert_almost(u.time_left, 42.5, 0.01)
	assert_eq(u.scores, PackedInt32Array([3, 7]))
	assert_eq(u.lit, PackedInt32Array([-1, 0, 1, -1]))
	assert_eq(u.ships.size(), 2)
	for i in 2:
		var a: Dictionary = s.ships[i]
		var b: Dictionary = u.ships[i]
		assert_eq(b.id, a.id)
		assert_almost(b.pos.x, a.pos.x, 0.01)
		assert_almost(b.pos.y, a.pos.y, 0.01)
		assert_almost(b.rot, a.rot, 0.01)
		assert_eq(b.driver, a.driver)
		assert_eq(b.parked, a.parked)
		assert_eq(b.glowing, a.glowing)
		assert_eq(b.firing, a.firing)


func test_snapshot_size() -> void:
	var s := _snap(0.0)
	s.ships.clear()
	for i in 30:
		s.ships.append({"id": i, "pos": Vector2(i, i), "rot": 0.1, "driver": -1, "parked": false, "glowing": false, "firing": 0xFFFF})
	assert_true(NetProtocol.pack_snapshot(s).size() < 600)


func test_ship_list_round_trip() -> void:
	var list: Array = [
		{"id": 0, "spec_path": "res://resources/ships/Milano.tres", "paint": 2, "headlight": 1, "tier": 3, "wants_retrieval": true},
		{"id": 4, "spec_path": "res://resources/ships/Other.tres", "paint": 0, "headlight": 0, "tier": 1, "wants_retrieval": false},
	]
	var u: Array = NetProtocol.unpack_ship_list(NetProtocol.pack_ship_list(list))
	assert_eq(u.size(), 2)
	for i in 2:
		assert_eq(u[i].id, list[i].id)
		assert_eq(u[i].spec_path, list[i].spec_path)
		assert_eq(u[i].paint, list[i].paint)
		assert_eq(u[i].headlight, list[i].headlight)
		assert_eq(u[i].tier, list[i].tier)
		assert_eq(u[i].wants_retrieval, list[i].wants_retrieval)


func test_ship_list_bay_round_trip() -> void:
	var list: Array = [
		{"id": 1, "spec_path": "res://resources/ships/Milano.tres", "paint": 2, "headlight": 1, "tier": 3, "wants_retrieval": true, "bay": 0},
		{"id": 2, "spec_path": "res://resources/ships/Miner.tres", "paint": 0, "headlight": 0, "tier": 3, "wants_retrieval": true, "bay": 1},
	]
	var u: Array = NetProtocol.unpack_ship_list(NetProtocol.pack_ship_list(list))
	assert_eq(u.size(), 2)
	assert_eq(u[0].bay, 0)
	assert_eq(u[1].bay, 1)
	assert_eq(u[1].spec_path, list[1].spec_path)


func test_buffer_interpolates() -> void:
	var b := SnapshotBuffer.new()
	b.push(_snap(0.0, 1), 1.0)
	b.push(_snap(100.0, 2), 1.1)
	assert_almost(b.sample(1.15).ships[0].pos.x, 50.0, 0.5)


func test_buffer_holds_when_starved() -> void:
	var b := SnapshotBuffer.new()
	b.push(_snap(0.0, 1), 1.0)
	b.push(_snap(100.0, 2), 1.1)
	assert_almost(b.sample(5.0).ships[0].pos.x, 100.0, 0.01)


func test_buffer_drops_old() -> void:
	var b := SnapshotBuffer.new()
	for i in 15:
		b.push(_snap(float(i), i), 1.0 + i * 0.05)
	assert_true(b.size() <= 10)


func test_oversized_ship_list_is_ignored() -> void:
	var p := StreamPeerBuffer.new()
	p.put_u16(60000)  # far more ships than any lot holds, and no data behind the count
	assert_eq(NetProtocol.unpack_ship_list(p.data_array), [])
	var short := NetProtocol.pack_ship_list([{"id": 1, "spec_path": "res://resources/ships/Milano.tres",
			"paint": 0, "headlight": 0, "tier": 0, "wants_retrieval": false}])
	short.resize(short.size() - 3)  # cut mid-entry
	short.encode_u16(0, 1)
	assert_eq(NetProtocol.unpack_ship_list(short), [], "a cut-off list is dropped")


func test_oversized_snapshot_is_ignored() -> void:
	var b := NetProtocol.pack_snapshot(_snap(10.0))
	var p := StreamPeerBuffer.new()
	p.data_array = b
	p.seek(4 + 4 + 8)
	var lit := p.get_u8()
	b.encode_u16(4 + 4 + 8 + 1 + lit, NetProtocol.MAX_SHIPS + 1)
	assert_eq(NetProtocol.unpack_snapshot(b), {}, "too many ships: ignored")
	var cut := NetProtocol.pack_snapshot(_snap(10.0))
	cut.resize(cut.size() - 5)
	assert_eq(NetProtocol.unpack_snapshot(cut), {}, "a cut-off snapshot is dropped")
	assert_eq(NetProtocol.unpack_snapshot(PackedByteArray()), {})
