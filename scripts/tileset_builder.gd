extends Node

const TILE_SIZE := 16

const ATLAS_PATH := "res://assets/sprites/terrain_atlas.png"
## Tile types have SLICES position slices; ore types have three blocks of
## them (on stone, dirt, deep stone). See tools/art/gen_terrain.gd.
const SLICES := 64
const SLICE_ROWS := {0: SLICES, 1: SLICES, 2: SLICES * 3, 3: SLICES * 3, 4: SLICES, 5: SLICES}


## wall = true builds the darkened, collision-free set used for the back wall
## that shows through dug-out space.
static func create_tileset(wall := false) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	if not wall:
		tileset.add_physics_layer(0)
		tileset.set_physics_layer_collision_layer(0, 1)

	var tex := load(ATLAS_PATH) as Texture2D
	var atlas_img := tex.get_image()
	atlas_img.convert(Image.FORMAT_RGBA8)
	if wall:
		_darken_for_wall(atlas_img)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(atlas_img)
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for tile_id in SLICE_ROWS:
		for row in SLICE_ROWS[tile_id]:
			atlas.create_tile(Vector2i(tile_id, row))
	tileset.add_source(atlas, 0)
	if wall:
		return tileset

	var polygon := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, 8), Vector2(-8, 8),
	])
	for tile_id in SLICE_ROWS:
		for row in SLICE_ROWS[tile_id]:
			var tile_data := atlas.get_tile_data(Vector2i(tile_id, row), 0)
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, polygon)
	return tileset


static func _darken_for_wall(img: Image) -> void:
	# Darker, desaturated and slightly cool, so walls read as "behind"
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var grey := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var d := c.lerp(Color(grey, grey, grey, c.a), 0.45) * 0.42
			d.b += 0.03
			d.a = c.a
			img.set_pixel(x, y, d)
