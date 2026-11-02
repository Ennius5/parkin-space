extends Control
## Offline / Online choice. The note under Online shows GameState.notice once (e.g. a rival
## leaving the match), then clears it.

const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const LOBBY := "res://scenes/ui/Lobby.tscn"
const TITLE := "res://scenes/ui/Title.tscn"
const CREDITS := "res://scenes/ui/Credits.tscn"

var change_scenes := true  # tests turn this off
var last_target := ""  # the scene a button last went to


func _ready() -> void:
	Sound.play_menu_music()
	GameState.duel_role = ""
	_add_credits_button()
	Sound.wire_clicks(self)
	%Offline.pressed.connect(_on_offline_pressed)
	%Online.pressed.connect(_on_online_pressed)
	%Back.pressed.connect(_go.bind(TITLE))
	_show_notice()


func _on_offline_pressed() -> void:
	GameState.mode = "offline"
	_go(LEVEL_SELECT)


func _on_online_pressed() -> void:
	GameState.mode = "online"
	_go(LOBBY)


## The pending notice, once; with none the note stays hidden.
func _show_notice() -> void:
	var note := %OnlineNote as Label
	note.text = GameState.notice
	note.add_theme_color_override("font_color", HexStyle.MAGENTA)
	note.visible = GameState.notice != ""
	GameState.notice = ""


func _go(path: String) -> void:
	last_target = path
	if change_scenes:
		get_tree().change_scene_to_file(path)


## A Credits button just above Back.
func _add_credits_button() -> void:
	var back := %Back as Button
	var credits := Button.new()
	credits.name = "Credits"
	credits.text = "Credits"
	credits.custom_minimum_size = back.custom_minimum_size
	credits.add_theme_font_size_override("font_size", back.get_theme_font_size("font_size"))
	credits.pressed.connect(_go.bind(CREDITS))
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
