class_name PauseMenu
extends CanvasLayer
## Pause screen over a level: Resume, Restart, Sound on/off, CCTV strength, Quit. Runs while the tree is paused.
## Online (set_online) the match keeps running: Restart is hidden and Quit becomes "Leave match",
## which asks "Leave the match?" before quit_pressed.

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal cctv_changed(level: int)

const QUIT_TEXT := "Quit to Level Select"
const LEAVE_TEXT := "Leave match"
const CONFIRM_TEXT := "Leave the match?"
const TITLE_TEXT := "Paused"
const ONLINE_TITLE_TEXT := "Match still running"  # online nothing stops: the rival plays on

var _panel := Control.new()
var _buttons: VBoxContainer  # the menu itself, hidden while the confirm shows
var _confirm: VBoxContainer
var _online := false


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_buttons = VBoxContainer.new()
	var box := _buttons
	box.add_theme_constant_override("separation", 14)
	stack.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	title.owner = self
	title.unique_name_in_owner = true
	_add_button(box, "Resume", "Resume").pressed.connect(func() -> void: resume_pressed.emit())
	_add_button(box, "Restart", "Restart").pressed.connect(func() -> void: restart_pressed.emit())
	_add_button(box, "SoundToggle", "").pressed.connect(_on_sound_pressed)
	_add_button(box, "CctvToggle", "").pressed.connect(_on_cctv_pressed)
	_add_button(box, "Quit", QUIT_TEXT).pressed.connect(_on_quit_pressed)
	_build_confirm(stack)
	Sound.wire_clicks(self)
	refresh_sound_label()
	refresh_cctv_label()
	_panel.visible = false


func _add_button(box: VBoxContainer, node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(420, 84)  # thumb-sized, five fit on a phone screen
	b.add_theme_font_size_override("font_size", 32)
	box.add_child(b)
	b.owner = self
	b.unique_name_in_owner = true
	return b


## "Leave the match?" with Yes and No, in place of the menu.
func _build_confirm(stack: VBoxContainer) -> void:
	_confirm = VBoxContainer.new()
	_confirm.name = "Confirm"
	_confirm.add_theme_constant_override("separation", 14)
	_confirm.visible = false
	stack.add_child(_confirm)
	_confirm.owner = self
	_confirm.unique_name_in_owner = true
	var text := Label.new()
	text.name = "ConfirmText"
	text.text = CONFIRM_TEXT
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 40)
	_confirm.add_child(text)
	text.owner = self
	text.unique_name_in_owner = true
	_add_button(_confirm, "Yes", "Yes").pressed.connect(func() -> void: quit_pressed.emit())
	_add_button(_confirm, "No", "No").pressed.connect(_show_confirm.bind(false))


## Online: the match can't be paused, restarted or quit without a word.
func set_online(on: bool) -> void:
	_online = on
	(get_node("%Title") as Label).text = ONLINE_TITLE_TEXT if on else TITLE_TEXT
	(get_node("%Restart") as Button).visible = not on
	(get_node("%Quit") as Button).text = LEAVE_TEXT if on else QUIT_TEXT


func _on_quit_pressed() -> void:
	if _online:
		_show_confirm(true)
	else:
		quit_pressed.emit()


func _show_confirm(on: bool) -> void:
	_confirm.visible = on
	_buttons.visible = not on


func open() -> void:
	_show_confirm(false)
	refresh_sound_label()
	refresh_cctv_label()
	_panel.visible = true


func close() -> void:
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func refresh_sound_label() -> void:
	(get_node("%SoundToggle") as Button).text = "Sound: On" if GameState.sound_on else "Sound: Off"


func _on_sound_pressed() -> void:
	Sound.set_sound_on(not GameState.sound_on)
	refresh_sound_label()


func refresh_cctv_label() -> void:
	(get_node("%CctvToggle") as Button).text = "CCTV: " + CctvFilter.NAMES[GameState.cctv_level]


## Steps Off -> Light -> Medium -> Heavy -> Off, saves it and tells the level.
func _on_cctv_pressed() -> void:
	GameState.cctv_level = (GameState.cctv_level + 1) % CctvFilter.STRENGTHS.size()
	GameState.save_progress()
	refresh_cctv_label()
	cctv_changed.emit(GameState.cctv_level)


## Escape on desktop closes the menu, like the back gesture.
func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
