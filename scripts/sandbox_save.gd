extends RefCounted
## Sandbox save/load (F5 / F9): the terrain as it is now (worlds are random
## each run, so a layout needs its ground) plus every placed piece with its
## settings: aims, forces, slopes, modes. Loose ore and enemies aren't kept.
## One slot, in user://sandbox_save.json.

const PATH := "user://sandbox_save.json"
## Settings worth keeping, on whichever pieces have them.
const PROPS := ["bounce_angle", "bounce_force", "eject_angle", "eject_force", "aim_angle",
	"throw_speed", "end_offset", "mode", "plate_offset_x", "lift_speed", "wind_speed", "mirrored", "recipe", "research"]


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func save(main: Node) -> int:
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var tiles := []
	for c in tm.get_used_cells():
		var a := tm.get_cell_atlas_coords(c)
		tiles.append([c.x, c.y, tm.get_cell_source_id(c), a.x, a.y])
	var pieces := []
	for b in main.get_node("/root/BuildSystem")._placed_buildings:
		if not is_instance_valid(b) or b.scene_file_path.is_empty():
			continue
		var props := {}
		for p in PROPS:
			if p in b:
				var v = b.get(p)
				props[p] = [v.x, v.y] if v is Vector2 else v
		pieces.append({"scene": b.scene_file_path, "pos": [b.global_position.x, b.global_position.y], "props": props})
	var player: Node2D = main.get_node("Player")
	var data := {"version": 1, "tiles": tiles, "pieces": pieces,
		"tech": preload("res://scripts/tech.gd").levels, "lab_progress": preload("res://scenes/lab.gd").progress,
		"player": [player.global_position.x, player.global_position.y]}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return -1
	f.store_string(JSON.stringify(data))
	return pieces.size()


## Replaces the world with the saved one. Returns the number of pieces
## placed, or -1 if there's no save.
static func load_into(main: Node) -> int:
	if not has_save():
		return -1
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return -1
	var tree := main.get_tree()
	var bs := main.get_node("/root/BuildSystem")
	# clear the field
	for b in bs._placed_buildings:
		if is_instance_valid(b):
			b.queue_free()
	bs._placed_buildings.clear()
	for g in ["showcase", "ore", "enemies"]:
		for n in tree.get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()
	# ground
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	tm.clear()
	for t in data.tiles:
		tm.set_cell(Vector2i(int(t[0]), int(t[1])), int(t[2]), Vector2i(int(t[3]), int(t[4])))
	preload("res://scripts/world_gen.gd").reframe_all(tm)   # saves from before edge frames, too
	var shading := main.get_node_or_null("TileShading")
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	var decor := main.get_node_or_null("CaveDecor")
	if decor:
		for c in decor.get_children():
			c.free()
		decor._by_support.clear()
		decor.setup(tm)
	# pieces go in once the new ground has collision (their legs and posts
	# are raycast down to it)
	await tree.physics_frame
	await tree.physics_frame
	var n := 0
	for p in data.pieces:
		var scene = load(p.scene)
		if scene == null:
			continue
		var b: Node2D = scene.instantiate()
		for k in p.props:
			var v = p.props[k]
			if v is Array:
				v = Vector2(v[0], v[1])
			elif b.get(k) is int:
				v = int(v)   # JSON numbers come back as floats (enums, modes)
			b.set(k, v)
		b.global_position = Vector2(p.pos[0], p.pos[1])
		main.add_child(b)
		if b.has_method("_update_visuals"):
			b._update_visuals()
		bs._placed_buildings.append(b)
		n += 1
	var tech := preload("res://scripts/tech.gd")
	tech.levels.clear()
	for k in data.get("tech", {}):
		tech.levels[k] = int(data.tech[k])
	var lab := preload("res://scenes/lab.gd")
	lab.progress.clear()
	for k in data.get("lab_progress", {}):
		lab.progress[k] = int(data.lab_progress[k])
	var player: Node2D = main.get_node("Player")
	player.global_position = Vector2(data.player[0], data.player[1])
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	return n
