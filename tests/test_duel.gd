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
	assert_eq(level.customer_queue.size(), GameState.duel_customers(4))
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
	var route := PackedVector2Array([level.get_node("Entrance").position, level.get_node("Exit").position])
	var blocked := false
	for pillar: Node2D in level.get_node("Pillars").get_children():
		if not Geometry2D.intersect_polyline_with_polygon(route, _world_polygon(pillar)).is_empty():
			blocked = true
	assert_true(blocked, "a pillar stands between the entrance and the exit")
	_done(level)


func test_duel_layout_clear_of_hud() -> void:
	var level := await _duel()
	var rects := {}  # name -> corners
	for space: ParkingSpace in level.get_node("Spaces").get_children():
		rects[space.name] = _corners(space, space.size())
	rects["bay"] = _corners(level.get_node("Entrance"), ArrivalBay.SIZE)
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
	assert_eq(level.get_node("Ships").get_child_count(), 0, "the first customer waits too")
	level._physics_process(0.2)  # the countdown ends
	assert_eq(level.get_node("Ships").get_child_count(), 1, "the first customer arrives at go")
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
	assert_eq(added.size(), 1)
	var entry: Dictionary = NetProtocol.unpack_ship_list(added[0][0])[0]
	assert_eq(entry.id, level.ship_id(ship))
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
	assert_eq(snap.ships.size(), 1)
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
