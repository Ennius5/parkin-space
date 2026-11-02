extends Node
## Plays the game's sound: one-shot effects from a small pool, a looping thruster for the driven
## ship, and music (one menu track, random level tracks). GameState.sound_on mutes everything.

const EFFECTS := {
	"thruster": ["res://assets/audio/sfx/thrusterFire_000.ogg"],
	"bump": ["res://assets/audio/sfx/impactSoft_medium_000.ogg", "res://assets/audio/sfx/impactSoft_medium_001.ogg", "res://assets/audio/sfx/impactSoft_medium_002.ogg", "res://assets/audio/sfx/impactSoft_medium_003.ogg", "res://assets/audio/sfx/impactSoft_medium_004.ogg"],
	"dent": ["res://assets/audio/sfx/impactMetal_heavy_000.ogg", "res://assets/audio/sfx/impactMetal_heavy_001.ogg", "res://assets/audio/sfx/impactMetal_heavy_002.ogg", "res://assets/audio/sfx/impactMetal_heavy_003.ogg", "res://assets/audio/sfx/impactMetal_heavy_004.ogg"],
	"crash": ["res://assets/audio/sfx/explosionCrunch_000.ogg", "res://assets/audio/sfx/explosionCrunch_001.ogg", "res://assets/audio/sfx/explosionCrunch_002.ogg", "res://assets/audio/sfx/explosionCrunch_003.ogg", "res://assets/audio/sfx/explosionCrunch_004.ogg"],
	"ready": ["res://assets/audio/sfx/tick_001.ogg", "res://assets/audio/sfx/tick_002.ogg", "res://assets/audio/sfx/tick_004.ogg"],
	"park": ["res://assets/audio/sfx/confirmation_001.ogg", "res://assets/audio/sfx/confirmation_002.ogg", "res://assets/audio/sfx/confirmation_003.ogg", "res://assets/audio/sfx/confirmation_004.ogg"],
	"fee": ["res://assets/audio/sfx/chip-lay-1.ogg", "res://assets/audio/sfx/chip-lay-2.ogg", "res://assets/audio/sfx/chip-lay-3.ogg"],
	"tip": ["res://assets/audio/sfx/chips-stack-1.ogg", "res://assets/audio/sfx/chips-stack-2.ogg", "res://assets/audio/sfx/chips-stack-3.ogg", "res://assets/audio/sfx/chips-stack-4.ogg", "res://assets/audio/sfx/chips-stack-5.ogg", "res://assets/audio/sfx/chips-stack-6.ogg"],
	"bonus": ["res://assets/audio/sfx/chips-handle-1.ogg", "res://assets/audio/sfx/chips-handle-2.ogg", "res://assets/audio/sfx/chips-handle-3.ogg", "res://assets/audio/sfx/chips-handle-4.ogg", "res://assets/audio/sfx/chips-handle-5.ogg", "res://assets/audio/sfx/chips-handle-6.ogg"],
	"arrive": ["res://assets/audio/sfx/bong_001.ogg"],
	"request": ["res://assets/audio/sfx/question_001.ogg", "res://assets/audio/sfx/question_002.ogg", "res://assets/audio/sfx/question_003.ogg", "res://assets/audio/sfx/question_004.ogg"],
	"fling": ["res://assets/audio/sfx/forceField_000.ogg", "res://assets/audio/sfx/forceField_001.ogg", "res://assets/audio/sfx/forceField_002.ogg", "res://assets/audio/sfx/forceField_003.ogg", "res://assets/audio/sfx/forceField_004.ogg"],
	"radiation": ["res://assets/audio/sfx/glitch_001.ogg", "res://assets/audio/sfx/glitch_002.ogg", "res://assets/audio/sfx/glitch_003.ogg", "res://assets/audio/sfx/glitch_004.ogg"],
	"warning": ["res://assets/audio/sfx/error_001.ogg", "res://assets/audio/sfx/error_002.ogg", "res://assets/audio/sfx/error_003.ogg", "res://assets/audio/sfx/error_004.ogg", "res://assets/audio/sfx/error_005.ogg", "res://assets/audio/sfx/error_006.ogg", "res://assets/audio/sfx/error_007.ogg", "res://assets/audio/sfx/error_008.ogg"],
	"click": ["res://assets/audio/sfx/click_001.ogg", "res://assets/audio/sfx/click_002.ogg", "res://assets/audio/sfx/click_003.ogg", "res://assets/audio/sfx/click_004.ogg", "res://assets/audio/sfx/click_005.ogg"],
	"open": ["res://assets/audio/sfx/open_001.ogg", "res://assets/audio/sfx/open_002.ogg", "res://assets/audio/sfx/open_003.ogg", "res://assets/audio/sfx/open_004.ogg"],
	"close": ["res://assets/audio/sfx/close_001.ogg", "res://assets/audio/sfx/close_002.ogg", "res://assets/audio/sfx/close_003.ogg", "res://assets/audio/sfx/close_004.ogg"],
	"win": ["res://assets/audio/sfx/maximize_001.ogg", "res://assets/audio/sfx/maximize_002.ogg", "res://assets/audio/sfx/maximize_003.ogg", "res://assets/audio/sfx/maximize_004.ogg", "res://assets/audio/sfx/maximize_005.ogg", "res://assets/audio/sfx/maximize_006.ogg", "res://assets/audio/sfx/maximize_007.ogg", "res://assets/audio/sfx/maximize_008.ogg", "res://assets/audio/sfx/maximize_009.ogg"],
	"lose": ["res://assets/audio/sfx/lowFrequency_explosion_000.ogg", "res://assets/audio/sfx/lowFrequency_explosion_001.ogg"],
}
const MENU_TRACK := "res://assets/audio/music/descent_mind_ascent.ogg"
const LEVEL_TRACKS: Array[String] = [
	"res://assets/audio/music/strange.ogg",
	"res://assets/audio/music/never_stop_rising.ogg",
	"res://assets/audio/music/squidgy.ogg",
	"res://assets/audio/music/just_not_right.ogg",
]
const POOL_SIZE := 8  # at most this many effects at once; the oldest is reused
const FADE_SECONDS := 0.5
const SILENT_DB := -40.0

