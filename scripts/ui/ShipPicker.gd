class_name ShipPicker
extends CanvasLayer
## Lot-view list of the ships near a tap. Each row is numbered; matching number badges sit in a
## ring around the tap with a line to their ship, so badges never pile up on close ships.
## Pressing a row rings its ship. Emits picked when a row is tapped.

signal picked(ship: Ship)

const ROW_HEIGHT := 64.0
const ROW_WIDTH := 380.0
const BADGE_RING := 70.0  # badges sit this far from the tap
const BADGE_RADIUS := 20.0
const FINGER_GAP := BADGE_RING + BADGE_RADIUS + 24.0  # the panel opens outside the badge ring
const SCREEN_MARGIN := 8.0
const FONT_SIZE := 28
const CLASS_LETTERS := ["L", "M", "H"]

var ships: Array[Ship] = []

var _rows: Array[Button] = []
var _swatches: Array[ColorRect] = []
var _coins: Array[Color] = []
var _highlight := -1
var _tap := Vector2.ZERO

@onready var _markers: Control = $Markers
@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/List


func _ready() -> void:
	_markers.draw.connect(_draw_markers)
	close()


func _process(_delta: float) -> void:
	if is_open():
		_markers.queue_redraw()  # ships can drift while the list is open


func open(near: Array[Ship], screen_pos: Vector2) -> void:
	close()
	_tap = screen_pos
	ships = near.duplicate()
	for i in ships.size():
		var ship := ships[i]
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = ship.swatch_color()
		swatch.custom_minimum_size = Vector2(32, 32)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var button := Button.new()
		button.text = "%d   %s · %s" % [i + 1, ship.spec.display_name, CLASS_LETTERS[ship.spec.ship_class]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(func() -> void: picked.emit(ship))
		button.button_down.connect(func() -> void: _set_highlight(i))
		button.mouse_entered.connect(func() -> void: _set_highlight(i))
		row.add_child(swatch)
		var coin_color := Color.TRANSPARENT
		if ship.customer and ship.customer.tier != Customer.Tier.NONE:
			coin_color = ship.customer.color()
			var coin := Label.new()
			coin.text = "●"
			coin.add_theme_font_size_override("font_size", FONT_SIZE)
			coin.add_theme_color_override("font_color", coin_color)
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(coin)
		_coins.append(coin_color)
		row.add_child(button)
		_list.add_child(row)
		_rows.append(button)
		_swatches.append(swatch)
	_panel.visible = true
	_place(screen_pos)
	_markers.queue_redraw()


func close() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	_swatches.clear()
	_coins.clear()
	ships.clear()
	_highlight = -1
	_panel.visible = false
	_markers.queue_redraw()


func is_open() -> bool:
	return _panel.visible


func rows() -> Array[Button]:
	return _rows


func swatch_color(index: int) -> Color:
	return _swatches[index].color


func coin_color(index: int) -> Color:
	return _coins[index]


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


## Beside the finger (right side, or left when there's no room), kept fully on screen.
func _place(screen_pos: Vector2) -> void:
	var view := _panel.get_viewport_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	var pos := screen_pos + Vector2(FINGER_GAP, -size.y / 2.0)
	if pos.x + size.x > view.x - SCREEN_MARGIN:
		pos.x = screen_pos.x - FINGER_GAP - size.x
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.x - size.x - SCREEN_MARGIN))
	pos.y = clampf(pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.y - size.y - SCREEN_MARGIN))
	_panel.position = pos


func _set_highlight(index: int) -> void:
	_highlight = index
	_markers.queue_redraw()


func _draw_markers() -> void:
	var font := ThemeDB.fallback_font
	var spots := badge_spots()
	for i in ships.size():
		var ship := ships[i]
		if not is_instance_valid(ship):
			continue
		var p := ship.get_global_transform_with_canvas().origin
		var lit := i == _highlight
		var color := Color(1, 0.85, 0.2) if lit else Color.WHITE
		if lit:
			_markers.draw_arc(p, 34.0, 0.0, TAU, 40, color, 3.0)
		var badge: Vector2 = spots[i]
		_markers.draw_line(badge, p, Color(color, 0.8), 2.0)
		_markers.draw_circle(badge, BADGE_RADIUS, Color(0.1, 0.1, 0.12, 0.9))
		_markers.draw_arc(badge, BADGE_RADIUS, 0.0, TAU, 32, color, 3.0)
		var label := str(i + 1)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		_markers.draw_string(font, badge + Vector2(-text_size.x / 2.0, text_size.y / 3.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## Screen positions of the number badges: evenly spaced on a ring around the tap,
## handed out in the angular order of the ships so the leader lines don't cross.
func badge_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	spots.resize(ships.size())
	if ships.is_empty():
		return spots
	var order := range(ships.size())
	var angle := func(i: int) -> float:
		var ship := ships[i]
		if not is_instance_valid(ship):
			return 0.0
		return (ship.get_global_transform_with_canvas().origin - _tap).angle()
	order.sort_custom(func(a: int, b: int) -> bool: return angle.call(a) < angle.call(b))
	var start: float = angle.call(order[0])
	for k in order.size():
		spots[order[k]] = _tap + Vector2.from_angle(start + TAU * k / order.size()) * BADGE_RING
	return spots
