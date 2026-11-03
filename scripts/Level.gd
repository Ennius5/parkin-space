class_name Level
extends Node2D
## Runs one shift: spawns customers, switches between lot view and driving, detects parking,
## tracks pay and ends the level. Each level scene only changes the exported values and layout.

## Random customer paint jobs, multiplied over the grey paint layer.
const PAINT_COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.25), Color(0.25, 0.55, 0.95), Color(0.3, 0.8, 0.4), Color(0.95, 0.75, 0.2),
	Color(0.7, 0.4, 0.9), Color(0.95, 0.5, 0.15), Color(0.9, 0.9, 0.92), Color(0.2, 0.75, 0.8),
]
const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const RESULT_SCENE := "res://scenes/ui/Result.tscn"
const CRASH_COST := 15  # dents this costly crunch instead of clang
const REQUEST_BONUS := 20  # for parking a special request in the space they asked for
const ORPHAN_EJECT_SECONDS := 30.0  # an orphan always appears early enough to be driven out after its countdown
const ORPHAN_RETRY_SECONDS := 1.0  # no space for a due orphan: look again this much later
const ARRIVAL_CLEAR_SECONDS := 1.0  # the arrival bay must stay empty this long before the next ship
const RADIATION_DENT_COST := 5
const RADIATION_INTERVAL := 2.0  # seconds inside radiation per dent
const RESELECT_DELAY_MS := 300  # the touch that presses Done must not also select a ship
const PICK_RADIUS_SCREEN := 100.0  # thumb-sized: ships this close to a tap (on screen) are candidates
const HINT_DRIVE := "Stop in a green space, then press Done when it turns orange"
const HINT_RETURN := "A customer wants their ship – return it to the EXIT"

@export var level_number: int = 1
@export var goal_text: String = ""
@export var customer_queue: Array[ShipSpec] = []
## Above 0: each shift draws this many customers from customer_queue by spawn_weight (repeats allowed).
@export var random_customers: int = 0
@export var base_pay: int = 100
@export var silver_target: int = 150
@export var gold_target: int = 170
@export var arrival_interval: float = 8.0
@export var tier_weights: Dictionary = {}  # Customer.Tier -> weight; empty = the usual odds
@export var use_tiers := false  # bronze/silver/gold customers who tip
## How many customers want their ship back at the exit. Needs an ExitPad named Exit.
@export var retrieval_count: int = 0
@export var allow_moving_parked := false  # the valet may pick up a parked customer ship to make room
@export var request_count := 0  # customers who ask for one named space
@export var orphan_count := 0  # abandoned ships that appear partway through the shift

var valets: Array[Valet] = []  # everyone driving in this lot; valets[0] plays on this device
## Valet 0's pay and timer.
var ledger: ShiftLedger:
	get:
		return valets[0].ledger
	set(value):
		valets[0].ledger = value
var customers: Dictionary = {}  # Ship -> Customer
## The ship valet 0 is driving.
var driven_ship: Ship:
	get:
		return valets[0].ship
	set(value):
		valets[0].ship = value
var change_scene_on_end := true  # tests turn this off

var _next_customer := 0
var _arrival_timer := 0.0
var _trackers: Dictionary = {}  # Ship -> ParkTracker
var _ended := false
var _drive_hint_shown := false
var _released_at_msec: int:  # when valet 0 last let go of a ship
	get:
		return valets[0].released_at_msec
	set(value):
		valets[0].released_at_msec = value
var _rng := RandomNumberGenerator.new()
var _retrieval_indexes: Array[int] = []  # queue positions of customers who will want their ship back
var _return_hint_shown := false
var _bay: ArrivalBay
var _bay_clear_for := 0.0
var _radiation_time: Dictionary = {}  # Ship -> seconds inside radiation since its last dent
var _radiation_hint_shown := false
var _pool: Array[ShipSpec] = []  # every ship this level can draw, kept for orphans
var _orphans_due: Array[float] = []  # shift seconds at which orphans are due to appear
var _orphan_clock := 0.0
var _orphan_hint_shown := false
var _request_indexes: Array[int] = []  # queue positions of customers with a special request
var _request_hint_shown := false
var last_pause_action := ""  # "restart" or "quit" when scene changes are off (tests)
var pauses_tree := true  # false online: the pause menu opens but the match keeps running
var _pause_menu := PauseMenu.new()
var _cctv: CctvFilter
var _flung_at: Dictionary = {}  # ship or asteroid -> msec it was last flung out of a black hole

