extends Control
## After an online match: You win / You lose / Draw with both scores, then Rematch or Leave.
## A rematch starts once both players have asked for it; the same pair reloads the duel lot.

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const DUEL := "res://scenes/levels/Duel.tscn"
const WAITING := "Waiting for rival…"
const RIVAL_ASKED := "Your rival wants a rematch"

var session: NetSession  # null = the Net autoload; tests give their own
var change_scenes := true  # tests turn this off
var last_target := ""  # the scene this screen last went to

var _asked := false  # this player tapped Rematch


func _ready() -> void:
	if session == null:
		session = Net
	Sound.play_menu_music()
	_build()
	show_result(GameState.duel_result)
	%Rematch.pressed.connect(_on_rematch_pressed)
	%Leave.pressed.connect(leave)
	session.rival_rematch.connect(_on_rival_rematch)
	session.rival_left.connect(_on_rival_left)
	Sound.wire_clicks(self)
	if GameState.duel_role != "" and not session.is_active():  # the rival dropped on the way here
		_on_rival_left.call_deferred()  # not mid-way through this scene's arrival
	elif session.rival_wants_rematch:
		(%Status as Label).text = RIVAL_ASKED


func _exit_tree() -> void:
	if is_instance_valid(session) and session.rival_left.is_connected(_on_rival_left):
		session.rival_left.disconnect(_on_rival_left)
		session.rival_rematch.disconnect(_on_rival_rematch)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	_add_label(box, "Title", "", 72)
	_add_label(box, "Scores", "", 40)
	_add_label(box, "Status", "", 30)
	_add_button(box, "Rematch", "Rematch")
	_add_button(box, "Leave", "Leave")


func _add_label(parent: Control, node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(parent, label)
	return label


func _add_button(parent: Control, node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(420, 110)
	b.add_theme_font_size_override("font_size", 36)
	_own(parent, b)
	return b


## Adds a child reachable as %Name.
func _own(parent: Control, child: Control) -> void:
	parent.add_child(child)
	child.owner = self
	child.unique_name_in_owner = true


## Shows the outcome of {mine, rival}.
func show_result(result: Dictionary) -> void:
	var mine: int = result.get("mine", 0)
	var rival: int = result.get("rival", 0)
	var title := %Title as Label
	if mine > rival:
		title.text = "You win"
		title.add_theme_color_override("font_color", HexStyle.CYAN)
	elif mine < rival:
		title.text = "You lose"
		title.add_theme_color_override("font_color", HexStyle.MAGENTA)
	else:
		title.text = "Draw"
		title.remove_theme_color_override("font_color")
	(%Scores as Label).text = "You ₵%d · Rival ₵%d" % [mine, rival]


func _on_rematch_pressed() -> void:
	if _asked:
		return
	_asked = true
	(%Rematch as Button).disabled = true
	(%Status as Label).text = WAITING
	session.ask_rematch()
	if session.rival_wants_rematch:
		_start_rematch()


func _on_rival_rematch() -> void:
	if _asked:
		_start_rematch()
	else:
		(%Status as Label).text = RIVAL_ASKED


## Both asked: the same roles and length reload the lot (the host picks a new seed there).
func _start_rematch() -> void:
	session.rival_wants_rematch = false
	_go.call_deferred(DUEL)  # may run inside the network poll


## Leave (button or gesture): tell the rival, close, go to Mode Select.
func leave() -> void:
	session.leave()
	GameState.duel_role = ""
	_go(MODE_SELECT)


func _on_rival_left() -> void:
	GameState.notice = DuelLevel.RIVAL_LEFT
	GameState.duel_role = ""
	_go(MODE_SELECT)


func _go(path: String) -> void:
	last_target = path
	if change_scenes and is_inside_tree():
		get_tree().change_scene_to_file(path)


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return MODE_SELECT


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		leave()
