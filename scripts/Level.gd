class_name Level
extends Node2D
## Runs one shift: spawns customers, switches between lot view and driving, detects parking,
## tracks pay and ends the level. Each level scene only changes the exported values and layout.

const SHIP_SCENE := preload("res://scenes/actors/Ship.tscn")
const RESULT_SCENE := "res://scenes/ui/Result.tscn"
const ENTRANCE_CLEAR_RADIUS := 120.0

@export var level_number: int = 1
@export var goal_text: String = ""
@export var customer_queue: Array[ShipSpec] = []
@export var shift_seconds: float = 180.0
@export var base_pay: int = 100
@export var silver_target: int = 150
@export var gold_target: int = 170
@export var arrival_interval: float = 8.0

var ledger: ShiftLedger
var driven_ship: Ship = null
var change_scene_on_end := true  # tests turn this off

var _next_customer := 0
var _arrival_timer := 0.0
var _trackers: Dictionary = {}  # Ship -> ParkTracker
var _ended := false
var _drive_hint_shown := false

@onready var _spaces: Node2D = $Spaces
@onready var _ships: Node2D = $Ships
@onready var _entrance: Marker2D = $Entrance
@onready var _lot_camera: Camera2D = $LotCamera
@onready var _hud: HUD = $HUD
@onready var _controls: ShipControls = $Controls


func _ready() -> void:
	ledger = ShiftLedger.new(base_pay, customer_queue.size(), shift_seconds)
	GameState.current_level = level_number
	_hud.set_goal(goal_text)
	_controls.done_pressed.connect(release_ship)
	_lot_camera.make_current()
	spawn_next_customer()
	_hud.show_hint("Tap a ship to drive it", 4.0)
	_refresh()


func _physics_process(delta: float) -> void:
	if _ended:
		return
	ledger.tick(delta)
	_arrival_timer += delta
	if _arrival_timer >= arrival_interval and _entrance_clear():
		if spawn_next_customer():
			_arrival_timer = 0.0
	_check_parking(delta)
	_refresh()


## Spawns the next customer's ship at the entrance. Returns null when the queue is used up.
func spawn_next_customer() -> Ship:
	if _next_customer >= customer_queue.size():
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.spec = customer_queue[_next_customer]
	ship.global_position = _entrance.global_position
	ship.rotation = _entrance.global_rotation
	_next_customer += 1
	_ships.add_child(ship)
	ship.dented.connect(_on_ship_dented)
	ship.selected.connect(select_ship)
	return ship


## Takes control of a ship. Ignored while already driving: press Done first.
func select_ship(ship: Ship) -> void:
	if _ended or ship.is_parked or driven_ship != null:
		return
	driven_ship = ship
	ship.set_driven(true)
	_controls.set_driving(true)
	if not _drive_hint_shown:
		_drive_hint_shown = true
		_hud.show_hint("Stop inside a green space", 3.0)


func release_ship() -> void:
	if driven_ship:
		driven_ship.set_driven(false)
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
		"served": ledger.served,
		"customers": ledger.customers,
		"reason": reasons.get(ledger.outcome, "timeout"),
	}
	if change_scene_on_end:
		get_tree().change_scene_to_file.call_deferred(RESULT_SCENE)


func _check_parking(delta: float) -> void:
	for ship: Ship in _ships.get_children():
		if ship.is_parked:
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
	ledger.serve_customer()
	_refresh()


func _on_ship_dented(_ship: Ship, cost: int) -> void:
	ledger.add_dent(cost)
	_hud.show_hint("-₵%d dent!" % cost, 1.0)
	_refresh()


func _entrance_clear() -> bool:
	for ship: Ship in _ships.get_children():
		if ship.global_position.distance_to(_entrance.global_position) < ENTRANCE_CLEAR_RADIUS:
			return false
	return true


func _refresh() -> void:
	_hud.set_time(ledger.time_left)
	_hud.set_pay(ledger.pay, ledger.earned)
	_hud.set_customers(ledger.served, ledger.customers)
	if ledger.outcome != ShiftLedger.Outcome.PLAYING:
		end_level()