@onready var _spaces: Node2D = $Spaces
@onready var _ships: Node2D = $Ships
@onready var _entrance: Marker2D = $Entrance
@onready var _lot_camera: Camera2D = $LotCamera
@onready var _hud: HUD = $HUD
@onready var _controls: ShipControls = $Controls
@onready var _picker: ShipPicker = $ShipPicker
@onready var _exit: ExitPad = get_node_or_null("Exit")
@onready var _radiation: Node = get_node_or_null("Radiation")
@onready var _asteroids: Node = get_node_or_null("Asteroids")
@onready var _black_hole: BlackHole = get_node_or_null("BlackHole")


func _ready() -> void:
	valets = [Valet.new(0, true)]
	seed_rng()
	_pool = customer_queue.duplicate()
	prepare_queue()
	ledger = new_ledger()
	if orphan_count > 0:
		_orphans_due = orphan_times(_rng, orphan_count, GameState.shift_seconds())
	GameState.current_level = level_number
	_hud.set_goal(goal_text)
	_controls.done_pressed.connect(_on_done_pressed)
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_hud.pause_pressed.connect(open_pause)
	_pause_menu.resume_pressed.connect(close_pause)
	_pause_menu.restart_pressed.connect(_on_pause_restart)
	_pause_menu.quit_pressed.connect(_on_pause_quit)
	_picker.picked.connect(_on_picked)
	_lot_camera.make_current()
	Sound.play_level_music()
	_add_darkness()
	_add_cctv()
	_add_arrival_bay()
	spawn_next_customer()
	_hud.show_hint("Tap a ship to drive it", 4.0)
	_refresh()


## Seeds the shift's random draws. A duel overrides it with the match seed.
func seed_rng() -> void:
	_rng.randomize()


## Settles this shift's customers: the random draw, then who wants their ship back and who asks
## for a space. A duel overrides it to draw without the lot's space classes.
func prepare_queue() -> void:
	if random_customers > 0:
		customer_queue = draw_customers(customer_queue, random_customers, _rng, _space_classes())
	if _exit:
		_retrieval_indexes = _pick_retrievals(customer_queue.size(), retrieval_count)
	_request_indexes = _pick_requests(customer_queue.size(), request_count)


## Valet 0's ledger for this shift. A duel overrides it with a duel ledger.
func new_ledger() -> ShiftLedger:
	return ShiftLedger.new(base_pay, customer_queue.size(), GameState.shift_seconds())


## The valet who answers for a ship: whoever drives it, else its last driver, else valet 0.
func valet_of(ship: Ship) -> Valet:
	for v in valets:
		if v.ship == ship:
			return v
	for v in valets:
		if v.id == ship.last_driver:
			return v
	return valets[0]


func _valet_or_first(valet: Valet) -> Valet:
	return valet if valet else valets[0]


func _driven_by_anyone(ship: Ship) -> bool:
	for v in valets:
		if v.ship == ship:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _ended:
		return
	for v in valets:
		v.ledger.tick(delta)
	var in_the_way: Array[Node] = _ships.get_children()
	if _asteroids:
		in_the_way.append_array(_asteroids.get_children())
	_update_arrivals(delta, in_the_way)
	if _radiation:
		_update_radiation(delta)
	if _black_hole:
		_apply_pull()
		_fling_from_core()
	_check_parking(delta)
	_update_customers(delta)
	_update_orphans(delta)
	_refresh()


## The next customer arrives once the interval has passed and the bay has stayed clear of
## in_the_way (ships and asteroids) for ARRIVAL_CLEAR_SECONDS. A duel overrides it with two bays.
func _update_arrivals(delta: float, in_the_way: Array[Node]) -> void:
	_arrival_timer += delta
	_bay_clear_for = _bay_clear_for + delta if _bay.is_clear(in_the_way) else 0.0
	if _arrival_timer >= arrival_interval and _bay_clear_for >= ARRIVAL_CLEAR_SECONDS:
		if spawn_next_customer():
			_arrival_timer = 0.0
			_bay_clear_for = 0.0


## A customer can only be gold if the lot has a gold space their ship fits.
func gold_allowed(ship_class: int) -> bool:
	for space: ParkingSpace in get_node("Spaces").get_children():
		if space.gold and ParkingRules.fits_class(ship_class, space.space_class):
			return true
	return false


