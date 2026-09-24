extends Node2D
## Dresses natural caves (tools/art/gen_cave.py): crystals, mushrooms and
## fossil gears on floors; stalactites, roots and chains from ceilings.
## Placed once, right after world generation, so only natural caves get it.
## A piece goes away when the tile it stands on or hangs from is mined
## (the player calls tile_cleared on the "cave_decor" group).

const WorldGen = preload("res://scripts/world_gen.gd")
const LightTextures = preload("res://scripts/light_textures.gd")
const TEX := preload("res://assets/sprites/cave_decor.png")
const C := 16
const FLOOR_CRYSTALS := [0, 1, 2]
const FOSSIL := 3
const MUSHROOMS := 4
const STALACTITES := [5, 6]
const ROOTS := 7
const CHAIN := 8
const KEEP_CLEAR := 10  # tiles either side of the dome shaft

var _tilemap: TileMapLayer
var _by_support := {}  # supporting cell -> [decor nodes]


func setup(tilemap: TileMapLayer, rng_seed := 7) -> void:
	_tilemap = tilemap
	add_to_group("cave_decor")  # the miner calls tile_cleared(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var mid := WorldGen.WORLD_WIDTH / 2
	for y in range(WorldGen.SURFACE_ROWS + 2, WorldGen.WORLD_HEIGHT - 1):
		for x in range(1, WorldGen.WORLD_WIDTH - 1):
			if absi(x - mid) < KEEP_CLEAR:
				continue
			var cell := Vector2i(x, y)
			if _solid(cell):
				continue
			var below := cell + Vector2i(0, 1)
			var above := cell + Vector2i(0, -1)
			if _solid(below) and rng.randf() < 0.22:
				_place(cell, below, _floor_piece(y, rng), false)
			elif _solid(above) and rng.randf() < 0.2:
				_place(cell, above, _ceiling_piece(y, rng), true)


func _solid(cell: Vector2i) -> bool:
	return _tilemap.get_cell_source_id(cell) != -1


func _floor_piece(y: int, rng: RandomNumberGenerator) -> int:
	var deep := y > WorldGen.STONE_DEPTH
	var roll := rng.randf()
	if roll < (0.5 if deep else 0.25):
		return FLOOR_CRYSTALS[rng.randi() % 3]
	if roll < 0.7:
		return MUSHROOMS
	return FOSSIL


func _ceiling_piece(y: int, rng: RandomNumberGenerator) -> int:
	if y < WorldGen.SURFACE_ROWS + 8 and rng.randf() < 0.7:
		return ROOTS
	if rng.randf() < 0.15:
		return CHAIN
	return STALACTITES[rng.randi() % 2]


func _place(cell: Vector2i, support: Vector2i, piece: int, hanging: bool) -> void:
	var spr := Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = TEX
	a.region = Rect2(piece * C, 0, C, C)
	spr.texture = a
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.position = _tilemap.map_to_local(cell) - Vector2(C, C) / 2.0
	spr.flip_h = randf() < 0.5
	add_child(spr)
	if piece in FLOOR_CRYSTALS or piece == MUSHROOMS:
		var light := PointLight2D.new()
		light.texture = LightTextures.create_radial_light(64)
		light.color = Color(0.45, 0.85, 0.95)
		light.energy = 0.9 if piece != MUSHROOMS else 0.55
		light.texture_scale = 2.4
		light.position = Vector2(8, 10)
		spr.add_child(light)
	if not _by_support.has(support):
		_by_support[support] = []
	_by_support[support].append(spr)


func tile_cleared(cell: Vector2i) -> void:
	if not _by_support.has(cell):
		return
	for spr in _by_support[cell]:
		if is_instance_valid(spr):
			var t: Tween = spr.create_tween()
			t.tween_property(spr, "modulate:a", 0.0, 0.15)
			t.tween_callback(spr.queue_free)
	_by_support.erase(cell)
