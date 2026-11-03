extends TestCase

const TEST_SAVE := "user://test_ui_save.cfg"

var _real_save_path: String


func _setup_state(unlocked: int) -> void:
	_real_save_path = GameState.save_path
	GameState.save_path = TEST_SAVE
	GameState.reset_progress()
	GameState.unlocked_level = unlocked
	GameState.last_result = {}


func _restore_state() -> void:
	GameState.save_path = _real_save_path
	GameState.load_progress()


func _result_screen() -> Control:
	var screen: Control = load("res://scenes/ui/Result.tscn").instantiate()
	tree.root.add_child(screen)
	return screen


func _result(reason: String, stars: int) -> Dictionary:
	return {"won": reason == "won", "stars": stars, "level": 1, "earnings": 160,
		"served": 4, "customers": 4, "reason": reason}


func test_level_select_locks() -> void:
	_setup_state(3)
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var buttons := screen.get_node("%Grid").get_children()
	assert_eq(buttons.size(), 5)
	if buttons.size() == 5:
		assert_false((buttons[0] as Button).disabled, "level 1 open")
		assert_false((buttons[1] as Button).disabled, "level 2 open")
		assert_false((buttons[2] as Button).disabled, "level 3 open")
		for i in range(3, 5):
			assert_true((buttons[i] as Button).disabled)
			assert_true((buttons[i] as Button).text.contains("LOCKED"), "level %d" % (i + 1))
	screen.queue_free()
	_restore_state()


func test_level5_opens() -> void:
	_setup_state(5)
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var button := screen.get_node("%Grid").get_child(4) as Button
	assert_false(button.disabled, "level 5 is playable")
	screen.queue_free()
	_restore_state()


func test_result_after_level5_has_no_next() -> void:
	_setup_state(5)
	var screen := _result_screen()
	var result := _result("won", 3)
	result["level"] = 5
	screen.show_result(result)
	assert_true(screen.get_node("%Next").disabled, "the campaign ends at level 5")
	screen.queue_free()
	_restore_state()


func test_level_select_picks_the_difficulty() -> void:
	_setup_state(1)
	var real: int = GameState.difficulty
	GameState.difficulty = GameState.Difficulty.NORMAL
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var row := screen.find_child("Difficulty", true, false)
	assert_true(row != null)
	if row:
		var buttons := row.get_children()
		assert_eq(buttons.size(), 3)
		assert_true((buttons[1] as Button).button_pressed, "Normal starts selected")
		(buttons[0] as Button).pressed.emit()
		assert_eq(GameState.difficulty, GameState.Difficulty.EASY)
		assert_true((buttons[0] as Button).text.contains("10:00"))
	screen.queue_free()
	GameState.difficulty = real
	_restore_state()


func test_result_shows_the_difficulty() -> void:
	_setup_state(2)
	var screen := _result_screen()
	var result := _result("won", 2)
	result["difficulty"] = "Easy"
	screen.show_result(result)
	assert_true(screen.get_node("%Earnings").text.contains("Easy"))
	screen.queue_free()
	_restore_state()


func test_result_shows_bonuses() -> void:
	_setup_state(2)
	var screen := _result_screen()
	var result := _result("won", 2)
	result["bonuses"] = 50
	screen.show_result(result)
	assert_true(screen.get_node("%Earnings").text.contains("Bonuses ₵50"))
	result["bonuses"] = 0
	screen.show_result(result)
	assert_false(screen.get_node("%Earnings").text.contains("Bonuses"))
	screen.queue_free()
	_restore_state()


func test_result_win() -> void:
	_setup_state(2)
	var screen := _result_screen()
	screen.show_result(_result("won", 2))
	assert_eq(screen.get_node("%Title").text, "Shift complete!")
	assert_eq(screen.get_node("%Stars").text, "★★☆")
	assert_true(screen.get_node("%Earnings").text.contains("160"))
	assert_false(screen.get_node("%Next").disabled, "Level02 exists")
	screen.queue_free()
	_restore_state()


func test_result_fired() -> void:
	_setup_state(1)
	var screen := _result_screen()
	screen.show_result(_result("fired", 0))
	assert_eq(screen.get_node("%Title").text, "You're fired!")
	assert_true(screen.get_node("%Next").disabled)
	screen.queue_free()
	_restore_state()


func test_result_timeout() -> void:
	_setup_state(1)
	var screen := _result_screen()
	screen.show_result(_result("timeout", 0))
	assert_eq(screen.get_node("%Title").text, "Shift over – customers still waiting")
	screen.queue_free()
	_restore_state()


func test_result_with_empty_result_does_not_crash() -> void:
	_setup_state(1)
	var screen := _result_screen()  # _ready reads the empty GameState.last_result
	assert_true(screen.get_node("%Next").disabled)
	screen.queue_free()
	_restore_state()



