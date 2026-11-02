extends Control
## Offline / Online choice. Online arrives in Week 4.

const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const TITLE := "res://scenes/ui/Title.tscn"


func _ready() -> void:
	Sound.play_menu_music()
	%Offline.pressed.connect(_on_offline_pressed)
	%Back.pressed.connect(get_tree().change_scene_to_file.bind(TITLE))


func _on_offline_pressed() -> void:
	GameState.mode = "offline"
	get_tree().change_scene_to_file(LEVEL_SELECT)
