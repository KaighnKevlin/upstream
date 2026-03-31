extends Node

# Builds the TileSet programmatically with colored squares for each tile type.
# Each tile is a 16x16 colored rectangle rendered via a CanvasTexture.

const TILE_SIZE := 16

# Tile colors by depth/type
static var TILE_COLORS := {
	0: Color(0.45, 0.30, 0.18),   # DIRT - brown
	1: Color(0.40, 0.40, 0.42),   # STONE - grey
	2: Color(0.72, 0.52, 0.35),   # IRON - rust orange
	3: Color(0.25, 0.65, 0.55),   # COPPER - teal green
	4: Color(0.30, 0.28, 0.32),   # DEEP_STONE - dark grey
}

# Slight color variation for visual interest
static var TILE_HIGHLIGHT := {
	0: Color(0.50, 0.35, 0.22),
	1: Color(0.44, 0.44, 0.46),
	2: Color(0.80, 0.58, 0.38),
	3: Color(0.30, 0.72, 0.60),
	4: Color(0.34, 0.32, 0.36),
}


static func create_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add physics layer for collision
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)  # layer 1 = walls

	# Create a TileSetAtlasSource with a generated image
	var atlas := TileSetAtlasSource.new()
	var img := Image.create(TILE_SIZE * 5, TILE_SIZE, false, Image.FORMAT_RGBA8)

	for tile_id in 5:
		var base_color: Color = TILE_COLORS[tile_id]
		var hi_color: Color = TILE_HIGHLIGHT[tile_id]

		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var c: Color
				# Border pixels are darker for a grid look
				if x == 0 or y == 0:
					c = base_color * 0.7
				elif x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
					c = base_color * 0.8
				# Top-left highlight
				elif x < 4 and y < 4:
					c = hi_color
				else:
					c = base_color
				# Add tiny noise for texture
				var noise_val := (((x * 7 + y * 13 + tile_id * 31) % 17) - 8) * 0.01
				c.r = clampf(c.r + noise_val, 0, 1)
				c.g = clampf(c.g + noise_val, 0, 1)
				c.b = clampf(c.b + noise_val, 0, 1)

				img.set_pixel(tile_id * TILE_SIZE + x, y, c)

	var texture := ImageTexture.create_from_image(img)
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create tiles in the atlas (no physics yet)
	for tile_id in 5:
		atlas.create_tile(Vector2i(tile_id, 0))

	# Add atlas source to tileset FIRST so tile data gets physics layers
	tileset.add_source(atlas, 0)

	# NOW add collision polygons (physics layer exists on tile data)
	var polygon := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, 8), Vector2(-8, 8),
	])
	for tile_id in 5:
		var tile_data := atlas.get_tile_data(Vector2i(tile_id, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, polygon)

	return tileset
