extends Node

const TILE_SIZE := 16

## Six atlases, one TileSet source each: source = host block * 2 + (edge
## frame >> 3); block 0 everything (ore on stone), 1 ore on dirt, 2 ore on
## deep stone (see tools/art/gen_terrain.gd). Each holds 64 position slices
## x 8 edge frames = 512 rows (GL won't load one 16384 px tall).
const ATLASES := ["res://assets/sprites/terrain_atlas_0.png", "res://assets/sprites/terrain_atlas_1.png",
	"res://assets/sprites/terrain_atlas_2.png", "res://assets/sprites/terrain_atlas_3.png",
	"res://assets/sprites/terrain_atlas_4.png", "res://assets/sprites/terrain_atlas_5.png"]
const ROWS := 64 * 8
const ALL := [0, 1, 2, 3, 4, 5, 6]
const ORE := [2, 3]
const COLUMNS := [ALL, ALL, ORE, ORE, ORE, ORE]   # tile types present per source


## wall = true builds the collision-free set used for the back wall that
## shows through dug-out space (the layer itself is tinted darker).
static func create_tileset(wall := false) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	if not wall:
		tileset.add_physics_layer(0)
		tileset.set_physics_layer_collision_layer(0, 1)
	var polygon := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for src in ATLASES.size():
		if wall and src > 0:
			break   # the wall is plain rock, unframed: source 0 rows 0-63
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(ATLASES[src])
		atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		for col in COLUMNS[src]:
			for row in (64 if wall else ROWS):   # walls only use the unframed slices
				atlas.create_tile(Vector2i(col, row))
		tileset.add_source(atlas, src)
		if wall:
			continue
		for col in COLUMNS[src]:
			for row in ROWS:
				var tile_data := atlas.get_tile_data(Vector2i(col, row), 0)
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, polygon)
	return tileset
