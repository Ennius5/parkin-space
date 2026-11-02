class_name DuelLevel
extends Level
## The 1v1 duel lot: a timed shift with no win or loss, only earnings. The queue length and
## retrievals follow the duel's minutes, and the result never touches campaign progress.
## The host runs the real shift for both valets and streams it to the guest through NetSync.
## Opened from the lobby (GameState.duel_role set), it takes its role and minutes from there,
## goes to the Online Result screen when the match ends and to Mode Select if the rival leaves.

signal match_ended(my_score: int, rival_score: int)

enum Role { HOST, GUEST }
enum Phase { WAITING, COUNTDOWN, PLAYING }  # waiting for the guest's loaded, 3-2-1, the shift

const COUNTDOWN := 3.0
const START_RESEND := 0.5  # host: match_start repeats this often until the guest has loaded
const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const ONLINE_RESULT := "res://scenes/ui/OnlineResult.tscn"
const RIVAL_LEFT := "Your rival left the match"
const SNAPSHOT_INTERVAL := 1.0 / 20.0
const RING_COLORS: Array[Color] = [HexStyle.CYAN, HexStyle.MAGENTA]  # by valet id: host, guest

var minutes := 3  # duel length, set before the level enters the tree
var role := Role.HOST
var session: NetSession  # null = the Net autoload
var match_seed := 0  # host: 0 = pick one in _ready
var rival_gone := false  # the guest left or went silent
var sync: NetSync
var mirror: GuestMirror  # guest role only: draws the host's shift

var _from_lobby := false  # role and minutes came from the lobby; scene changes follow the match
var _phase := Phase.WAITING
var _start_args: Array = []  # host: the match_start message, kept to repeat while waiting
var _resend_clock := 0.0
var _countdown_left := COUNTDOWN
var _snapshot_clock := 0.0
var _tick := 0
var _ship_ids: Dictionary = {}  # Ship -> network id
var _ships_by_id: Dictionary = {}  # network id -> Ship
var _next_ship_id := 0


func _ready() -> void:
	if session == null:
		session = Net
	_from_lobby = GameState.duel_role != ""
	if _from_lobby:
		role = Role.HOST if GameState.duel_role == "host" else Role.GUEST
		minutes = GameState.duel_minutes if role == Role.HOST else session.duel_minutes
	if match_seed == 0 and role == Role.HOST:
		match_seed = randi_range(1, 0x7fffffff)
	allow_moving_parked = true
	super._ready()
	sync = NetSync.new()
	sync.name = "NetSync"
	sync.level = self
	sync.session = session
	add_child(sync)
	recolor_floodlights()
	pauses_tree = false
	_pause_menu.set_online(true)
	if _from_lobby:
		if not session.is_active():  # the rival dropped while this scene loaded
			_leave_for_mode_select(RIVAL_LEFT)
			return
		match_ended.connect(_show_online_result)
	session.rival_left.connect(_on_rival_left)
	if role == Role.GUEST:
		_become_mirror()
		return
	valets.append(Valet.new(1, false, new_ledger(), NetPilot.new()))
	var ships: Array = []
	for ship: Ship in _ship_ids:
		ships.append(_ship_entry(ship))
	_start_args = [match_seed, minutes * 60.0, NetProtocol.pack_ship_list(ships)]
	sync.send(&"match_start", _start_args)
	if not session.is_active():
		on_guest_loaded()  # no guest to wait for (tests): loaded counts as received at once


func _exit_tree() -> void:
	if session and session.rival_left.is_connected(_on_rival_left):
		session.rival_left.disconnect(_on_rival_left)


## Guest: no shift rules run here and nothing in the lot collides (in a loopback test it shares
## the host's physics world); a GuestMirror shows the host's snapshots instead.
func _become_mirror() -> void:
	set_physics_process(false)
	for body in find_children("*", "CollisionObject2D", true, false):
		(body as CollisionObject2D).collision_layer = 0
		(body as CollisionObject2D).collision_mask = 0
	mirror = GuestMirror.new()
	mirror.name = "GuestMirror"
	mirror.setup(self, _ships, _spaces, _hud, _controls, _lot_camera)
	add_child(mirror)


func seed_rng() -> void:
	_rng.seed = match_seed


## Draws enough customers for the whole duel from the pool. No space classes: far more ships
## arrive than the lot holds at once, so a draw that had to fit them all would stop early.
func prepare_queue() -> void:
	customer_queue = draw_customers(_pool, GameState.duel_customers(minutes), _rng)
	retrieval_count = GameState.duel_retrievals(minutes)
	if _exit:
		_retrieval_indexes = _pick_retrievals(customer_queue.size(), retrieval_count)


