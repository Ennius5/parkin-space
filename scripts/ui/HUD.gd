class_name HUD
extends CanvasLayer
## In-level heads-up display: goal, shift timer, pay, customers served and short hints.

signal pause_pressed

var _hint_left := 0.0

@onready var _goal: Label = %Goal
@onready var _time: Label = %Time
@onready var _pay: Label = %Pay
@onready var _customers: Label = %Customers
@onready var _hint: Label = %Hint


func _ready() -> void:
	var pause := Button.new()
	pause.name = "PauseButton"
	pause.text = "II"
	pause.add_theme_font_size_override("font_size", 40)
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -140.0
	pause.offset_right = -40.0
	pause.offset_top = 80.0
	pause.offset_bottom = 180.0  # 100 x 100, under the timer: thumb-sized
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	$Root.add_child(pause)


func _process(delta: float) -> void:
	if _hint_left > 0.0:
		_hint_left -= delta
		_hint.visible = _hint_left > 0.0


func set_goal(text: String) -> void:
	_goal.text = text


func set_time(seconds: float) -> void:
	var s := ceili(seconds)
	_time.text = "%d:%02d" % [s / 60, s % 60]


func set_pay(pay: int, earned: int) -> void:
	_pay.text = "Pay ₵%d   Earned ₵%d" % [pay, earned]


func set_customers(served: int, total: int) -> void:
	_customers.text = "Served %d / %d" % [served, total]


func show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	_hint.visible = true
	_hint_left = seconds
