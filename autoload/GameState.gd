extends Node
## Global game state: level progress, settings and the last level result.
## Registered as the "GameState" autoload.

const TOTAL_LEVELS := 5

var save_path: String = "user://save.cfg"  # user:// is the app's private folder on the phone
var unlocked_level: int = 1  # highest level the player may open
var best_stars: Dictionary = {}  # level number -> best stars (1..3)
var current_level: int = 1
var mode: String = "offline"  # "offline" or "online"
var last_result: Dictionary = {}  # filled when a level ends
var sound_on: bool = true


func _ready() -> void:
	load_progress()


func is_unlocked(level: int) -> bool:
	return level <= unlocked_level


func complete_level(level: int, stars: int) -> void:
	best_stars[level] = maxi(stars, best_stars.get(level, 0))
	if level == unlocked_level and level < TOTAL_LEVELS:
		unlocked_level = level + 1
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "best_stars", best_stars)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.save(save_path)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(save_path) or cfg.load(save_path) != OK:
		return
	var level: Variant = cfg.get_value("progress", "unlocked_level", 1)
	if level is int:
		unlocked_level = clampi(level, 1, TOTAL_LEVELS)
	var stars: Variant = cfg.get_value("progress", "best_stars", {})
	if stars is Dictionary:
		best_stars = stars
	var sound: Variant = cfg.get_value("settings", "sound_on", true)
	if sound is bool:
		sound_on = sound


func reset_progress() -> void:  # call from a hidden debug button while testing
	unlocked_level = 1
	best_stars.clear()
	save_progress()


func level_scene_path(level: int) -> String:
	return "res://scenes/levels/Level%02d.tscn" % level


func has_level_scene(level: int) -> bool:
	return ResourceLoader.exists(level_scene_path(level))
