extends Control
## Offline / Online choice. Online arrives in Week 4.

const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const TITLE := "res://scenes/ui/Title.tscn"
const CREDITS := "res://scenes/ui/Credits.tscn"


func _ready() -> void:
	Sound.play_menu_music()
	_add_credits_button()
	Sound.wire_clicks(self)
	%Offline.pressed.connect(_on_offline_pressed)
	%Back.pressed.connect(get_tree().change_scene_to_file.bind(TITLE))


func _on_offline_pressed() -> void:
	GameState.mode = "offline"
	get_tree().change_scene_to_file(LEVEL_SELECT)


## A Credits button just above Back.
func _add_credits_button() -> void:
	var back := %Back as Button
	var credits := Button.new()
	credits.name = "Credits"
	credits.text = "Credits"
	credits.custom_minimum_size = back.custom_minimum_size
	credits.add_theme_font_size_override("font_size", back.get_theme_font_size("font_size"))
	credits.pressed.connect(get_tree().change_scene_to_file.bind(CREDITS))
	back.add_sibling(credits)
	back.get_parent().move_child(credits, back.get_index())
	credits.owner = self
	credits.unique_name_in_owner = true


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return TITLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if back_target() == "":
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(back_target())
