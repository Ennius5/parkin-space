extends TestCase
## The How to Play guide: nine pages (three of them showing the ship roster by class), page
## navigation, copy read from the game's constants, and icons that draw.

const GUIDE := "res://scenes/ui/Guide.tscn"
const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const SHIP_DIR := "res://resources/ships/"
const CLASS_TITLES := {ShipSpec.ShipClass.LIGHT: "Light ships", ShipSpec.ShipClass.MEDIUM: "Medium ships",
	ShipSpec.ShipClass.HEAVY: "Heavy ships"}


func _guide() -> Guide:
	var guide: Guide = load(GUIDE).instantiate()
	guide.change_scenes = false
	tree.root.add_child(guide)
	return guide


func test_guide_has_nine_titled_pages() -> void:
	var guide := _guide()
	assert_eq(guide.page_count(), 9)
	assert_eq(guide.page_titles(), ["Controls", "Parking", "Customers", "Light ships", "Medium ships",
		"Heavy ships", "Hazards", "Online duel", "Settings"])
	guide.free()


## Resource names of every ship of one class in resources/ships, sorted.
func _ships_of(ship_class: int) -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(SHIP_DIR):
		if file.ends_with(".tres") and (load(SHIP_DIR + file) as ShipSpec).ship_class == ship_class:
			names.append(file.get_basename())
	names.sort()
	return names


func test_each_class_page_lists_exactly_that_class_of_ships() -> void:
	var guide := _guide()
	var titles := guide.page_titles()
	for ship_class: int in CLASS_TITLES:
		var expected := _ships_of(ship_class)
		assert_true(expected.size() > 0, "ships of class %d" % ship_class)
		var listed: Array[String] = []
		for i in titles.size():
			if titles[i].begins_with(CLASS_TITLES[ship_class]):
				listed.append_array(guide.page_ships(i))
		assert_eq(listed, expected, CLASS_TITLES[ship_class])
		for ship_name in expected:
			var page := titles.find(CLASS_TITLES[ship_class])
			if page >= 0 and guide.page_ships(page).has(ship_name):
				var text := guide.page_text(page)
				assert_true(text.contains(Guide.split_camel(ship_name)), "%s named" % ship_name)
				assert_true(text.contains(Guide.feel_line(ship_name, load(SHIP_DIR + ship_name + ".tres"))), "%s feel" % ship_name)
	guide.free()


func test_every_shipped_ship_has_a_written_feel_line() -> void:
	for file in DirAccess.get_files_at(SHIP_DIR):
		if file.ends_with(".tres"):
			assert_true(Guide.FEEL.has(file.get_basename()), "feel line for %s" % file)


func test_unknown_ship_gets_a_generated_feel_line() -> void:
	var spec := ShipSpec.new()
	spec.ship_class = ShipSpec.ShipClass.MEDIUM
	spec.thrusters = [ThrusterSpec.new(), ThrusterSpec.new(), ThrusterSpec.new()]
	assert_eq(Guide.feel_line("NotAShip", spec), "Medium ship · 3 thrusters")


func test_split_camel() -> void:
	assert_eq(Guide.split_camel("ManipulatorDrone"), "Manipulator Drone")
	assert_eq(Guide.split_camel("Milano"), "Milano")
	assert_eq(Guide.split_camel("AgriShip"), "Agri Ship")
	assert_eq(Guide.split_camel("RecreationalDrone"), "Recreational Drone")


func test_ship_row_icons_draw_their_own_ship() -> void:
	var guide := _guide()
	var titles := guide.page_titles()
	var seen := 0
	for i in titles.size():
		for icon in guide.get_page(i).find_children("*", "GuideIcon", true, false):
			var gi := icon as GuideIcon
			if gi.spec != null:
				seen += 1
				assert_true(gi.ship_texture() == gi.spec.texture, "icon draws its own ship")
		guide.show_page(i)
		await tree.process_frame
	assert_eq(seen, DirAccess.get_files_at(SHIP_DIR).size(), "one ship icon per ship")
	guide.free()


