extends RefCounted
## Sandbox save/load (F5 / F9): the terrain as it is now (worlds are random
## each run, so a layout needs its ground) plus every placed piece with its
## settings: aims, forces, slopes, modes. Loose ore and enemies aren't kept,
## nor are marbles riding a track (chutes and the rest: scripts/track).
## One slot, in user://sandbox_save.json.

const PATH := "user://sandbox_save.json"
## Where it goes (tests point it elsewhere so they don't eat the player's save).
static var path := PATH
## 2: "mode" (sandbox / factory) and "tree_progress" (Factory research, per
## science kind). Version 1 saves still load (as sandbox).
const VERSION := 2
## Settings worth keeping, on whichever pieces have them.
const PROPS := ["bounce_angle", "bounce_force", "eject_angle", "eject_interval", "eject_force", "aim_angle", "aim", "wire_l", "wire_r", "upper", "lower",
	"throw_speed", "end_offset", "mode", "plate_offset_x", "lift_speed", "wind_speed", "mirrored", "recipe", "research", "segments", "spill",
	"fuel", "charge", "ammo",   # what's loaded: flamer / steam engine fuel, tesla charge, harpoon ammo
	# the marble pieces: which way they face or lean, springs, notes, wires, targets
	"side", "heavy_side", "tilt", "springs", "angle_deg", "note", "watch", "full", "wire_to",
	"kinds", "stored", "target", "accept", "backboard", "muffled", "steps", "limit", "depth", "turns", "raised", "on", "wire_1", "wire_2", "wire_3", "outlets", "tree_id"]


static func has_save() -> bool:
	return FileAccess.file_exists(path)


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
	var data := {"version": VERSION, "tiles": tiles, "pieces": pieces,
		"tech": preload("res://scripts/tech.gd").levels, "lab_progress": preload("res://scenes/lab.gd").progress,
		"tree_progress": preload("res://scenes/lab.gd").tree_progress,
		"mode": "factory" if main.get("factory") else "sandbox",
		"player": [player.global_position.x, player.global_position.y]}
	var dn := main.get_node_or_null("DayNight")
	if dn:
		data["clock"] = dn.clock
	var fog := main.get_node_or_null("Fog")
	if fog:
		data["fog"] = Marshalls.raw_to_base64(fog._img.save_png_to_buffer())   # what's been explored
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return -1
	f.store_string(JSON.stringify(data))
	return pieces.size()


## Replaces the world with the saved one. Returns the number of pieces
## placed, or -1 if there's no save.
static func load_into(main: Node) -> int:
	if not has_save():
		return -1
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return -1
	var tree := main.get_tree()
	var bs := main.get_node("/root/BuildSystem")
	# clear the field (marbles riding tracks go with them, like loose ore: dropped, not spilt)
	var net: Node = load("res://scripts/track/track_net.gd").find_net(main)
	if net != null:
		net.clear_all_riders()
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
			if v is Array and b.get(k) is Vector2:
				v = Vector2(v[0], v[1])
			elif v is Array and b.get(k) is Array:
				# a list setting (flap springs, dispenser kinds, silo contents): filled in
				# place, since a typed array silently refuses a plain one
				(b.get(k) as Array).assign(v)
				continue
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
	lab.tree_progress.clear()
	for k in data.get("lab_progress", {}):
		var v = data.lab_progress[k]
		if v is Dictionary:
			lab.tree_progress[k] = _kinds(v)   # per-kind progress filed under the old key
		else:
			lab.progress[k] = int(v)
	for k in data.get("tree_progress", {}):
		if data.tree_progress[k] is Dictionary:
			lab.tree_progress[k] = _kinds(data.tree_progress[k])
	# the mode it was saved in (a version 1 save is a sandbox one)
	if data.get("mode", "sandbox") == "factory":
		if main.has_method("enter_factory"):
			main.enter_factory()
	elif main.has_method("leave_factory"):
		main.leave_factory()
	for b in bs._placed_buildings:
		if b.get_script() == lab:
			b._update_label()   # labs: their research's progress, restored just now
	var dn := main.get_node_or_null("DayNight")
	if dn and data.has("clock"):
		dn.clock = float(data.clock)
		dn.apply()
	var fog := main.get_node_or_null("Fog")
	if fog and data.has("fog"):
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(data.fog)) == OK:
			fog._img = img
			fog._tex.update(img)
	var player: Node2D = main.get_node("Player")
	player.global_position = Vector2(data.player[0], data.player[1])
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	return n


static func _kinds(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
