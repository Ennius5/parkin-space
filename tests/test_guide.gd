extends TestCase
## The How to Play guide: six pages, page navigation, copy read from the game's constants,
## and icons that draw.

const GUIDE := "res://scenes/ui/Guide.tscn"
const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"


func _guide() -> Guide:
	var guide: Guide = load(GUIDE).instantiate()
	guide.change_scenes = false
	tree.root.add_child(guide)
	return guide


func test_guide_has_six_titled_pages() -> void:
	var guide := _guide()
	assert_eq(guide.page_count(), 6)
	assert_eq(guide.page_titles(), ["Controls", "Parking", "Customers", "Hazards", "Online duel", "Settings"])
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
	for i in 10:
		next.pressed.emit()
	assert_eq(guide.page, 5, "stops at the last page")
	assert_true(next.disabled, "no page after the last")
	prev.pressed.emit()
	assert_eq(guide.page, 4)
	guide.free()


func test_current_dot_follows_the_page() -> void:
	var guide := _guide()
	for p in 6:
		guide.show_page(p)
		for d in 6:
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
	var text := guide.page_text(5)
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
