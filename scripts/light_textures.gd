extends Node


static func create_radial_light(size: int, color: Color = Color.WHITE) -> ImageTexture:
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
