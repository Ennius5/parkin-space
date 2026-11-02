extends Control
## End-of-shift screen: outcome, stars, earnings and Retry / Next / Menu.

const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"
const TITLES := {
	"won": "Shift complete!",
	"fired": "You're fired!",
	"timeout": "Shift over – customers still waiting",
}

var _level := 1


func _ready() -> void:
	Sound.play_menu_music()
	Sound.wire_clicks(self)
	%Retry.pressed.connect(_on_retry_pressed)
	%Next.pressed.connect(_on_next_pressed)
	%Menu.pressed.connect(get_tree().change_scene_to_file.bind(LEVEL_SELECT))
	show_result(GameState.last_result)


func show_result(result: Dictionary) -> void:
	_level = result.get("level", GameState.current_level)
	var won: bool = result.get("won", false)
	var stars: int = result.get("stars", 0)
	%Title.text = TITLES.get(result.get("reason", "timeout"), TITLES["timeout"])
	%Stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	%Earnings.text = "Earnings ₵%d   Served %d / %d" % [
		result.get("earnings", 0), result.get("served", 0), result.get("customers", 0)]
	var tips: int = result.get("tips", 0)
	if tips > 0:
		%Earnings.text += "
Tips ₵%d" % tips
	var bonuses: int = result.get("bonuses", 0)
	if bonuses > 0:
		%Earnings.text += "
Bonuses ₵%d" % bonuses
	if result.has("difficulty"):
		%Earnings.text += "
Difficulty: %s" % result["difficulty"]
	var next := _level + 1
	%Next.disabled = not won or next > GameState.TOTAL_LEVELS or not GameState.has_level_scene(next)


func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file(GameState.level_scene_path(_level))


func _on_next_pressed() -> void:
	GameState.current_level = _level + 1
	get_tree().change_scene_to_file(GameState.level_scene_path(_level + 1))
