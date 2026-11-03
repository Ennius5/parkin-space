class_name LotEdge
extends Node2D
## Red outline along the inside of the lot walls. Faint at rest, it lights up as the ship
## you're driving nears a wall, so you see the edge before you hit it.

const NEAR := 80.0  # px between the closest hull point and a wall where the glow starts
const FADE_SPEED := 8.0  # how fast the glow follows its target, per second
const DIM_COLOR := Color(1.0, 0.2, 0.2, 0.35)
const BRIGHT_COLOR := Color(1.0, 0.15, 0.15, 1.0)
const DIM_WIDTH := 3.0
const BRIGHT_WIDTH := 6.0

var rect := Rect2()
var glow := 0.0  # 0 = dim, 1 = full warning
var _target := 0.0


func _ready() -> void:
	material = Lighting.unlit()  # a marking, always readable in the dark
	z_index = 5


## The open floor between the WallTop/WallBottom/WallLeft/WallRight bodies under `walls`, in its parent's space.
static func inner_rect(walls: Node2D) -> Rect2:
	var top := _wall_rect(walls, "WallTop")
	var bottom := _wall_rect(walls, "WallBottom")
	var left := _wall_rect(walls, "WallLeft")
	var right := _wall_rect(walls, "WallRight")
	var start := Vector2(left.end.x, top.end.y)
	return Rect2(start, Vector2(right.position.x, bottom.position.y) - start)


static func _wall_rect(walls: Node2D, wall_name: String) -> Rect2:
	var body := walls.get_node(wall_name) as Node2D
	var shape := body.get_child(0) as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	var centre := walls.transform * body.transform * shape.position
	return Rect2(centre - size / 2.0, size)


## Smallest distance from any of `points` to an edge of `rect` (negative once a point is past it).
static func clearance(r: Rect2, points: PackedVector2Array) -> float:
	var least := INF
	for p in points:
		least = minf(least, minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y)))
	return least


## Warning strength for a clearance: 0 from NEAR outwards, 1 at the wall.
static func glow_for(distance: float) -> float:
	return clampf(1.0 - distance / NEAR, 0.0, 1.0)


## Aims the glow at the driven ship (null = nobody driving here: fade out).
func track(ship: Ship) -> void:
	if ship == null:
		_target = 0.0
		return
	var local := PackedVector2Array()
	for p in ship.hull_points():
		local.append(to_local(p))
	_target = glow_for(clearance(rect, local))


func _process(delta: float) -> void:
	var before := glow
	glow = move_toward(glow, _target, FADE_SPEED * delta)
	if glow != before:
		queue_redraw()


func _draw() -> void:
	draw_rect(rect.grow(-BRIGHT_WIDTH / 2.0), DIM_COLOR.lerp(BRIGHT_COLOR, glow), false, lerpf(DIM_WIDTH, BRIGHT_WIDTH, glow))
