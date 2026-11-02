class_name Upright
## Keeps world text readable: the rotation that cancels a node's on-screen turn, from its own
## rotation and the camera's together.


static func angle(item: CanvasItem) -> float:
	return -item.get_global_transform_with_canvas().get_rotation()
