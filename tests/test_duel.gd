extends TestCase

const DUEL := "res://scenes/levels/Duel.tscn"
const TEST_SAVE := "user://test_duel_save.cfg"


var _real_save := ""


## Adds a duel to the tree (members such as space pins are only parented in _ready, so a level
## freed outside the tree would leak them).
func _duel(minutes := 3) -> DuelLevel:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	var level: DuelLevel = load(DUEL).instantiate()
	level.minutes = minutes
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done(level: DuelLevel) -> void:
	level.free()
	GameState.save_path = _real_save


## Mean of a pillar's visual polygon, in lot coordinates.
func _centroid(pillar: Node2D) -> Vector2:
	var poly := pillar.get_node("Polygon2D") as Polygon2D
	var sum := Vector2.ZERO
	for p in poly.polygon:
		sum += p
	return pillar.position + sum / poly.polygon.size()


func test_duel_lot_layout() -> void:
	var level := await _duel()
	var spaces := level.get_node("Spaces").get_children()
	assert_eq(spaces.size(), 22)
	var light := 0
	var medium := 0
	var heavy := 0
	var gold := 0
	for space: ParkingSpace in spaces:
		if space.gold:
			gold += 1
			assert_eq(space.space_class, ShipSpec.ShipClass.MEDIUM)
			continue
		match space.space_class:
			ShipSpec.ShipClass.LIGHT: light += 1
			ShipSpec.ShipClass.MEDIUM: medium += 1
			ShipSpec.ShipClass.HEAVY: heavy += 1
	assert_eq(light, 8)
	assert_eq(medium, 8)
	assert_eq(heavy, 4)
	assert_eq(gold, 2)
	for k in range(1, 12):
		var left := level.get_node("Spaces/L%d" % k) as ParkingSpace
		var right := level.get_node("Spaces/R%d" % k) as ParkingSpace
		assert_true(left != null and right != null, "L%d and R%d exist" % [k, k])
		if left == null or right == null:
			continue
		assert_true(left.position.distance_to(Vector2(2400 - right.position.x, right.position.y)) <= 1.0,
				"R%d mirrors L%d" % [k, k])
		assert_eq(left.space_class, right.space_class)
		assert_eq(left.gold, right.gold)
	assert_true(level.get_node_or_null("Exit") is ExitPad)
	assert_true(level.get_node_or_null("Entrance") is Marker2D)
	assert_true(level.get_node("Pillars").get_child_count() >= 5)
	_done(level)


func test_duel_pillars_mirrored() -> void:
	var level := await _duel()
	var centroids: Array[Vector2] = []
	for pillar: Node2D in level.get_node("Pillars").get_children():
		centroids.append(_centroid(pillar))
	for c in centroids:
		var mirrored := Vector2(2400 - c.x, c.y)
		var found := false
		for other in centroids:
			if other.distance_to(mirrored) <= 2.0:
				found = true
		assert_true(found, "pillar at %s has a mirrored partner" % c)
	_done(level)


func test_duel_queue_follows_minutes() -> void:
	var level := await _duel(4)
	assert_eq(level.customer_queue.size(), 2 * DuelLevel.slots_per_bay(4), "both bays' slots")
	assert_true(level.ledger.endless)
	assert_almost(level.ledger.time_left, 240.0, 0.5)
	_done(level)


## A node's rectangle of the given size, as lot-space corners.
func _corners(node: Node2D, size: Vector2) -> PackedVector2Array:
	var xf := node.transform
	return PackedVector2Array([xf * (-size / 2), xf * Vector2(size.x / 2, -size.y / 2),
			xf * (size / 2), xf * Vector2(-size.x / 2, size.y / 2)])


