class_name GuestMirror
extends Node
## A duel guest's lot runs no shift of its own: it shows the host's snapshots and sends this
## player's buttons and requests. DuelLevel adds it as a child in guest role; NetSync hands it the
## host's messages. Mirror ships are frozen with collisions off, so they never touch anything.

const GUEST_VALET := 1  # the guest's valet id on the host
const INPUT_INTERVAL := 1.0 / 30.0
const SHIP_DIR := "res://resources/ships/"  # ship specs the host may name

var level: DuelLevel

var _ships_node: Node2D
var _spaces: Node2D
var _hud: HUD
var _controls: ShipControls
var _lot_camera: Camera2D
var _buffer := SnapshotBuffer.new()
var _mirrors: Dictionary = {}  # network id -> Ship
var _ids: Dictionary = {}  # Ship -> network id
var _claimed: Dictionary = {}  # parked mirror Ship -> the ParkingSpace drawn as taken by it
var _input_clock := 0.0
var _countdown_left := -1.0  # below 0 = no countdown showing
var _ships_total := 0  # customers in the whole duel
var _ships_added := 0
var _drive_hint_shown := false
var _return_hint_shown := false
var _over := false


## The level's nodes the mirror draws on.
func setup(duel: DuelLevel, ships: Node2D, spaces: Node2D, hud: HUD, controls: ShipControls,
		lot_camera: Camera2D) -> void:
	level = duel
	_ships_node = ships
	_spaces = spaces
	_hud = hud
	_controls = controls
	_lot_camera = lot_camera


## The mirror ship with this network id, or null.
func ship_by_id(id: int) -> Ship:
	var ship: Ship = _mirrors.get(id)
	return ship if is_instance_valid(ship) else null


# --- Messages from the host ---

## The host's seed, match length and the ships already in the lot. Answers with `loaded`.
func on_match_start(match_seed: int, seconds: float, ships: Array) -> void:
	level.match_seed = match_seed
	level.minutes = roundi(seconds / 60.0)
	level.recolor_floodlights()
	_ships_total = GameState.duel_customers(level.minutes)
	_hud.set_time(seconds)
	add_ships(ships, false)
	level.sync.send(&"loaded", [])


## The countdown starts on both phones; lamps flicker from now.
func on_go() -> void:
	level.start_lights_clock()
	_countdown_left = DuelLevel.COUNTDOWN
	_hud.show_hint("3", 1.0)


func on_snapshot(s: Dictionary) -> void:
	_buffer.push(s, _now())


## Builds mirror ships from ship list entries. arriving = they just came in at the bay.
func add_ships(entries: Array, arriving := true) -> void:
	for e: Dictionary in entries:
		if _mirrors.has(e.id):
			continue
		var ship := _build_ship(e)
		if ship == null:
			continue
		_mirrors[e.id] = ship
		_ids[ship] = e.id
		_ships_added += 1
		if arriving:
			Sound.play("arrive")
	_hud.set_customers_left(maxi(0, _ships_total - _ships_added))


func remove_ship(id: int) -> void:
	var ship := ship_by_id(id)
	_mirrors.erase(id)
	if ship == null:
		return
	if level.driven_ship == ship:
		_follow(null)
	_unclaim(ship)
	_ids.erase(ship)
	_ships_node.remove_child(ship)
	ship.queue_free()


## A sound (and the offline hint, where one goes with it) for something on the host.
func on_event(effect: String) -> void:
	Sound.play(effect)
	if effect == "request" and not _return_hint_shown:
		_return_hint_shown = true
		_hud.show_hint(Level.HINT_RETURN, 4.0)


func on_match_end(host_score: int, guest_score: int) -> void:
	_over = true
	level.finish_as_guest(host_score, guest_score)


# --- This player's requests ---

## A tap picked this ship: ask the host for it.
func request(ship: Ship) -> void:
	if _over or level.driven_ship != null or not _ids.has(ship):
		return
	level.sync.send(&"select", [_ids[ship]])


func press_done() -> void:
	if not _over:
		level.sync.send(&"done", [])


# --- Every frame ---

func _process(delta: float) -> void:
	if _over:
		return
	_count_down(delta)
	var s := _buffer.sample(_now())
	if not s.is_empty():
		_show(s)
	_send_input_when_due(delta)


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _count_down(delta: float) -> void:
	if _countdown_left < 0.0:
		return
	var shown := ceili(_countdown_left)
	_countdown_left -= delta
	if _countdown_left <= 0.0:
		_countdown_left = -1.0
		_hud.show_hint("Go!", 1.0)
	elif ceili(_countdown_left) != shown:
		_hud.show_hint(str(ceili(_countdown_left)), 1.0)


