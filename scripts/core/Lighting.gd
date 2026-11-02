class_name Lighting
## Shared pieces for the dark lots: a material for markers that ignore lighting, and the
## light shapes, generated once and reused by every light.

const TEXTURE_SIZE := 256  # light textures are this many pixels across at texture_scale 1
const CONE_APEX := 102.0  # the headlight beam's tip sits this many pixels below the texture's centre

static var _unlit: CanvasItemMaterial
static var _round: Texture2D
static var _cone: Texture2D


## For markings the player must always read (spaces, zones, coins): drawn at full brightness in the dark.
static func unlit() -> CanvasItemMaterial:
	if _unlit == null:
		_unlit = CanvasItemMaterial.new()
		_unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unlit


## A soft disc, bright in the middle and fading to nothing at the edge.
static func round_texture() -> Texture2D:
	if _round == null:
		var g := GradientTexture2D.new()
		g.width = TEXTURE_SIZE
		g.height = TEXTURE_SIZE
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		_round = g
	return _round


## A headlight beam pointing up (-Y), brightest at its tip and along its middle.
static func cone_texture() -> Texture2D:
	if _cone == null:
		var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		var apex := Vector2(TEXTURE_SIZE / 2.0, TEXTURE_SIZE / 2.0 + CONE_APEX)
		var half_angle := deg_to_rad(28.0)
		for y in TEXTURE_SIZE:
			for x in TEXTURE_SIZE:
				var d := Vector2(x, y) - apex
				var a := 0.0
				if d.y < 0.0:
					var angle := absf(atan2(d.x, -d.y))
					if angle < half_angle:
						a = clampf(1.0 - d.length() / 220.0, 0.0, 1.0) * (1.0 - angle / half_angle)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cone = ImageTexture.create_from_image(img)
	return _cone
