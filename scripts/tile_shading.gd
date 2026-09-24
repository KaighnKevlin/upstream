extends Node2D
## Draws depth cues on top of the terrain TileMapLayer: a dark outline and inner
## shadow wherever solid rock meets air, a faint highlight on upward faces, and
## grass tufts on exposed grass. Split into chunks so mining a tile only redraws
## the 16x16 chunk around it.

const CHUNK := 16
const TILE := 16
const GRASS_ATLAS_X := 5

const OUTLINE := Color(0.02, 0.01, 0.03, 0.75)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const HIGHLIGHT := Color(1.0, 0.95, 0.85, 0.16)
const TUFT_COLORS := [Color(0.25, 0.55, 0.15), Color(0.3, 0.65, 0.2), Color(0.4, 0.75, 0.28)]

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


## Call after changing a cell. Redraws its chunk, plus the neighbour chunk
## when the cell sits on a chunk border (its outline lives there too).
func mark_dirty(cell: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var key: Vector2i = (cell + d) / CHUNK
		if _chunks.has(key):
			_chunks[key].queue_redraw()


func _solid(cell: Vector2i) -> bool:
	return _tilemap.get_cell_source_id(cell) != -1


func draw_chunk(ci: CanvasItem, origin: Vector2i) -> void:
	for y in range(origin.y, origin.y + CHUNK):
		for x in range(origin.x, origin.x + CHUNK):
			var cell := Vector2i(x, y)
			if not _solid(cell):
				continue
			var p := Vector2(x * TILE, y * TILE)
			var open_up := not _solid(cell + Vector2i.UP)
			var open_down := not _solid(cell + Vector2i.DOWN)
			var open_left := not _solid(cell + Vector2i.LEFT)
			var open_right := not _solid(cell + Vector2i.RIGHT)
			if not (open_up or open_down or open_left or open_right):
				continue

			# Inner shadow first, outline on top
			if open_down:
				ci.draw_rect(Rect2(p.x, p.y + TILE - 4, TILE, 3), SHADOW)
			if open_left:
				ci.draw_rect(Rect2(p.x + 1, p.y, 2, TILE), SHADOW)
			if open_right:
				ci.draw_rect(Rect2(p.x + TILE - 3, p.y, 2, TILE), SHADOW)
			if open_up:
				ci.draw_rect(Rect2(p.x, p.y + 1, TILE, 1), HIGHLIGHT)

			if open_up:
				ci.draw_rect(Rect2(p.x, p.y, TILE, 1), OUTLINE)
			if open_down:
				ci.draw_rect(Rect2(p.x, p.y + TILE - 1, TILE, 1), OUTLINE)
			if open_left:
				ci.draw_rect(Rect2(p.x, p.y, 1, TILE), OUTLINE)
			if open_right:
				ci.draw_rect(Rect2(p.x + TILE - 1, p.y, 1, TILE), OUTLINE)

			if open_up and _tilemap.get_cell_atlas_coords(cell).x == GRASS_ATLAS_X:
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
