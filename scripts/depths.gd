extends Node2D
## The depths: the bottom of the world runs hot. Rock faces in the last
## DEPTH rows show glowing seams of molten rock (unshaded: they shine in the
## dark), getting brighter the deeper you go, and the deepest cave floors
## hold magma pools (scenes/magma.gd) in basins. Redraws its seams when
## tiles there are cleared (group "cave_decor").

const WorldGen = preload("res://scripts/world_gen.gd")

const DEPTH := 14               # rows above the bottom that run hot
const POOLS := 6

var _tm: TileMapLayer
var _rooms := []                # hot chambers: [centre cell, rx, ry]
const BATS_PER := 3


static func build(main: Node, tm: TileMapLayer) -> Node2D:
	var d: Node2D = load("res://scripts/depths.gd").new()
	d.name = "Depths"
	d._tm = tm
	d.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	d.material = mat
	d.add_to_group("cave_decor")
	d.add_to_group("depths")
	main.add_child(d)
	d._chambers()
	d._pools(main)
	d._bats(main)
	return d


## Cinder bats roosting on each hot chamber's ceiling.
func _bats(main: Node) -> void:
	for room in _rooms:
		var c: Vector2i = room[0]
		var rx: int = room[1]
		for k in BATS_PER:
			var x := c.x + randi_range(-rx + 2, rx - 2)
			var cell := Vector2i(x, c.y)
			for i in 8:
				if _tm.get_cell_source_id(cell + Vector2i.UP) != -1:
					break
				cell.y -= 1
			if _tm.get_cell_source_id(cell + Vector2i.UP) == -1:
				continue
			var b: Node2D = load("res://scenes/cinderbat.tscn").instantiate()
			b.global_position = _tm.to_global(_tm.map_to_local(cell)) + Vector2(0, -2)
			main.add_child(b)


## A few wide hot chambers carved near the bottom, so every world has
## somewhere down there to find (the random caverns rarely reach it).
func _chambers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var xs := []
	for k in rng.randi_range(2, 3):
		var cx := 0
		for attempt in 50:
			cx = rng.randi_range(14, WorldGen.WORLD_WIDTH - 15)
			var ok := absi(cx - 75) > 12
			for o in xs:
				ok = ok and absi(o - cx) > 30
			if ok:
				break
		xs.append(cx)
		var cy := WorldGen.WORLD_HEIGHT - rng.randi_range(6, 8)
		var rx := rng.randi_range(8, 11)
		var ry := rng.randi_range(3, 4)
		_rooms.append([Vector2i(cx, cy), rx, ry])
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var dx := float(x - cx) / rx
				var dy := float(y - cy) / ry
				if dx * dx + dy * dy > 1.0 + 0.15 * sin(x * 1.7 + y):
					continue
				var c := Vector2i(x, y)
				if c.y >= WorldGen.WORLD_HEIGHT - 3:
					continue
				_tm.set_cell(c, -1)
				get_tree().call_group("tile_shading", "mark_dirty", c)
		for y in range(cy - ry - 1, cy + ry + 2):
			for x in range(cx - rx - 1, cx + rx + 2):
				WorldGen.reframe(_tm, Vector2i(x, y))


func tile_cleared(c: Vector2i) -> void:
	if c.y >= WorldGen.WORLD_HEIGHT - DEPTH - 1:
		queue_redraw()


func _hash(c: Vector2i, k: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ (k * 83492791))


## Seams on exposed rock faces: short bright cracks along the face.
func _draw() -> void:
	if _tm == null:
		return
	var top := WorldGen.WORLD_HEIGHT - DEPTH
	for y in range(top, WorldGen.WORLD_HEIGHT):
		var heat := float(y - top) / DEPTH          # 0 at the top of the band, 1 at the bottom
		for x in WorldGen.WORLD_WIDTH:
			var c := Vector2i(x, y)
			if _tm.get_cell_source_id(c) == -1:
				continue
			var p := _tm.to_global(_tm.map_to_local(c)) - Vector2(8, 8)
			for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if _tm.get_cell_source_id(c + side) != -1:
					continue
				var h := _hash(c, side.x * 3 + side.y)
				if h % 100 > 35 + int(heat * 55):
					continue
				var col := Color(1.0, 0.45 + 0.3 * heat, 0.12, 0.55 + 0.4 * heat)
				var n := 2 + h % 4
				var o := float(h % 11)
				for k in n:
					var t := fmod(o + k * 1.0, 14.0) + 1
					match side:
						Vector2i.UP:
							draw_rect(Rect2(p + Vector2(t, 0 + (k % 2)), Vector2(1, 1)), col)
						Vector2i.DOWN:
							draw_rect(Rect2(p + Vector2(t, 15 - (k % 2)), Vector2(1, 1)), col)
						Vector2i.LEFT:
							draw_rect(Rect2(p + Vector2(0 + (k % 2), t), Vector2(1, 1)), col)
						Vector2i.RIGHT:
							draw_rect(Rect2(p + Vector2(15 - (k % 2), t), Vector2(1, 1)), col)


## Magma pools on the deepest cave floors: a run of floor 3-6 tiles long
## gets its top row scooped out into a basin and filled.
func _pools(main: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed := 0
	var used := []
	for attempt in 3000:
		if placed >= POOLS:
			break
		var x := rng.randi_range(3, WorldGen.WORLD_WIDTH - 10)
		var y := rng.randi_range(WorldGen.WORLD_HEIGHT - DEPTH + 2, WorldGen.WORLD_HEIGHT - 3)
		var c := Vector2i(x, y)
		# air here, floor below
		if _tm.get_cell_source_id(c) != -1 or _tm.get_cell_source_id(c + Vector2i.DOWN) == -1:
			continue
		var n := 0
		while n < 6 and _tm.get_cell_source_id(c + Vector2i(n, 0)) == -1 and _tm.get_cell_source_id(c + Vector2i(n, 1)) != -1 \
				and _tm.get_cell_source_id(c + Vector2i(n, 2)) != -1:
			n += 1
		if n < 3:
			continue
		var at := _tm.to_global(_tm.map_to_local(c))
		var near := false
		for u in used:
			near = near or u.distance_to(at) < 160.0
		if near:
			continue
		used.append(at)
		for k in n:
			var f := c + Vector2i(k, 1)
			_tm.set_cell(f, -1)
			get_tree().call_group("tile_shading", "mark_dirty", f)
		# a lip of rock either side keeps it in
		for f in [c + Vector2i(-1, 1), c + Vector2i(n, 1)]:
			if _tm.get_cell_source_id(f) == -1:
				WorldGen.set_tile(_tm, f, WorldGen.TILE_DEEP_STONE)
		for k in range(-2, n + 2):
			WorldGen.reframe(_tm, c + Vector2i(k, 1))
			WorldGen.reframe(_tm, c + Vector2i(k, 0))
			WorldGen.reframe(_tm, c + Vector2i(k, 2))
		var pool: Node2D = load("res://scenes/magma.tscn").instantiate()
		pool.width = n * 16.0
		pool.global_position = _tm.to_global(_tm.map_to_local(c + Vector2i(0, 1))) + Vector2(-8, -6)
		main.add_child(pool)
		placed += 1
