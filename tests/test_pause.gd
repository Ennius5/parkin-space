extends TestCase

const TEST_SAVE := "user://test_pause_save.cfg"

var _real_save := ""
var _real_sound := true


func _level() -> Level:
	_real_save = GameState.save_path
	_real_sound = GameState.sound_on
	GameState.save_path = TEST_SAVE
	var level: Level = load("res://scenes/levels/Level01.tscn").instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


func _done(level: Level) -> void:
	tree.paused = false
	level.free()
	GameState.save_path = _real_save
	GameState.sound_on = _real_sound
	Sound.apply_mute()


func _menu(level: Level) -> PauseMenu:
	return level.get_node("PauseMenu") as PauseMenu


func test_pause_button_pauses_the_game() -> void:
	var level := await _level()
	(level.get_node("HUD") as HUD).pause_pressed.emit()
	assert_true(tree.paused)
	assert_true(_menu(level).is_open())
	_menu(level).get_node("%Resume").pressed.emit()
	assert_false(tree.paused)
	assert_false(_menu(level).is_open())
	_done(level)


func test_hud_has_a_thumb_sized_pause_button() -> void:
	var level := await _level()
	var button := level.get_node("HUD").find_child("PauseButton", true, false) as Button
	assert_true(button != null and button.text == "II")
	if button:
		assert_true(button.size.x >= 100.0 and button.size.y >= 100.0, str(button.size))
	_done(level)


func test_pause_freezes_the_shift_clock() -> void:
	var level := await _level()
	level.open_pause()
	var left := level.ledger.time_left
	for i in 30:
		await tree.process_frame
	assert_almost(level.ledger.time_left, left, 0.001)
	level.close_pause()
	for i in 30:
		await tree.physics_frame
	assert_true(level.ledger.time_left < left)
	_done(level)


func test_sound_toggle_in_pause() -> void:
	var level := await _level()
	GameState.sound_on = true
	level.open_pause()
	var toggle := _menu(level).get_node("%SoundToggle") as Button
	_menu(level).refresh_sound_label()
	assert_eq(toggle.text, "Sound: On")
	toggle.pressed.emit()
	assert_false(GameState.sound_on)
	assert_eq(toggle.text, "Sound: Off")
	_done(level)


func test_back_toggles_pause() -> void:
	var level := await _level()
	level._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(tree.paused)
	level._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(tree.paused)
	_done(level)


func test_no_pause_after_the_shift_ends() -> void:
	var level := await _level()
	level.end_level()
	level.open_pause()
	assert_false(tree.paused)
	_done(level)


func test_restart_and_quit_actions() -> void:
	var level := await _level()
	level.open_pause()
	_menu(level).get_node("%Restart").pressed.emit()
	assert_eq(level.last_pause_action, "restart")
	assert_false(tree.paused)
	level.open_pause()
	_menu(level).get_node("%Quit").pressed.emit()
	assert_eq(level.last_pause_action, "quit")
	assert_false(tree.paused)
	_done(level)


func test_back_gesture_doesnt_quit_the_app() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back", true))
