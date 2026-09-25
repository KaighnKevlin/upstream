extends Node

# Tile IDs in our TileSet
const TILE_EMPTY := -1
const TILE_DIRT := 0
const TILE_STONE := 1
const TILE_IRON := 2
const TILE_COPPER := 3
const TILE_DEEP_STONE := 4
const TILE_GRASS := 5
const TILE_HARD := 6   # ironstone: the starting pickaxe can't break it (nor ore veins)

## Tiles the starting pickaxe bounces off.
const PICK_PROOF := [TILE_HARD, TILE_IRON, TILE_COPPER]

# Ironstone shelves in staggered bands, so the way down zig-zags instead of
# going straight (see _generate_ledges).
const LEDGE_FIRST := SURFACE_ROWS + 5
const LEDGE_GAP_ROWS := Vector2i(8, 12)
const LEDGE_HOLE_WIDTH := Vector2i(2, 4)  # gaps between shelves: 2 to 10 tiles

# World dimensions in tiles
const WORLD_WIDTH := 150  # tiles
const WORLD_HEIGHT := 80  # tiles
const TILE_SIZE := 16     # pixels
const SLICE_GRID := 4     # terrain textures repeat every 4 tiles (tools/art/gen_terrain.gd)
const FRAMES := 16        # edge frames per slice: which sides are open to air
const BLOCK_ROWS := SLICE_GRID * SLICE_GRID * FRAMES

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
				set_tile(tilemap, Vector2i(x, y), tile, rng)

	# Carve out the surface (open air)
	for y in SURFACE_ROWS:
		for x in WORLD_WIDTH:
			tilemap.set_cell(Vector2i(x, y), TILE_EMPTY)

	# Carve random caverns
	_generate_caverns(tilemap, rng)

	# Ironstone ledges (before ore, so veins can sit on them)
	_generate_ledges(tilemap, rng)

	# Generate ore veins
	_scatter_ore(tilemap, rng, TILE_IRON, IRON_CHANCE, IRON_VEIN_SIZE,
		DIRT_DEPTH, WORLD_HEIGHT)
	_scatter_ore(tilemap, rng, TILE_COPPER, COPPER_CHANCE, COPPER_VEIN_SIZE,
		STONE_DEPTH, WORLD_HEIGHT)

	# Place grass on the surface row (first row of dirt)
	for x in WORLD_WIDTH:
		set_tile(tilemap, Vector2i(x, SURFACE_ROWS), TILE_GRASS, rng)

	# Carve starter shaft below spawn point (5 tiles wide, 12 deep)
	var shaft_x := WORLD_WIDTH / 2
	for y in range(SURFACE_ROWS, SURFACE_ROWS + 12):
		for x in range(shaft_x - 2, shaft_x + 3):
			tilemap.set_cell(Vector2i(x, y), TILE_EMPTY)

	# Staircase up the left wall so the player can walk out of the pit:
	# 2-tile treads, 1-tile risers, 4 tiles of headroom.
	var floor_y := SURFACE_ROWS + 12
	var step := 0
	while floor_y - step > SURFACE_ROWS:
		var tread_y := floor_y - step
		for dx in 2:
			var x := shaft_x - 3 - step * 2 - dx
			for y in range(tread_y - 4, tread_y):
				tilemap.set_cell(Vector2i(x, y), TILE_EMPTY)
		step += 1
	# frames were picked as cells went in; settle them against the final shape
	reframe_all(tilemap)


## Places a tile, picking the atlas row from the cell position (the slice, so
## each material reads as one continuous texture), from which neighbours are
## air (the edge frame: carved lumpy edges, rounded corners, lit crust; see
## tools/art/gen_terrain.gd), and for ore the block painted on its host rock
## for that depth. Neighbours are re-framed around it.
static func set_tile(tilemap: TileMapLayer, cell: Vector2i, tile: int, _rng: RandomNumberGenerator = null) -> void:
	tilemap.set_cell(cell, 0, Vector2i(tile, _row(tilemap, cell, tile)))
	reframe_around(tilemap, cell)


static func _row(tilemap: TileMapLayer, cell: Vector2i, tile: int) -> int:
	var row := posmod(cell.x, SLICE_GRID) + posmod(cell.y, SLICE_GRID) * SLICE_GRID
	row += _open_mask(tilemap, cell) * SLICE_GRID * SLICE_GRID
	if tile == TILE_IRON or tile == TILE_COPPER:
		match _get_base_tile(cell.y):
			TILE_DIRT: row += BLOCK_ROWS
			TILE_DEEP_STONE: row += BLOCK_ROWS * 2
	return row


