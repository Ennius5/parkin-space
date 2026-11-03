extends TestCase
## The Manipulator Drone app icon: the generated PNGs exist at the sizes Godot and Android want,
## and the project and Android export preset point at them.

const ICONS := {
	"res://assets/icon/icon_512.png": 512,
	"res://assets/icon/icon_192.png": 192,
	"res://assets/icon/adaptive_fg_432.png": 432,
	"res://assets/icon/adaptive_bg_432.png": 432,
}
const PRESET_KEYS := {
	"launcher_icons/main_192x192": "res://assets/icon/icon_192.png",
	"launcher_icons/adaptive_foreground_432x432": "res://assets/icon/adaptive_fg_432.png",
	"launcher_icons/adaptive_background_432x432": "res://assets/icon/adaptive_bg_432.png",
}


func test_icon_files_exist_at_their_sizes() -> void:
	for path: String in ICONS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_true(img != null and not img.is_empty(), "%s loads" % path)
		if img and not img.is_empty():
			assert_eq(img.get_size(), Vector2i(ICONS[path], ICONS[path]), path)


func test_adaptive_background_is_opaque_and_foreground_has_a_transparent_margin() -> void:
	var bg := Image.load_from_file(ProjectSettings.globalize_path("res://assets/icon/adaptive_bg_432.png"))
	var fg := Image.load_from_file(ProjectSettings.globalize_path("res://assets/icon/adaptive_fg_432.png"))
	assert_eq(bg.get_pixel(0, 0).a, 1.0, "background opaque")
	assert_eq(bg.get_pixel(216, 216).a, 1.0, "background opaque")
	assert_eq(fg.get_pixel(2, 2).a, 0.0, "foreground corner transparent")


func test_project_icon_is_the_512_png() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://project.godot"), OK)
	assert_eq(cfg.get_value("application", "config/icon", ""), "res://assets/icon/icon_512.png")


func test_android_preset_launcher_icons_point_at_the_pngs() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var options := ""
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") \
				and cfg.get_value(section, "platform", "") == "Android":
			options = section + ".options"
	assert_true(options != "", "an Android preset")
	for key: String in PRESET_KEYS:
		assert_eq(cfg.get_value(options, key, ""), PRESET_KEYS[key], key)
