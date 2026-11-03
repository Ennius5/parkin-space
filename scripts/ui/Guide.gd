class_name Guide
extends Control
## How to Play: one topic per page, every row a small GuideIcon and a line or two of text.
## Three pages (Light, Medium, Heavy ships) list the roster found in resources/ships at runtime.
## As a screen (Guide.tscn, from Mode Select) Back returns to Mode Select. As an overlay
## (as_overlay, from the pause menu) Back and Escape emit `closed` and the pause menu frees it.
## No gameplay runs here; numbers in the copy are read from the game's constants.

signal closed

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const RUNNING_TEXT := "Match still running"
const TITLE_SIZE := 44
const BODY_SIZE := 26
const ICON_GAP := 8
const DIM_DOT := Color(0.35, 0.55, 0.6, 0.45)
const SHIP_DIR := "res://resources/ships/"
const SHIPS_PER_PAGE := 4
const SHIP_NAME_SIZE := 26
const SHIP_FEEL_SIZE := 24
const TIP_COLOR := Color(1.0, 0.85, 0.3)  # a highlighted tip row: [[], text, TIP_COLOR]
const CLASS_NAMES := {ShipSpec.ShipClass.LIGHT: "Light", ShipSpec.ShipClass.MEDIUM: "Medium",
	ShipSpec.ShipClass.HEAVY: "Heavy"}
const ROW_PAINTS := [5, 1, 2, 4, 0]  # Level.PAINT_COLORS entries, one per row: orange, blue, green, purple, red
## One line on how each ship handles, keyed by resource name. Ships not listed get a generated line.
const FEEL := {
	"AsteroidJunker": "Scrappy little hauler: the snappiest turner on the lot.",
	"ManipulatorDrone": "Nimble workhorse with grabby arms: spins on a dime.",
	"ReconDrone": "Rare and nose-heavy: lazy to turn, easy to overshoot.",
	"RecreationalDrone": "Light, quick and forgiving: a Sunday cruiser.",
	"Milano": "The all-rounder, with a tail-heavy swing.",
	"Miner": "Lopsided ore hauler: the slowest medium to turn.",
	"Nostrom": "Rare, well balanced, and the sharpest-turning medium.",
	"AgriShip": "Tail-heavy giant on 19 thrusters: the slowest turner of all.",
	"Hammerhead": "Nose-heavy bruiser: start your turns early.",
	"Researcher": "Big, but nimble for a heavy: it leans a little to the left.",
}

var as_overlay := false  # set before adding to the tree
var change_scenes := true  # tests turn this off
var last_target := ""  # the scene Back last went to
var page := 0

var _data: Array[Dictionary] = []
var _pages: Array[Control] = []
var _title := Label.new()
var _note := Label.new()
var _dots := HBoxContainer.new()
var _prev := Button.new()
var _next := Button.new()
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not as_overlay:
		Sound.play_menu_music()
	_data = page_data()
	_build()
	Sound.wire_clicks(self)
	show_page(0)


## Every page: a title and rows of [icon kinds, text].
static func page_data() -> Array[Dictionary]:
	var shift := PackedStringArray()
	for d: int in GameState.SHIFT_SECONDS:
		var s := int(GameState.SHIFT_SECONDS[d])
		shift.append("%s %d:%02d" % [GameState.DIFFICULTY_NAMES[d], s / 60, s % 60])
	var pages: Array[Dictionary] = [
		{"title": "Controls", "rows": [
			[[&"ship"], "Tap a ship to drive it.\nShips drift in zero-g: nothing slows them but you."],
			[[&"pad_fwd", &"pad_back", &"pad_left", &"pad_right"], "Fwd / Back: thrust.\nLeft / Right: slide sideways."],
			[[&"pad_rot_l", &"pad_rot_r", &"pad_stop", &"pad_stop_spin"], "Rot L / Rot R: turn.\nSTOP: brake. Stop Spin: stop turning."],
			[[&"pad_done"], "Done: park the ship, or let it go."],
			[[], "It is better to tap the controls rather than holding them.\nWe're not racing ships here, rookie, we're parking them!\nLet the momentum do the work!", TIP_COLOR],
		]},
		{"title": "Parking", "rows": [
			[[&"space_free"], "Park in the green outlined spaces."],
			[[&"space_sizes"], "The letter is the size: L light, M medium, H heavy.\nA ship fits its own size or bigger."],
			[[&"space_ready"], "The space turns orange when your ship fits and is still:\nthen press Done."],
			[[&"dent"], "Hitting things too fast costs pay (dents). At ₵0 you're fired.\nThe red lot edge glows when you get close to a wall."],
			[[&"stars"], "Your earnings decide your stars."],
		]},
		{"title": "Customers", "rows": [
			[[&"bay"], "New ships arrive in the ARRIVALS bay."],
			[[&"coin_bronze", &"coin_silver"], "Bronze customers tip ₵%d, silver ₵%d." % [Customer.BRONZE_TIP, Customer.SILVER_TIP]],
			[[&"coin_gold", &"space_gold"], "Gold tips ₵%d, but only in a ★ gold space." % Customer.GOLD_TIP],
			[[&"request_glow"], "↩ 0:12 on a parked ship: its owner comes back soon.\nA glowing outline: they want it back now."],
			[[&"exit"], "Drive it onto the EXIT to hand it over."],
		]},
	]
	pages.append_array(ship_pages())
	pages.append_array([
		{"title": "Hazards", "rows": [
			[[&"radiation", &"asteroid"], "Radiation zones dent ships inside them.\nAsteroids drift around the lot."],
			[[&"black_hole"], "The black hole pulls the ship you're driving,\nand its core flings ships away."],
			[[&"orphan"], "Orphan ships show a countdown. When it ends,\neject them through the EXIT for a ₵%d bonus." % Orphan.BONUS],
			[[&"pin"], "A request like \"→ G4\" wants that exact space (pinned)."],
			[[&"move"], "In Level 5 you can move parked ships."],
		]},
		{"title": "Online duel", "rows": [
			[[&"wifi"], "Same Wi-Fi: one phone hosts, the other joins."],
			[[&"ring_host", &"ring_guest"], "Your ring is cyan if you host, magenta if you join.\nTwo bays deliver matching ships."],
			[[&"exit"], "Every ship leaves 20–30 s after it's parked: the parker\ngets the fee, whoever takes it to the EXIT gets the tip."],
			[[&"dent"], "A crash is charged to whoever knocked the ship.\nWhen two driven ships collide, the faster one pays."],
		]},
		{"title": "Settings", "rows": [
			[[&"pause"], "The II button or the back gesture pauses the game."],
			[[&"sound"], "Sound: On or Off."],
			[[&"cctv"], "CCTV look: %s." % ", ".join(CctvFilter.NAMES)],
			[[&"clock"], "Difficulty sets the shift length:\n%s." % ", ".join(shift)],
		]},
	])
	return pages


