extends Node

# Tile IDs in our TileSet
const TILE_EMPTY := -1
const TILE_DIRT := 0
const TILE_STONE := 1
const TILE_IRON := 2
const TILE_COPPER := 3
const TILE_DEEP_STONE := 4
const TILE_GRASS := 5

# World dimensions in tiles
const WORLD_WIDTH := 150  # tiles
const WORLD_HEIGHT := 80  # tiles
const TILE_SIZE := 16     # pixels

# Zone boundaries (in tile rows from top)
const SURFACE_ROWS := 6       # open air above ground
const DIRT_DEPTH := 20        # dirt layer thickness
const STONE_DEPTH := 40       # stone layer starts here
const DEEP_STONE_DEPTH := 60  # deep stone starts here

# Ore generation
const IRON_CHANCE := 0.015
const COPPER_CHANCE := 0.01
const IRON_VEIN_SIZE := 3
const COPPER_VEIN_SIZE := 3


static func generate(tilemap: TileMapLayer, rng_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	# Fill the world
	for y in WORLD_HEIGHT:
		for x in WORLD_WIDTH:
			var tile := _get_base_tile(y)
			if tile != TILE_EMPTY:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

	# Carve out the surface (open air)
	for y in SURFACE_ROWS:
		for x in WORLD_WIDTH:
			tilemap.set_cell(Vector2i(x, y), TILE_EMPTY)

	# Carve random caverns
	_generate_caverns(tilemap, rng)

	# Generate ore veins
	_scatter_ore(tilemap, rng, TILE_IRON, IRON_CHANCE, IRON_VEIN_SIZE,
		DIRT_DEPTH, WORLD_HEIGHT)
	_scatter_ore(tilemap, rng, TILE_COPPER, COPPER_CHANCE, COPPER_VEIN_SIZE,
		STONE_DEPTH, WORLD_HEIGHT)

	# Place grass on the surface row (first row of dirt)
	for x in WORLD_WIDTH:
		tilemap.set_cell(Vector2i(x, SURFACE_ROWS), 0, Vector2i(TILE_GRASS, 0))

	# Carve starter shaft below spawn point (5 tiles wide, 12 deep)
	var shaft_x := WORLD_WIDTH / 2
	for y in range(SURFACE_ROWS, SURFACE_ROWS + 12):
		for x in range(shaft_x - 2, shaft_x + 3):
			tilemap.set_cell(Vector2i(x, y), TILE_EMPTY)


static func _get_base_tile(y: int) -> int:
	if y < SURFACE_ROWS:
		return TILE_EMPTY
	elif y < SURFACE_ROWS + DIRT_DEPTH:
		return TILE_DIRT
	elif y < SURFACE_ROWS + DEEP_STONE_DEPTH:
		return TILE_STONE
	else:
		return TILE_DEEP_STONE


static func _scatter_ore(tilemap: TileMapLayer, rng: RandomNumberGenerator,
		ore_tile: int, chance: float, vein_size: int,
		min_row: int, max_row: int) -> void:
	for y in range(min_row, max_row):
		for x in WORLD_WIDTH:
			if rng.randf() < chance:
				_place_vein(tilemap, rng, Vector2i(x, y), ore_tile, vein_size)


static func _generate_caverns(tilemap: TileMapLayer, rng: RandomNumberGenerator) -> void:
	var cavern_count := 3 + rng.randi_range(0, 2)

	for _i in cavern_count:
		var cx := rng.randi_range(15, WORLD_WIDTH - 15)
		var cy := rng.randi_range(SURFACE_ROWS + 12, WORLD_HEIGHT - 8)

		var depth_factor := float(cy - SURFACE_ROWS) / float(WORLD_HEIGHT - SURFACE_ROWS)
		var cavern_size := rng.randi_range(40, 70) + int(depth_factor * 30)

		_carve_cavern(tilemap, rng, Vector2i(cx, cy), cavern_size)


static func _carve_cavern(tilemap: TileMapLayer, rng: RandomNumberGenerator,
		center: Vector2i, size: int) -> void:
	# Drunkard's walk with wide brush — creates smooth, connected caves
	var carved := {}
	var pos := center

	for step in size:
		# Larger brush in the middle of the walk, smaller at edges
		var progress := float(step) / float(size)
		var brush_max := 4 if progress > 0.2 and progress < 0.8 else 2
		var blob_radius := rng.randi_range(2, brush_max)

		# Carve an ellipse — wider than tall for natural cave look
		for dy in range(-blob_radius, blob_radius + 1):
			var width := int(blob_radius * 1.5)
			for dx in range(-width, width + 1):
				var dist := float(dx * dx) / float(width * width + 1) + float(dy * dy) / float(blob_radius * blob_radius + 1)
				if dist <= 1.0:
					var tile := Vector2i(pos.x + dx, pos.y + dy)
					if tile.x >= 2 and tile.x < WORLD_WIDTH - 2 and tile.y > SURFACE_ROWS + 4 and tile.y < WORLD_HEIGHT - 2:
						if tile not in carved:
							tilemap.set_cell(tile, TILE_EMPTY)
							carved[tile] = true

		# Smooth random walk — prefer horizontal movement
		var angle := rng.randf() * TAU
		# Bias horizontal
		var move_x := int(round(cos(angle) * 2.0))
		var move_y := int(round(sin(angle) * 1.0))
		pos += Vector2i(move_x, move_y)

		# Occasionally make big horizontal jumps for tunnels connecting chambers
		if rng.randf() < 0.08:
			pos += Vector2i(rng.randi_range(-6, 6), 0)


static func _place_vein(tilemap: TileMapLayer, rng: RandomNumberGenerator,
		center: Vector2i, ore_tile: int, size: int) -> void:
	var placed := [center]
	tilemap.set_cell(center, 0, Vector2i(ore_tile, 0))

	for i in size - 1:
		var base: Vector2i = placed[rng.randi() % placed.size()]
		var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var dir: Vector2i = dirs[rng.randi() % 4]
		var next := base + dir
		# Only place ore in solid ground
		if next.x >= 0 and next.x < WORLD_WIDTH and next.y >= SURFACE_ROWS and next.y < WORLD_HEIGHT:
			var existing := tilemap.get_cell_source_id(next)
			if existing != -1:  # not empty
				tilemap.set_cell(next, 0, Vector2i(ore_tile, 0))
				placed.append(next)
