extends Control
## Level grid. Locked levels cannot be opened; unlocked levels without a scene yet say "Coming soon".

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	Sound.play_menu_music()
	%Back.pressed.connect(get_tree().change_scene_to_file.bind(MODE_SELECT))
	_add_difficulty_row()
	build()
	Sound.wire_clicks(self)


## Easy / Normal / Hard buttons above the grid. The choice sets every shift's length and is saved.
func _add_difficulty_row() -> void:
	var row := HBoxContainer.new()
	row.name = "Difficulty"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var group := ButtonGroup.new()
	for d: int in [GameState.Difficulty.EASY, GameState.Difficulty.NORMAL, GameState.Difficulty.HARD]:
		var b := Button.new()
		var seconds: int = int(GameState.SHIFT_SECONDS[d])
		b.text = "%s
%d:%02d" % [GameState.DIFFICULTY_NAMES[d], seconds / 60, seconds % 60]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d == GameState.difficulty
		b.custom_minimum_size = Vector2(180, 100)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_on_difficulty_pressed.bind(d))
		row.add_child(b)
	_grid.add_sibling(row)
	_grid.get_parent().move_child(row, _grid.get_index())


func _on_difficulty_pressed(d: int) -> void:
	GameState.difficulty = d
	GameState.save_progress()


func build() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for i in range(1, GameState.TOTAL_LEVELS + 1):
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 180)  # big enough for a thumb
		b.add_theme_font_size_override("font_size", 30)
		if not GameState.is_unlocked(i):
			b.text = "Level %d\nLOCKED" % i
			b.disabled = true
		elif not GameState.has_level_scene(i):
			b.text = "Level %d\nComing soon" % i
			b.disabled = true
		else:
			b.text = "Level %d\nStars: %d/3" % [i, GameState.best_stars.get(i, 0)]
			b.pressed.connect(_on_level_pressed.bind(i))
		_grid.add_child(b)


func _on_level_pressed(level: int) -> void:
	GameState.current_level = level
	get_tree().change_scene_to_file(GameState.level_scene_path(level))