## A duel customer asks for the ship back 20-30 s after it first parks.
func retrieval_delay() -> float:
	return _rng.randf_range(20.0, 30.0)


## A duel ledger that only the clock ends.
func new_ledger() -> ShiftLedger:
	return ShiftLedger.duel(minutes * 60.0)


## Host: the guest has loaded the lot. Starts the 3-2-1 countdown on both phones.
func on_guest_loaded() -> void:
	if _phase != Phase.WAITING:
		return
	sync.send(&"go", [])
	_phase = Phase.COUNTDOWN
	_countdown_left = COUNTDOWN
	start_lights_clock()
	_hud.show_hint("3", 1.0)


## Flicker counts from now, so lamps on both phones stutter together.
func start_lights_clock() -> void:
	var now := Time.get_ticks_msec()
	for light in _floodlights():
		light.clock_zero_msec = now


func _floodlights() -> Array[Floodlight]:
	var lights: Array[Floodlight] = []
	var holder := get_node_or_null("Floodlights")
	if holder:
		for child in holder.get_children():
			if child is Floodlight:
				lights.append(child)
	return lights


## Lamp shades from the match seed, the same on both phones.
func recolor_floodlights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	for light in _floodlights():
		light.recolor(rng)


func _physics_process(delta: float) -> void:
	if role != Role.HOST or _ended:
		return
	(valets[1].pilot as NetPilot).bits = 0 if rival_gone else sync.guest_bits
	match _phase:
		Phase.WAITING:
			_resend_start_when_due(delta)
			return
		Phase.COUNTDOWN:
			_count_down(delta)
		Phase.PLAYING:
			super._physics_process(delta)
	if not _ended:
		_send_snapshot_when_due(delta)


## The guest's lot may still be loading when the first match_start goes out, so it repeats
## until the guest answers with loaded. A repeat that arrives is harmless (see GuestMirror).
func _resend_start_when_due(delta: float) -> void:
	_resend_clock += delta
	if _resend_clock >= START_RESEND and session.is_active():
		_resend_clock = 0.0
		sync.send(&"match_start", _start_args)


## The shift clock and arrivals wait until the countdown ends; then the first customer arrives.
func _count_down(delta: float) -> void:
	var shown := ceili(_countdown_left)
	_countdown_left -= delta
	if _countdown_left <= 0.0:
		_phase = Phase.PLAYING
		_hud.show_hint("Go!", 1.0)
		spawn_next_customer()
		_arrival_timer = 0.0
	elif ceili(_countdown_left) != shown:
		_hud.show_hint(str(ceili(_countdown_left)), 1.0)


func spawn_next_customer() -> Ship:
	if _phase != Phase.PLAYING or role != Role.HOST:
		return null
	var ship := super.spawn_next_customer()
	if ship:
		customer_for(ship).wants_retrieval = true  # every duel ship leaves again
		_ship_ids[ship] = _next_ship_id
		_ships_by_id[_next_ship_id] = ship
		_next_ship_id += 1
		sync.send(&"ship_added", [NetProtocol.pack_ship_list([_ship_entry(ship)])])
	return ship


## Paint and headlight from the seeded rng, so the guest can be told which.
func _dress_ship(ship: Ship) -> void:
	ship.paint_index = _rng.randi_range(0, PAINT_COLORS.size() - 1)
	ship.headlight_index = _rng.randi_range(0, Ship.HEADLIGHT_COLORS.size() - 1)
	ship.paint_color = PAINT_COLORS[ship.paint_index]


## A ship's network id, or -1 for one the duel didn't spawn.
func ship_id(ship: Ship) -> int:
	return _ship_ids.get(ship, -1)


func ship_by_id(id: int) -> Ship:
	var ship: Ship = _ships_by_id.get(id)
	return ship if is_instance_valid(ship) else null


func _ship_entry(ship: Ship) -> Dictionary:
	var c := customer_for(ship)
	return {
		"id": ship_id(ship), "spec_path": ship.spec.resource_path, "paint": ship.paint_index,
		"headlight": ship.headlight_index, "tier": c.tier if c else 0,
		"wants_retrieval": c != null and c.wants_retrieval,
	}


## A ship handed back at the exit leaves the guest's lot too.
func _return(ship: Ship) -> void:
	var id := ship_id(ship)
	super._return(ship)
	_ship_ids.erase(ship)
	_ships_by_id.erase(id)
	if id >= 0:
		sync.send(&"ship_removed", [id])


