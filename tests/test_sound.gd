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


func _bus_muted(bus_name: String) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name))


func test_music_off_mutes_only_the_music_bus() -> void:
	var real_path := GameState.save_path
	var real_music := GameState.music_on
	var real_sfx := GameState.sfx_on
	GameState.save_path = TEST_SAVE
	Sound.set_sfx_on(true)
	Sound.set_music_on(false)
	assert_true(_bus_muted("Music"))
	assert_false(_bus_muted("SFX"))
	assert_false(AudioServer.is_bus_mute(0), "master stays on")
	assert_false(GameState.music_on)
	Sound.set_music_on(true)
	assert_false(_bus_muted("Music"))
	GameState.save_path = real_path
	GameState.music_on = real_music
	GameState.sfx_on = real_sfx
	Sound.apply_mute()


func test_sound_effects_off_mutes_only_the_sfx_bus() -> void:
	var real_path := GameState.save_path
	var real_music := GameState.music_on
	var real_sfx := GameState.sfx_on
	GameState.save_path = TEST_SAVE
	Sound.set_music_on(true)
	Sound.set_sfx_on(false)
	assert_true(_bus_muted("SFX"))
	assert_false(_bus_muted("Music"))
	assert_false(GameState.sfx_on)
	Sound.set_sfx_on(true)
	assert_false(_bus_muted("SFX"))
	GameState.save_path = real_path
	GameState.music_on = real_music
	GameState.sfx_on = real_sfx
	Sound.apply_mute()


func test_saved_mute_applies_at_start() -> void:
	var real_music := GameState.music_on
	var real_sfx := GameState.sfx_on
	GameState.music_on = false
	GameState.sfx_on = false
	Sound.apply_mute()
	assert_true(_bus_muted("Music"))
	assert_true(_bus_muted("SFX"))
	GameState.music_on = real_music
	GameState.sfx_on = real_sfx
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


# --- Effects at game events ---

func _level() -> Level:
	var level: Level = load("res://scenes/levels/Level01.tscn").instantiate()
	level.change_scene_on_end = false
	tree.root.add_child(level)
	await tree.process_frame
	return level


## The first ship, driven and at rest centred in A1.
func _driven_in_a1(level: Level) -> Ship:
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.select_ship(ship)
	var a1: ParkingSpace = level.get_node("Spaces/A1")
	ship.freeze = true
	ship.global_position = a1.global_position
	ship.global_rotation = a1.global_rotation
	ship.linear_velocity = Vector2.ZERO
	return ship


func test_parking_plays_park_and_fee() -> void:
	var level := await _level()
	_driven_in_a1(level)
	level._check_parking(0.016)
	Sound.played.clear()
	level._on_done_pressed()
	assert_true("park" in Sound.played and "fee" in Sound.played, str(Sound.played))
	level.free()


func test_space_turning_orange_ticks_once() -> void:
	var level := await _level()
	_driven_in_a1(level)
	Sound.played.clear()
	level._check_parking(0.016)
	level._check_parking(0.016)
	assert_eq(Sound.played.count("ready"), 1)
	level.free()


func test_dent_sounds_by_cost() -> void:
	var level := await _level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	Sound.played.clear()
	level._on_ship_dented(ship, 5)
	level._on_ship_dented(ship, 20)
	assert_eq(Sound.played.slice(0, 2), ["dent", "crash"] as Array[String])
	level.free()


func test_fling_plays_fling() -> void:
	var level := await _level()
	var hole := BlackHole.new()
	hole.position = Vector2(1200, 1000)
	level.add_child(hole)
	level._black_hole = hole
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.select_ship(ship)
	level.release_ship()
	ship.global_position = hole.position
	ship.linear_velocity = Vector2(50, 0)
	Sound.played.clear()
	for i in 2:
		await tree.physics_frame
	assert_true("fling" in Sound.played, str(Sound.played))
	level.free()


func test_thruster_stops_when_ship_is_let_go() -> void:
	var level := await _level()
	var ship: Ship = level.get_node("Ships").get_child(0)
	level.select_ship(ship)
	Input.action_press("thrust_forward")
	for i in 3:
		await tree.physics_frame
	assert_true(Sound.thruster_on(), "firing thrusters hiss")
	Input.action_release("thrust_forward")
	level.release_ship()
	for i in 2:
		await tree.physics_frame
	assert_false(Sound.thruster_on(), "letting go silences them")
	level._released_at_msec = -100000
	level.select_ship(ship)
	Input.action_press("thrust_forward")
	for i in 3:
		await tree.physics_frame
	level._return(ship)
	Input.action_release("thrust_forward")
	for i in 2:
		await tree.physics_frame
	assert_false(Sound.thruster_on(), "and so does the ship leaving the lot")
	level.free()


func test_wired_buttons_click() -> void:
	var root := Control.new()
	var button := Button.new()
	root.add_child(button)
	tree.root.add_child(root)
	Sound.wire_clicks(root)
	Sound.played.clear()
	button.pressed.emit()
	assert_eq(Sound.played, ["click"] as Array[String])
	root.free()


func test_menu_buttons_are_wired() -> void:
	var screen: Control = load("res://scenes/ui/ModeSelect.tscn").instantiate()
	tree.root.add_child(screen)
	var wired := false
	for conn in (screen.get_node("%Offline") as Button).pressed.get_connections():
		wired = wired or (conn["callable"] as Callable).get_object() == Sound
	assert_true(wired)
	screen.free()
