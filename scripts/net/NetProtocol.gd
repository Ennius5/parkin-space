class_name NetProtocol
extends RefCounted
## Binary layouts for the duel's network messages (pure functions, no networking).

const FLAG_PARKED := 4
const FLAG_GLOWING := 8
const MAX_SHIPS := 512  # a guest ignores a snapshot or ship list claiming more ships than this
const SNAPSHOT_HEADER := 4 + 4 + 4 + 4 + 1  # tick, time_left, two scores, lit count
const SNAPSHOT_SHIP := 2 + 4 + 4 + 4 + 1 + 2  # id, x, y, rot, flags, firing
const SHIP_ENTRY_MIN := 2 + 4 + 5  # id, string length, five bytes (the name may be empty)


## Packs a snapshot dictionary (tick, time_left, scores, lit, ships) into bytes.
static func pack_snapshot(s: Dictionary) -> PackedByteArray:
	var p := StreamPeerBuffer.new()
	p.put_u32(int(s.tick))
	p.put_float(float(s.time_left))
	var scores: PackedInt32Array = s.scores
	p.put_32(scores[0])
	p.put_32(scores[1])
	var lit: PackedInt32Array = s.lit
	p.put_u8(lit.size())
	for v in lit:
		p.put_8(v)
	var ships: Array = s.ships
	p.put_u16(ships.size())
	for ship: Dictionary in ships:
		p.put_u16(int(ship.id))
		var pos: Vector2 = ship.pos
		p.put_float(pos.x)
		p.put_float(pos.y)
		p.put_float(float(ship.rot))
		# flags: bits 0-1 driver+1, bit 2 parked, bit 3 glowing
		var flags: int = int(ship.driver) + 1
		if ship.parked:
			flags |= FLAG_PARKED
		if ship.glowing:
			flags |= FLAG_GLOWING
		p.put_u8(flags)
		p.put_u16(int(ship.firing))
	return p.data_array


## Unpacks bytes made by pack_snapshot. {} when the bytes are short or claim more than
## MAX_SHIPS ships (a bad packet must not make the guest loop or allocate without bound).
static func unpack_snapshot(b: PackedByteArray) -> Dictionary:
	if b.size() < SNAPSHOT_HEADER:
		return {}
	var p := StreamPeerBuffer.new()
	p.data_array = b
	var s := {}
	s.tick = p.get_u32()
	s.time_left = p.get_float()
	s.scores = PackedInt32Array([p.get_32(), p.get_32()])
	var lit_count := p.get_u8()  # u8: never more than 255 spaces
	if p.get_available_bytes() < lit_count + 2:
		return {}
	var lit := PackedInt32Array()
	for i in lit_count:
		lit.append(p.get_8())
	s.lit = lit
	var count := p.get_u16()
	if count > MAX_SHIPS or p.get_available_bytes() < count * SNAPSHOT_SHIP:
		return {}
	var ships: Array = []
	for i in count:
		var ship := {}
		ship.id = p.get_u16()
		var x := p.get_float()
		var y := p.get_float()
		ship.pos = Vector2(x, y)
		ship.rot = p.get_float()
		var flags := p.get_u8()
		ship.driver = (flags & 3) - 1
		ship.parked = (flags & FLAG_PARKED) != 0
		ship.glowing = (flags & FLAG_GLOWING) != 0
		ship.firing = p.get_u16()
		ships.append(ship)
	s.ships = ships
	return s


## Packs the ship list (id, spec_path, paint, headlight, tier, wants_retrieval, bay).
static func pack_ship_list(ships: Array) -> PackedByteArray:
	var p := StreamPeerBuffer.new()
	p.put_u16(ships.size())
	for e: Dictionary in ships:
		p.put_u16(int(e.id))
		p.put_utf8_string(String(e.spec_path))
		p.put_u8(int(e.paint))
		p.put_u8(int(e.headlight))
		p.put_u8(int(e.tier))
		p.put_u8(1 if e.wants_retrieval else 0)
		p.put_u8(int(e.get("bay", 0)))  # the arrival bay: 0 = left, 1 = right
	return p.data_array


## Unpacks bytes made by pack_ship_list. [] when the bytes are short or claim more than
## MAX_SHIPS ships.
static func unpack_ship_list(b: PackedByteArray) -> Array:
	if b.size() < 2:
		return []
	var p := StreamPeerBuffer.new()
	p.data_array = b
	var count := p.get_u16()
	if count > MAX_SHIPS or p.get_available_bytes() < count * SHIP_ENTRY_MIN:
		return []
	var out: Array = []
	for i in count:
		if p.get_available_bytes() < SHIP_ENTRY_MIN:
			return []
		var e := {}
		e.id = p.get_u16()
		var name_size := p.get_u32()
		if p.get_available_bytes() < name_size + 5:
			return []
		e.spec_path = p.get_utf8_string(name_size)
		e.paint = p.get_u8()
		e.headlight = p.get_u8()
		e.tier = p.get_u8()
		e.wants_retrieval = p.get_u8() != 0
		e.bay = p.get_u8()
		out.append(e)
	return out