func _world_polygon(pillar: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in (pillar.get_node("Polygon2D") as Polygon2D).polygon:
		points.append(pillar.position + p)
	return points


func test_duel_pillars_block_straight_route() -> void:
	var level := await _duel()
	for bay: String in ["Entrance", "EntranceR"]:
		var route := PackedVector2Array([level.get_node(bay).position, level.get_node("Exit").position])
		var blocked := false
		for pillar: Node2D in level.get_node("Pillars").get_children():
			if not Geometry2D.intersect_polyline_with_polygon(route, _world_polygon(pillar)).is_empty():
				blocked = true
		assert_true(blocked, "a pillar stands between %s and the exit" % bay)
	_done(level)


func test_duel_has_two_bays_and_black_hole() -> void:
	var level := await _duel()
	var left := level.get_node("Entrance") as Marker2D
	var right := level.get_node_or_null("EntranceR") as Marker2D
	assert_true(right != null, "a right bay")
	if right == null:
		_done(level)
		return
	assert_almost(right.position.x, 2400.0 - left.position.x, 1.0)
	assert_almost(right.position.y, left.position.y, 1.0)
	assert_almost(right.rotation, left.rotation, 0.01)
	assert_true(left.position.x < 1200.0, "the left bay is left of the centre line")
	assert_true(level.get_node_or_null("ArrivalBay") is ArrivalBay)
	var bay_r := level.get_node_or_null("ArrivalBayR") as ArrivalBay
	assert_true(bay_r != null, "the right bay is marked")
	if bay_r:
		assert_true(bay_r.global_position.distance_to(right.global_position) < 0.5)
	var hole := level.get_node_or_null("BlackHole") as BlackHole
	assert_true(hole != null, "a black hole")
	if hole:
		assert_almost(hole.position.x, 1200.0, 1.0)
		assert_true(hole.position.y > left.position.y, "below the bays")
	assert_true(level.get_node_or_null("Asteroids") == null, "no asteroids in the duel")
	_done(level)


## Gap between two pillars' visual outlines (approximate: centroid distance minus both radii).
func _radius(pillar: Node2D) -> float:
	var best := 0.0
	var c := _centroid(pillar)
	for p in _world_polygon(pillar):
		best = maxf(best, p.distance_to(c))
	return best


func test_duel_lanes_around_black_hole_and_bays() -> void:
	var level := await _duel()
	var hole := level.get_node("BlackHole") as Node2D
	var ring := BlackHole.CORE_RADIUS * 1.75  # the outermost accretion ring
	var bays: Array[PackedVector2Array] = [_corners(level.get_node("Entrance"), ArrivalBay.SIZE),
			_corners(level.get_node("EntranceR"), ArrivalBay.SIZE)]
	var pillars := level.get_node("Pillars").get_children()
	for pillar: Node2D in pillars:
		var c := _centroid(pillar)
		var r := _radius(pillar)
		assert_true(c.distance_to(hole.position) - r - ring >= 160.0,
				"%s leaves a 160 px lane around the black hole" % pillar.name)
		for bay in bays:
			var rect := Rect2(bay[0], Vector2.ZERO).expand(bay[2])
			var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
			assert_true(c.distance_to(nearest) - r >= 160.0, "%s leaves a 160 px lane around a bay" % pillar.name)
		for other: Node2D in pillars:
			if other != pillar:
				assert_true(c.distance_to(_centroid(other)) - r - _radius(other) >= 160.0,
						"%s and %s leave a 160 px lane" % [pillar.name, other.name])
	_done(level)


func test_duel_layout_clear_of_hud() -> void:
	var level := await _duel()
	var rects := {}  # name -> corners
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		rects[space.name] = _corners(space, space.size())
	rects["bay"] = _corners(level.get_node("Entrance"), ArrivalBay.SIZE)
	rects["bay R"] = _corners(level.get_node("EntranceR"), ArrivalBay.SIZE)
	rects["exit"] = _corners(level.get_node("Exit"), ExitPad.SIZE)
	for key: String in rects:
		for p: Vector2 in rects[key]:
			assert_true(p.y >= 300.0 - 0.5 and p.y <= 1320.0 + 0.5, "%s stays clear of the HUD (y %.0f)" % [key, p.y])
	_done(level)


# --- Host mode ---
# The host tests give the level a NetSession that never connects. NetSync then records every
# message in `sent` instead of sending it, and the level treats the guest's `loaded` as
# received straight away, so the countdown starts in _ready.

## A host duel with its own unconnected session (freed by _done_host).
func _host(seed := 0) -> DuelLevel:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	var level: DuelLevel = load(DUEL).instantiate()
	level.change_scene_on_end = false
	level.session = NetSession.new()
	level.match_seed = seed
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done_host(level: DuelLevel) -> void:
	var session := level.session
	level.free()
	session.free()
	GameState.save_path = _real_save


## Runs the 3-2-1 countdown out at once, which lets the first customer in.
func _skip_countdown(level: DuelLevel) -> void:
	level._physics_process(DuelLevel.COUNTDOWN + 0.01)


func _sync(level: DuelLevel) -> NetSync:
	return level.get_node("NetSync")


## The argument lists of every recorded message with this name, oldest first.
func _sent(level: DuelLevel, method: String) -> Array:
	var found := []
	for entry: Array in _sync(level).sent:
		if String(entry[0]) == method:
			found.append(entry[1])
	return found


func _first_ship(level: DuelLevel) -> Ship:
	return level.get_node("Ships").get_child(0)


## Puts the ship at rest in a free, non-gold space it fits.
func _park_spot(level: DuelLevel, ship: Ship) -> ParkingSpace:
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		if not space.gold and space.occupant == null \
				and ParkingRules.fits_class(ship.spec.ship_class, space.space_class):
			ship.freeze = true
			ship.global_position = space.global_position
			ship.global_rotation = space.global_rotation
			ship.linear_velocity = Vector2.ZERO
			ship.angular_velocity = 0.0
			return space
	return null


func test_host_adds_remote_valet() -> void:
	var level := await _host()
	assert_eq(level.valets.size(), 2)
	assert_false(level.valets[1].local)
	assert_true(level.valets[1].pilot is NetPilot)
	assert_true(level.valets[1].ledger != level.valets[0].ledger, "each valet keeps its own ledger")
	assert_true(level.valets[1].ledger.endless)
	assert_eq(_sent(level, "match_start").size(), 1)
	assert_eq(_sent(level, "go").size(), 1, "no guest to wait for: loaded counts as received")
	_done_host(level)


func test_guest_select_and_done_credit_guest() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	var v1 := level.valets[1]
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(v1.ship == ship)
	assert_true(level.driven_ship == null)
	assert_true(_park_spot(level, ship) != null)
	level._check_parking(0.016)
	assert_true(["ready"] in _sent(level, "event"), "the guest hears its own ready chime")
	_sync(level)._on_done()
	assert_true(ship.is_parked)
	assert_true(v1.ledger.earned > 0, "valet 1 earns")
	assert_eq(level.valets[0].ledger.earned, 0, "valet 0 doesn't")
	assert_true(["park"] in _sent(level, "event"))
	assert_true(["fee"] in _sent(level, "event"))
	_done_host(level)


func test_same_ship_first_request_wins() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	level.select_ship(ship)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(level.driven_ship == ship, "still the host's")
	assert_true(level.valets[1].ship == null)
	_sync(level)._on_select(9999)  # an unknown id is ignored
	assert_true(level.valets[1].ship == null)
	_done_host(level)


func test_rival_left_releases_ship() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(ship.is_driven)
	level.session.rival_left.emit()
	assert_false(ship.is_driven)
	assert_true(level.valets[1].ship == null)
	assert_eq(ship.ring_color, Color.TRANSPARENT)
	assert_true(level.rival_gone)
	_done_host(level)


func _flood_colors(level: DuelLevel) -> Array:
	var colors := []
	for light in level.get_node("Floodlights").get_children():
		colors.append((light as Floodlight).color)
	return colors


func test_seeded_lighting_matches() -> void:
	var a := await _host(4242)
	var first := _flood_colors(a)
	_done_host(a)
	var b := await _host(4242)
	assert_eq(_flood_colors(b), first)
	_done_host(b)


func test_countdown_holds_the_clock() -> void:
	var level := await _host()
	var start := level.ledger.time_left
	var rival_start := level.valets[1].ledger.time_left
	level._countdown_left = DuelLevel.COUNTDOWN  # engine frames during loading already counted some
	for i in 29:
		level._physics_process(0.1)
	assert_eq(level.ledger.time_left, start, "the clock waits for the countdown")
	assert_eq(level.valets[1].ledger.time_left, rival_start)
	assert_eq(level.get_node("Ships").get_child_count(), 0, "the first customers wait too")
	level._physics_process(0.2)  # the countdown ends
	assert_eq(level.get_node("Ships").get_child_count(), 2, "one customer arrives in each bay at go")
	level._physics_process(0.5)
	assert_true(level.ledger.time_left < start, "the shift runs after go")
	_done_host(level)


func test_driver_rings() -> void:
	var level := await _host()
	_skip_countdown(level)
	var mine := _first_ship(level)
	var theirs := level.spawn_next_customer()
	level.select_ship(mine)
	_sync(level)._on_select(level.ship_id(theirs))
	assert_eq(mine.ring_color, HexStyle.CYAN)
	assert_eq(theirs.ring_color, HexStyle.MAGENTA)
	level.release_ship()
	assert_eq(mine.ring_color, Color.TRANSPARENT, "cleared on release")
	_done_host(level)


func test_dent_charged_to_driving_valet() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	_sync(level)._on_select(level.ship_id(ship))
	level._on_ship_dented(ship, 10)
	assert_eq(level.valets[1].ledger.pay, -10, "the driver pays")
	assert_eq(level.valets[0].ledger.pay, 0)
	assert_true(["dent"] in _sent(level, "event"))
	_sync(level)._on_done()  # let go, not in a space
	assert_false(ship.is_driven)
	level._on_ship_dented(ship, 10)
	assert_eq(level.valets[1].ledger.pay, -20, "an undriven ship falls back to its last driver")
	assert_eq(level.valets[0].ledger.pay, 0)
	_done_host(level)


func test_knocked_ship_crash_charges_knocker() -> void:
	var level := await _host()
	_skip_countdown(level)
	var b := _first_ship(level)
	level.select_ship(b)  # valet 0 parks B...
	var space := _park_spot(level, b)
	assert_true(space != null)
	level._check_parking(0.016)
	level.press_done()
	assert_true(b.is_parked)
	level._request(b)  # ...then its owner wants it back: undriven and unparked
	assert_false(b.is_parked)
	assert_false(b.is_driven)
	var a := level.spawn_next_customer()
	_sync(level)._on_select(level.ship_id(a))  # valet 1 drives A
	assert_true(level.valets[1].ship == a)
	b.blame_from(a)  # A knocks B
	var pay0 := level.valets[0].ledger.pay
	b.dented.emit(b, 20)
	assert_eq(level.valets[1].ledger.pay, -20, "the knocker pays")
	assert_eq(level.valets[0].ledger.pay, pay0, "the valet who parked it doesn't")
	_done_host(level)


func test_knocked_ship_into_driven_rival_charges_rammer() -> void:
	var level := await _host()
	_skip_countdown(level)
	var k := _first_ship(level)
	var d := level.spawn_next_customer()
	level.select_ship(d)  # valet 0 drives D, slowly
	k.last_driver = 1  # K was knocked by valet 1...
	k._physics_process(0.0)
	k._prev_velocity = Vector2(300, 0)  # ...and flies into D
	d._prev_velocity = Vector2.ZERO
	var pay0 := level.valets[0].ledger.pay
	k._on_body_entered(d)
	d._on_body_entered(k)
	var cost := ShiftLedger.dent_cost(300.0)
	assert_true(cost > 0)
	assert_eq(level.valets[1].ledger.pay, -cost, "the rammer pays")
	assert_eq(level.valets[0].ledger.pay, pay0, "the driven victim doesn't")
	_done_host(level)


func test_exit_handover_credits_the_driver() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	var id := level.ship_id(ship)
	var c := level.customer_for(ship)
	c.tier = Customer.Tier.SILVER
	c.parked_once = true
	c.requested = true  # the customer wants it back
	level.select_ship(ship)  # the host drives it first...
	level.release_ship()
	level.valets[1].released_at_msec = -Level.RESELECT_DELAY_MS
	_sync(level)._on_select(id)  # ...the guest takes it onto the EXIT
	assert_true(level.valets[1].ship == ship)
	ship.freeze = true
	ship.global_position = level.get_node("Exit").global_position
	level._update_customers(0.0)
	assert_eq(level.valets[1].ledger.tips, Customer.SILVER_TIP, "the valet on the EXIT is paid")
	assert_eq(level.valets[0].ledger.tips, 0)
	assert_true([id] in _sent(level, "ship_removed"))
	_done_host(level)


func test_host_streams_ship_list_and_snapshots() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	var added: Array = _sent(level, "ship_added")
	assert_eq(added.size(), 2, "one per bay")
	var entry: Dictionary = NetProtocol.unpack_ship_list(added[0][0])[0]
	assert_eq(entry.id, level.ship_id(ship))
	assert_eq(entry.bay, 0)
	assert_eq(NetProtocol.unpack_ship_list(added[1][0])[0].bay, 1)
	assert_eq(entry.spec_path, ship.spec.resource_path)
	assert_eq(entry.paint, ship.paint_index)
	assert_eq(entry.headlight, ship.headlight_index)
	_sync(level)._on_select(level.ship_id(ship))
	level.valets[1].ledger.add_tip(7)
	level._physics_process(DuelLevel.SNAPSHOT_INTERVAL + 0.001)
	var snaps: Array = _sent(level, "snapshot")
	assert_true(snaps.size() > 0)
	var snap := NetProtocol.unpack_snapshot(snaps[-1][0])
	assert_eq(snap.scores[1], 7)
	assert_eq(snap.ships.size(), 2)
	assert_eq(snap.ships[0].driver, 1)
	assert_eq(snap.lit.size(), 22)
	_done_host(level)


func test_guest_input_reaches_its_pilot() -> void:
	var level := await _host()
	_skip_countdown(level)
	_sync(level).guest_bits = 1  # thrust_forward
	level._physics_process(0.016)
	assert_true((level.valets[1].pilot as NetPilot).is_pressed(&"thrust_forward"))
	_done_host(level)


func test_timeout_ends_the_match() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ended := []
	level.match_ended.connect(func(mine: int, rival: int) -> void: ended.append([mine, rival]))
	level.valets[1].ledger.add_tip(30)
	level.ledger.time_left = 0.05
	level.valets[1].ledger.time_left = 0.05
	level._physics_process(0.1)
	assert_eq(ended, [[0, 30]])
	assert_eq(_sent(level, "match_end"), [[0, 30]])
	_done_host(level)


func test_duel_hud_scores() -> void:
	var level := await _host()
	level.valets[1].ledger.add_tip(12)
	level._refresh()
	assert_eq(level.get_node("HUD/Root/Pay").text, "You ₵0 · Rival ₵12")
	var customers: Label = level.get_node("HUD/Root/Customers")
	assert_true(customers.visible)
	assert_eq(customers.text, "Customers left %d" % level.customer_queue.size())
	_done_host(level)


# --- Opened from the lobby (GameState.duel_role set) ---

## A lobby-opened host duel. listen = its session really listens (is_active), else it's closed.
func _lobby_duel(listen: bool, port := 24612) -> DuelLevel:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	GameState.duel_role = "host"
	GameState.notice = ""
	GameState.duel_result = {}
	var session := NetSession.new()
	session.port = port
	tree.root.add_child(session)
	if listen:
		assert_eq(session.host(), OK)
	var level: DuelLevel = load(DUEL).instantiate()
	level.change_scene_on_end = false
	level.session = session
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done_lobby(level: DuelLevel) -> void:
	var session := level.session
	level.free()
	session.close()
	session.free()
	GameState.save_path = _real_save
	GameState.duel_role = ""
	GameState.notice = ""
	GameState.duel_result = {}


func test_lobby_duel_with_dropped_rival_starts_no_match() -> void:
	var level := await _lobby_duel(false)
	assert_eq(GameState.notice, "Your rival left the match")
	assert_eq(GameState.duel_role, "")
	assert_true(level._ended, "the lot is over before it starts")
	var left := level.ledger.time_left
	level._physics_process(DuelLevel.COUNTDOWN + 1.0)
	for i in 5:
		await tree.physics_frame
	assert_eq(level.get_node("Ships").get_child_count(), 0, "no solo match: no ships")
	assert_almost(level.ledger.time_left, left, 0.001)
	_done_lobby(level)


func test_lobby_duel_rival_left_goes_to_mode_select() -> void:
	var level := await _lobby_duel(true, 24613)
	assert_false(level._ended, "a live session starts the duel")
	assert_eq(GameState.notice, "")
	level.session.rival_left.emit()
	assert_eq(GameState.notice, "Your rival left the match")
	assert_eq(GameState.duel_role, "")
	assert_true(level._ended)
	_done_lobby(level)


func test_lobby_duel_end_fills_duel_result() -> void:
	var level := await _lobby_duel(true, 24614)
	level.on_guest_loaded()
	_skip_countdown(level)
	level.ledger.add_tip(40)
	level.valets[1].ledger.add_tip(15)
	level.end_level()
	assert_eq(GameState.duel_result, {"mine": 40, "rival": 15})
	_done_lobby(level)


func test_every_duel_ship_leaves() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ships: Array[Ship] = [_first_ship(level)]
	for i in 4:
		ships.append(level.spawn_next_customer())
	for ship in ships:
		assert_true(level.customer_for(ship).wants_retrieval, "every duel customer wants their ship back")
	assert_true(level.allow_moving_parked)
	level.select_ship(ships[0])
	assert_true(_park_spot(level, ships[0]) != null)
	level._check_parking(0.016)
	level.press_done()
	var wait := level.customer_for(ships[0]).request_in
	assert_true(wait >= 20.0 and wait <= 30.0, "request in 20-30 s, got %.1f" % wait)
	_done_host(level)


func test_moving_parked_pays_nothing() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(_park_spot(level, ship) != null)
	level._check_parking(0.016)
	_sync(level)._on_done()
	assert_true(ship.is_parked)
	var fee := level.valets[1].ledger.earnings()
	assert_true(fee > 0)
	var c := level.customer_for(ship)
	level._update_customers(1.0)
	var counting := c.request_in
	level.valets[0].released_at_msec = -10000
	level.select_ship(ship)  # valet 0 picks the parked ship up
	assert_false(ship.is_parked)
	assert_true(level.valets[0].ship == ship)
	assert_eq(c.request_in, counting, "picking it up doesn't reset the countdown")
	level._update_customers(1.0)
	assert_almost(c.request_in, counting - 1.0, 0.001)
	assert_true(_park_spot(level, ship) != null)
	level._check_parking(0.016)
	level.press_done()
	assert_true(ship.is_parked)
	assert_eq(level.valets[1].ledger.earnings(), fee, "no second fee")
	assert_eq(level.valets[0].ledger.earnings(), 0, "the mover earns nothing")
	assert_almost(c.request_in, counting - 1.0, 0.001)
	_done_host(level)


func test_rival_cannot_take_driven_parked_move() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(_park_spot(level, ship) != null)
	level._check_parking(0.016)
	_sync(level)._on_done()
	assert_true(ship.is_parked)
	level.valets[0].released_at_msec = -10000
	level.select_ship(ship)
	assert_true(level.valets[0].ship == ship)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(level.valets[1].ship == null, "the rival can't take a ship being moved")
	assert_true(level.valets[0].ship == ship)
	_done_host(level)


# --- Two paired bays ---

func _pool() -> Array[ShipSpec]:
	var pool: Array[ShipSpec] = []
	for ship_name in ["AsteroidJunker", "ManipulatorDrone", "ReconDrone", "RecreationalDrone", "Milano",
			"Miner", "Nostrom", "AgriShip", "Hammerhead", "Researcher"]:
		pool.append(ship_spec(ship_name))
	return pool


func _slot_list(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var no_gold_for_heavy := func(ship_class: int) -> bool: return ship_class != ShipSpec.ShipClass.HEAVY
	return BaySlots.build(_pool(), 30, rng, no_gold_for_heavy, true, {})


func test_bay_slots_pair_class_and_tier() -> void:
	var slots := _slot_list(777)
	assert_eq(slots.size(), 30)
	var models_differ := false
	for pair: Array in slots:
		assert_eq(pair.size(), 2)
		var a: Dictionary = pair[0]
		var b: Dictionary = pair[1]
		assert_eq(a.spec.ship_class, b.spec.ship_class, "same class in both bays")
		assert_eq(a.tier, b.tier, "same tier in both bays")
		assert_true(a.tier != Customer.Tier.NONE, "tiers in use")
		if a.spec.ship_class == ShipSpec.ShipClass.HEAVY:
			assert_true(a.tier != Customer.Tier.GOLD, "gold only where gold_allowed says so")
		if a.spec != b.spec:
			models_differ = true
	assert_true(models_differ, "each bay draws its own model")
	var again := _slot_list(777)
	for i in slots.size():
		for bay in 2:
			assert_eq(again[i][bay].spec, slots[i][bay].spec, "the same seed, the same slots")
			assert_eq(again[i][bay].tier, slots[i][bay].tier)


func test_slots_per_bay() -> void:
	assert_eq(DuelLevel.slots_per_bay(3), 21)
	assert_eq(DuelLevel.slots_per_bay(20), 123)


## Moves every ship sitting in a bay (but the kept one) out to the lot floor.
func _clear_bays(level: DuelLevel, keep: Ship, dumped: Array) -> void:
	for ship: Ship in level.get_node("Ships").get_children():
		if ship == keep or ship in dumped:
			continue
		ship.freeze = true
		ship.global_position = Vector2(300.0 + 40.0 * dumped.size(), 1040.0)
		dumped.append(ship)


func test_camped_bay_catches_up() -> void:
	var level := await _host()
	_skip_countdown(level)
	assert_eq(level.bay_index(0), 1)
	assert_eq(level.bay_index(1), 1)
	var blocker: Ship = null
	for ship: Ship in level.get_node("Ships").get_children():
		if level.bay_of(ship) == 1:
			blocker = ship
	assert_true(blocker != null)
	blocker.freeze = true
	var dumped := []
	var step := 0.1
	var t := 0.0
	var spawned_at := [[0.0], [0.0]]  # per bay: shift seconds of each arrival
	var last := [level.bay_index(0), level.bay_index(1)]
	var freed_at := -1.0
	while t < 120.0:
		_clear_bays(level, blocker, dumped)
		level._physics_process(step)
		t += step
		for bay in 2:
			if level.bay_index(bay) != last[bay]:
				assert_eq(level.bay_index(bay), last[bay] + 1, "one slot at a time, none skipped")
				last[bay] = level.bay_index(bay)
				spawned_at[bay].append(t)
		if freed_at < 0.0 and level.bay_index(0) >= 4:
			assert_eq(level.bay_index(1), 1, "the camped bay waited")
			blocker.global_position = Vector2(1900.0, 1040.0)  # the camper drives off
			dumped.append(blocker)
			blocker = null
			freed_at = t
		elif freed_at >= 0.0 and level.bay_index(1) >= level.bay_index(0):
			break
	assert_true(freed_at > 0.0, "bay L spawned three slots")
	assert_eq(level.bay_index(1), level.bay_index(0), "bay R caught up")
	var catch_up: Array = spawned_at[1].slice(1)
	assert_true(catch_up.size() >= 3, "bay R spawned its missed slots: %s" % [catch_up])
	var previous := freed_at
	for at: float in catch_up:
		assert_true(at - previous <= Level.ARRIVAL_CLEAR_SECONDS + 0.25,
				"a catching-up bay only waits for a clear bay (%.2f s)" % (at - previous))
		previous = at
	for bay in 2:
		for i in range(1, spawned_at[bay].size()):
			assert_true(spawned_at[bay][i] - spawned_at[bay][i - 1] >= Level.ARRIVAL_CLEAR_SECONDS - 0.001,
					"bay %d never spawns twice within the clear time" % bay)
	# Level again: bay R goes back to its interval.
	var index: int = level.bay_index(1)
	for i in 30:
		_clear_bays(level, null, dumped)
		level._physics_process(step)
	assert_true(level.bay_index(1) <= level.bay_index(0), "bay R never runs ahead of bay L")
	assert_eq(level.bay_index(1), index, "caught up, bay R waits for its interval again")
	_done_host(level)


func test_duel_black_hole_pulls_driven_ship() -> void:
	var level := await _host()
	_skip_countdown(level)
	var hole := level.get_node("BlackHole") as Node2D
	var ship := _first_ship(level)
	level.select_ship(ship)
	assert_true(level.driven_ship == ship)
	ship.global_position = hole.global_position + Vector2(-190, 60)
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0
	await tree.physics_frame
	var start := ship.global_position.distance_to(hole.global_position)
	for i in 30:
		await tree.physics_frame
	var now := ship.global_position.distance_to(hole.global_position)
	assert_true(now < start - 1.0, "the hole pulled the driven ship (%.1f -> %.1f px)" % [start, now])
	_done_host(level)


## A guest-role duel with its own unconnected session (freed by _done_host).
func _guest() -> DuelLevel:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	var level: DuelLevel = load(DUEL).instantiate()
	level.change_scene_on_end = false
	level.session = NetSession.new()
	level.role = DuelLevel.Role.GUEST
	tree.root.add_child(level)
	await tree.process_frame
	return level


func test_guest_mirror_does_not_simulate_black_hole() -> void:
	var level := await _guest()
	assert_true(level.get_node_or_null("BlackHole") is BlackHole, "the guest draws the black hole")
	assert_true(level.get_node_or_null("ArrivalBayR") is ArrivalBay, "and both bays")
	var mirror := level.mirror
	mirror.add_ships([{"id": 3, "spec_path": "res://resources/ships/Milano.tres", "paint": 1, "headlight": 0,
			"tier": 2, "wants_retrieval": true, "bay": 1}])
	var ship := mirror.ship_by_id(3)
	assert_true(ship != null)
	var right := level.get_node("EntranceR") as Node2D
	assert_true(ship.global_position.distance_to(right.global_position) < 0.5, "it arrives at bay R")
	var hole := level.get_node("BlackHole") as Node2D
	var spot := hole.global_position + Vector2(BlackHole.FLING_RADIUS * 0.5, 0.0)  # inside the core
	ship.driven_since_free = true
	mirror.on_snapshot({"tick": 1, "time_left": 100.0, "scores": PackedInt32Array([0, 0]),
			"lit": PackedInt32Array(), "ships": [{"id": 3, "pos": spot, "rot": 0.25, "driver": 0,
			"parked": false, "glowing": false, "firing": 0}]})
	assert_false(level.is_physics_processing(), "the guest lot runs no shift physics")
	assert_false(ship.is_physics_processing(), "nor do its mirror ships")
	for i in 30:
		await tree.physics_frame
	assert_eq(ship.global_position, spot, "the mirror stays exactly where the snapshot puts it")
	assert_false(level._flung_at.has(ship), "the core never flung it")
	assert_eq(ship.linear_velocity, Vector2.ZERO)
	_done_host(level)


## A mirror ship from the host's ship list, already placed by a snapshot.
func _mirror_ship(level: DuelLevel, id: int, parked: bool) -> Ship:
	level.mirror.add_ships([{"id": id, "spec_path": "res://resources/ships/Milano.tres", "paint": 1,
			"headlight": 0, "tier": 2, "wants_retrieval": true, "bay": 0}], false)
	var ship := level.mirror.ship_by_id(id)
	level.mirror._show_parked(ship, parked)
	return ship


func _tap_on(level: DuelLevel, ship: Ship) -> void:
	level.handle_lot_tap(level.get_canvas_transform() * ship.global_position)


func test_guest_tap_on_parked_ship_asks_the_host() -> void:
	var level := await _guest()
	var ship := _mirror_ship(level, 5, true)
	assert_true(ship.is_parked)
	_tap_on(level, ship)
	assert_eq(_sent(level, "select"), [[5]], "a parked customer ship can be asked for")
	_done_host(level)


func test_guest_tap_on_moving_ship_asks_the_host() -> void:
	var level := await _guest()
	var ship := _mirror_ship(level, 6, false)
	_tap_on(level, ship)
	assert_eq(_sent(level, "select"), [[6]])
	_done_host(level)


func test_guest_done_asks_the_host() -> void:
	var level := await _guest()
	level.press_done()
	assert_eq(_sent(level, "done"), [[]])
	_done_host(level)


func test_guest_remove_ship_of_freed_ship_drops_its_keys() -> void:
	var level := await _guest()
	var ship := _mirror_ship(level, 7, false)
	ship.get_parent().remove_child(ship)
	ship.free()
	level.mirror.remove_ship(7)
	assert_eq(level.mirror._mirrors.size(), 0)
	assert_eq(level.mirror._ids.size(), 0, "no stale key for the freed ship")
	_done_host(level)


func test_guest_picker_closes_only_for_its_ships() -> void:
	var level := await _guest()
	var listed := _mirror_ship(level, 8, false)
	_mirror_ship(level, 9, false)
	var picker := level.get_node("ShipPicker") as ShipPicker
	picker.open([listed] as Array[Ship], Vector2(400, 300))
	level.mirror.remove_ship(9)
	assert_true(picker.is_open(), "another ship leaving keeps the list")
	level.mirror.remove_ship(8)
	assert_false(picker.is_open(), "a listed ship leaving closes it")
	_done_host(level)


func test_host_picker_closes_only_for_its_ships() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ships := level.get_node("Ships").get_children()
	assert_true(ships.size() >= 2, "a ship from each bay")
	var listed: Ship = ships[0]
	var other: Ship = ships[1]
	var picker := level.get_node("ShipPicker") as ShipPicker
	picker.open([listed] as Array[Ship], Vector2(400, 300))
	level._return(other)
	assert_true(picker.is_open(), "the rival's ship leaving keeps the list")
	level._return(listed)
	assert_false(picker.is_open(), "a listed ship leaving closes it")
	_done_host(level)


func test_request_on_driven_ship_keeps_the_pull() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	level.select_ship(ship)
	assert_true(ship.driven_since_free)
	level._request(ship)
	assert_true(ship.driven_since_free, "the hole keeps pulling a ship someone drives")
	assert_true(level.customer_for(ship).requested)
	_done_host(level)


func test_request_on_parked_ship_unparks_it() -> void:
	var level := await _host()
	_skip_countdown(level)
	var ship := _first_ship(level)
	_sync(level)._on_select(level.ship_id(ship))
	assert_true(_park_spot(level, ship) != null)
	level._check_parking(0.016)
	_sync(level)._on_done()
	assert_true(ship.is_parked)
	level._request(ship)
	assert_false(ship.is_parked)
	assert_false(ship.driven_since_free, "a parked ship waits to be picked up again")
	_done_host(level)


func test_flung_at_forgets_freed_ships() -> void:
	var level := await _host()
	var gone := Node2D.new()
	level._flung_at[gone] = 0
	gone.free()
	level._fling_from_core()
	assert_eq(level._flung_at.size(), 0, "freed ships are pruned")
	_done_host(level)


func test_net_pilot_actions_follow_drive_actions() -> void:
	var expected: Array[StringName] = []
	for a in Ship.DRIVE_ACTIONS:
		expected.append(StringName(a))
	expected.append(&"brake")
	expected.append(&"stop_rotation")
	assert_eq(NetPilot.ACTIONS, expected)


func test_scene_loads_use_the_long_silence_limit() -> void:
	var level := await _lobby_duel(true, 24615)
	var session := level.session
	session.loading = true  # as if the handshake just finished and this lot was loading
	level.on_guest_loaded()
	assert_false(session.loading, "the guest's loaded ends the load grace on the host")
	_skip_countdown(level)
	level.end_level()
	assert_true(session.loading, "the result screen and any rematch reload get the grace again")
	_done_lobby(level)


func test_guest_go_ends_the_load_grace() -> void:
	var level := await _guest()
	level.session.loading = true
	level.mirror.on_go()
	assert_false(level.session.loading)
	_done_host(level)


func test_net_sync_ignores_rpc_without_multiplayer() -> void:
	var root := Node.new()
	root.name = "SyncRoot"
	tree.root.add_child(root)
	tree.set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session := NetSession.new()
	session.port = 24608
	root.add_child(session)
	assert_eq(session.host(), OK)
	var sync := NetSync.new()  # outside the tree: its multiplayer is null, like a node being freed
	sync.session = session
	sync.input(5)
	assert_eq(sync.guest_bits, 0, "ignored")
	session.close()
	sync.input(6)  # and with the session closed
	assert_eq(sync.guest_bits, 0)
	sync.free()
	tree.set_multiplayer(null, root.get_path())
	root.free()
