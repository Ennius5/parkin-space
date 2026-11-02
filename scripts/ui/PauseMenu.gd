class_name PauseMenu
extends CanvasLayer
## Pause screen over a level: Resume, Restart, Sound on/off, Quit. Runs while the tree is paused.

signal resume_pressed
signal restart_pressed
signal quit_pressed

var _panel := Control.new()


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	_add_button(box, "Resume", "Resume").pressed.connect(func() -> void: resume_pressed.emit())
	_add_button(box, "Restart", "Restart").pressed.connect(func() -> void: restart_pressed.emit())
	_add_button(box, "SoundToggle", "").pressed.connect(_on_sound_pressed)
	_add_button(box, "Quit", "Quit to Level Select").pressed.connect(func() -> void: quit_pressed.emit())
	Sound.wire_clicks(self)
	refresh_sound_label()
	_panel.visible = false


func _add_button(box: VBoxContainer, node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(420, 96)  # thumb-sized
	b.add_theme_font_size_override("font_size", 32)
	box.add_child(b)
	b.owner = self
	b.unique_name_in_owner = true
	return b


func open() -> void:
	refresh_sound_label()
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


## Escape on desktop closes the menu, like the back gesture.
func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