var played: Array[String] = []  # every effect asked for, in order (tests read this)

var _effects := Node.new()
var _next_player := 0
var _thruster := AudioStreamPlayer.new()
var _music := AudioStreamPlayer.new()
var _track := ""
var _last_level_track := ""
var _level_mode := false
var _rng := RandomNumberGenerator.new()
var _fade: Tween
var _pending: AudioStream  # the track to start once the old one has faded out


func _ready() -> void:
	_rng.randomize()
	_add_bus("Music")
	_add_bus("SFX")
	_effects.name = "Effects"
	add_child(_effects)
	var loop: AudioStreamOggVorbis = (load(EFFECTS["thruster"][0]) as AudioStreamOggVorbis).duplicate()
	loop.loop = true
	_thruster.stream = loop
	_thruster.bus = "SFX"
	_thruster.volume_db = -6.0
	add_child(_thruster)
	_music.bus = "Music"
	_music.volume_db = -4.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS  # music keeps playing while the game is paused
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	apply_mute()


func _exit_tree() -> void:
	if _fade:
		_fade.kill()
	_music.stop()
	_thruster.stop()
	_music.stream = null
	_pending = null
	_thruster.stream = null
	for player: AudioStreamPlayer in _effects.get_children():
		player.stream = null


func _add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


## A one-shot effect by name (a random variant when there are several).
func play(effect: String) -> void:
	if not EFFECTS.has(effect):
		print("Sound: no effect named %s" % effect)  # a typo in a name: logged, never a crash
		return
	played.append(effect)
	var player: AudioStreamPlayer
	if _effects.get_child_count() < POOL_SIZE:
		player = AudioStreamPlayer.new()
		player.bus = "SFX"
		_effects.add_child(player)
	else:
		player = _effects.get_child(_next_player)
		_next_player = (_next_player + 1) % POOL_SIZE
	var variants: Array = EFFECTS[effect]
	player.stream = load(variants[_rng.randi_range(0, variants.size() - 1)])
	player.play()


func start_thruster() -> void:
	if not _thruster.playing:
		_thruster.play()


func stop_thruster() -> void:
	if _thruster.playing:
		_thruster.stop()


func thruster_on() -> bool:
	return _thruster.playing


## The menu track, looping. Left alone if it's already playing, so menus don't restart it.
func play_menu_music() -> void:
	_level_mode = false
	if _track == MENU_TRACK and _music.playing:
		return
	_switch_to(MENU_TRACK, true)


## A random level track; another random one follows when it ends.
func play_level_music() -> void:
	_level_mode = true
	_last_level_track = next_track(LEVEL_TRACKS, _last_level_track, _rng)
	_switch_to(_last_level_track, false)


func current_track() -> String:
	return _track


## A random track that isn't the one just played.
static func next_track(tracks: Array[String], previous: String, rng: RandomNumberGenerator) -> String:
	var choices := tracks.filter(func(t: String) -> bool: return t != previous)
	if choices.is_empty():
		return previous
	return choices[rng.randi_range(0, choices.size() - 1)]


func set_sound_on(on: bool) -> void:
	GameState.sound_on = on
	GameState.save_progress()
	apply_mute()


func apply_mute() -> void:
	AudioServer.set_bus_mute(0, not GameState.sound_on)


func _switch_to(path: String, loop: bool) -> void:
	_track = path
	var stream: AudioStreamOggVorbis = (load(path) as AudioStreamOggVorbis).duplicate()
	stream.loop = loop
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _music.playing:
		_fade.tween_property(_music, "volume_db", SILENT_DB, FADE_SECONDS / 2.0)
	_pending = stream
	_fade.tween_callback(_start_pending)
	_fade.tween_property(_music, "volume_db", -4.0, FADE_SECONDS / 2.0)


func _start_pending() -> void:
	_music.stream = _pending
	_pending = null
	_music.volume_db = SILENT_DB
	_music.play()


func _on_music_finished() -> void:
	if _level_mode:
		play_level_music()