## Rings the ship in its driver's colour. A guest's pick becomes a request to the host.
func select_ship(ship: Ship, valet: Valet = null) -> void:
	if role == Role.GUEST:
		_picker.close()
		if mirror:
			mirror.request(ship)
		return
	super.select_ship(ship, valet)
	var v := _valet_or_first(valet)
	if v.ship == ship:
		ship.ring_color = RING_COLORS[v.id]


func release_ship(valet: Valet = null) -> void:
	var v := _valet_or_first(valet)
	if v.ship and is_instance_valid(v.ship):
		v.ship.ring_color = Color.TRANSPARENT
	super.release_ship(valet)


## Guest: Done is a request to the host.
func press_done(valet: Valet = null) -> void:
	if role == Role.GUEST:
		if mirror:
			mirror.press_done()
		return
	super.press_done(valet)


## The host hears its own cues; the guest is sent theirs, and both get shared ones.
func _cue(effect: String, valet: Valet = null) -> void:
	super._cue(effect, valet)
	if sync and (valet == null or not valet.local):
		sync.send(&"event", [effect])


func _rival_score() -> int:
	return valets[1].ledger.earnings() if valets.size() > 1 else 0


func _refresh() -> void:
	_hud.set_time(ledger.time_left)
	_hud.set_duel_scores(ledger.earnings(), _rival_score())
	_hud.set_customers_left(customer_queue.size() - _next_customer)
	if ledger.outcome != ShiftLedger.Outcome.PLAYING:
		end_level()


func _send_snapshot_when_due(delta: float) -> void:
	if rival_gone:
		return
	_snapshot_clock += delta
	if _snapshot_clock < SNAPSHOT_INTERVAL:
		return
	_snapshot_clock = fmod(_snapshot_clock, SNAPSHOT_INTERVAL)
	_tick += 1
	sync.send(&"snapshot", [NetProtocol.pack_snapshot(snapshot())])


## What the guest needs to draw this moment (see NetProtocol.pack_snapshot).
func snapshot() -> Dictionary:
	var lit := PackedInt32Array()
	for space: ParkingSpace in _spaces.get_children():
		var lit_for: Ship = space.ready_for
		lit.append(valet_of(lit_for).id if is_instance_valid(lit_for) else -1)
	var ships: Array = []
	for ship: Ship in _ships.get_children():
		if not _ship_ids.has(ship):
			continue
		var driver := -1
		for v in valets:
			if v.ship == ship:
				driver = v.id
		var firing := 0
		for i in ship.firing:
			firing |= 1 << i
		ships.append({"id": _ship_ids[ship], "pos": ship.global_position, "rot": ship.global_rotation,
				"driver": driver, "parked": ship.is_parked, "glowing": ship.is_glowing(), "firing": firing})
	return {"tick": _tick, "time_left": ledger.time_left, "lit": lit, "ships": ships,
			"scores": PackedInt32Array([ledger.earnings(), _rival_score()])}


func _on_rival_left() -> void:
	rival_gone = true
	sync.guest_bits = 0
	if role == Role.HOST and valets.size() > 1:
		release_ship(valets[1])
	if _from_lobby:
		_leave_for_mode_select(RIVAL_LEFT)


## Online pause: Leave match (after its Yes) tells the rival and goes to Mode Select.
func _on_pause_quit() -> void:
	_pause_menu.close()
	last_pause_action = "leave"
	session.leave()
	_leave_for_mode_select("")


## Ends this lot for good and goes to Mode Select, which shows `notice` once.
func _leave_for_mode_select(notice: String) -> void:
	_ended = true
	Sound.stop_thruster()
	GameState.notice = notice
	GameState.duel_role = ""
	if change_scene_on_end:
		get_tree().change_scene_to_file.call_deferred(MODE_SELECT)


## The match is over: both scores go to the Online Result screen.
func _show_online_result(my_score: int, rival_score: int) -> void:
	GameState.duel_result = {"mine": my_score, "rival": rival_score}
	if change_scene_on_end:
		get_tree().change_scene_to_file.call_deferred(ONLINE_RESULT)


## Stops the shift without recording campaign progress, stars or a result screen. The host
## tells the guest the final scores.
func end_level() -> void:
	if _ended:
		return
	_ended = true
	for v in valets:
		release_ship(v)
	Sound.stop_thruster()
	if role == Role.HOST:
		var mine := ledger.earnings()
		var rival := _rival_score()
		sync.send(&"match_end", [mine, rival])
		match_ended.emit(mine, rival)


## Guest: the host's final scores arrived. Ends this lot and reports mine first.
func finish_as_guest(host_score: int, guest_score: int) -> void:
	end_level()
	match_ended.emit(guest_score, host_score)
