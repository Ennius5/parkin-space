class_name CctvFilter
extends CanvasLayer
## Makes the lot look like low-bitrate surveillance video: blocky dark gradients, smeared colour,
## banding and fuzz around sharp edges, plus faint scanlines, a vignette, "● REC CAM 03" and a
## ticking timestamp. Drawn over the world only; the level keeps the HUD above it.

const NAMES: Array[String] = ["Off", "Light", "Medium", "Heavy"]
const STRENGTHS: Array[float] = [0.0, 0.35, 0.6, 0.85]
const START_SECONDS := 21 * 3600 + 47 * 60  # the timestamp starts at 21:47:00

var _rect := ColorRect.new()
var _mat := ShaderMaterial.new()
var _rec := Label.new()
var _stamp := Label.new()
var _level := 0
var _clock := 0.0


func _init() -> void:
	layer = 1
	_mat.shader = load("res://scripts/fx/cctv.gdshader")
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)  # children from the start, so they are freed with the layer
	add_child(_rec)
	add_child(_stamp)
	set_level(GameState.CCTV_MEDIUM)


func _ready() -> void:
	for label: Label in [_rec, _stamp]:
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 0.85))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec.position = Vector2(40, 116)  # under the HUD's Served line
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stamp.offset_bottom = -20


## 0 = off, 3 = heavy. Off hides the whole effect, overlay included.
func set_level(level: int) -> void:
	_level = clampi(level, 0, STRENGTHS.size() - 1)
	_mat.set_shader_parameter("strength", STRENGTHS[_level])
	var on := _level > 0
	_rect.visible = on
	_rec.visible = on
	_stamp.visible = on


func strength() -> float:
	return _mat.get_shader_parameter("strength")


func overlay_visible() -> bool:
	return _rec.visible and _stamp.visible


func _process(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("time_step", floorf(_clock * 12.0))  # codec-like fuzz flicker
	var secs := START_SECONDS + int(_clock)
	_stamp.text = "2187-11-02  %02d:%02d:%02d" % [secs / 3600 % 24, secs / 60 % 60, secs % 60]
	_rec.text = ("●" if int(_clock * 2.0) % 2 == 0 else "  ") + " REC   CAM 03"