func customer_for(ship: Ship) -> Customer:
	return customers.get(ship)


## count distinct queue positions, chosen at random.
func _pick_retrievals(queue_size: int, count: int) -> Array[int]:
	var indexes: Array[int] = []
	for i in queue_size:
		indexes.append(i)
	for i in range(queue_size - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := indexes[i]
		indexes[i] = indexes[j]
		indexes[j] = t
	return indexes.slice(0, mini(count, queue_size))


## Waiting time, retrieval requests, freeing spaces behind leaving ships, and hand-overs at the exit.
func _update_customers(delta: float) -> void:
	for ship: Ship in customers.keys():
		var c: Customer = customers[ship]
		if c.is_waiting():
			c.wait += delta
		if c.request_in >= 0.0 and not c.requested:
			c.request_in -= delta
			if c.request_in <= 0.0:
				_request(ship)
		if not ship.is_parked:
			var space := _space_of(ship)
			if space and not space.touches(ship):
				space.release()
		if c.requested and _exit and _exit.contains(ship.global_position):
			_return(ship)


func _space_of(ship: Ship) -> ParkingSpace:
	for space: ParkingSpace in _spaces.get_children():
		if space.occupant == ship:
			return space
	return null


func _request(ship: Ship) -> void:
	var c: Customer = customers[ship]
	c.requested = true
	c.request_in = -1.0
	_cue("request")
	var driven := _driven_by_anyone(ship)
	ship.unpark()
	if driven:
		ship.driven_since_free = true  # in someone's hands: the black hole keeps pulling it
	_trackers.erase(ship)
	if not _return_hint_shown:
		_return_hint_shown = true
		_hud.show_hint(HINT_RETURN, 4.0)


## Hands a requested ship back to its customer: it leaves the lot and the customer is served.
func _return(ship: Ship) -> void:
	var c: Customer = customers[ship]
	var valet := valet_of(ship)
	if ship == valet.ship:
		release_ship(valet)
	var space := _space_of(ship)
	if space:
		space.release()
	close_picker_listing(ship)
	customers.erase(ship)
	_trackers.erase(ship)
	_flung_at.erase(ship)
	_ships.remove_child(ship)
	ship.queue_free()
	_pay_tip(c.tip(), valet)  # before serving: the final serve ends the shift
	valet.ledger.serve_customer(0)


## Draws count ships from pool, each pick weighted by its spawn_weight. With space_classes,
## only ships that still leave room for everyone drawn so far can be picked; the draw stops
## early when none can.
static func draw_customers(pool: Array[ShipSpec], count: int, rng: RandomNumberGenerator,
		space_classes: Array[int] = []) -> Array[ShipSpec]:
	var drawn: Array[ShipSpec] = []
	var drawn_classes: Array[int] = []
	for i in count:
		var options: Array[ShipSpec] = []
		var weights := PackedFloat32Array()
		for spec in pool:
			var with_spec := drawn_classes.duplicate()
			with_spec.append(spec.ship_class)
			if space_classes.is_empty() or ParkingRules.fits_lot(with_spec, space_classes):
				options.append(spec)
				weights.append(spec.spawn_weight)
		if options.is_empty():
			break
		var pick := options[rng.rand_weighted(weights)]
		drawn.append(pick)
		drawn_classes.append(pick.ship_class)
	return drawn


func _space_classes() -> Array[int]:
	var classes: Array[int] = []
	for space: ParkingSpace in _spaces.get_children():
		classes.append(space.space_class)
	return classes


## Spawns the next customer's ship at the entrance. Returns null when the queue is used up.
func spawn_next_customer() -> Ship:
	if _next_customer >= customer_queue.size():
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = customer_queue[_next_customer]
	_dress_ship(ship)
	var c := Customer.roll(_rng, use_tiers, gold_allowed(ship.spec.ship_class), tier_weights)
	c.wants_retrieval = _next_customer in _retrieval_indexes
	if _next_customer in _request_indexes:
		var wanted := _pick_request_space(ship.spec.ship_class)
		if wanted:
			c.wants_space = wanted.label
			wanted.set_pin(c.color())
			if not _request_hint_shown:
				_request_hint_shown = true
				_hud.show_hint("Special request: park them in their space", 4.0)
	_next_customer += 1
	_place_arrival(ship, c, _entrance)
	return ship


## Puts a new customer's ship into the lot at an entrance marker, facing the way it points.
func _place_arrival(ship: Ship, c: Customer, entrance: Node2D) -> void:
	ship.customer = c
	customers[ship] = c
	ship.global_position = entrance.global_position
	ship.rotation = entrance.global_rotation
	_ships.add_child(ship)
	ship.dented.connect(_on_ship_dented)
	ship.bumped.connect(_on_ship_bumped)
	Sound.play("arrive")


## Picks a new ship's paint before it enters the tree. A duel overrides it to choose the paint
## and headlight from the seeded rng, so it can tell the guest.
func _dress_ship(ship: Ship) -> void:
	ship.paint_index = randi() % PAINT_COLORS.size()
	ship.paint_color = PAINT_COLORS[ship.paint_index]


## Plays a sound cue for the valet it concerns: only for one on this device, or for everyone
## when valet is null. A duel host also tells the guest about its own cues.
func _cue(effect: String, valet: Valet = null) -> void:
	if valet == null or valet.local:
		Sound.play(effect)


## Lot view: a tap picks the one ship near it, or lists them when there's a choice.
## A tap while the list is open closes it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape on desktop, like the back gesture
		open_pause()
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if _picker.is_open():
		_picker.close()
		return
	handle_lot_tap(touch.position)


func handle_lot_tap(screen_pos: Vector2) -> void:
	if _ended or driven_ship != null or Time.get_ticks_msec() - _released_at_msec < RESELECT_DELAY_MS:
		return
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var near := ships_near_world(world, pick_radius_world())
	if near.size() > 1 and _distance_to_hull(near[0], world) == 0.0 and _distance_to_hull(near[1], world) > 0.0:
		select_ship(near[0])  # a tap right on one ship takes it, even among neighbours
	elif near.size() == 1:
		select_ship(near[0])
	elif near.size() > 1:
		_picker.open(near, screen_pos)


func pick_radius_world() -> float:
	return PICK_RADIUS_SCREEN / _lot_camera.zoom.x


## Drivable ships whose outline is within radius of a world point, nearest first.
func ships_near_world(world: Vector2, radius: float) -> Array[Ship]:
	var found: Array[Ship] = []
	var distance := {}
	for ship: Ship in _ships.get_children():
		if ship.is_parked and not _can_move_parked(ship):
			continue
		var d := _distance_to_hull(ship, world)
		if d <= radius:
			found.append(ship)
			distance[ship] = d
	found.sort_custom(func(a: Ship, b: Ship) -> bool: return distance[a] < distance[b])
	return found


func _distance_to_hull(ship: Ship, world: Vector2) -> float:
	var points := ship.hull_points()
	var outline := points.slice(0, points.size() - 1)  # the last point is the centre
	if Geometry2D.is_point_in_polygon(world, outline):
		return 0.0
	var best := INF
	for i in outline.size():
		var closest := Geometry2D.get_closest_point_to_segment(world, outline[i], outline[(i + 1) % outline.size()])
		best = minf(best, world.distance_to(closest))
	return best


## Closes the ship list if it offers this ship (which is about to leave the lot).
func close_picker_listing(ship: Ship) -> void:
	if _picker.is_open() and _picker.lists(ship):
		_picker.close()


func _on_picked(ship: Ship) -> void:
	_picker.close()
	select_ship(ship)


## Takes control of a ship. Ignored while already driving (press Done first)
## and for a moment after Done, so the same touch doesn't grab a ship under the button.
## A ship another valet is driving can't be taken. valet null means valet 0.
func select_ship(ship: Ship, valet: Valet = null) -> void:
	valet = _valet_or_first(valet)
	if _ended or (ship.is_parked and not _can_move_parked(ship)) or valet.ship != null:
		return
	if _driven_by_anyone(ship):
		return
	if Time.get_ticks_msec() - valet.released_at_msec < RESELECT_DELAY_MS:
		return
	if ship.is_parked:  # an orphan, or a parked ship moved to make room
		ship.unpark()
		_trackers.erase(ship)
	if valet.local:
		_picker.close()
	valet.ship = ship
	ship.pilot = valet.pilot
	ship.last_driver = valet.id
	ship.set_driven(true, valet.local)
	if not valet.local:
		return
	_controls.set_driving(true)
	if not _drive_hint_shown:
		_drive_hint_shown = true
		_hud.show_hint(HINT_DRIVE, 4.0)


## A parked ship the valet may pick up: an orphan, or any customer ship where the level allows moving.
func _can_move_parked(ship: Ship) -> bool:
	return ship.orphan != null or (allow_moving_parked and customer_for(ship) != null)


## Lets go of the valet's ship, if any. valet null means valet 0.
func release_ship(valet: Valet = null) -> void:
	valet = _valet_or_first(valet)
	if valet.ship:
		valet.ship.set_driven(false, valet.local)
		valet.released_at_msec = Time.get_ticks_msec()
	valet.ship = null
	if not valet.local:
		return
	_lot_camera.make_current()
	_controls.set_driving(false)


func end_level() -> void:
	if _ended:
		return
	_ended = true
	for v in valets:
		release_ship(v)
	Sound.stop_thruster()
	Sound.play("win" if ledger.outcome == ShiftLedger.Outcome.WON else "lose")
	var won := ledger.outcome == ShiftLedger.Outcome.WON
	var stars := ShiftLedger.stars_for(ledger.earnings(), silver_target, gold_target, won)
	if won:
		GameState.complete_level(level_number, stars)
	var reasons := {
		ShiftLedger.Outcome.WON: "won",
		ShiftLedger.Outcome.FIRED: "fired",
		ShiftLedger.Outcome.TIMEOUT: "timeout",
	}
	GameState.last_result = {
		"won": won,
		"stars": stars,
		"level": level_number,
		"difficulty": GameState.difficulty_name(),
		"earnings": ledger.earnings(),
		"tips": ledger.tips,
		"bonuses": ledger.bonuses,
		"served": ledger.served,
		"customers": ledger.customers,
		"reason": reasons.get(ledger.outcome, "timeout"),
	}
	if change_scene_on_end:
		get_tree().change_scene_to_file.call_deferred(RESULT_SCENE)


## Lights up (orange) the space each valet's ship could park in right now. Nothing parks by itself:
## the valet presses Done to park there.
func _check_parking(_delta: float) -> void:
	var ready := {}  # ParkingSpace -> the ship it lights up for
	for v in valets:
		var ship := v.ship
		if ship == null or not is_instance_valid(ship):
			continue
		var c := customer_for(ship)
		if c and c.requested:
			continue
		for space: ParkingSpace in _spaces.get_children():
			if not ready.has(space) and space.check(ship):
				ready[space] = ship
				break
	for space: ParkingSpace in _spaces.get_children():
		var now: Ship = ready.get(space)
		if now != null and space.ready_for == null:
			_cue("ready", valet_of(now))
		if space.ready_for != now:
			space.ready_for = now
			space.queue_redraw()


func _on_done_pressed() -> void:
	press_done()


## Done: park the valet's ship in the space lit up for it, or just let go of it. valet null means valet 0.
func press_done(valet: Valet = null) -> void:
	valet = _valet_or_first(valet)
	var ship := valet.ship
	var space: ParkingSpace = null
	if ship:
		for s: ParkingSpace in _spaces.get_children():
			if s.ready_for == ship and s.check(ship):
				space = s
	if space == null:
		release_ship(valet)
		return
	space.ready_for = null
	_cue("park", valet)
	if ship.orphan:
		_repark_orphan(ship, space)
	else:
		_on_ship_parked(ship, space)


## Seconds from a first park until the customer asks for the ship back.
func retrieval_delay() -> float:
	return Customer.request_delay(_rng, ledger.time_left)


## Credits the valet who drove the ship in.
func _on_ship_parked(ship: Ship, space: ParkingSpace) -> void:
	space.claim(ship)
	var valet := valet_of(ship)
	if ship == valet.ship:
		release_ship(valet)
	ship.set_parked()
	var c := customer_for(ship)
	if c and c.parked_once:  # a ship moved to make room: already paid for and counted
		_refresh()
		return
	if c == null:
		valet.ledger.serve_customer()
		_cue("fee", valet)
	else:
		c.parked_once = true
		c.parked_in_gold = space.gold
		if c.wants_space != "":
			c.got_wanted_space = space.label == c.wants_space
			_update_pin(c.wants_space)
			if c.got_wanted_space:
				valet.ledger.add_bonus(REQUEST_BONUS)
				Sound.play("bonus")
		if c.wants_retrieval and _exit:
			valet.ledger.add_fee()  # the tip waits until the ship is handed back
			_cue("fee", valet)
			c.request_in = retrieval_delay()
		else:
			_pay_tip(c.tip(), valet)  # before serving: the final serve ends the shift
			valet.ledger.serve_customer()
			_cue("fee", valet)
	_refresh()


func _on_ship_dented(ship: Ship, cost: int) -> void:
	_charge_dent(ship, cost, "dent" if cost < CRASH_COST else "crash")


func _on_ship_bumped(_ship: Ship) -> void:
	Sound.play("bump")


func _pay_tip(amount: int, valet: Valet) -> void:
	valet.ledger.add_tip(amount)
	if amount > 0:
		_cue("tip", valet)


## Charges a dent to the ship's customer and to the pay of the valet answering for it, with the given sound.
func _charge_dent(ship: Ship, cost: int, effect: String) -> void:
	var valet := valet_of(ship)
	_cue(effect, valet)
	var c := customer_for(ship)
	if c:
		c.dents += 1
	valet.ledger.add_dent(cost)
	if valet.local:
		_hud.show_hint("-₵%d dent!" % cost, 1.0)
	_refresh()


## Drawn on the floor at the entrance, under the ships.
func _add_arrival_bay() -> void:
	_bay = _make_arrival_bay(_entrance, "ArrivalBay")


## An ArrivalBay marking drawn just above the floor at an entrance marker.
func _make_arrival_bay(entrance: Node2D, bay_name: String) -> ArrivalBay:
	var bay := ArrivalBay.new()
	bay.name = bay_name
	var floor_node := get_node_or_null("Floor")
	if floor_node:
		floor_node.add_sibling(bay)
	else:
		add_child(bay)
	bay.global_transform = entrance.global_transform
	return bay


func _refresh() -> void:
	_hud.set_time(ledger.time_left)
	_hud.set_pay(ledger.pay, ledger.earned)
	_hud.set_customers(ledger.served, ledger.customers)
	if ledger.outcome != ShiftLedger.Outcome.PLAYING:
		end_level()


## A ship inside any radiation zone takes a dent every RADIATION_INTERVAL seconds it stays in.
func _update_radiation(delta: float) -> void:
	for key: Variant in _radiation_time.keys():
		if not is_instance_valid(key):
			_radiation_time.erase(key)
	for ship: Ship in _ships.get_children():
		if ship.is_queued_for_deletion() or not _in_radiation(ship):
			_radiation_time.erase(ship)
			continue
		_radiation_time[ship] = _radiation_time.get(ship, 0.0) + delta
		if _radiation_time[ship] >= RADIATION_INTERVAL:
			_radiation_time[ship] -= RADIATION_INTERVAL
			_charge_dent(ship, RADIATION_DENT_COST, "radiation")
			if not _radiation_hint_shown:
				_radiation_hint_shown = true
				_hud.show_hint("Radiation! It dents ships inside", 3.0)


func _in_radiation(ship: Ship) -> bool:
	for zone: RadiationZone in _radiation.get_children():
		if zone.touches(ship):
			return true
	return false


## Every lot is pitch black: only floodlights and the ships' own lights show what's there.
## The compressed surveillance-video look over the world. Added first so it draws under the HUD,
## the driving pad and the picker, which share or sit above its canvas layer.
func _add_cctv() -> void:
	_cctv = CctvFilter.new()
	_cctv.name = "CctvFilter"
	_cctv.set_level(GameState.cctv_level)
	add_child(_cctv)
	move_child(_cctv, 0)
	_pause_menu.cctv_changed.connect(_cctv.set_level)


func _add_darkness() -> void:
	var dark := CanvasModulate.new()
	dark.name = "Darkness"
	dark.color = Color.BLACK
	add_child(dark)


## The black hole drags every ship the valet has taken in hand and that isn't parked, at its centre
## of mass so it never spins it. Untouched ships (waiting arrivals, ships whose owner wants them
## back) stay put until picked up. A ship resting inside a space it fits is shielded, so it can
## always settle and park. Drifting asteroids are always pulled.
func _apply_pull() -> void:
	for ship: Ship in _ships.get_children():
		if ship.driven_since_free and not ship.is_parked and not _sheltered(ship):
			ship.apply_central_force(_black_hole.pull_on(ship.global_position) * ship.mass)
	if _asteroids:
		for rock: Asteroid in _asteroids.get_children():
			rock.apply_central_force(_black_hole.pull_on(rock.global_position) * rock.mass)


func _sheltered(ship: Ship) -> bool:
	for space: ParkingSpace in _spaces.get_children():
		if (space.occupant == null or space.occupant == ship) \
				and ParkingRules.fits_class(ship.spec.ship_class, space.space_class) \
				and ParkingRules.points_inside(ship.hull_points(), space.global_transform, space.size()):
			return true
	return false


# --- Orphaned ships ---

## When each orphan shows up: a random moment between 25% and 60% of the shift, but never so late
## that its countdown plus a drive to the exit would outlast the shift.
static func orphan_times(rng: RandomNumberGenerator, count: int, shift: float) -> Array[float]:
	var earliest := 0.25 * shift
	var latest := maxf(earliest, minf(0.6 * shift, shift - Orphan.COUNTDOWN - ORPHAN_EJECT_SECONDS))
	var times: Array[float] = []
	for i in count:
		times.append(rng.randf_range(earliest, latest))
	return times


## Appears due orphans (trying again a second later when no space is allowed), counts down their
## timers, frees a space behind an orphan driven out of it, and settles orphans at the exit.
func _update_orphans(delta: float) -> void:
	_orphan_clock += delta
	for i in _orphans_due.size():
		if _orphans_due[i] <= _orphan_clock and _spawn_orphan() == null:
			_orphans_due[i] = _orphan_clock + ORPHAN_RETRY_SECONDS
		elif _orphans_due[i] <= _orphan_clock:
			_orphans_due[i] = INF
	_orphans_due = _orphans_due.filter(func(t: float) -> bool: return t != INF)
	for ship: Ship in _ships.get_children():
		if ship.orphan == null or ship.is_queued_for_deletion():
			continue
		ship.orphan.tick(delta)
		if ship.is_parked:
			continue
		var space := _space_of(ship)
		if space and not space.touches(ship):
			space.release()
		if _exit and _exit.contains(ship.global_position):
			_eject_orphan(ship)


## Spaces an orphan may take: free, and losing them still leaves room for every customer.
func _allowed_orphan_spaces() -> Array[ParkingSpace]:
	var needed: Array[int] = []
	for spec in customer_queue:
		needed.append(spec.ship_class)
	var allowed: Array[ParkingSpace] = []
	for space: ParkingSpace in _spaces.get_children():
		if space.occupant != null or _space_touched(space):
			continue
		var left: Array[int] = []
		for other: ParkingSpace in _spaces.get_children():
			if other != space and not (other.occupant and other.occupant.orphan):
				left.append(other.space_class)
		if ParkingRules.fits_lot(needed, left):
			allowed.append(space)
	return allowed


func _space_touched(space: ParkingSpace) -> bool:
	for ship: Ship in _ships.get_children():
		if space.touches(ship):
			return true
	return false


## Leaves an abandoned ship parked in an allowed space. Returns null when there is none.
func _spawn_orphan() -> Ship:
	var spaces := _allowed_orphan_spaces()
	spaces.shuffle()
	for space in spaces:
		var fitting := _pool.filter(func(spec: ShipSpec) -> bool:
			return ParkingRules.fits_class(spec.ship_class, space.space_class))
		if fitting.is_empty():
			continue
		var ship: Ship = SHIP_SCENE.instantiate()
		ship.spec = fitting.pick_random()
		ship.global_position = space.global_position
		ship.rotation = space.global_rotation
		_ships.add_child(ship)
		ship.make_orphan(Orphan.new())
		ship.dented.connect(_on_ship_dented)
		ship.bumped.connect(_on_ship_bumped)
		Sound.play("warning")
		space.claim(ship)
		ship.set_parked()
		if not _orphan_hint_shown:
			_orphan_hint_shown = true
			_hud.show_hint("Orphaned ship! Eject it at the EXIT after its timer", 4.0)
		return ship
	return null


## An orphan left at rest in a space settles back into it: parked again, but nobody pays or is served.
func _repark_orphan(ship: Ship, space: ParkingSpace) -> void:
	space.claim(ship)
	var valet := valet_of(ship)
	if ship == valet.ship:
		release_ship(valet)
	ship.set_parked()
	_trackers.erase(ship)


## An orphan leaves through the exit: a bonus once its timer has run out, a fine before that.
func _eject_orphan(ship: Ship) -> void:
	var valet := valet_of(ship)
	if ship == valet.ship:
		release_ship(valet)
	if _picker.is_open():
		_picker.close()
	var space := _space_of(ship)
	if space:
		space.release()
	_trackers.erase(ship)
	_ships.remove_child(ship)
	ship.queue_free()
	if ship.orphan.ready_to_eject():
		valet.ledger.add_bonus(Orphan.BONUS)
		Sound.play("bonus")
	else:
		Sound.play("warning")
		valet.ledger.add_dent(Orphan.EARLY_COST)
		_hud.show_hint("-₵%d ejected too early" % Orphan.EARLY_COST, 1.5)



## A ship or asteroid whose centre reaches the hole's core is flung out the far side, spinning.
func _fling_from_core() -> void:
	var now := Time.get_ticks_msec()
	for body: Variant in _flung_at.keys():
		if not is_instance_valid(body):
			_flung_at.erase(body)  # a ship that left the lot
	var bodies: Array[RigidBody2D] = []
	for ship: Ship in _ships.get_children():
		if not ship.is_parked:
			bodies.append(ship)
	if _asteroids:
		for rock: Asteroid in _asteroids.get_children():
			bodies.append(rock)
	for body in bodies:
		if body.global_position.distance_to(_black_hole.global_position) > BlackHole.FLING_RADIUS:
			continue
		if now - int(_flung_at.get(body, -BlackHole.FLING_COOLDOWN_MS)) < BlackHole.FLING_COOLDOWN_MS:
			continue
		_flung_at[body] = now
		Sound.play("fling")
		body.linear_velocity = BlackHole.fling_velocity(body.linear_velocity, _rng)
		body.angular_velocity = BlackHole.FLING_SPIN * (1.0 if _rng.randf() < 0.5 else -1.0)



# --- Special requests ---

## count distinct queue positions for special requests, never ones that will want their ship back.
func _pick_requests(queue_size: int, count: int) -> Array[int]:
	var free: Array[int] = []
	for i in queue_size:
		if not i in _retrieval_indexes:
			free.append(i)
	for i in range(free.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := free[i]
		free[i] = free[j]
		free[j] = t
	return free.slice(0, mini(count, free.size()))


## The space a request customer asks for: one their ship fits, preferring a space that's taken
## right now so the valet has to make room.
func _pick_request_space(ship_class: int) -> ParkingSpace:
	var named := _open_request_spaces()
	var fitting: Array[ParkingSpace] = []
	var taken: Array[ParkingSpace] = []
	for space: ParkingSpace in _spaces.get_children():
		if ParkingRules.fits_class(ship_class, space.space_class) and not space.label in named:
			fitting.append(space)
			if space.occupant != null:
				taken.append(space)
	if fitting.is_empty():  # every fitting space is already asked for: share one rather than none
		for space: ParkingSpace in _spaces.get_children():
			if ParkingRules.fits_class(ship_class, space.space_class):
				fitting.append(space)
	if not taken.is_empty():
		return taken[_rng.randi_range(0, taken.size() - 1)]
	if not fitting.is_empty():
		return fitting[_rng.randi_range(0, fitting.size() - 1)]
	return null



## Labels of spaces asked for by customers who haven't parked yet.
func _open_request_spaces() -> Array[String]:
	var named: Array[String] = []
	for c: Customer in customers.values():
		if c.wants_space != "" and not c.parked_once:
			named.append(c.wants_space)
	return named


## Shows a space's pin for the first customer still waiting for it, or clears it when nobody is.
func _update_pin(label: String) -> void:
	for space: ParkingSpace in _spaces.get_children():
		if space.label != label:
			continue
		space.clear_pin()
		for c: Customer in customers.values():
			if c.wants_space == label and not c.parked_once:
				space.set_pin(c.color())
				break



# --- Pause ---

func open_pause() -> void:
	if _ended or _pause_menu.is_open():
		return
	get_tree().paused = pauses_tree
	_pause_menu.open()
	Sound.play("open")


func close_pause() -> void:
	if not _pause_menu.is_open():
		return
	_pause_menu.close()
	get_tree().paused = false
	Sound.play("close")


## Android's back gesture opens the pause menu during a shift, and closes it again
## (closing How to Play first when it's open over the menu).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _pause_menu.close_guide():
			return
		if _pause_menu.is_open():
			close_pause()
		else:
			open_pause()


func _on_pause_restart() -> void:
	_pause_menu.close()
	get_tree().paused = false
	last_pause_action = "restart"
	if change_scene_on_end:
		get_tree().reload_current_scene()


func _on_pause_quit() -> void:
	_pause_menu.close()
	get_tree().paused = false
	last_pause_action = "quit"
	if change_scene_on_end:
		get_tree().change_scene_to_file(LEVEL_SELECT)
