extends Control
## Level grid. Locked levels cannot be opened; unlocked levels without a scene yet say "Coming soon".

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	%Back.pressed.connect(get_tree().change_scene_to_file.bind(MODE_SELECT))
	build()


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
