class_name ShipControls
extends CanvasLayer
## On-screen thruster buttons. Each TouchScreenButton presses an Input Map action,
## so multi-touch (thrust + rotate together) works without extra code.

signal done_pressed

const EDGE_MARGIN := 40.0

@onready var _buttons: Node2D = $Buttons
@onready var _right_cluster: Node2D = $Buttons/Right


func _ready() -> void:
	$Buttons/Right/Done.pressed.connect(done_pressed.emit)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_driving(false)


func set_driving(on: bool) -> void:
	_buttons.visible = on


## Keep the right-hand cluster against the right edge on wider-than-16:9 screens.
func _layout() -> void:
	var view_size := get_viewport().get_visible_rect().size
	_right_cluster.position = Vector2(view_size.x - EDGE_MARGIN, view_size.y - EDGE_MARGIN)
	$Buttons/Left.position = Vector2(EDGE_MARGIN, view_size.y - EDGE_MARGIN)
