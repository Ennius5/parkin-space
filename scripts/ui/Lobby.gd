extends Control
## Online lobby: pick the match length, then Host (shows this phone's Wi-Fi address) or Join an
## address. When the rival connects both phones open the duel lot. Back closes any connection.

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const DUEL := "res://scenes/levels/Duel.tscn"
const HOSTING := "Hosting on %s — waiting for a rival…"
const HOST_FAILED := "Could not start hosting. Try again."
const JOINING := "Joining %s…"
const CONNECTED := "Connected — %d:00 match"

var session: NetSession  # null = the Net autoload; tests give their own
var change_scenes := true  # tests turn this off
var last_target := ""  # the scene this screen last went to


func _ready() -> void:
	if session == null:
		session = Net
	Sound.play_menu_music()
	GameState.duel_role = ""
	_build()
	refresh_minutes()
	%Less.pressed.connect(step_minutes.bind(-1))
	%More.pressed.connect(step_minutes.bind(1))
	%Host.pressed.connect(_on_host_pressed)
	%Join.pressed.connect(_on_join_pressed)
	%Ip.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	%Back.pressed.connect(go_back)
	session.connected.connect(_on_connected)
	session.join_failed.connect(_on_join_failed)
	Sound.wire_clicks(self)


func _exit_tree() -> void:
	if is_instance_valid(session) and session.connected.is_connected(_on_connected):
		session.connected.disconnect(_on_connected)
		session.join_failed.disconnect(_on_join_failed)


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
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_add_label(box, "Heading", "Online duel", 48)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	box.add_child(columns)
	# Host column: the match length stepper sits above Host.
	var host_col := VBoxContainer.new()
	host_col.add_theme_constant_override("separation", 22)
	columns.add_child(host_col)
	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 16)
	host_col.add_child(stepper)
	_add_button(stepper, "Less", "−", Vector2(96, 96))
	var minutes := _add_label(stepper, "Minutes", "3:00", 44)
	minutes.custom_minimum_size = Vector2(180, 0)
	_add_button(stepper, "More", "+", Vector2(96, 96))
	_add_button(host_col, "Host", "Host", Vector2(420, 110))
	# Join column: the address field above Join.
	var join_col := VBoxContainer.new()
	join_col.add_theme_constant_override("separation", 22)
	columns.add_child(join_col)
	var ip := LineEdit.new()
	ip.name = "Ip"
	ip.text = GameState.last_ip
	ip.placeholder_text = "Host's IP, e.g. 192.168.1.5"
	ip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip.custom_minimum_size = Vector2(420, 96)
	ip.add_theme_font_size_override("font_size", 32)
	_own(join_col, ip)
	_add_button(join_col, "Join", "Join", Vector2(420, 110))
	var status := _add_label(box, "Status", "", 30)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(900, 0)
	var big_ip := _add_label(box, "HostIp", "", 72)
	big_ip.add_theme_color_override("font_color", HexStyle.CYAN)
	big_ip.visible = false
	var back := _add_button(box, "Back", "Back", Vector2(420, 96))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _add_label(parent: Control, node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(parent, label)
	return label


func _add_button(parent: Control, node_name: String, text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 36)
	_own(parent, b)
	return b


## Adds a child reachable as %Name.
func _own(parent: Control, child: Control) -> void:
	parent.add_child(child)
	child.owner = self
	child.unique_name_in_owner = true


## Changes the match length by `delta` minutes, within 3..20, and saves it as the next default.
func step_minutes(delta: int) -> void:
	GameState.duel_minutes = clampi(GameState.duel_minutes + delta, GameState.DUEL_MIN, GameState.DUEL_MAX)
	GameState.save_progress()
	refresh_minutes()


func refresh_minutes() -> void:
	(%Minutes as Label).text = "%d:00" % GameState.duel_minutes
	session.duel_minutes = GameState.duel_minutes  # what a guest joining now is told


func _set_status(text: String, ip := "") -> void:
	(%Status as Label).text = text
	(%HostIp as Label).text = ip
	(%HostIp as Label).visible = ip != ""


func _on_host_pressed() -> void:
	session.duel_minutes = GameState.duel_minutes
	if session.host() != OK:
		_set_status(HOST_FAILED)
		return
	var ip := session.local_ip()
	if ip == "":
		ip = "this device"
		_set_status(HOSTING % ip)
	else:
		_set_status(HOSTING % ip, ip)


func _on_join_pressed() -> void:
	var ip := (%Ip as LineEdit).text.strip_edges()
	GameState.last_ip = ip
	GameState.save_progress()
	# An address ENet can't parse fails at once, without join_failed.
	if ip == "" or session.join(ip) != OK:
		_set_status(NetSession.MSG_UNREACHABLE)
		return
	_set_status(JOINING % ip)


func _on_join_failed(reason: String) -> void:
	_set_status(reason)


## Both phones open the duel lot; the duel reads its role from GameState.
func _on_connected() -> void:
	GameState.duel_role = "host" if session.is_host() else "guest"
	_set_status(CONNECTED % session.duel_minutes)
	_go.call_deferred(DUEL)  # this runs inside the network poll


## Back (button or gesture): close any connection and return to Mode Select.
func go_back() -> void:
	session.close()
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
		go_back()
