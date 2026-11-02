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
const RESULT_SCENE := "res://scenes/ui/Result.tscn"
const ARRIVAL_CLEAR_SECONDS := 1.0  # the arrival bay must stay empty this long before the next ship
const RESELECT_DELAY_MS := 300  # the touch that presses Done must not also select a ship
const PICK_RADIUS_SCREEN := 100.0  # thumb-sized: ships this close to a tap (on screen) are candidates

@export var level_number: int = 1
@export var goal_text: String = ""
@export var customer_queue: Array[ShipSpec] = []
## Above 0: each shift draws this many customers from customer_queue by spawn_weight (repeats allowed).
@export var random_customers: int = 0
@export var shift_seconds: float = 180.0
@export var base_pay: int = 100
@export var silver_target: int = 150
@export var gold_target: int = 170
@export var arrival_interval: float = 8.0
@export var use_tiers := false  # bronze/silver/gold customers who tip
## How many customers want their ship back at the exit. Needs an ExitPad named Exit.
@export var retrieval_count: int = 0

var ledger: ShiftLedger
var customers: Dictionary = {}  # Ship -> Customer
var driven_ship: Ship = null
var change_scene_on_end := true  # tests turn this off

var _next_customer := 0
var _arrival_timer := 0.0
var _trackers: Dictionary = {}  # Ship -> ParkTracker
var _ended := false
var _drive_hint_shown := false
var _released_at_msec := -RESELECT_DELAY_MS
var _rng := RandomNumberGenerator.new()
var _retrieval_indexes: Array[int] = []  # queue positions of customers who will want their ship back
var _return_hint_shown := false
var _bay: ArrivalBay
var _bay_clear_for := 0.0

@onready var _spaces: Node2D = $Spaces
@onready var _ships: Node2D = $Ships
@onready var _entrance: Marker2D = $Entrance
@onready var _lot_camera: Camera2D = $LotCamera
@onready var _hud: HUD = $HUD
@onready var _controls: ShipControls = $Controls
@onready var _picker: ShipPicker = $ShipPicker
@onready var _exit: ExitPad = get_node_or_null("Exit")


func _ready() -> void:
	_rng.randomize()
	if random_customers > 0:
		customer_queue = draw_customers(customer_queue, random_customers, _rng, _space_classes())
	if _exit:
		_retrieval_indexes = _pick_retrievals(customer_queue.size(), retrieval_count)
	ledger = ShiftLedger.new(base_pay, customer_queue.size(), shift_seconds)
	GameState.current_level = level_number
	_hud.set_goal(goal_text)
	_controls.done_pressed.connect(release_ship)
	_picker.picked.connect(_on_picked)
	_lot_camera.make_current()
	_add_arrival_bay()
	spawn_next_customer()
	_hud.show_hint("Tap a ship to drive it", 4.0)
	_refresh()


func _physics_process(delta: float) -> void:
	if _ended:
		return
	ledger.tick(delta)
	_arrival_timer += delta
	_bay_clear_for = _bay_clear_for + delta if _bay.is_clear(_ships.get_children()) else 0.0
	if _arrival_timer >= arrival_interval and _bay_clear_for >= ARRIVAL_CLEAR_SECONDS:
		if spawn_next_customer():
			_arrival_timer = 0.0
			_bay_clear_for = 0.0
	_check_parking(delta)
	_update_customers(delta)
	_refresh()


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
		if c.requested:
			var space := _space_of(ship)
			if space and not space.touches(ship):
				space.release()
			if _exit and _exit.contains(ship.global_position):
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
	ship.unpark()
	_trackers.erase(ship)
	if not _return_hint_shown:
		_return_hint_shown = true
		_hud.show_hint("A customer wants their ship – return it to the EXIT", 4.0)


