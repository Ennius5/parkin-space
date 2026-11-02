extends TestCase

const TEST_SAVE := "user://test_sound_save.cfg"


func _pool() -> Array:
	return Sound.get_node("Effects").get_children()


func test_every_effect_file_exists() -> void:
	for effect: String in Sound.EFFECTS:
		for path: String in Sound.EFFECTS[effect]:
			assert_true(ResourceLoader.exists(path), path)
	assert_true(ResourceLoader.exists(Sound.MENU_TRACK), Sound.MENU_TRACK)
	for path in Sound.LEVEL_TRACKS:
		assert_true(ResourceLoader.exists(path), path)


func test_play_records_and_uses_the_sfx_bus() -> void:
	Sound.played.clear()
	Sound.play("park")
	assert_eq(Sound.played, ["park"] as Array[String])
	var used := false
	for p: AudioStreamPlayer in _pool():
		used = used or (p.bus == "SFX" and p.stream != null)
	assert_true(used)


func test_unknown_effect_is_ignored() -> void:
	Sound.played.clear()
	Sound.play("nope")
	assert_false("nope" in Sound.played)


func test_effect_pool_is_bounded() -> void:
	for i in 30:
		Sound.play("dent")
	assert_true(_pool().size() <= Sound.POOL_SIZE, "pool %d" % _pool().size())


func test_next_track_never_repeats() -> void:
	var rng := RandomNumberGenerator.new()
	var prev := ""
	for i in 100:
		var t := Sound.next_track(Sound.LEVEL_TRACKS, prev, rng)
		assert_true(t != prev and t in Sound.LEVEL_TRACKS)
		prev = t


func test_menu_music_is_descent_mind_ascent() -> void:
	Sound.play_menu_music()
	assert_eq(Sound.current_track(), Sound.MENU_TRACK)


func test_sound_off_mutes_master() -> void:
	var real_path := GameState.save_path
	var real_on := GameState.sound_on
	GameState.save_path = TEST_SAVE
	Sound.set_sound_on(false)
	assert_true(AudioServer.is_bus_mute(0))
	assert_false(GameState.sound_on)
	Sound.set_sound_on(true)
	assert_false(AudioServer.is_bus_mute(0))
	GameState.save_path = real_path
	GameState.sound_on = real_on
	Sound.apply_mute()


func test_saved_mute_applies_at_start() -> void:
	var real_on := GameState.sound_on
	GameState.sound_on = false
	Sound.apply_mute()
	assert_true(AudioServer.is_bus_mute(0))
	GameState.sound_on = real_on
	Sound.apply_mute()


func test_level_plays_a_level_track() -> void:
	var level: Level = load("res://scenes/levels/Level01.tscn").instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	assert_true(Sound.current_track() in Sound.LEVEL_TRACKS, Sound.current_track())
	level.free()


func test_level_select_plays_menu_music() -> void:
	Sound.play_level_music()
	var screen: Control = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	tree.root.add_child(screen)
	assert_eq(Sound.current_track(), Sound.MENU_TRACK)
	screen.free()


func test_menu_track_isnt_restarted_between_menus() -> void:
	Sound.play_menu_music()
	for i in 40:
		await tree.process_frame
	var player: AudioStreamPlayer = Sound.get("_music")
	var stream := player.stream
	Sound.play_menu_music()
	assert_true(player.stream == stream, "the same track keeps playing")
