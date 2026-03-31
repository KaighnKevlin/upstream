extends Node

# Generates pixel art background layers programmatically


static func create_sky_texture(width: int, height: int) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var top_color := Color(0.05, 0.05, 0.15)
	var mid_color := Color(0.1, 0.12, 0.25)
	var horizon_color := Color(0.2, 0.18, 0.3)

	for y in height:
		var t := float(y) / float(height)
		var color: Color
		if t < 0.5:
			color = top_color.lerp(mid_color, t * 2)
		else:
			color = mid_color.lerp(horizon_color, (t - 0.5) * 2)
		for x in width:
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_stars_texture(width: int, height: int, seed_val: int = 42) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Scatter stars
	var star_count := width * height / 200
	for i in star_count:
		var x := rng.randi_range(0, width - 1)
		var y := rng.randi_range(0, height - 1)
		var brightness := rng.randf_range(0.4, 1.0)
		var size := 1 if rng.randf() > 0.15 else 2
		var color := Color(brightness, brightness, brightness * 0.9, brightness)
		img.set_pixel(x, y, color)
		if size == 2 and x + 1 < width:
			img.set_pixel(x + 1, y, color * 0.6)

	return ImageTexture.create_from_image(img)


static func create_mountains_texture(width: int, height: int, seed_val: int = 123) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var base_color := Color(0.12, 0.1, 0.18)
	var highlight := Color(0.16, 0.14, 0.22)

	# Generate mountain silhouette using midpoint displacement
	var points: Array[float] = []
	for i in width + 1:
		points.append(height * 0.6)

	# Rough mountain shape
	_displace(points, 0, width, height * 0.4, rng)

	# Draw filled mountains
	for x in width:
		var peak := int(points[x])
		for y in range(peak, height):
			var depth := float(y - peak) / float(height - peak)
			var color: Color = base_color.lerp(highlight, depth * 0.3)
			# Add subtle pixel noise
			if (x + y * 3) % 7 == 0:
				color = color * 1.1
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func create_hills_texture(width: int, height: int, seed_val: int = 456) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var base_color := Color(0.18, 0.15, 0.12)
	var highlight := Color(0.22, 0.19, 0.15)

	# Gentler hills
	var points: Array[float] = []
	for i in width + 1:
		points.append(height * 0.5)

	_displace(points, 0, width, height * 0.25, rng)

	# Smooth the hills
	for _pass in 3:
		for i in range(1, points.size() - 1):
			points[i] = (points[i - 1] + points[i] + points[i + 1]) / 3.0

	for x in width:
		var peak := int(points[x])
		for y in range(peak, height):
			var depth := float(y - peak) / float(height - peak)
			var color: Color = base_color.lerp(highlight, depth * 0.5)
			if (x * 3 + y) % 5 == 0:
				color = color * 1.08
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


static func _displace(points: Array[float], left: int, right: int, amplitude: float, rng: RandomNumberGenerator) -> void:
	if right - left < 2:
		return
	var mid := (left + right) / 2
	points[mid] = (points[left] + points[right]) / 2.0 + rng.randf_range(-amplitude, amplitude)
	_displace(points, left, mid, amplitude * 0.55, rng)
	_displace(points, mid, right, amplitude * 0.55, rng)
