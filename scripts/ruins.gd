extends Node2D
## A buried clockwork ruin: one per world, deep underground and away from
## the dome, hidden in the fog. An ironstone-walled vault (the starting
## pickaxe can't cut ironstone) with a doorway at floor level on each side
## to dig through to; inside, a brick back wall, pillars, two hanging lamps,
## a sentinel on the ceiling (scenes/sentinel.gd) and a chained relic chest
## (scenes/cache.gd, sealed + relic) that opens once the sentinel is down.
## This node draws the room's backdrop; build() makes the whole thing.

const WorldGen = preload("res://scripts/world_gen.gd")

const W := 16                  # interior, tiles
const H := 6

var room := Rect2()            # interior in world px (tests; the backdrop)


## Carve the vault into the world and fill it. Returns the ruin's node (the
## backdrop), or null if nowhere fit.
static func build(main: Node, tm: TileMapLayer) -> Node2D:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dome_col := 75
	var at := Vector2i(-1, -1)
	for attempt in 200:
		var x := rng.randi_range(6, WorldGen.WORLD_WIDTH - W - 6)
		if absi(x + W / 2 - dome_col) < 24:
			continue
		at = Vector2i(x, rng.randi_range(34, WorldGen.WORLD_HEIGHT - H - 6))
		break
	if at.x < 0:
		return null
	var shading := main.get_node_or_null("TileShading")
	var decor := main.get_node_or_null("CaveDecor")
	# ironstone shell, air inside, doorways low in each side wall
	for y in range(at.y - 1, at.y + H + 1):
		for x in range(at.x - 1, at.x + W + 1):
			var c := Vector2i(x, y)
			var inside := x >= at.x and x < at.x + W and y >= at.y and y < at.y + H
			var door := (x == at.x - 1 or x == at.x + W) and y >= at.y + H - 3 and y < at.y + H
			if inside or door:
				tm.set_cell(c, -1)
				if shading:
					shading.mark_dirty(c)
				if decor:
					decor.tile_cleared(c)
			else:
				WorldGen.set_tile(tm, c, WorldGen.TILE_HARD)
	for y in range(at.y - 2, at.y + H + 2):
		for x in range(at.x - 2, at.x + W + 2):
			WorldGen.reframe(tm, Vector2i(x, y))
	var ruin: Node2D = load("res://scripts/ruins.gd").new()
	ruin.name = "Ruins"
	var top_left := tm.to_global(tm.map_to_local(at)) - Vector2(8, 8)
	ruin.room = Rect2(top_left, Vector2(W, H) * WorldGen.TILE_SIZE)
	ruin.add_to_group("ruins")
	main.add_child(ruin)
	main.move_child(ruin, tm.get_index())      # over the rock back wall, under the terrain
	# lamps: warm light from two hanging lanterns
	for fx in [0.2, 0.8]:
		var l := PointLight2D.new()
		l.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
		l.color = Color(1.0, 0.72, 0.4)
		l.energy = 0.75
		l.texture_scale = 1.4
		l.global_position = ruin.room.position + Vector2(ruin.room.size.x * fx, 22)
		l.add_to_group("ruins")
		main.add_child(l)
	var floor_y: float = ruin.room.end.y
	var chest: Node2D = load("res://scenes/cache.tscn").instantiate()
	chest.sealed = true
	chest.relic = true
	chest.global_position = Vector2(ruin.room.get_center().x, floor_y)
	chest.add_to_group("ruins")
	main.add_child(chest)
	var s: Node2D = load("res://scenes/sentinel.tscn").instantiate()
	s.global_position = Vector2(ruin.room.get_center().x, ruin.room.position.y)
	s.vault = chest
	main.add_child(s)
	return ruin


func _draw() -> void:
	var r := room
	# ashlar back wall: courses of dressed stone, staggered joints
	draw_rect(r, Color(0.19, 0.16, 0.15))
	var course := 8.0
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var h := minf(course, r.end.y - y)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.1, 0.085, 0.08), 1.0)
		var x := r.position.x + (8.0 if row % 2 else 0.0)
		while x < r.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + h), Color(0.1, 0.085, 0.08), 1.0)
			draw_line(Vector2(x + 1, y + 1), Vector2(minf(x + 15, r.end.x), y + 1), Color(0.27, 0.23, 0.2), 1.0)
			x += 16.0
		y += course
		row += 1
	# brass-banded pillars at the quarters
	for fx in [0.12, 0.88]:
		var px: float = r.position.x + r.size.x * fx
		draw_rect(Rect2(px - 6, r.position.y, 12, r.size.y), Color(0.28, 0.24, 0.21))
		draw_rect(Rect2(px - 6, r.position.y, 2, r.size.y), Color(0.36, 0.31, 0.26))
		for by in [r.position.y + 6, r.end.y - 10]:
			draw_rect(Rect2(px - 7, by, 14, 3), Color(0.62, 0.48, 0.27))
	# the lanterns' chains and cages
	for fx in [0.2, 0.8]:
		var lx: float = r.position.x + r.size.x * fx
		draw_line(Vector2(lx, r.position.y), Vector2(lx, r.position.y + 16), Color(0.4, 0.42, 0.42), 1.0)
		draw_rect(Rect2(lx - 3, r.position.y + 16, 6, 8), Color(0.55, 0.42, 0.24))
		draw_rect(Rect2(lx - 2, r.position.y + 18, 4, 4), Color(1.0, 0.8, 0.45))
