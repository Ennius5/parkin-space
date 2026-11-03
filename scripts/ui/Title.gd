extends Control
## Title screen: tap anywhere to continue.

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const HINT_PERIOD := 2.4  # seconds for one fade out and back in

@onready var _hint: Label = %TapHint
var _time := 0.0


func _ready() -> void:
	Sound.play_menu_music()


func _process(delta: float) -> void:
	_time += delta
	_hint.modulate.a = hint_alpha(_time)


## "Tap to start" opacity at time t: breathes between 0.35 and 1.
static func hint_alpha(t: float) -> float:
	return 0.675 + 0.325 * cos(t * TAU / HINT_PERIOD)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if tapped or clicked:
		accept_event()
		get_tree().change_scene_to_file(MODE_SELECT)


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if back_target() == "":
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(back_target())
