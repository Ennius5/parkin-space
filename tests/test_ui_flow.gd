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


func test_level4_says_coming_soon() -> void:
	_setup_state(4)
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var button := screen.get_node("%Grid").get_child(3) as Button
	assert_true(button.disabled, "level 4 has no scene yet")
	assert_true(button.text.contains("Coming soon"))
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
