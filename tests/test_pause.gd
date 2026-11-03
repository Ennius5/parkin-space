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


func test_online_pause_does_not_pause() -> void:
	_real_save = GameState.save_path
	_real_sound = GameState.sound_on
	GameState.save_path = TEST_SAVE
	var level: DuelLevel = load("res://scenes/levels/Duel.tscn").instantiate()
	level.change_scene_on_end = false
	level.role = DuelLevel.Role.HOST
	level.session = NetSession.new()  # never connects
	tree.root.add_child(level)
	await tree.process_frame
	level.open_pause()
	assert_false(tree.paused, "the match keeps running")
	assert_true(_menu(level).is_open())
	assert_false((_menu(level).get_node("%Restart") as Button).visible, "no Restart online")
	var quit := _menu(level).get_node("%Quit") as Button
	assert_eq(quit.text, "Leave match")
	quit.pressed.emit()
	assert_true(_menu(level).get_node("%Confirm").visible, "asks first")
	assert_eq((_menu(level).get_node("%ConfirmText") as Label).text, "Leave the match?")
	(_menu(level).get_node("%No") as Button).pressed.emit()
	assert_false(_menu(level).get_node("%Confirm").visible)
	assert_eq(level.last_pause_action, "", "No keeps playing")
	quit.pressed.emit()
	(_menu(level).get_node("%Yes") as Button).pressed.emit()
	assert_eq(level.last_pause_action, "leave")
	var session := level.session
	_done(level)
	session.free()


func test_pause_title_says_whether_the_match_runs_on() -> void:
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	var title := menu.get_node("%Title") as Label
	assert_eq(title.text, "Paused")
	menu.set_online(true)
	assert_eq(title.text, "Match still running", "online the match doesn't stop")
	menu.set_online(false)
	assert_eq(title.text, "Paused")
	menu.free()


# --- How to Play from the pause menu ---

func _cancel() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	return ev


func test_pause_menu_has_how_to_play_between_cctv_and_quit() -> void:
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	var button := menu.get_node_or_null("%HowToPlay") as Button
	assert_true(button != null)
	if button:
		assert_eq(button.text, "How to Play")
		assert_eq(button.get_index(), menu.get_node("%CctvToggle").get_index() + 1)
		assert_eq(button.get_index() + 1, menu.get_node("%Quit").get_index())
	menu.free()


func test_pause_menu_fits_a_720px_screen() -> void:
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	menu.open()
	await tree.process_frame
	var box := menu.get_node("%Title").get_parent() as Control
	var h := box.get_combined_minimum_size().y
	assert_true(h <= 720.0 - 24.0, "menu height %s" % h)
	var resume := menu.get_node("%Resume") as Button
	assert_true(resume.size.y >= 72.0, "thumb-sized buttons")
	menu.free()


func test_how_to_play_opens_the_guide_over_the_paused_level() -> void:
	var level := await _level()
	level.open_pause()
	var menu := _menu(level)
	(menu.get_node("%HowToPlay") as Button).pressed.emit()
	assert_true(menu.is_guide_open())
	var guide := menu.find_child("Guide", true, false) as Guide
	assert_true(guide != null and guide.as_overlay, "the guide is an overlay")
	if guide:
		assert_eq(guide.process_mode, Node.PROCESS_MODE_ALWAYS)
		var layer := guide.get_parent() as CanvasLayer
		assert_true(layer != null and layer.layer > menu.layer, "drawn above the pause menu")
		assert_false((guide.get_node("%RunningNote") as Label).visible, "offline the level is paused")
	assert_true(tree.paused, "the level stays paused while reading")
	assert_true(menu.is_open())
	(guide.get_node("%Back") as Button).pressed.emit()
	assert_false(menu.is_guide_open(), "Back closes the guide")
	assert_true(menu.is_open(), "the pause menu stays open")
	assert_true(tree.paused)
	assert_eq(level.last_pause_action, "")
	_done(level)


func test_cancel_closes_the_guide_before_the_pause_menu() -> void:
	var level := await _level()
	level.open_pause()
	var menu := _menu(level)
	(menu.get_node("%HowToPlay") as Button).pressed.emit()
	tree.root.push_input(_cancel())
	assert_false(menu.is_guide_open(), "Escape closes the guide")
	assert_true(menu.is_open(), "the pause menu stays open")
	assert_true(tree.paused)
	tree.root.push_input(_cancel())
	assert_false(menu.is_open(), "a second Escape resumes")
	assert_false(tree.paused)
	_done(level)


func test_back_gesture_closes_the_guide_before_the_pause_menu() -> void:
	var level := await _level()
	level.open_pause()
	var menu := _menu(level)
	(menu.get_node("%HowToPlay") as Button).pressed.emit()
	level._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(menu.is_guide_open())
	assert_true(menu.is_open())
	assert_true(tree.paused)
	_done(level)


func test_resume_drops_the_guide() -> void:
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	menu.open()
	(menu.get_node("%HowToPlay") as Button).pressed.emit()
	menu.close()
	assert_false(menu.is_guide_open())
	menu.free()


func test_online_guide_says_the_match_runs_on() -> void:
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	menu.set_online(true)
	menu.open()
	(menu.get_node("%HowToPlay") as Button).pressed.emit()
	var guide := menu.find_child("Guide", true, false) as Guide
	assert_true(guide != null)
	if guide:
		var note := guide.get_node("%RunningNote") as Label
		assert_true(note.visible)
		assert_eq(note.text, "Match still running")
	menu.free()
