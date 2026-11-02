extends Control
## Title screen: tap anywhere to continue.

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"



func _ready() -> void:
	Sound.play_menu_music()

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if tapped or clicked:
		accept_event()
		get_tree().change_scene_to_file(MODE_SELECT)
