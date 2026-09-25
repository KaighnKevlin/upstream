extends Node2D
## Draws on top of the terrain TileMapLayer: grass tufts on exposed grass,
## and a ragged blend where two materials meet (dirt grains bleeding into
## stone, etc.), so seams between rock types aren't ruler-straight. Edges
## against air are baked into the tiles themselves (edge frames: see
## WorldGen.set_tile); mark_dirty re-frames a changed cell's neighbours.
## Split into chunks so mining a tile only redraws the 16x16 chunk around it.

const WorldGen = preload("res://scripts/world_gen.gd")
const CHUNK := 16
const TILE := 16
const GRASS_ATLAS_X := 5

const TUFT_COLORS := [Color(0.25, 0.55, 0.15), Color(0.3, 0.65, 0.2), Color(0.4, 0.75, 0.28)]
## material class per atlas column (ore takes its host rock's class)
const CLASS_COLORS := {
	"dirt": [Color(0.36, 0.22, 0.15), Color(0.54, 0.34, 0.23)],
	"stone": [Color(0.18, 0.19, 0.24), Color(0.33, 0.35, 0.41)],
	"deep": [Color(0.12, 0.12, 0.17), Color(0.23, 0.21, 0.29)],
	"hard": [Color(0.11, 0.08, 0.07), Color(0.24, 0.16, 0.13)],
}

var _tilemap: TileMapLayer
var _chunks := {}  # Vector2i -> _Chunk


class _Chunk extends Node2D:
	var shading: Node2D
	var origin: Vector2i

	func _draw() -> void:
		shading.draw_chunk(self, origin)


func setup(tilemap: TileMapLayer, width: int, height: int) -> void:
	_tilemap = tilemap
	add_to_group("tile_shading")
	for cy in ceili(float(height) / CHUNK):
		for cx in ceili(float(width) / CHUNK):
			var c := _Chunk.new()
			c.shading = self
			c.origin = Vector2i(cx * CHUNK, cy * CHUNK)
			add_child(c)
			_chunks[Vector2i(cx, cy)] = c


## Call after changing a cell: re-frames it and its neighbours, and redraws
## its chunk plus any neighbour chunk it borders.
func mark_dirty(cell: Vector2i) -> void:
	WorldGen.reframe_around(_tilemap, cell)
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var key: Vector2i = (cell + d) / CHUNK
		if _chunks.has(key):
			_chunks[key].queue_redraw()


func _solid(cell: Vector2i) -> bool:
	return _tilemap.get_cell_source_id(cell) != -1


func _class(cell: Vector2i) -> String:
	match _tilemap.get_cell_atlas_coords(cell).x:
		0, 5: return "dirt"
		1: return "stone"
		4: return "deep"
		6: return "hard"
		_:
			match WorldGen._get_base_tile(cell.y):
				0: return "dirt"
				4: return "deep"
				_: return "stone"


func draw_chunk(ci: CanvasItem, origin: Vector2i) -> void:
	for y in range(origin.y, origin.y + CHUNK):
		for x in range(origin.x, origin.x + CHUNK):
			var cell := Vector2i(x, y)
			if not _solid(cell):
				continue
			var p := Vector2(x * TILE, y * TILE)
			var mine := _class(cell)
			# ragged blend: the neighbouring material's grains bleed a few
			# pixels over the seam, thinning out (deterministic per cell)
			for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var n: Vector2i = cell + d
				if not _solid(n):
					continue
				var other := _class(n)
				if other == mine or other == "hard" or mine == "hard":
					continue
				var cols: Array = CLASS_COLORS[other]
				for i in TILE:
					var h := hash(x * 73856093 ^ y * 19349663 ^ i * 83492791 ^ (d.x + 2) * 7 ^ (d.y + 2) * 13)
					var depth := 1 + (h % 4)            # 1..4 px in
					for k in depth:
						if (h >> (4 + k)) & 1 == 0 and k > 0:
							continue                       # dithered: sparser the deeper it goes
						var col: Color = cols[(h >> 9) & 1]
						var q: Vector2
						if d == Vector2i.UP:
							q = p + Vector2(i, k)
						elif d == Vector2i.DOWN:
							q = p + Vector2(i, TILE - 1 - k)
						elif d == Vector2i.LEFT:
							q = p + Vector2(k, i)
						else:
							q = p + Vector2(TILE - 1 - k, i)
						ci.draw_rect(Rect2(q, Vector2.ONE), col)
			if not _solid(cell + Vector2i.UP) and _tilemap.get_cell_atlas_coords(cell).x == GRASS_ATLAS_X:
				_draw_tufts(ci, p, x)


func _draw_tufts(ci: CanvasItem, p: Vector2, x: int) -> void:
	# Deterministic per column so tufts don't change when a chunk redraws
	var h := hash(x * 7919)
	var blades := 2 + h % 4
	for i in blades:
		var bh := hash(h + i * 31)
		var bx := p.x + bh % TILE
		var height := 1 + (bh >> 4) % 4
		var col: Color = TUFT_COLORS[(bh >> 8) % TUFT_COLORS.size()]
		ci.draw_rect(Rect2(bx, p.y - height, 1, height), col)
