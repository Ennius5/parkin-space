extends TestCase

const TEST_PATH := "user://test_save.cfg"


func _new_state() -> Node:
	var gs: Node = load("res://autoload/GameState.gd").new()
	gs.save_path = TEST_PATH
	return gs


func _fresh_state() -> Node:
	DirAccess.remove_absolute(TEST_PATH)
	return _new_state()


func test_fresh_start_only_level_1_unlocked() -> void:
	var gs := _fresh_state()
	gs.load_progress()
	assert_true(gs.is_unlocked(1))
	assert_false(gs.is_unlocked(2))
	gs.free()


func test_clearing_level_unlocks_next_and_persists() -> void:
	var gs := _fresh_state()
	gs.complete_level(1, 2)
	gs.free()
	var reloaded := _new_state()
	reloaded.load_progress()
	assert_eq(reloaded.unlocked_level, 2)
	assert_eq(reloaded.best_stars.get(1, 0), 2)
	reloaded.free()


func test_replay_never_lowers_stars_or_unlocks() -> void:
	var gs := _fresh_state()
	gs.complete_level(1, 3)
	gs.complete_level(2, 1)
	gs.complete_level(1, 1)
	assert_eq(gs.best_stars[1], 3)
	assert_eq(gs.unlocked_level, 3)
	gs.free()


func test_last_level_does_not_unlock_beyond_total() -> void:
	var gs := _fresh_state()
	gs.unlocked_level = 5
	gs.complete_level(5, 1)
	assert_eq(gs.unlocked_level, 5)
	gs.free()


func test_corrupt_save_falls_back_to_defaults() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("not a config {{{")
	f.close()
	var gs := _new_state()
	gs.load_progress()
	assert_eq(gs.unlocked_level, 1)
	assert_true(gs.best_stars.is_empty())
	gs.free()


func test_wrong_types_in_save_fall_back_to_defaults() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", "three")
	cfg.set_value("progress", "best_stars", 7)
	cfg.save(TEST_PATH)
	var gs := _new_state()
	gs.load_progress()
	assert_eq(gs.unlocked_level, 1)
	assert_true(gs.best_stars.is_empty())
	gs.free()


func test_sound_setting_persists() -> void:
	var gs := _fresh_state()
	gs.sound_on = false
	gs.save_progress()
	gs.free()
	var reloaded := _new_state()
	reloaded.load_progress()
	assert_false(reloaded.sound_on)
	reloaded.free()


func test_level_scene_path_format() -> void:
	var gs := _fresh_state()
	assert_eq(gs.level_scene_path(3), "res://scenes/levels/Level03.tscn")
	gs.free()
