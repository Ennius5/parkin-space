extends TestCase
## A whole duel over 127.0.0.1 in one process: a host and a guest, each under its own root with
## its own SceneMultiplayer, so NetSync's RPCs travel through real ENet peers.

const DUEL := "res://scenes/levels/Duel.tscn"
const TEST_SAVE := "user://test_duel_loopback_save.cfg"
const PORT := 24601

var _real_save := ""
var _roots: Array[Node] = []


## A root with its own SceneMultiplayer and a NetSession at <root>/Session.
func _side(root_name: String) -> NetSession:
	var root := Node.new()
	root.name = root_name
	tree.root.add_child(root)
	tree.set_multiplayer(SceneMultiplayer.new(), root.get_path())
	_roots.append(root)
	var s := NetSession.new()
	s.name = "Session"
	s.port = PORT
	root.add_child(s)
	return s


## A duel at <root>/DuelLevel (the same relative path on both sides) using that root's session.
func _level(session: NetSession, role: DuelLevel.Role) -> DuelLevel:
	var level: DuelLevel = load(DUEL).instantiate()
	level.name = "DuelLevel"
	level.role = role
	level.minutes = 3
	level.change_scene_on_end = false
	level.session = session
	session.get_parent().add_child(level)
	return level


## Closes both sessions and frees both roots, whatever state the test stopped in.
func _cleanup() -> void:
	Input.action_release(&"thrust_forward")
	for root in _roots:
		var s := root.get_node_or_null("Session") as NetSession
		if s:
			s.close()
	for root in _roots:
		tree.set_multiplayer(null, root.get_path())
		root.free()
	_roots.clear()
	GameState.save_path = _real_save


## Awaits process frames until cond is true or the wall-clock budget runs out.
func _wait_seconds(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


func _physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _first_ship(level: DuelLevel) -> Ship:
	var ships := level.get_node("Ships")
	return ships.get_child(0) as Ship if ships.get_child_count() > 0 else null


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


func test_loopback_match() -> void:
	_real_save = GameState.save_path
	GameState.save_path = TEST_SAVE
	var host_session := _side("H")
	var guest_session := _side("G")
	assert_eq(host_session.host(), OK)
	assert_eq(guest_session.join("127.0.0.1"), OK)
	var linked: bool = await _wait_seconds(func() -> bool:
		return host_session.rival_id() != 0 and guest_session.rival_id() != 0, 5.0)
	assert_true(linked, "sessions connected")
	if not linked:
		_cleanup()
		return
	var guest := _level(guest_session, DuelLevel.Role.GUEST)  # first, so it hears match_start
	var host := _level(host_session, DuelLevel.Role.HOST)
	var guest_sync: NetSync = guest.get_node("NetSync")

	# The ship list reaches the guest once the countdown lets the first customer in.
	var listed: bool = await _wait_seconds(func() -> bool:
		return _first_ship(host) != null and _first_ship(guest) != null, 10.0)
	assert_true(listed, "the guest mirrors the first ship")
	if not listed:
		_cleanup()
		return
	var ship := _first_ship(host)
	var mirror := _first_ship(guest)
	assert_eq(mirror.spec.resource_path, ship.spec.resource_path)
	assert_true(mirror.freeze, "mirror ships are frozen")
	assert_eq(mirror.collision_layer, 0)
	assert_eq(mirror.collision_mask, 0)
	assert_false(mirror.contact_monitor)

	# The guest asks for it and drives it through the host.
	guest_sync.send(&"select", [host.ship_id(ship)])
	var taken: bool = await _wait_seconds(func() -> bool:
		return ship.last_driver == 1 and guest.driven_ship == mirror, 5.0)
	assert_true(taken, "the host gave the guest the ship, and the guest sees it")
	if not taken:
		_cleanup()
		return
	assert_true(guest.get_node("Controls/Buttons").visible, "the guest's controls show while it drives")
	assert_true((mirror.get_node("DriveCamera") as Camera2D).is_current(), "the guest's camera follows its mirror")
	assert_false(ship.get_node("DriveCamera").is_current(), "the host's ship didn't take the camera")
	var start := ship.global_position
	Input.action_press(&"thrust_forward")
	await _physics_frames(30)
	Input.action_release(&"thrust_forward")
	assert_true(ship.global_position.distance_to(start) > 5.0,
			"the guest's thrust moved the host's ship (%.1f px)" % ship.global_position.distance_to(start))
	await _physics_frames(20)
	var gap := mirror.global_position.distance_to(ship.global_position)
	assert_true(gap <= 40.0, "the mirror follows the host's ship (%.1f px apart)" % gap)

	# The host parks it for the guest; the guest's HUD shows the guest's earnings.
	assert_true(_park_spot(host, ship) != null)
	host._check_parking(0.016)
	host.press_done(host.valets[1])
	var earned := host.valets[1].ledger.earnings()
	assert_true(earned > 0, "the guest earned the fee")
	var pay: Label = guest.get_node("HUD/Root/Pay")
	var shown: bool = await _wait_seconds(func() -> bool:
		return pay.text.begins_with("You ₵%d " % earned), 3.0)
	assert_true(shown, "guest HUD shows its own score first: %s" % pay.text)
	assert_true(mirror.is_parked, "the mirror looks parked")
	assert_true(guest.driven_ship == null, "the guest no longer drives it")
	assert_false(guest.get_node("Controls/Buttons").visible)

	assert_eq((guest.get_node("Walls/WallTop") as StaticBody2D).collision_layer, 0)
	assert_eq((guest.get_node("Walls/WallTop") as StaticBody2D).collision_mask, 0)

	# The guest leaves; the host notices.
	guest_session.close()
	var gone: bool = await _wait_seconds(func() -> bool: return host.rival_gone, 3.0)
	assert_true(gone, "host saw the guest leave")
	_cleanup()
