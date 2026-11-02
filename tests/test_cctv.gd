extends TestCase

const TEST_SAVE := "user://test_cctv_save.cfg"

var _real_save := ""
var _real_cctv := 2


func _level(number: int = 1) -> Level:
	_real_save = GameState.save_path
	_real_cctv = GameState.cctv_level
	GameState.save_path = TEST_SAVE
	var level: Level = load(GameState.level_scene_path(number)).instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done(level: Level) -> void:
	tree.paused = false
	level.free()
	GameState.save_path = _real_save
	GameState.cctv_level = _real_cctv


func _filter(level: Level) -> CctvFilter:
	return level.get_node("CctvFilter") as CctvFilter


func test_four_named_strengths() -> void:
	assert_eq(CctvFilter.NAMES, ["Off", "Light", "Medium", "Heavy"])
	assert_eq(CctvFilter.STRENGTHS, [0.0, 0.35, 0.6, 0.85])


func test_filter_strength_and_overlay_follow_the_level() -> void:
	var filter := CctvFilter.new()
	tree.root.add_child(filter)
	for n in 4:
		filter.set_level(n)
		assert_almost(filter.strength(), CctvFilter.STRENGTHS[n], 0.0001)
		assert_eq(filter.overlay_visible(), n > 0, "overlay at level %d" % n)
	filter.free()


func test_every_level_has_the_filter_beneath_the_hud() -> void:
	for n in range(1, GameState.TOTAL_LEVELS + 1):
		var level := await _level(n)
		var filter := _filter(level)
		assert_true(filter != null, "Level %d has a filter" % n)
		if filter:
			var hud := level.get_node("HUD") as CanvasLayer
			assert_true(filter.layer < hud.layer or (filter.layer == hud.layer and filter.get_index() < hud.get_index()),
				"Level %d filter draws under the HUD" % n)
			assert_true(filter.layer < (level.get_node("Controls") as CanvasLayer).layer or filter.get_index() < level.get_node("Controls").get_index())
		_done(level)


func test_level_starts_with_the_saved_strength() -> void:
	GameState.cctv_level = 0
	var level := await _level()
	assert_almost(_filter(level).strength(), 0.0, 0.0001)
	assert_false(_filter(level).overlay_visible())
	_done(level)


func test_pause_button_cycles_cctv() -> void:
	var level := await _level()
	GameState.cctv_level = 2
	level.open_pause()
	var menu := level.get_node("PauseMenu") as PauseMenu
	var toggle := menu.get_node("%CctvToggle") as Button
	assert_eq(toggle.text, "CCTV: Medium")
	toggle.pressed.emit()
	assert_eq(GameState.cctv_level, 3)
	assert_eq(toggle.text, "CCTV: Heavy")
	assert_almost(_filter(level).strength(), 0.85, 0.0001)
	toggle.pressed.emit()
	assert_eq(toggle.text, "CCTV: Off")
	assert_false(_filter(level).overlay_visible())
	toggle.pressed.emit()
	assert_eq(toggle.text, "CCTV: Light")
	_done(level)