func test_credits_lists_every_track() -> void:
	var screen: Control = load("res://scenes/ui/Credits.tscn").instantiate()
	tree.root.add_child(screen)
	var text: String = (screen.get_node("%Text") as Label).text
	for title in ["Descent Mind Ascent", "Strange", "Never Stop Rising", "squidgy", "just not right"]:
		assert_true(text.contains(title), title)
	assert_true(text.contains("CC BY-NC 3.0"))
	assert_true(text.contains("Kenney"))
	assert_true(text.contains("The music is licensed for non-commercial use only."))
	assert_true(screen.get_node_or_null("%Back") is Button)
	screen.free()


func test_mode_select_has_credits() -> void:
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	tree.root.add_child(screen)
	assert_true(screen.get_node_or_null("%Credits") is Button)
	screen.free()


func test_mode_select_how_to_play_opens_the_guide() -> void:
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	screen.change_scenes = false
	tree.root.add_child(screen)
	var button := screen.get_node_or_null("%HowToPlay") as Button
	assert_true(button != null, "How to Play button")
	if button:
		assert_eq(button.text, "How to Play")
		assert_eq(button.get_index() + 1, screen.get_node("%Credits").get_index(), "just above Credits")
		button.pressed.emit()
		assert_eq(screen.last_target, "res://scenes/ui/Guide.tscn")
	screen.free()


func test_mode_select_fits_the_screen() -> void:
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	var box := screen.get_node("Center/Box") as Control
	assert_true(box.get_combined_minimum_size().y <= 720.0, str(box.get_combined_minimum_size()))
	screen.free()


func test_back_gesture_goes_somewhere_on_every_menu() -> void:
	var expected := {
		"res://scenes/ui/Title.tscn": "",  # quits the app
		"res://scenes/ui/ModeSelect.tscn": "res://scenes/ui/Title.tscn",
		"res://scenes/ui/LevelSelect.tscn": "res://scenes/ui/ModeSelect.tscn",
		"res://scenes/ui/Credits.tscn": "res://scenes/ui/ModeSelect.tscn",
		"res://scenes/ui/Guide.tscn": "res://scenes/ui/ModeSelect.tscn",
		"res://scenes/ui/Result.tscn": "res://scenes/ui/LevelSelect.tscn",
		"res://scenes/ui/Lobby.tscn": "res://scenes/ui/ModeSelect.tscn",
		"res://scenes/ui/OnlineResult.tscn": "res://scenes/ui/ModeSelect.tscn",
	}
	for path: String in expected:
		var screen: Control = load(path).instantiate()
		assert_true(screen.has_method("back_target"), "%s handles back" % path)
		if screen.has_method("back_target"):
			assert_eq(screen.call("back_target"), expected[path], path)
		screen.free()


# --- Online screens ---
# Screens that change scenes take `change_scenes = false` in tests and record where they
# would have gone in `last_target`.

func test_mode_select_online_opens_lobby() -> void:
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	screen.change_scenes = false
	tree.root.add_child(screen)
	var online := screen.get_node("%Online") as Button
	assert_false(online.disabled, "Online is playable")
	online.pressed.emit()
	assert_eq(screen.last_target, "res://scenes/ui/Lobby.tscn")
	assert_eq(GameState.mode, "online")
	GameState.mode = "offline"
	screen.free()


func test_lobby_minutes_clamped_and_saved() -> void:
	_setup_state(1)
	var real: int = GameState.duel_minutes
	GameState.duel_minutes = GameState.DUEL_MIN
	var screen: Control = load("res://scenes/ui/Lobby.tscn").instantiate()
	screen.change_scenes = false
	tree.root.add_child(screen)
	var minutes := screen.get_node("%Minutes") as Label
	assert_eq(minutes.text, "3:00")
	(screen.get_node("%Less") as Button).pressed.emit()
	assert_eq(GameState.duel_minutes, 3, "Less at 3 stays at 3")
	assert_eq(minutes.text, "3:00")
	for i in 20:
		(screen.get_node("%More") as Button).pressed.emit()
	assert_eq(GameState.duel_minutes, 20, "More stops at 20")
	assert_eq(minutes.text, "20:00")
	GameState.duel_minutes = 5
	GameState.load_progress()
	assert_eq(GameState.duel_minutes, 20, "the length was saved")
	screen.free()
	GameState.duel_minutes = real
	_restore_state()