## Hands a requested ship back to its customer: it leaves the lot and the customer is served.
func _return(ship: Ship) -> void:
	var c: Customer = customers[ship]
	if ship == driven_ship:
		release_ship()
	var space := _space_of(ship)
	if space:
		space.release()
	if _picker.is_open():
		_picker.close()
	customers.erase(ship)
	_trackers.erase(ship)
	_ships.remove_child(ship)
	ship.queue_free()
	ledger.add_tip(c.tip())  # before serving: the final serve ends the shift
	ledger.serve_customer(0)


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
	ship.paint_color = PAINT_COLORS.pick_random()
	var c := Customer.roll(_rng, use_tiers, gold_allowed(ship.spec.ship_class))
	c.wants_retrieval = _next_customer in _retrieval_indexes
	ship.customer = c
	customers[ship] = c
	ship.global_position = _entrance.global_position
	ship.rotation = _entrance.global_rotation
	_next_customer += 1
	_ships.add_child(ship)
	ship.dented.connect(_on_ship_dented)
	return ship


## Lot view: a tap picks the one ship near it, or lists them when there's a choice.
## A tap while the list is open closes it.
func _unhandled_input(event: InputEvent) -> void:
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
	if near.size() == 1:
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
		if ship.is_parked:
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


func _on_picked(ship: Ship) -> void:
	_picker.close()
	select_ship(ship)


## Takes control of a ship. Ignored while already driving (press Done first)
## and for a moment after Done, so the same touch doesn't grab a ship under the button.
func select_ship(ship: Ship) -> void:
	if _ended or ship.is_parked or driven_ship != null:
		return
	if Time.get_ticks_msec() - _released_at_msec < RESELECT_DELAY_MS:
		return
	_picker.close()
	driven_ship = ship
	ship.set_driven(true)
	_controls.set_driving(true)
	if not _drive_hint_shown:
		_drive_hint_shown = true
		_hud.show_hint("Stop inside a green space", 3.0)


func release_ship() -> void:
	if driven_ship:
		driven_ship.set_driven(false)
		_released_at_msec = Time.get_ticks_msec()
	driven_ship = null
	_lot_camera.make_current()
	_controls.set_driving(false)


func end_level() -> void:
	if _ended:
		return
	_ended = true
	release_ship()
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
		"earnings": ledger.earnings(),
		"tips": ledger.tips,
		"served": ledger.served,
		"customers": ledger.customers,
		"reason": reasons.get(ledger.outcome, "timeout"),
	}
	if change_scene_on_end:
		get_tree().change_scene_to_file.call_deferred(RESULT_SCENE)


func _check_parking(delta: float) -> void:
	for ship: Ship in _ships.get_children():
		var c := customer_for(ship)
		if ship.is_parked or (c and c.requested):
			continue
		var hit: ParkingSpace = null
		for space: ParkingSpace in _spaces.get_children():
			if space.check(ship):
				hit = space
				break
		var tracker: ParkTracker = _trackers.get_or_add(ship, ParkTracker.new())
		if tracker.update(delta, hit != null):
			_on_ship_parked(ship, hit)


func _on_ship_parked(ship: Ship, space: ParkingSpace) -> void:
	space.claim(ship)
	if ship == driven_ship:
		release_ship()
	ship.set_parked()
	var c := customer_for(ship)
	if c == null:
		ledger.serve_customer()
	else:
		c.parked_once = true
		c.parked_in_gold = space.gold
		if c.wants_retrieval and _exit:
			ledger.add_fee()  # the tip waits until the ship is handed back
			c.request_in = Customer.request_delay(_rng, ledger.time_left)
		else:
			ledger.add_tip(c.tip())  # before serving: the final serve ends the shift
			ledger.serve_customer()
	_refresh()


func _on_ship_dented(ship: Ship, cost: int) -> void:
	var c := customer_for(ship)
	if c:
		c.dents += 1
	ledger.add_dent(cost)
	_hud.show_hint("-₵%d dent!" % cost, 1.0)
	_refresh()


## Drawn on the floor at the entrance, under the ships.
func _add_arrival_bay() -> void:
	_bay = ArrivalBay.new()
	_bay.name = "ArrivalBay"
	var floor_node := get_node_or_null("Floor")
	if floor_node:
		floor_node.add_sibling(_bay)
	else:
		add_child(_bay)
	_bay.global_transform = _entrance.global_transform


func _refresh() -> void:
	_hud.set_time(ledger.time_left)
	_hud.set_pay(ledger.pay, ledger.earned)
	_hud.set_customers(ledger.served, ledger.customers)
	if ledger.outcome != ShiftLedger.Outcome.PLAYING:
		end_level()
