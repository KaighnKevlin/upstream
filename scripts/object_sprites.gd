extends Node

# Generates pixel art sprites for game objects


static func create_trampoline_texture() -> ImageTexture:
	var img := Image.create(20, 6, false, Image.FORMAT_RGBA8)
	var green := Color(0.2, 0.75, 0.3)
	var green_hi := Color(0.3, 0.85, 0.4)
	var green_dk := Color(0.15, 0.55, 0.2)
	var metal := Color(0.5, 0.5, 0.55)

	# Metal legs
	img.set_pixel(2, 4, metal); img.set_pixel(2, 5, metal)
	img.set_pixel(17, 4, metal); img.set_pixel(17, 5, metal)

	# Bounce pad
	for x in range(1, 19):
		img.set_pixel(x, 0, green_hi)
		img.set_pixel(x, 1, green)
		img.set_pixel(x, 2, green)
		img.set_pixel(x, 3, green_dk)

	# Edge caps
	img.set_pixel(0, 1, green_dk); img.set_pixel(0, 2, green_dk)
	img.set_pixel(19, 1, green_dk); img.set_pixel(19, 2, green_dk)

	# Spring coils
	for x in [5, 9, 13]:
		img.set_pixel(x, 4, metal)
		img.set_pixel(x + 1, 5, metal)
		img.set_pixel(x, 5, metal)

	return ImageTexture.create_from_image(img)


static func create_ore_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var colors := [
		Color(0.75, 0.5, 0.25), Color(0.8, 0.55, 0.3),
		Color(0.65, 0.4, 0.2), Color(0.7, 0.45, 0.22),
	]
	for y in 8:
		for x in 8:
			var ci := (x * 3 + y * 7) % 4
			var dist := Vector2(x, y).distance_to(Vector2(3.5, 3.5))
			if dist < 4:
				img.set_pixel(x, y, colors[ci])
	return ImageTexture.create_from_image(img)


static func create_ingot_texture() -> ImageTexture:
	var img := Image.create(10, 6, false, Image.FORMAT_RGBA8)
	var silver := Color(0.75, 0.78, 0.82)
	var silver_hi := Color(0.85, 0.88, 0.92)
	var silver_dk := Color(0.55, 0.58, 0.62)

	# Trapezoid ingot shape
	for y in range(0, 6):
		var indent := 0 if y > 1 else (2 - y)
		for x in range(indent, 10 - indent):
			var color := silver
			if y == 0:
				color = silver_hi
			elif y >= 4:
				color = silver_dk
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_turret_texture() -> ImageTexture:
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	var metal := Color(0.4, 0.4, 0.45)
	var metal_hi := Color(0.5, 0.5, 0.55)
	var metal_dk := Color(0.3, 0.3, 0.35)
	var barrel := Color(0.5, 0.5, 0.52)

	# Base
	for y in range(10, 16):
		for x in range(1, 11):
			img.set_pixel(x, y, metal if y % 2 == 0 else metal_dk)

	# Turret head
	for y in range(6, 10):
		for x in range(2, 10):
			img.set_pixel(x, y, metal_hi)

	# Barrel
	for y in range(0, 7):
		img.set_pixel(5, y, barrel)
		img.set_pixel(6, y, barrel)

	# Muzzle
	img.set_pixel(4, 0, metal_dk)
	img.set_pixel(7, 0, metal_dk)

	return ImageTexture.create_from_image(img)


static func create_receiver_texture() -> ImageTexture:
	var img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
	var gold := Color(0.8, 0.7, 0.2)
	var gold_dk := Color(0.6, 0.5, 0.15)
	var gold_hi := Color(0.9, 0.8, 0.3)

	# Funnel shape — wider at top
	for y in 12:
		var half_w := 10 - y / 3
		for x in range(10 - half_w, 10 + half_w):
			var color := gold
			if y < 2:
				color = gold_hi
			elif y > 9:
				color = gold_dk
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_miner_texture() -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	var blue := Color(0.3, 0.3, 0.75)
	var blue_dk := Color(0.2, 0.2, 0.55)
	var blue_hi := Color(0.4, 0.4, 0.85)
	var metal := Color(0.5, 0.5, 0.55)
	var green := Color(0.3, 0.8, 0.3)

	# Body
	for y in range(3, 14):
		for x in range(2, 12):
			img.set_pixel(x, y, blue if (x + y) % 3 != 0 else blue_dk)

	# Top highlight
	for x in range(3, 11):
		img.set_pixel(x, 3, blue_hi)

	# Nozzle
	for y in range(0, 4):
		img.set_pixel(6, y, metal)
		img.set_pixel(7, y, metal)

	# Status light
	img.set_pixel(6, 8, green)
	img.set_pixel(7, 8, green)

	return ImageTexture.create_from_image(img)


static func create_dome_texture() -> ImageTexture:
	var img := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	var dome_color := Color(0.25, 0.35, 0.5)
	var dome_hi := Color(0.35, 0.45, 0.6)
	var dome_dk := Color(0.18, 0.25, 0.38)

	# Dome arc
	var cx := 32.0
	var cy := 24.0
	var rx := 30.0
	var ry := 22.0

	for y in 24:
		for x in 64:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy < 1.0 and y < 22:
				var color := dome_color
				if y < 8:
					color = dome_hi
				elif y > 18:
					color = dome_dk
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_bullet_texture() -> ImageTexture:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var yellow := Color(1.0, 0.9, 0.3)
	var yellow_hi := Color(1.0, 1.0, 0.6)

	for y in 6:
		for x in 6:
			if Vector2(x, y).distance_to(Vector2(2.5, 2.5)) < 3:
				img.set_pixel(x, y, yellow if (x + y) % 2 == 0 else yellow_hi)

	return ImageTexture.create_from_image(img)
