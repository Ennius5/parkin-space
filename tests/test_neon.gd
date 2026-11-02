extends TestCase

const THEME_PATH := "res://assets/ui/neon_theme.tres"


func _style(state: String, type := "Button") -> HexStyle:
	return (load(THEME_PATH) as Theme).get_stylebox(state, type) as HexStyle


func test_theme_is_set_game_wide() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
	assert_true(_style("normal") != null, "buttons draw as hexagons")


func test_button_states_glow_cyan_and_flash_magenta() -> void:
	var normal := _style("normal")
	var pressed := _style("pressed")
	var disabled := _style("disabled")
	var hover := _style("hover")
	assert_true(normal.color.b > 0.8 and normal.color.r < 0.4, "cyan %s" % normal.color)
	assert_true(pressed.color.r > 0.8 and pressed.color.b > 0.6 and pressed.color.g < 0.5, "magenta %s" % pressed.color)
	assert_true(disabled.color.a < normal.color.a, "disabled is dimmer")
	assert_true(hover.glow > normal.glow, "hover glows brighter")


func test_selected_toggle_stays_cyan() -> void:
	var selected := _style("pressed", "ToggleHexButton")
	assert_true(selected != null and selected.color.b > 0.8 and selected.color.g > 0.8 and selected.color.r < 0.7, "selected stays a bright cyan, not magenta")
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	for b: Button in screen.find_child("Difficulty", true, false).get_children():
		assert_eq(b.theme_type_variation, &"ToggleHexButton")
	screen.free()


func test_hex_points_fit_the_rect() -> void:
	var pts := HexStyle.hex_points(Rect2(0, 0, 200, 100))
	assert_eq(pts.size(), 6)
	assert_true(Vector2(0, 50) in pts, "pointed left end")
	assert_true(Vector2(200, 50) in pts, "pointed right end")
	assert_true(Vector2(50, 0) in pts and Vector2(150, 100) in pts, "flat top and bottom")


func test_driving_pad_is_hexagonal() -> void:
	var controls: CanvasLayer = load("res://scenes/ui/ShipControls.tscn").instantiate()
	tree.root.add_child(controls)
	var buttons := controls.find_children("*", "TouchScreenButton", true, false)
	assert_true(buttons.size() >= 6)
	for node in buttons:
		var b := node as TouchScreenButton
		var face := b.get_node_or_null("HexFace") as HexFace
		assert_true(face != null, b.name)
		if face:
			assert_false(face.lit)
			b.pressed.emit()
			assert_true(face.lit, "%s lights up while held" % b.name)
			b.released.emit()
			assert_false(face.lit)
	controls.free()
