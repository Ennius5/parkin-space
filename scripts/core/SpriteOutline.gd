class_name SpriteOutline
## Traces a sprite's opaque pixels into a collision outline.


## The largest opaque outline of the texture, centred on it and scaled, in local pixels.
static func outline(texture: Texture2D, scale: float) -> PackedVector2Array:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bits := BitMap.new()
	bits.create_from_image_alpha(image, 0.5)
	var size := image.get_size()
	var best := PackedVector2Array()
	for poly in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 2.0):
		if poly.size() > best.size():
			best = poly
	var centre := Vector2(size) / 2.0
	var result := PackedVector2Array()
	for p in best:
		result.append((p - centre) * scale)
	return result
