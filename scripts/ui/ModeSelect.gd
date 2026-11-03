extends Control
## Offline / Online choice. The note under Online shows GameState.notice once (e.g. a rival
## leaving the match), then clears it.

const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const LOBBY := "res://scenes/ui/Lobby.tscn"
const TITLE := "res://scenes/ui/Title.tscn"
const CREDITS := "res://scenes/ui/Credits.tscn"
const GUIDE := "res://scenes/ui/Guide.tscn"
const BUTTON_HEIGHT := 100.0  # five buttons and the heading fit a 720-px-tall screen
const SEPARATION := 18

var change_scenes := true  # tests turn this off
var last_target := ""  # the scene a button last went to


func _ready() -> void:
	Sound.play_menu_music()
	GameState.duel_role = ""
	_add_credits_button()
	_add_guide_button()
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


## A How to Play button just above Credits; the menu tightens up so it still fits.
func _add_guide_button() -> void:
	var credits := %Credits as Button
	var guide := Button.new()
	guide.name = "HowToPlay"
	guide.text = "How to Play"
	guide.custom_minimum_size = credits.custom_minimum_size
	guide.add_theme_font_size_override("font_size", credits.get_theme_font_size("font_size"))
	guide.pressed.connect(_go.bind(GUIDE))
	credits.add_sibling(guide)
	credits.get_parent().move_child(guide, credits.get_index())
	guide.owner = self
	guide.unique_name_in_owner = true
	var box := credits.get_parent() as VBoxContainer
	box.add_theme_constant_override("separation", SEPARATION)
	for b in box.get_children():
		if b is Button:
			(b as Button).custom_minimum_size.y = BUTTON_HEIGHT


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return TITLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if back_target() == "":
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(back_target())
