extends Node

const TILE_SIZE := 16

# Paths to sprite textures
const TILE_PATHS := {
	0: "res://assets/sprites/tile_dirt.png",      # DIRT
	1: "res://assets/sprites/tile_stone.png",      # STONE
	2: "",                                          # IRON - generated
	3: "res://assets/sprites/tile_copper.png",     # COPPER
	4: "res://assets/sprites/tile_deepstone.png",  # DEEP_STONE
	5: "",                                          # GRASS - generated
}

const TILE_COUNT := 6


static func create_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add physics layer for collision
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)

	# Build a combined atlas image
	var atlas_img := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)

	for tile_id in TILE_COUNT:
		var tile_img: Image
		var path: String = TILE_PATHS[tile_id]

		if path != "":
			tile_img = _load_tile_image(path)
		elif tile_id == 2:
			tile_img = _generate_iron_ore()
		elif tile_id == 5:
			tile_img = _generate_grass_dirt()

		if tile_img:
			tile_img.convert(Image.FORMAT_RGBA8)
			atlas_img.blit_rect(tile_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
				Vector2i(tile_id * TILE_SIZE, 0))

	var texture := ImageTexture.create_from_image(atlas_img)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create tiles
	for tile_id in TILE_COUNT:
		atlas.create_tile(Vector2i(tile_id, 0))

	# Add atlas to tileset, then add physics
	tileset.add_source(atlas, 0)

	var polygon := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, 8), Vector2(-8, 8),
	])
	for tile_id in TILE_COUNT:
		var tile_data := atlas.get_tile_data(Vector2i(tile_id, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, polygon)

	return tileset


static func _load_tile_image(path: String) -> Image:
	var tex := load(path) as Texture2D
	if tex == null:
		return _fallback_image(Color.MAGENTA)
	var img := tex.get_image()
	if img.get_width() != TILE_SIZE or img.get_height() != TILE_SIZE:
		img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	return img


static func _generate_iron_ore() -> Image:
	# Start with stone texture, add orange/rust specks
	var base := _load_tile_image(TILE_PATHS[1])  # stone
	if base == null:
		return _fallback_image(Color(0.7, 0.5, 0.3))

	base.convert(Image.FORMAT_RGBA8)

	# Add iron specks using deterministic pattern
	var iron_colors := [
		Color(0.75, 0.45, 0.25),  # rust
		Color(0.85, 0.55, 0.3),   # light rust
		Color(0.65, 0.35, 0.2),   # dark rust
	]

	# Deterministic speck positions
	var specks := [
		Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4),
		Vector2i(10, 7), Vector2i(11, 7), Vector2i(11, 8),
		Vector2i(6, 11), Vector2i(7, 11), Vector2i(7, 12),
		Vector2i(13, 13), Vector2i(13, 14),
		Vector2i(2, 9), Vector2i(3, 9),
	]

	for i in specks.size():
		var pos: Vector2i = specks[i]
		var col: Color = iron_colors[i % iron_colors.size()]
		if pos.x < TILE_SIZE and pos.y < TILE_SIZE:
			base.set_pixel(pos.x, pos.y, col)

	return base


static func _generate_grass_dirt() -> Image:
	# Dirt base with green grass on top 3 rows
	var base := _load_tile_image(TILE_PATHS[0])  # dirt
	if base == null:
		return _fallback_image(Color(0.3, 0.6, 0.2))

	base.convert(Image.FORMAT_RGBA8)

	var grass_colors := [
		Color(0.25, 0.55, 0.15),  # dark green
		Color(0.3, 0.65, 0.2),    # green
		Color(0.35, 0.7, 0.25),   # light green
	]

	# Top 3 rows are grass
	for y in 3:
		for x in TILE_SIZE:
			var ci := (x + y) % 3
			base.set_pixel(x, y, grass_colors[ci])

	# Irregular grass edge on row 3-4
	var edge_pattern := [3, 2, 4, 3, 2, 3, 4, 2, 3, 4, 2, 3, 3, 4, 2, 3]
	for x in TILE_SIZE:
		var depth: int = edge_pattern[x]
		if depth > 3:
			base.set_pixel(x, 3, grass_colors[1])

	return base


static func _fallback_image(color: Color) -> Image:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img