## Bits: 1 up, 2 right, 4 down, 8 left are air. The world's edges count as
## solid (no carved rim along the map border).
static func _open_mask(tilemap: TileMapLayer, cell: Vector2i) -> int:
	var m := 0
	var dirs := [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]
	for d in dirs:
		var n: Vector2i = cell + d[0]
		if n.x < 0 or n.x >= WORLD_WIDTH or n.y >= WORLD_HEIGHT:
			continue
		if tilemap.get_cell_source_id(n) == -1:
			m |= d[1]
	return m


## Re-pick one solid cell's frame for its current neighbours.
static func reframe(tilemap: TileMapLayer, cell: Vector2i) -> void:
	if tilemap.get_cell_source_id(cell) == -1:
		return
	var tile := tilemap.get_cell_atlas_coords(cell).x
	var row := _row(tilemap, cell, tile)
	if tilemap.get_cell_atlas_coords(cell).y != row:
		tilemap.set_cell(cell, 0, Vector2i(tile, row))


## After a cell changes (mined, placed): it and its four neighbours.
static func reframe_around(tilemap: TileMapLayer, cell: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		reframe(tilemap, cell + d)


## Every cell (after generation, after loading a save).
static func reframe_all(tilemap: TileMapLayer) -> void:
	for c in tilemap.get_used_cells():
		reframe(tilemap, c)


## Fills the back wall layer: the plain rock type for each depth, from the
## grass row down, so dug-out space shows rock behind it instead of void.
static func generate_back_wall(wall: TileMapLayer, rng_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else 12345
	for y in range(SURFACE_ROWS, WORLD_HEIGHT):
		for x in WORLD_WIDTH:
			var c := Vector2i(x, y)
			var t := _get_base_tile(y)
			# the wall is one unbroken surface: no carved edges except its top
			var row := posmod(x, SLICE_GRID) + posmod(y, SLICE_GRID) * SLICE_GRID
			if y == SURFACE_ROWS:
				row += 1 * SLICE_GRID * SLICE_GRID
			wall.set_cell(c, 0, Vector2i(t, row))


static func _generate_ledges(tilemap: TileMapLayer, rng: RandomNumberGenerator) -> void:
	# Staggered shelves rather than full-width bands: each band row is a run of
	# segments (10-34 tiles, 1-3 thick, rounded ends, wandering up and down)
	# with gaps between them. Consecutive bands shift so gaps rarely line up,
	# so a straight dig down hits ironstone within a band or two.
	var y := LEDGE_FIRST
	var offset := 0
	while y < WORLD_HEIGHT - 4:
		var x := -rng.randi_range(0, 12) + offset
		while x < WORLD_WIDTH:
			var length := rng.randi_range(10, 34)
			var thick := rng.randi_range(1, 3)
			var dy := 0
			for k in length:
				if rng.randf() < 0.18:
					dy = clampi(dy + rng.randi_range(-1, 1), -2, 2)
				# rounded ends: thinner in the first/last 2 tiles
				var t_here := mini(thick, 1 + mini(k, length - 1 - k))
				for t in t_here:
					var cell := Vector2i(x + k, y + dy + t)
					if cell.x >= 0 and cell.x < WORLD_WIDTH and cell.y < WORLD_HEIGHT \
							and tilemap.get_cell_source_id(cell) != -1:  # don't fill caverns
						set_tile(tilemap, cell, TILE_HARD)
			x += length + rng.randi_range(LEDGE_HOLE_WIDTH.x, LEDGE_HOLE_WIDTH.y + 6)
		offset = rng.randi_range(5, 17)
		y += rng.randi_range(LEDGE_GAP_ROWS.x, LEDGE_GAP_ROWS.y)


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
					var near_spawn := absi(tile.x - WORLD_WIDTH / 2) <= 16 and tile.y <= SURFACE_ROWS + 16
					if tile.x >= 2 and tile.x < WORLD_WIDTH - 2 and tile.y > SURFACE_ROWS + 4 and tile.y < WORLD_HEIGHT - 2 and not near_spawn:
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
	set_tile(tilemap, center, ore_tile, rng)

	for i in size - 1:
		var base: Vector2i = placed[rng.randi() % placed.size()]
		var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var dir: Vector2i = dirs[rng.randi() % 4]
		var next := base + dir
		# Only place ore in solid ground
		if next.x >= 0 and next.x < WORLD_WIDTH and next.y >= SURFACE_ROWS and next.y < WORLD_HEIGHT:
			var existing := tilemap.get_cell_source_id(next)
			if existing != -1:  # not empty
				set_tile(tilemap, next, ore_tile, rng)
				placed.append(next)
