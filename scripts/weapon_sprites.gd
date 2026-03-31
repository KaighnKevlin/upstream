extends Node

# Generates pixel art weapon sprites programmatically to match the 16x16 art style


static func create_shotgun_texture() -> ImageTexture:
	var img := Image.create(24, 8, false, Image.FORMAT_RGBA8)

	# Stock (brown wood)
	var wood := Color(0.45, 0.3, 0.15)
	var wood_dark := Color(0.35, 0.22, 0.1)
	for y in range(1, 7):
		for x in range(0, 6):
			img.set_pixel(x, y, wood if (x + y) % 3 != 0 else wood_dark)
	# Stock taper
	img.set_pixel(0, 1, Color.TRANSPARENT)
	img.set_pixel(0, 2, Color.TRANSPARENT)
	img.set_pixel(0, 6, Color.TRANSPARENT)

	# Receiver (dark metal)
	var metal_dark := Color(0.3, 0.3, 0.32)
	for y in range(1, 7):
		for x in range(6, 10):
			img.set_pixel(x, y, metal_dark)

	# Barrel (lighter metal)
	var metal := Color(0.42, 0.42, 0.44)
	var metal_hi := Color(0.52, 0.52, 0.55)
	for y in range(2, 6):
		for x in range(10, 22):
			img.set_pixel(x, y, metal)
	# Barrel highlight (top edge)
	for x in range(10, 22):
		img.set_pixel(x, 2, metal_hi)

	# Pump grip (wood)
	for y in range(1, 7):
		for x in range(13, 17):
			img.set_pixel(x, y, wood if y % 2 == 0 else wood_dark)

	# Muzzle (dark)
	var muzzle := Color(0.25, 0.25, 0.27)
	for y in range(2, 6):
		img.set_pixel(22, y, muzzle)
		img.set_pixel(23, y, muzzle)

	# Trigger guard
	img.set_pixel(8, 6, metal_dark)
	img.set_pixel(8, 7, metal_dark)
	img.set_pixel(9, 7, metal_dark)

	return ImageTexture.create_from_image(img)