## One page per ship class (more if a class outgrows a page), each row a ship:
## [[&"ship"], name, feel line, spec, resource name, paint colour]. Pages also carry "ships".
static func ship_pages() -> Array[Dictionary]:
	var by_class := ship_roster()
	var pages: Array[Dictionary] = []
	for ship_class: int in [ShipSpec.ShipClass.LIGHT, ShipSpec.ShipClass.MEDIUM, ShipSpec.ShipClass.HEAVY]:
		var names: Array = by_class.get(ship_class, [])
		var title := "%s ships" % CLASS_NAMES[ship_class]
		for start in range(0, names.size(), SHIPS_PER_PAGE):
			var page_number := start / SHIPS_PER_PAGE + 1
			var rows := []
			var ships: Array[String] = []
			for i in range(start, mini(start + SHIPS_PER_PAGE, names.size())):
				var ship_name: String = names[i]
				var spec := load(SHIP_DIR + ship_name + ".tres") as ShipSpec
				var paint: Color = Level.PAINT_COLORS[ROW_PAINTS[(i - start) % ROW_PAINTS.size()]]
				rows.append([[&"ship"], split_camel(ship_name), feel_line(ship_name, spec), spec, ship_name, paint])
				ships.append(ship_name)
			pages.append({"title": title if page_number == 1 else "%s (%d)" % [title, page_number],
				"rows": rows, "ships": ships})
	return pages


## Resource names of every ship in resources/ships, grouped by ShipSpec.ship_class and sorted.
static func ship_roster() -> Dictionary:
	var names: Array[String] = []
	for file in ResourceLoader.list_directory(SHIP_DIR):
		if file.ends_with(".tres") or file.ends_with(".res"):
			names.append(file.get_basename())
	names.sort()
	var by_class := {}
	for ship_name in names:
		var spec := load(SHIP_DIR + ship_name + ".tres") as ShipSpec
		if spec:
			if not by_class.has(spec.ship_class):
				by_class[spec.ship_class] = []
			by_class[spec.ship_class].append(ship_name)
	return by_class