func test_lobby_back_closes_session() -> void:
	_setup_state(1)
	var session := NetSession.new()
	session.port = 24611
	tree.root.add_child(session)
	var screen: Control = load("res://scenes/ui/Lobby.tscn").instantiate()
	screen.change_scenes = false
	screen.session = session
	tree.root.add_child(screen)
	assert_eq(screen.back_target(), "res://scenes/ui/ModeSelect.tscn")
	(screen.get_node("%Host") as Button).pressed.emit()
	assert_true(session.is_active(), "hosting")
	assert_true((screen.get_node("%Status") as Label).text.ends_with("— waiting for a rival…"))
	(screen.get_node("%Back") as Button).pressed.emit()
	assert_false(session.is_active(), "Back closed the connection")
	assert_eq(screen.last_target, "res://scenes/ui/ModeSelect.tscn")
	screen.free()
	session.free()
	_restore_state()


func test_online_result_texts() -> void:
	var real: Dictionary = GameState.duel_result
	GameState.duel_result = {"mine": 50, "rival": 20}
	var screen: Control = load("res://scenes/ui/OnlineResult.tscn").instantiate()
	screen.change_scenes = false
	tree.root.add_child(screen)
	assert_eq((screen.get_node("%Title") as Label).text, "You win")
	var scores := (screen.get_node("%Scores") as Label).text
	assert_true(scores.contains("50") and scores.contains("20"), scores)
	screen.show_result({"mine": 20, "rival": 20})
	assert_eq((screen.get_node("%Title") as Label).text, "Draw")
	screen.show_result({"mine": -5, "rival": 20})
	assert_eq((screen.get_node("%Title") as Label).text, "You lose")
	screen.free()
	GameState.duel_result = real


func test_rival_left_notice_shows_once() -> void:
	var result: Control = load("res://scenes/ui/OnlineResult.tscn").instantiate()
	result.change_scenes = false
	result.session = NetSession.new()
	tree.root.add_child(result)
	result.session.rival_left.emit()
	assert_eq(GameState.notice, "Your rival left the match")
	assert_eq(result.last_target, "res://scenes/ui/ModeSelect.tscn")
	var session: NetSession = result.session
	result.free()
	session.free()
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var note := screen.get_node("%OnlineNote") as Label
	assert_true(note.visible)
	assert_eq(note.text, "Your rival left the match")
	assert_eq(GameState.notice, "", "shown once")
	screen.free()
	screen = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	tree.root.add_child(screen)
	assert_false((screen.get_node("%OnlineNote") as Label).visible, "no notice the second time")
	screen.free()


func _online_result() -> Control:
	GameState.duel_result = {"mine": 10, "rival": 10}
	var screen: Control = load("res://scenes/ui/OnlineResult.tscn").instantiate()
	screen.change_scenes = false
	screen.session = NetSession.new()  # never connects
	tree.root.add_child(screen)
	return screen


func _free_online_result(screen: Control) -> void:
	var session: NetSession = screen.session
	screen.free()
	session.free()
	GameState.duel_result = {}


func test_rematch_when_rival_asked_first() -> void:
	var screen := _online_result()
	screen.session.rival_wants_rematch = true
	screen.session.rival_rematch.emit()
	assert_eq((screen.get_node("%Status") as Label).text, "Your rival wants a rematch")
	assert_eq(screen.last_target, "", "no reload until I ask")
	(screen.get_node("%Rematch") as Button).pressed.emit()
	await tree.process_frame
	assert_eq(screen.last_target, "res://scenes/levels/Duel.tscn")
	assert_false(screen.session.rival_wants_rematch, "cleared for the next match")
	_free_online_result(screen)


func test_rematch_when_i_ask_first() -> void:
	var screen := _online_result()
	(screen.get_node("%Rematch") as Button).pressed.emit()
	assert_eq((screen.get_node("%Status") as Label).text, "Waiting for rival…")
	assert_true((screen.get_node("%Rematch") as Button).disabled)
	await tree.process_frame
	assert_eq(screen.last_target, "", "waits for the rival")
	screen.session.rival_wants_rematch = true
	screen.session.rival_rematch.emit()
	await tree.process_frame
	assert_eq(screen.last_target, "res://scenes/levels/Duel.tscn")
	_free_online_result(screen)


func test_lobby_keeps_last_ip_when_field_empty() -> void:
	_setup_state(1)
	var real: String = GameState.last_ip
	GameState.last_ip = "10.0.0.9"
	var session := NetSession.new()
	tree.root.add_child(session)
	var screen: Control = load("res://scenes/ui/Lobby.tscn").instantiate()
	screen.change_scenes = false
	screen.session = session
	tree.root.add_child(screen)
	(screen.get_node("%Ip") as LineEdit).text = "  "
	(screen.get_node("%Join") as Button).pressed.emit()
	assert_eq(GameState.last_ip, "10.0.0.9", "an empty field doesn't wipe the saved address")
	assert_eq((screen.get_node("%Status") as Label).text, NetSession.MSG_UNREACHABLE)
	screen.free()
	session.free()
	GameState.last_ip = real
	_restore_state()
