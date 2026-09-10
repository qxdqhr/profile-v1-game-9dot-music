extends RefCounted
class_name NoteStyleIcons
## Procedural icons for note color / slide-width OptionButtons (no text labels).

static func color_swatch(color: Color, size: int = 32) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := Color(0.12, 0.15, 0.18, 1.0)
	var border := Color(0.35, 0.42, 0.48, 1.0)
	img.fill(bg)
	var inset := 3
	for y in range(size):
		for x in range(size):
			var edge := x < 1 or y < 1 or x >= size - 1 or y >= size - 1
			var inner := x >= inset and y >= inset and x < size - inset and y < size - inset
			if edge:
				img.set_pixel(x, y, border)
			elif inner:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

## Horizontal bar icon: thin / medium / wide stroke.
static func slide_width_bar(line_h: int, size: Vector2i = Vector2i(56, 32)) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var bg := Color(0.12, 0.15, 0.18, 1.0)
	var border := Color(0.35, 0.42, 0.48, 1.0)
	var bar := Color(0.95, 0.96, 0.98, 1.0)
	img.fill(bg)
	for y in range(size.y):
		for x in range(size.x):
			if x < 1 or y < 1 or x >= size.x - 1 or y >= size.y - 1:
				img.set_pixel(x, y, border)
	var h := clampi(line_h, 1, size.y - 8)
	var y0 := int((size.y - h) * 0.5)
	var x0 := 8
	var x1 := size.x - 8
	for y in range(y0, y0 + h):
		for x in range(x0, x1):
			img.set_pixel(x, y, bar)
	# end caps (dots)
	var r := maxi(2, int(h * 0.55))
	_fill_circle(img, Vector2i(x0 + 2, size.y / 2), r, bar)
	_fill_circle(img, Vector2i(x1 - 3, size.y / 2), r, bar)
	return ImageTexture.create_from_image(img)

static func _fill_circle(img: Image, c: Vector2i, radius: int, col: Color) -> void:
	var r2 := radius * radius
	for y in range(c.y - radius, c.y + radius + 1):
		for x in range(c.x - radius, c.x + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)