## "ManipulatorDrone" -> "Manipulator Drone".
static func split_camel(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		var prev := text[i - 1] if i > 0 else " "
		if ch != ch.to_lower() and prev != " " and prev == prev.to_lower():
			out += " "
		out += ch
	return out


## How a ship handles, from FEEL, or "Light ship · 8 thrusters" for a ship not written up yet.
static func feel_line(ship_name: String, spec: ShipSpec) -> String:
	if FEEL.has(ship_name):
		return FEEL[ship_name]
	return "%s ship · %d thrusters" % [CLASS_NAMES.get(spec.ship_class, "A"), spec.thrusters.size()]


func page_count() -> int:
	return _pages.size()


func page_titles() -> Array[String]:
	var titles: Array[String] = []
	for d in _data:
		titles.append(d["title"])
	return titles


func get_page(i: int) -> Control:
	return _pages[i]


## Resource names of the ships listed on page i (empty for non-ship pages).
func page_ships(i: int) -> Array[String]:
	var ships: Array[String] = []
	ships.assign(_data[i].get("ships", []))
	return ships


## A page's title and all of its text, for tests.
func page_text(i: int) -> String:
	var parts := PackedStringArray([_data[i]["title"]])
	for label in _pages[i].find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return "\n".join(parts)


## Every icon kind the pages use.
func icon_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for d in _data:
		for row: Array in d["rows"]:
			for k: StringName in row[0]:
				if not kinds.has(k):
					kinds.append(k)
	return kinds


func show_page(i: int) -> void:
	page = clampi(i, 0, _pages.size() - 1)
	for p in _pages.size():
		_pages[p].visible = p == page
		(_dots.get_child(p) as Label).add_theme_color_override("font_color", HexStyle.CYAN if p == page else DIM_DOT)
	_title.text = _data[page]["title"]
	_prev.disabled = page == 0
	_next.disabled = page == _pages.size() - 1


func next_page() -> void:
	show_page(page + 1)


func prev_page() -> void:
	show_page(page - 1)


## Online the match keeps running behind the overlay: say so.
func set_running_note(on: bool) -> void:
	_note.visible = on


# --- building ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)  # opaque: the pause menu underneath would show through
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)  # also stops taps reaching the pause menu underneath
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 56
	box.offset_right = -56
	box.offset_top = 22
	box.offset_bottom = -22
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", HexStyle.CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own(_title, "Title", header)
	_note.text = RUNNING_TEXT
	_note.add_theme_font_size_override("font_size", BODY_SIZE)
	_note.add_theme_color_override("font_color", HexStyle.MAGENTA)
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.visible = false
	_own(_note, "RunningNote", header)

	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(holder)
	for d in _data:
		var p := _build_page(d["rows"])
		holder.add_child(p)
		_pages.append(p)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	box.add_child(footer)
	var back := Button.new()
	back.text = "Back"
	_style_button(back, 220)
	back.pressed.connect(_on_back)
	_own(back, "Back", footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_prev.text = "‹ Prev"
	_style_button(_prev, 220)
	_prev.pressed.connect(prev_page)
	_own(_prev, "Prev", footer)
	_dots.add_theme_constant_override("separation", 10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_own(_dots, "Dots", footer)
	for i in _data.size():
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 26)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.size_flags_vertical = Control.SIZE_FILL
		_dots.add_child(dot)
	_next.text = "Next ›"
	_style_button(_next, 220)
	_next.pressed.connect(next_page)
	_own(_next, "Next", footer)


func _build_page(rows: Array) -> Control:
	var page_box := VBoxContainer.new()
	page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 20)
	if rows.size() > 0 and (rows[0] as Array).size() > 3:
		return _build_ship_page(rows)
	var most := 1
	for row: Array in rows:
		most = maxi(most, (row[0] as Array).size())
	var icon_width := most * GuideIcon.SIZE.x + (most - 1) * ICON_GAP
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 28)
		page_box.add_child(line)
		var icons := HBoxContainer.new()
		icons.custom_minimum_size = Vector2(icon_width, GuideIcon.SIZE.y)
		icons.add_theme_constant_override("separation", ICON_GAP)
		line.add_child(icons)
		for k: StringName in row[0]:
			var icon := GuideIcon.new()
			icon.kind = k
			icons.add_child(icon)
		var text := Label.new()
		text.text = row[1]
		text.add_theme_font_size_override("font_size", BODY_SIZE)
		if row.size() > 2:
			text.add_theme_color_override("font_color", row[2])
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_FILL
		line.add_child(text)
	return page_box


## Rows of ships: the painted sprite, its name in cyan and its feel line underneath.
func _build_ship_page(rows: Array) -> Control:
	var page_box := VBoxContainer.new()
	page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 14)
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 28)
		page_box.add_child(line)
		var icon := GuideIcon.new()
		icon.spec = row[3]
		icon.paint = row[5]
		icon.kind = &"ship"
		line.add_child(icon)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		var ship_name := Label.new()
		ship_name.text = row[1]
		ship_name.add_theme_font_size_override("font_size", SHIP_NAME_SIZE)
		ship_name.add_theme_color_override("font_color", HexStyle.CYAN)
		words.add_child(ship_name)
		var feel := Label.new()
		feel.text = row[2]
		feel.add_theme_font_size_override("font_size", SHIP_FEEL_SIZE)
		words.add_child(feel)
	return page_box


func _style_button(b: Button, width: float) -> void:
	b.custom_minimum_size = Vector2(width, 84)
	b.add_theme_font_size_override("font_size", 30)


## Adds a node reachable as %node_name.
func _own(node: Node, node_name: String, parent: Node) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true


func _on_back() -> void:
	if as_overlay:
		_close()
	else:
		_go(back_target())


func _close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()


func _go(path: String) -> void:
	last_target = path
	if change_scenes:
		get_tree().change_scene_to_file(path)


## Escape on desktop closes the overlay before the pause menu sees it.
func _unhandled_input(event: InputEvent) -> void:
	if as_overlay and not _closing and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return MODE_SELECT


## As a screen the back gesture returns to Mode Select; as an overlay the level handles it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not as_overlay:
		_go(back_target())
