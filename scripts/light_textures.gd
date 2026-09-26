extends Node


## Built once per size and colour and shared: callers only read it (lights,
## flashes, glows), and building one pixel by pixel costs 10-60 ms, which
## hitched the game every time a slag gob, meteor, shell or bolt made one.
static var _cache := {}


static func create_radial_light(size: int, color: Color = Color.WHITE) -> ImageTexture:
	var key := "%d:%s" % [size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var tex := _build(size, color)
	_cache[key] = tex
	return tex


static func _build(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0

	for y in size:
		for x in size:
			var dist := Vector2(x, y).distance_to(center)
			var t := clampf(dist / radius, 0.0, 1.0)
			# Smooth falloff
			var alpha := (1.0 - t * t) * color.a
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(img)