func test_next_and_prev_move_the_page_and_stop_at_the_ends() -> void:
	var guide := _guide()
	var prev := guide.get_node("%Prev") as Button
	var next := guide.get_node("%Next") as Button
	assert_eq(guide.page, 0)
	assert_true(prev.disabled, "no page before the first")
	assert_false(next.disabled)
	assert_true(guide.get_page(0).visible)
	next.pressed.emit()
	assert_eq(guide.page, 1)
	assert_false(prev.disabled)
	assert_true(guide.get_page(1).visible)
	assert_false(guide.get_page(0).visible, "one page at a time")
	for i in 20:
		next.pressed.emit()
	assert_eq(guide.page, guide.page_count() - 1, "stops at the last page")
	assert_true(next.disabled, "no page after the last")
	prev.pressed.emit()
	assert_eq(guide.page, guide.page_count() - 2)
	guide.free()


func test_current_dot_follows_the_page() -> void:
	var guide := _guide()
	for p in guide.page_count():
		guide.show_page(p)
		for d in guide.page_count():
			var dot := guide.get_node("%Dots").get_child(d) as Label
			var lit := dot.get_theme_color("font_color") == HexStyle.CYAN
			assert_eq(lit, d == p, "page %d dot %d" % [p, d])
	guide.free()


func test_customer_tips_come_from_the_customer_constants() -> void:
	var guide := _guide()
	var text := guide.page_text(2)
	for tip: int in [Customer.BRONZE_TIP, Customer.SILVER_TIP, Customer.GOLD_TIP]:
		assert_true(text.contains("₵%d" % tip), "₵%d in %s" % [tip, text])
	assert_true(text.contains("★"), "gold spaces")
	assert_true(text.contains("EXIT"))
	guide.free()


func test_settings_page_lists_the_shift_lengths() -> void:
	var guide := _guide()
	var text := guide.page_text(guide.page_titles().find("Settings"))
	for d: int in GameState.SHIFT_SECONDS:
		var s := int(GameState.SHIFT_SECONDS[d])
		var entry := "%s %d:%02d" % [GameState.DIFFICULTY_NAMES[d], s / 60, s % 60]
		assert_true(text.contains(entry), entry)
	assert_true(text.contains("Easy 10:00"))
	guide.free()


func test_scene_guide_back_goes_to_mode_select() -> void:
	var guide := _guide()
	assert_eq(guide.back_target(), MODE_SELECT)
	(guide.get_node("%Back") as Button).pressed.emit()
	assert_eq(guide.last_target, MODE_SELECT)
	guide.free()


func test_overlay_guide_back_emits_closed_instead() -> void:
	var guide: Guide = load(GUIDE).instantiate()
	guide.as_overlay = true
	guide.change_scenes = false
	tree.root.add_child(guide)
	var seen := [false]
	guide.closed.connect(func() -> void: seen[0] = true)
	(guide.get_node("%Back") as Button).pressed.emit()
	assert_true(seen[0], "closed emitted")
	assert_eq(guide.last_target, "", "no scene change from the overlay")
	guide.free()


func test_running_note_only_when_asked() -> void:
	var guide := _guide()
	assert_false((guide.get_node("%RunningNote") as Label).visible)
	guide.set_running_note(true)
	var note := guide.get_node("%RunningNote") as Label
	assert_true(note.visible)
	assert_eq(note.text, "Match still running")
	guide.free()


func test_every_icon_kind_on_the_pages_draws() -> void:
	var guide := _guide()
	var kinds := guide.icon_kinds()
	assert_true(kinds.size() >= 15, "icons used: %s" % [kinds])
	for kind in kinds:
		assert_true(kind in GuideIcon.KINDS, "known kind %s" % kind)
	guide.free()
	var holder := Control.new()
	tree.root.add_child(holder)
	for kind in GuideIcon.KINDS:
		var icon := GuideIcon.new()
		icon.kind = kind
		holder.add_child(icon)
	await tree.process_frame
	await tree.process_frame
	holder.free()