## Places every ship and draws its flags, then the HUD and the lit spaces.
func _show(s: Dictionary) -> void:
	var drivers := {}  # valet id -> the ship they drive
	for e: Dictionary in s.ships:
		var ship := ship_by_id(e.id)
		if ship == null:
			continue
		var driver := int(e.driver)
		if driver >= DuelLevel.RING_COLORS.size():
			driver = -1
		if driver >= 0:
			drivers[driver] = ship
		ship.global_position = e.pos
		ship.global_rotation = e.rot
		var ring := DuelLevel.RING_COLORS[driver] if driver >= 0 else Color.TRANSPARENT
		if ship.ring_color != ring:
			ship.ring_color = ring
		if ship != level.driven_ship and ship.is_driven != (driver >= 0 and driver != GUEST_VALET):
			ship.set_driven(not ship.is_driven, false)  # the rival's: lights only, no camera or sound
		ship.show_firing(_thrusters(int(e.firing), ship.spec.thrusters.size()))
		_show_parked(ship, e.parked)
		ship.customer.requested = e.glowing
		ship.customer.request_seen = false
	_follow(drivers.get(GUEST_VALET))
	if level.driven_ship:
		if level.driven_ship.firing.is_empty():
			Sound.stop_thruster()
		else:
			Sound.start_thruster()
	_hud.set_time(s.time_left)
	_hud.set_duel_scores(s.scores[1], s.scores[0])  # mine first
	var lit: PackedInt32Array = s.lit
	var spaces := _spaces.get_children()
	for i in spaces.size():
		var space := spaces[i] as ParkingSpace
		var lit_by := lit[i] if i < lit.size() else -1
		var lit_ship: Ship = drivers.get(lit_by)
		if space.ready_for != lit_ship:
			space.ready_for = lit_ship
			space.queue_redraw()


## Thruster indices from a firing bitmask, ignoring any past the ship's count.
static func _thrusters(mask: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in mini(count, 16):
		if mask & (1 << i):
			out.append(i)
	return out


## The parked look, and the space it sits in drawn as taken.
func _show_parked(ship: Ship, parked: bool) -> void:
	if ship.is_parked != parked:
		ship.is_parked = parked
		ship.modulate = Color(1, 1, 1, 0.7) if parked else Color.WHITE
	if not parked:
		_unclaim(ship)
	elif not _claimed.has(ship):
		for space: ParkingSpace in _spaces.get_children():
			var local := space.global_transform.affine_inverse() * ship.global_position
			if space.occupant == null and Rect2(-space.size() / 2, space.size()).has_point(local):
				space.claim(ship)
				_claimed[ship] = space
				break


func _unclaim(ship: Ship) -> void:
	var space: ParkingSpace = _claimed.get(ship)
	_claimed.erase(ship)
	if space and space.occupant == ship:
		space.release()


## The guest drives this mirror ship now (null = none): its camera, its controls.
func _follow(ship: Ship) -> void:
	var valet := level.valets[0]
	if valet.ship == ship:
		return
	if valet.ship != null:
		if is_instance_valid(valet.ship):
			valet.ship.set_driven(false, true)
		valet.released_at_msec = Time.get_ticks_msec()
		level.sync.send(&"input", [0])  # no stale buttons for the next ship
	valet.ship = ship
	if ship:
		ship.set_driven(true, true)
		_controls.set_driving(true)
		_input_clock = INPUT_INTERVAL  # send the buttons at once
		if not _drive_hint_shown:
			_drive_hint_shown = true
			_hud.show_hint(Level.HINT_DRIVE, 4.0)
	else:
		Sound.stop_thruster()
		_lot_camera.make_current()
		_controls.set_driving(false)


func _send_input_when_due(delta: float) -> void:
	if level.driven_ship == null:
		return
	_input_clock += delta
	if _input_clock < INPUT_INTERVAL:
		return
	_input_clock = fmod(_input_clock, INPUT_INTERVAL)
	level.sync.send(&"input", [NetPilot.bits_from_input()])


## A frozen ship with collisions off, dressed as the host's.
func _build_ship(e: Dictionary) -> Ship:
	var path := String(e.spec_path)
	if not path.begins_with(SHIP_DIR) or not ResourceLoader.exists(path):
		return null
	var spec := load(path) as ShipSpec
	if spec == null:
		return null
	var ship: Ship = Level.SHIP_SCENE.instantiate()
	ship.spec = spec
	ship.paint_index = clampi(int(e.paint), 0, Level.PAINT_COLORS.size() - 1)
	ship.paint_color = Level.PAINT_COLORS[ship.paint_index]
	ship.headlight_index = clampi(int(e.headlight), 0, Ship.HEADLIGHT_COLORS.size() - 1)
	var c := Customer.new()
	c.tier = clampi(int(e.tier), 0, Customer.Tier.size() - 1) as Customer.Tier
	c.wants_retrieval = e.wants_retrieval
	ship.customer = c
	ship.freeze = true
	ship.collision_layer = 0
	ship.collision_mask = 0
	var entrance := level.get_node("Entrance") as Node2D
	ship.global_position = entrance.global_position
	ship.rotation = entrance.global_rotation
	_ships_node.add_child(ship)
	ship.contact_monitor = false  # its _ready turned it on
	ship.set_physics_process(false)  # no thrusters of its own; flames come from the snapshot
	return ship
