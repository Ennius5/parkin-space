@tool
class_name HexStyle
extends StyleBox
## A neon hexagon button face: flat top and bottom, pointed ends, a dark translucent fill and a
## glowing outline. Used by the game-wide theme for every Button.

const CYAN := Color(0.25, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.85)

@export var color := CYAN  # outline, glow and (through the theme) text
@export var fill := Color(0.02, 0.06, 0.1, 0.75)
@export_range(0.0, 1.0) var glow := 0.35  # strength of the soft outer outlines
@export var width := 3.0


## The six corners of a hexagon filling rect, with pointed left and right ends.
static func hex_points(rect: Rect2) -> PackedVector2Array:
	var inset := minf(rect.size.y / 2.0, rect.size.x * 0.25)
	var mid := rect.position.y + rect.size.y / 2.0
	var left := rect.position.x
	var right := rect.end.x
	return PackedVector2Array([
		Vector2(left + inset, rect.position.y), Vector2(right - inset, rect.position.y),
		Vector2(right, mid), Vector2(right - inset, rect.end.y),
		Vector2(left + inset, rect.end.y), Vector2(left, mid),
	])


## Draws a neon hexagon onto any canvas item; HexFace uses the same look for the driving pad.
static func draw_hex(item: RID, rect: Rect2, outline: Color, body: Color, glow_strength: float, line_width: float) -> void:
	var pts := hex_points(rect)
	RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([body]))
	for i in 2:  # two soft, wider outlines make the neon glow
		var halo := hex_points(rect.grow(2.0 + i * 3.0))
		halo.append(halo[0])
		var c := Color(outline, glow_strength * (0.5 - i * 0.2))
		RenderingServer.canvas_item_add_polyline(item, halo, PackedColorArray([c]), line_width + 4.0 + i * 4.0, true)
	var edge := pts.duplicate()
	edge.append(pts[0])
	RenderingServer.canvas_item_add_polyline(item, edge, PackedColorArray([outline]), line_width, true)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	draw_hex(to_canvas_item, rect, color, fill, glow, width)
