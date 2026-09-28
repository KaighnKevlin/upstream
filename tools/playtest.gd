extends SceneTree
## Scripted playtest harness. Boots main.tscn, drives real input events, and
## saves screenshots + a log.
##
##   godot --path . --windowed --resolution 1280x720 --script tools/playtest.gd -- <scenario> <out_dir>

var out_dir := "/tmp/upstream_playtest"
var scenario := "tour"
var main: Node
var shot_n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scenario = args[0]
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	# Deterministic world: regenerate with a fixed seed (SEED env, default 1)
	var seed := int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 1
	if seed != 0:
		tilemap().clear()
		preload("res://scripts/world_gen.gd").generate(tilemap(), seed)
		for c in main.get_node("TileShading").get_children():
			c.queue_redraw()
		for c in main.get_tree().get_nodes_in_group("caches") + main.get_tree().get_nodes_in_group("geysers") + main.get_tree().get_nodes_in_group("crawlers") + main.get_tree().get_nodes_in_group("ruins") + main.get_tree().get_nodes_in_group("firedamp") + main.get_tree().get_nodes_in_group("magma") + main.get_tree().get_nodes_in_group("depths") + main.get_tree().get_nodes_in_group("cinderbats") + main.get_tree().get_nodes_in_group("wyrms"):
			if is_instance_valid(c):
				c.free()   # placed on the old world (a vault chest is in two of these groups)
		# scenarios start clean: drop the sandbox showcase built on the old world
		preload("res://scripts/sandbox_showcase.gd").clear(main)
		var decor := main.get_node_or_null("CaveDecor")
		if decor:  # re-dress the regenerated caves
			for c in decor.get_children():
				c.free()
			decor._by_support.clear()
			decor.setup(tilemap())
		main.get_node("Player").global_position = Vector2(1200, 150)
	# scenarios look underground: no fog unless it's what's being tested
	if main.has_node("Fog") and not scenario.begins_with("fog"):
		main.get_node("Fog").visible = false
	log_line("scenario=%s  godot=%s" % [scenario, Engine.get_version_info().string])
	await call(scenario)
	log_line("done")
	quit()


# ── helpers ─────────────────────────────────────────────────────────────

func log_line(s: String) -> void:
	var t := "%7.2f" % (Time.get_ticks_msec() / 1000.0)
	print("[%s] %s" % [t, s])


func wait(sec: float) -> void:
	await create_timer(sec, true, true).timeout


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		log_line("shot %s (skipped, headless)  %s" % [label, status()])
		return
	var ts := Engine.time_scale
	Engine.time_scale = 0.0  # freeze the game while grabbing
	await process_frame
	# macOS stops drawing a window that isn't in front; force a fresh frame
	RenderingServer.force_draw(false)
	shot_n += 1
	var path := "%s/%02d_%s.png" % [out_dir, shot_n, label]
	root.get_texture().get_image().save_png(path)
	Engine.time_scale = ts
	log_line("shot %s  %s" % [path.get_file(), status()])


func status() -> String:
	var p: Node2D = main.get_node("Player")
	return "player=(%d,%d) hp=%d dome=%d wave=%d ammo=%d enemies=%d ore=%d" % [
		p.global_position.x, p.global_position.y, p.hp, main.dome_hp,
		main.wave_number, main.get_node("Receiver").buffer,
		get_nodes_in_group("enemies").size(), get_nodes_in_group("ore").size()]


func key(code: Key, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tap(code: Key) -> void:
	key(code, true)
	await physics_frame
	await physics_frame
	key(code, false)
	await physics_frame


func hold(code: Key, sec: float) -> void:
	key(code, true)
	await wait(sec)
	key(code, false)


func hold_action(action: String, sec: float) -> void:
	Input.action_press(action)
	await wait(sec)
	Input.action_release(action)


func world_to_screen(world: Vector2) -> Vector2:
	return root.get_canvas_transform() * world


func click_world(world: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var sp := world_to_screen(world)
	var mv := InputEventMouseMotion.new()
	mv.position = sp
	mv.global_position = sp
	Input.parse_input_event(mv)
	root.warp_mouse(sp)
	await physics_frame
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = sp
		ev.global_position = sp
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame


func zoom(z: float) -> void:
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.zoom = Vector2(z, z)
	cam.reset_smoothing()


func tilemap() -> TileMapLayer:
	return main.get_node("TileMapLayer")


func tile_center(cell: Vector2i) -> Vector2:
	var tm := tilemap()
	return tm.to_global(tm.map_to_local(cell))


func find_ore_near(x: float) -> Vector2i:
	var tm := tilemap()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for cell in tm.get_used_cells():
		var ac := tm.get_cell_atlas_coords(cell)
		if ac.x == 2 or ac.x == 3:
			# need solid rock between the ore and the starter pit, so the
			# test chain isn't placed into a cavern
			var clear := true
			for y in range(19, cell.y):
				for dx in range(-3, 4):
					if tm.get_cell_source_id(Vector2i(cell.x + dx, y)) == -1:
						clear = false
			if not clear:
				continue
			var d := absf(tile_center(cell).x - x) + cell.y * 4.0
			if d < best_d:
				best_d = d
				best = cell
	return best


# ── scenarios ───────────────────────────────────────────────────────────

func tour() -> void:
	await wait(1.0)
	await shot("start")
	await tap(KEY_L)  # full-bright cheat
	await shot("start_bright")
	zoom(0.5)
	await wait(0.3)
	await shot("zoomed_out")
	await tap(KEY_L)
	zoom(1.0)
	# walk right, jump, walk left
	await hold_action("move_right", 1.0)
	await shot("walk_right")
	await hold_action("move_left", 2.0)
	await tap(KEY_SPACE)
	await wait(0.2)
	await shot("jump")
	# dig down in the starter shaft
	await hold_action("move_right", 1.0)
	for i in 8:
		key(KEY_S, true)
		key(KEY_J, true)
		await wait(0.3)
		key(KEY_J, false)
		key(KEY_S, false)
	await wait(0.5)
	await shot("dug_down")


func waves() -> void:
	# Do nothing, let waves come. How long does the dome survive?
	# (Skips the first-ingot grace period, i.e. the old pre-grace behaviour.)
	main._waves_started = true
	Engine.time_scale = 3.0
	var t := 0.0
	await tap(KEY_L)
	zoom(0.6)
	var last_dome: int = main.dome_hp
	var last_wave := 0
	while not main._game_over and t < 400.0:
		await wait(0.5)
		t += 0.5
		if main.wave_number != last_wave:
			last_wave = main.wave_number
			var kinds := {}
			for e in get_nodes_in_group("enemies"):
				kinds[e.enemy_type] = kinds.get(e.enemy_type, 0) + 1
			log_line("t=%.1fs WAVE %d spawned, enemies by type %s" % [t, last_wave, kinds])
		if main.dome_hp != last_dome:
			log_line("t=%.1fs dome %d -> %d   %s" % [t, last_dome, main.dome_hp, status()])
			last_dome = main.dome_hp
			if last_dome < 100 and last_dome > 50:
				await shot("dome_hit")
	await shot("waves_end")
	log_line("game_over=%s at ~%ds game time" % [main._game_over, t])


func economy() -> void:
	# Try to build the ore → laser → trampoline → receiver chain with the
	# build tools, the way a player would.
	await tap(KEY_L)
	var ore := find_ore_near(1200)
	log_line("nearest ore cell %s at %s" % [ore, tile_center(ore)])
	var ore_pos := tile_center(ore)
	# Teleport player near it (walking/digging there is tested in tour)
	var p: CharacterBody2D = main.get_node("Player")
	zoom(0.5)
	await wait(0.5)
	await shot("econ_overview")
	# carve a column from the ore up to the surface so ore can fly out
	var tm := tilemap()
	for y in range(6, ore.y):
		tm.set_cell(Vector2i(ore.x, y), -1)
		get_nodes_in_group("tile_shading")[0].mark_dirty(Vector2i(ore.x, y))
	p.global_position = ore_pos + Vector2(0, -40)
	await wait(0.5)
	await tap(KEY_2)
	await click_world(ore_pos)
	log_line("miner placed? buildings=%d" % root.get_node("BuildSystem")._placed_buildings.size())
	await tap(KEY_Q)
	await wait(4.0)
	await shot("econ_miner")
	log_line(status())
	await tap(KEY_3)
	await click_world(ore_pos + Vector2(0, -48))
	await tap(KEY_Q)
	await wait(4.0)
	await shot("econ_laser")
	var ingots := 0
	for n in main.get_children():
		if n is RigidBody2D and not n.is_in_group("ore"):
			ingots += 1
	log_line("ingots in world: %d  %s" % [ingots, status()])
	# trampoline further up the column to kick ingots the rest of the way
	for dy in [-130, -260]:
		await tap(KEY_1)
		await click_world(ore_pos + Vector2(0, dy))
		await tap(KEY_Q)
		var peak := INF
		var ammo0: int = main.get_node("Receiver").buffer
		for i in 100:
			await wait(0.1)
			for n in main.get_children():
				if n is RigidBody2D and not n.is_in_group("ore"):
					peak = minf(peak, n.global_position.y)
		log_line("trampoline at dy=%d: ingot peak y=%.0f (receiver spans y 55-85), ammo +%d  %s" % [dy, peak, main.get_node("Receiver").buffer - ammo0, status()])
	zoom(1.0)
	p.global_position = Vector2(1200, 80)
	await wait(1.0)
	await shot("econ_later")


func mobility() -> void:
	var p: CharacterBody2D = main.get_node("Player")
	var tm := tilemap()
	await wait(1.0)
	log_line("spawn: on_floor=%s pos=%s" % [p.is_on_floor(), p.global_position])
	# 1. jump height
	var y0 := p.global_position.y
	var min_y := y0
	await tap(KEY_SPACE)
	for i in 60:
		await physics_frame
		min_y = minf(min_y, p.global_position.y)
	log_line("jump height = %.0f px  (pit depth = %d px)" % [y0 - min_y, 12 * 16])
	await wait(0.5)
	# 2. J + S dig down
	var n0 := tm.get_used_cells().size()
	var py := p.global_position.y
	key(KEY_S, true); key(KEY_J, true)
	await wait(1.0)
	key(KEY_J, false); key(KEY_S, false)
	log_line("J+S for 1s: tiles removed=%d, player moved down %.0f px" % [n0 - tm.get_used_cells().size(), p.global_position.y - py])
	# 3. J sideways
	var right := tm.local_to_map(tm.to_local(p.global_position + Vector2(40, 0)))
	await hold_action("move_right", 0.6)
	right = tm.local_to_map(tm.to_local(p.global_position + Vector2(16, 0)))
	var right_feet := right + Vector2i(0, 1)
	log_line("before J right: mid=%d feet=%d" % [tm.get_cell_source_id(right), tm.get_cell_source_id(right_feet)])
	Input.action_press("move_right"); key(KEY_J, true)
	await wait(1.0)
	Input.action_release("move_right"); key(KEY_J, false)
	log_line("after J right: mid=%d feet=%d pos=%s" % [tm.get_cell_source_id(right), tm.get_cell_source_id(right_feet), p.global_position])
	await shot("after_side_dig")
	# 4. click-mine under feet
	await wait(0.5)
	var below := tm.local_to_map(tm.to_local(p.global_position + Vector2(0, 26)))
	log_line("tile under feet %s source=%d" % [below, tm.get_cell_source_id(below)])
	await click_world(tile_center(below))
	await wait(0.4)
	log_line("click-mine under feet: source now %d" % tm.get_cell_source_id(below))
	# 5. upstream shaft to escape the pit
	p.global_position = Vector2(1200, 250)
	await wait(1.0)
	await tap(KEY_4)
	await click_world(Vector2(1200, 230))
	await tap(KEY_Q)
	log_line("placed shaft; buildings=%d" % root.get_node("BuildSystem")._placed_buildings.size())
	var best := p.global_position.y
	for i in 40:
		if i % 5 == 0:
			await tap(KEY_SPACE)
		await wait(0.1)
		best = minf(best, p.global_position.y)
	log_line("shaft ride: highest y=%.0f  (surface grass top = 96, player needs y<~78)" % best)
	await shot("shaft_ride")
	# 6. can you just jump out holding right at the top?
	Input.action_press("move_right")
	for i in 10:
		await tap(KEY_SPACE)
		await wait(0.2)
	Input.action_release("move_right")
	await wait(0.5)
	log_line("escape attempt: pos=%s" % p.global_position)
	await shot("escape")


func _build_chain() -> void:
	# Same working chain as economy(): miner → laser → 2 trampolines, on an
	# ore tile planted under the receiver so the test doesn't depend on the seed.
	var tm := tilemap()
	var ore := Vector2i(76, 26)
	preload("res://scripts/world_gen.gd").set_tile(tm, ore, 2)
	for y in range(19, ore.y):
		for dx in range(-3, 4):
			if tm.get_cell_source_id(Vector2i(ore.x + dx, y)) == -1:
				preload("res://scripts/world_gen.gd").set_tile(tm, Vector2i(ore.x + dx, y), 0)
	var ore_pos := tile_center(ore)
	for y in range(6, ore.y):
		tm.set_cell(Vector2i(ore.x, y), -1)
		get_nodes_in_group("tile_shading")[0].mark_dirty(Vector2i(ore.x, y))
	var p: CharacterBody2D = main.get_node("Player")
	zoom(0.5)
	await wait(0.2)
	var bs := root.get_node("BuildSystem")
	for step in [[KEY_2, 0], [KEY_3, -48], [KEY_1, -130], [KEY_1, -260]]:
		var target: Vector2 = ore_pos + Vector2(0, step[1])
		var n0: int = bs._placed_buildings.size()
		await tap(step[0])
		await click_world(target)
		await tap(KEY_Q)
		# The click goes through the real build path; snap to the exact spot
		# afterwards, since camera smoothing can shift the click a few px.
		if bs._placed_buildings.size() > n0:
			bs._placed_buildings[-1].global_position = target
		else:
			# e.g. headless, where there's no mouse to click with
			var b: Node2D = bs._scenes[{KEY_1: 1, KEY_2: 2, KEY_3: 3}[step[0]]].instantiate()
			b.global_position = target
			main.add_child(b)
			bs._placed_buildings.append(b)
	# park the player on the surface, off to the left of the dome
	p.global_position = Vector2(1100, 60)
	zoom(0.6)


func defense() -> void:
	await tap(KEY_L)
	await _build_chain()
	Engine.time_scale = 2.0
	var t := 0.0
	var last_dome: int = main.dome_hp
	var last_wave := 0
	var shots := 0
	var peak_enemies := 0
	while not main._game_over and t < 300.0:
		await wait(1.0)
		t += 1.0
		peak_enemies = maxi(peak_enemies, get_nodes_in_group("enemies").size())
		if main.wave_number != last_wave:
			last_wave = main.wave_number
			log_line("t=%3ds WAVE %d  %s" % [t, last_wave, status()])
		if main.dome_hp != last_dome:
			last_dome = main.dome_hp
		if int(t) % 20 == 0:
			log_line("t=%3ds  %s" % [t, status()])
		if int(t) % 60 == 0:
			await shot("defense_t%d" % t)
	await shot("defense_end")
	log_line("END t=%ds game_over=%s peak_enemies=%d  %s" % [t, main._game_over, peak_enemies, status()])


func _spawn(type: int, pos: Vector2) -> Node:
	var e: Node = preload("res://scenes/enemy.tscn").instantiate()
	e.add_to_group("enemies")
	e.setup(type)
	e.global_position = pos
	e.direction = -1.0
	main.add_child(e)
	return e


func combat() -> void:
	await tap(KEY_L)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1500, 60)
	main._wave_timer = -9999.0  # no natural waves
	await wait(1.0)
	var names := ["TITAN", "GOBLIN", "SKELETON", "WIZARD"]
	for type in 4:
		var e := _spawn(type, Vector2(1700, 40))
		e.speed = 0.0
		await wait(1.0)
		var hp0: int = e.hp
		# aim at the middle of the sprite (what a player would do)
		var spr: AnimatedSprite2D = e.get_node("AnimatedSprite2D")
		var frame := spr.sprite_frames.get_frame_texture(spr.animation, 0)
		var h := frame.get_height() * spr.scale.y
		var aim: Vector2 = e.global_position + Vector2(0, spr.offset.y * spr.scale.y)
		var mv := InputEventMouseMotion.new()
		mv.position = world_to_screen(aim)
		Input.parse_input_event(mv)
		root.warp_mouse(mv.position)
		await physics_frame
		key(KEY_F, true)
		await wait(0.1)
		key(KEY_F, false)
		await wait(0.6)
		var hp1: int = e.hp if is_instance_valid(e) else 0
		log_line("%s: sprite ~%dpx tall, origin y=%.0f, aimed at y=%.0f  hp %d -> %d (5 pellets x 2 dmg)" % [names[type], h, e.global_position.y if is_instance_valid(e) else 0.0, aim.y, hp0, hp1])
		if type == 0:
			await shot("combat_titan")
		if is_instance_valid(e):
			e.queue_free()
		await wait(0.3)
	# contact damage / knockback from a goblin walking into the player
	var g := _spawn(1, Vector2(1650, 40))
	var hp_before: int = p.hp
	await wait(3.0)
	log_line("goblin contact: player hp %d -> %d, pos=%s" % [hp_before, p.hp, p.global_position])


func verify() -> void:
	# Checks for the fixes made after the first playtest.
	var p: CharacterBody2D = main.get_node("Player")
	var tm := tilemap()
	await wait(1.0)
	await shot("verify_start_hud")
	# 1. walk out of the starter pit via the staircase (hold left, hop)
	var t := 0.0
	Input.action_press("move_left")
	while t < 8.0 and p.global_position.y > 80:
		if p.is_on_floor() or p.is_on_wall():
			await tap(KEY_SPACE)
		await wait(0.1)
		t += 0.1
	Input.action_release("move_left")
	log_line("pit escape: %s after %.1fs, pos=%s" % ["OK" if p.global_position.y <= 80 else "FAILED", t, p.global_position])
	await shot("verify_escaped")
	# 2. grace period: no wave while there's no ammo
	Engine.time_scale = 4.0
	await wait(45.0)
	Engine.time_scale = 1.0
	log_line("grace: after 45s with no ammo, wave=%d label='%s'" % [main.wave_number, main.get_node("CanvasLayer/WaveLabel").text])
	# 3. J+S digs down (stand on flat ground away from the pit)
	p.global_position = Vector2(700, 70)
	await wait(1.0)
	var n0 := tm.get_used_cells().size()
	var y0 := p.global_position.y
	key(KEY_S, true); key(KEY_J, true)
	await wait(1.5)
	key(KEY_J, false); key(KEY_S, false)
	await wait(0.5)
	log_line("dig down: tiles removed=%d, player dropped %.0f px" % [n0 - tm.get_used_cells().size(), p.global_position.y - y0])
	# 4. knockback distance from a goblin
	p.global_position = Vector2(1500, 70)
	main._waves_started = false
	await wait(1.0)
	var x0 := p.global_position.x
	var g := _spawn(1, Vector2(1580, 40))
	g.speed = 60.0
	await wait(2.5)
	log_line("knockback: player pushed %.0f px (was ~735)" % absf(p.global_position.x - x0))
	if is_instance_valid(g):
		g.queue_free()
	# 5. sky at different camera heights
	p.global_position = Vector2(1400, -250)
	zoom(0.5)
	await wait(0.1)
	await shot("verify_sky_high_zoomed")



func gallery() -> void:
	# Representative close-up shots for judging visuals (normal lighting, zoom 1).
	var p: CharacterBody2D = main.get_node("Player")
	await tap(KEY_L)
	await _build_chain()
	await tap(KEY_L)
	zoom(1.0)
	p.global_position = tile_center(Vector2i(76, 26)) + Vector2(-40, -60)
	await wait(4.0)
	await shot("gallery_loop")
	p.global_position = Vector2(1330, 60)
	await wait(1.5)
	await shot("gallery_surface_idle")
	await tap(KEY_P)
	await wait(9.0)
	await shot("gallery_wave_arrives")
	var m := InputEventMouseMotion.new()
	m.position = world_to_screen(Vector2(1600, 60))
	Input.parse_input_event(m)
	root.warp_mouse(m.position)
	key(KEY_F, true)
	await wait(0.05)
	await shot("gallery_shotgun")
	key(KEY_F, false)
	await wait(3.0)
	await shot("gallery_combat")
	# mining underground
	p.global_position = Vector2(800, 380)
	await wait(1.0)
	key(KEY_J, true)
	Input.action_press("move_right")
	await wait(0.6)
	await shot("gallery_mining")
	Input.action_release("move_right")
	key(KEY_J, false)


func fx() -> void:
	# Freeze-frames of the one-shot effects.
	var p: CharacterBody2D = main.get_node("Player")
	main._wave_timer = -9999.0
	await tap(KEY_L)
	zoom(2.0)
	# mining debris
	p.global_position = Vector2(700, 70)
	await wait(1.0)
	key(KEY_S, true); key(KEY_J, true)
	await wait(0.08)
	await shot("fx_mining")
	key(KEY_J, false); key(KEY_S, false)
	# enemy death burst
	p.global_position = Vector2(1500, 70)
	await wait(0.8)
	var g := _spawn(2, Vector2(1560, 40))
	g.speed = 0.0
	await wait(0.8)
	g.take_damage(100)
	await wait(0.08)
	await shot("fx_death")
	# titan death
	var t := _spawn(0, Vector2(1580, 40))
	t.speed = 0.0
	await wait(0.8)
	t.take_damage(100)
	await wait(0.1)
	await shot("fx_titan_death")
	# hot ingots in the loop
	await tap(KEY_L)
	await _build_chain()
	zoom(1.5)
	p.global_position = tile_center(Vector2i(76, 26)) + Vector2(-50, -80)
	await wait(3.0)
	await shot("fx_hot_ingots")
	p.global_position = Vector2(1250, 60)
	await wait(2.0)
	await shot("fx_receiver")


func titan() -> void:
	# A titan walks in, reaches the dome and chops. Burst-captures frames.
	var p: CharacterBody2D = main.get_node("Player")
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)  # let it live
	p.global_position = Vector2(1200, 150)
	zoom(2.0)
	var t := _spawn(0, Vector2(1420, 40))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	# frame the dome's right side
	cam.top_level = true
	cam.global_position = Vector2(1300, 30)
	cam.reset_smoothing()
	await wait(1.2)
	for i in 8:
		await shot("titan_walk_%d" % i)
		await wait(0.12)
	var hp0: int = main.dome_hp
	var chops := 0
	var dome_log := []
	while chops < 2 and is_instance_valid(t):
		await wait(0.05)
		var anim: AnimatedSprite2D = t.get_node("AnimatedSprite2D")
		if anim.animation == "attack" and anim.is_playing():
			chops += 1
			for f in 9:
				await shot("titan_chop%d_f%d" % [chops, anim.frame])
				await wait(0.085)
			dome_log.append(main.dome_hp)
			await wait(0.3)
	log_line("titan at x=%.0f  dome %d -> %s after %d chops" % [t.global_position.x, hp0, dome_log, chops])
	# chop the player too
	p.global_position = Vector2(t.global_position.x - 40, 60)
	var php: int = p.hp
	await wait(2.5)
	log_line("player next to titan: hp %d -> %d" % [php, p.hp])


func titan_vs_player() -> void:
	# Recording: a titan walks up to the player on open ground and chops twice.
	# Camera tracks the midpoint of the two; frames go to tools/art/frames_to_gif.py.
	var p: CharacterBody2D = main.get_node("Player")
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	p.global_position = Vector2(1720, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	await wait(1.0)
	var t := _spawn(0, Vector2(1805, 76))
	await wait(0.25)  # settle onto the ground before recording
	var chops := 0
	var was_attacking := false
	var tail := -1
	var i := 0
	while i < 160 and tail != 0:
		var mid: float = (p.global_position.x + t.global_position.x) / 2.0 + 10
		cam.global_position = Vector2(mid, 38)
		await process_frame
		await _grab(Rect2(Vector2(mid - 170, -44), Vector2(340, 150)), "rec_%03d" % i, -2)
		var anim: AnimatedSprite2D = t.get_node("AnimatedSprite2D")
		var attacking := anim.animation == "attack" or anim.animation == "sweep"
		if was_attacking and not attacking:
			chops += 1
			if chops == 2:
				tail = 10  # a beat after the second chop
		was_attacking = attacking
		if tail > 0:
			tail -= 1
		await wait(0.08)
		i += 1
	log_line("recorded %d frames, %d chops; player hp=%d" % [i, chops, p.hp])


## Crop a world-space rect out of the frame and downscale it by `div`.
func _grab(region: Rect2, label: String, div: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ts := Engine.time_scale
	Engine.time_scale = 0.0
	await process_frame
	RenderingServer.force_draw(false)
	var img := root.get_texture().get_image()
	var k := float(img.get_width()) / root.get_visible_rect().size.x  # physical px per logical px
	var a := world_to_screen(region.position) * k
	var b := world_to_screen(region.end) * k
	var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
	# div > 0: shrink by that factor; div < 0: output -div px per world px
	# (independent of window size / HiDPI)
	if div > 0:
		crop.resize(crop.get_width() / div, crop.get_height() / div, Image.INTERPOLATE_NEAREST)
	else:
		crop.resize(int(region.size.x) * -div, int(region.size.y) * -div, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/%s.png" % [out_dir, label])
	Engine.time_scale = ts


func titan_death() -> void:
	# Recording: titan chops at the player, gets shot down, collapses.
	var p: CharacterBody2D = main.get_node("Player")
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	p.global_position = Vector2(1700, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1760, 38)
	await wait(1.0)
	var t := _spawn(0, Vector2(1800, 76))
	await wait(0.25)
	var region := Rect2(Vector2(1590, -44), Vector2(340, 150))
	var killed := false
	for i in 95:
		await _grab(region, "death_%03d" % i, 4)
		# shotgun blast every so often, aimed at the titan's chest
		if i % 9 == 4 and is_instance_valid(t) and not t._dying:
			var m := InputEventMouseMotion.new()
			m.position = world_to_screen(t.global_position + Vector2(0, -40))
			Input.parse_input_event(m)
			root.warp_mouse(m.position)
			key(KEY_F, true)
		else:
			key(KEY_F, false)
		if i == 40 and is_instance_valid(t):
			t.take_damage(100)  # finish it so the recording shows the collapse
			killed = true
		await wait(0.08)
	log_line("titan_death recorded; killed=%s" % killed)


func parade() -> void:
	# Recording: a titan and scuttlers walk in along the surface.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1560, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1700, 38)
	await wait(0.8)
	_spawn(1, Vector2(1880, 76))
	_spawn(1, Vector2(1930, 76))
	_spawn(0, Vector2(1870, 76))
	await wait(0.3)
	for i in 60:
		await _grab(Rect2(Vector2(1540, -44), Vector2(340, 150)), "parade_%03d" % i, 4)
		await wait(0.08)


func caster() -> void:
	# Recording: a tesla caster hovers in, stops at range and shoots the player.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1560, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1720, 40)
	await wait(0.8)
	var c := _spawn(3, Vector2(1905, 76))
	await wait(0.3)
	var hp0: int = p.hp
	for i in 80:
		await _grab(Rect2(Vector2(1540, -24), Vector2(360, 128)), "caster_%03d" % i, 3)
		await wait(0.08)
	log_line("caster: player hp %d -> %d" % [hp0, p.hp])


func soldier() -> void:
	# Recording: two clockwork soldiers advance on the player and thrust.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1640, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	await wait(0.8)
	var s1 := _spawn(2, Vector2(1740, 76))
	_spawn(2, Vector2(1790, 76))
	await wait(0.3)
	var hp0: int = p.hp
	for i in 90:
		var mid: float = (p.global_position.x + s1.global_position.x) / 2.0 if is_instance_valid(s1) else 1700.0
		cam.global_position = Vector2(mid + 20, 40)
		await process_frame
		await _grab(Rect2(Vector2(mid - 130, -20), Vector2(300, 124)), "soldier_%03d" % i, 3)
		await wait(0.08)
	log_line("soldier: player hp %d -> %d" % [hp0, p.hp])


func loop_rec() -> void:
	# Recording: the whole ore loop in one tall shot — miner, laser, both
	# trampolines, receiver.
	main._wave_timer = -9999.0
	await _build_chain()
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1100, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(1.5, 1.5)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1224, 245)
	await wait(2.0)
	for i in 70:
		await _grab(Rect2(Vector2(1124, 30), Vector2(200, 420)), "loop_%03d" % i, -2)
		await wait(0.06)


func dome_rec() -> void:
	# Recording: the dome cannon swivelling onto an incoming wave.
	var p: CharacterBody2D = main.get_node("Player")
	main._wave_timer = -9999.0
	await _build_chain()
	p.global_position = Vector2(1100, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1300, 40)
	await wait(4.0)  # let some ammo arrive
	_spawn(1, Vector2(1560, 76))
	_spawn(1, Vector2(1600, 76))
	_spawn(2, Vector2(1640, 76))
	for i in 90:
		await _grab(Rect2(Vector2(1100, -40), Vector2(420, 150)), "dome_%03d" % i, -2)
		await wait(0.08)


func hud() -> void:
	await wait(1.0)
	await tap(KEY_1)
	await shot("hud")
	await tap(KEY_Q)
	main.damage_dome(35)
	main.get_node("Player").take_damage(40)
	await wait(0.5)
	await shot("hud_damaged")


func mining_rec() -> void:
	# Recording: the prospector tunnels right, then left, from a pocket in
	# solid dirt.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	var tm := tilemap()
	var shading := get_nodes_in_group("tile_shading")[0]
	for x in range(38, 42):
		for y in range(17, 20):
			tm.set_cell(Vector2i(x, y), -1)
			shading.mark_dirty(Vector2i(x, y))
	p.global_position = tile_center(Vector2i(40, 18)) + Vector2(0, -2)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	await wait(1.0)
	var i := 0
	for step in ["move_right", "move_left"]:
		Input.action_press(step)
		key(KEY_J, true)
		for k in 34:
			await _grab(Rect2(p.global_position + Vector2(-80, -45), Vector2(160, 80)), "mine_%03d" % i, -3)
			await wait(0.05)
			i += 1
		key(KEY_J, false)
		Input.action_release(step)


func deaths_rec() -> void:
	# Recording: one of each small enemy is destroyed, then a titan.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1500, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1660, 40)
	await wait(0.6)
	var foes := [_spawn(1, Vector2(1600, 76)), _spawn(2, Vector2(1650, 76)), _spawn(3, Vector2(1700, 76)), _spawn(0, Vector2(1770, 76))]
	for f in foes:
		f.speed = 0.0
	await wait(0.4)
	var i := 0
	for k in 4:
		foes[k].take_damage(100)
		for j in (14 if k == 0 else 32 if k < 3 else 40):
			await _grab(Rect2(Vector2(1540, -30), Vector2(260, 130)), "death_%03d" % i, -3)
			await wait(0.06)
			i += 1


func pounce_rec() -> void:
	# Recording: two scuttlers leap onto the dome and burst.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1000, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1300, 40)
	await wait(0.6)
	_spawn(1, Vector2(1400, 76))
	_spawn(1, Vector2(1470, 76))
	for i in 60:
		await _grab(Rect2(Vector2(1150, -20), Vector2(300, 120)), "pounce_%03d" % i, -3)
		await wait(0.05)


func player_death_rec() -> void:
	# Recording: a titan closes in; the prospector takes a hit, then a fatal one.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1500, 60)
	p.hp = 18
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1520, 40)
	await wait(0.5)
	var t: Node2D = _spawn(0, Vector2(1600, 76))
	t.speed = 0.0
	for i in 70:
		if i == 8:
			p.take_damage(5)
			p.launch(Vector2(-120, -120))
		if i == 24:
			p.take_damage(999)
			p.launch(Vector2(-160, -200))
		await _grab(Rect2(Vector2(1380, -40), Vector2(280, 130)), "pd_%03d" % i, -3)
		await wait(0.05)
	await shot("player_game_over")


func stomp_rec() -> void:
	# Recording: the prospector keeps just out of axe reach; the titan stomps.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1480, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1560, 30)
	await wait(0.5)
	var t: Node2D = _spawn(0, Vector2(1590, 76))
	t._stomp_cooldown = 0.6
	t.speed = 0.0
	for i in 60:
		await _grab(Rect2(Vector2(1420, -30), Vector2(290, 130)), "st_%03d" % i, -3)
		await wait(0.05)


func skyline() -> void:
	# Screenshots of the backdrop from the surface at a few zooms and positions.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1300, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	for spec in [[Vector2(1200, -20), 2.0, "sky_z2"], [Vector2(1200, -60), 1.0, "sky_z1"],
			[Vector2(1700, -20), 2.0, "sky_z2_east"], [Vector2(1200, -60), 0.5, "sky_z05"]]:
		cam.global_position = spec[0]
		cam.zoom = Vector2(spec[1], spec[1])
		await wait(0.4)
		await shot(spec[2])


func shaft_rec() -> void:
	# Recording: an upstream shaft in a dug pit carries ore up to the surface.
	main._wave_timer = -9999.0
	var tm := tilemap()
	var shading := get_nodes_in_group("tile_shading")[0]
	for x in range(100, 103):
		for y in range(6, 14):
			tm.set_cell(Vector2i(x, y), -1)
			shading.mark_dirty(Vector2i(x, y))
	var shaft: Node2D = preload("res://scenes/upstream_shaft.tscn").instantiate()
	shaft.global_position = Vector2(1624, 96 + 60)
	main.add_child(shaft)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1560, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1624, 150)
	await wait(0.5)
	for i in 48:
		if i % 8 == 0 and i < 32:
			var ore: Node2D = preload("res://scenes/ore.tscn").instantiate()
			ore.global_position = Vector2(1616 + (i / 8) % 2 * 16, 206)
			main.add_child(ore)
		await _grab(Rect2(Vector2(1550, 70), Vector2(150, 150)), "sh_%03d" % i, -3)
		await wait(0.05)


func gun_rec() -> void:
	# Recording: the prospector fires the blunderbuss at scuttlers, both ways.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1560, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1560, 40)
	await wait(0.5)
	for x in [1640, 1480]:
		var e: Node2D = _spawn(1, Vector2(x, 76))
		e.speed = 0.0
	var gun: Node2D = p.get_node("Shotgun")
	for i in 44:
		# aim right for the first half, then left (the gun reads the mouse)
		var aim := Vector2(1700 if i < 22 else 1420, 70)
		get_root().warp_mouse(main.get_viewport().get_canvas_transform() * aim)
		if i % 11 == 2:
			gun._timer = 0.0
			gun._fire((aim - gun.global_position).normalized())
		await _grab(Rect2(Vector2(1440, 0), Vector2(240, 100)), "gun_%03d" % i, -3)
		await wait(0.03)


func tramp_rec() -> void:
	# Recording: ore dropped onto two trampolines, one flat, one tilted.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1000, 60)
	var t1: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t1.global_position = Vector2(1560, 80)
	main.add_child(t1)
	var t2: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t2.global_position = Vector2(1660, 80)
	t2.bounce_angle = -35.0
	t2.bounce_force = 520.0
	main.add_child(t2)
	t2._update_visuals()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1610, 20)
	await wait(0.5)
	for i in 60:
		if i % 15 == 0:
			for x in [1560, 1660]:
				var ore: Node2D = preload("res://scenes/ore.tscn").instantiate()
				ore.global_position = Vector2(x, -40)
				main.add_child(ore)
		await _grab(Rect2(Vector2(1500, -70), Vector2(220, 170)), "tr_%03d" % i, -3)
		await wait(0.03)


func caves() -> void:
	# Screenshots of the three nearest dressed caves, lights on as in play.
	main._wave_timer = -9999.0
	var decor: Node2D = main.get_node("CaveDecor")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(2.5, 2.5)
	cam.position_smoothing_enabled = false
	log_line("cave decor pieces: %d" % decor.get_child_count())
	var seen := []
	var lit := decor.get_children().filter(func(c): return c.get_child_count() > 0)  # crystals first
	for spr in lit + decor.get_children():
		var pos: Vector2 = spr.global_position
		var far := true
		for q in seen:
			if q.distance_to(pos) < 260:
				far = false
		if far:
			seen.append(pos)
		if seen.size() >= 3:
			break
	for k in seen.size():
		# the prospector stands a little way off, lamp on, as when exploring
		main.get_node("Player").global_position = seen[k] + Vector2(-60 if k == 0 else 0, -400 if k == 1 else 0)
		cam.global_position = seen[k] + Vector2(40, 0)
		await wait(0.4)
		await shot("cave_%d" % k)


func rig_rec() -> void:
	# Recording: close-up of the drill rig in the working chain.
	main._wave_timer = -9999.0
	await _build_chain()
	var rig: Node2D = null
	for b in root.get_node("BuildSystem")._placed_buildings:
		if b.has_method("_eject_ore"):
			rig = b
	if rig == null:
		log_line("no rig")
		return
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = rig.global_position + Vector2(-30, -60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(4, 4)
	cam.position_smoothing_enabled = false
	cam.global_position = rig.global_position + Vector2(0, -20)
	await wait(0.5)
	for i in 48:
		await _grab(Rect2(rig.global_position + Vector2(-40, -70), Vector2(80, 90)), "rig_%03d" % i, -4)
		await wait(0.03)


func light_check() -> void:
	# Stills where lights stack: soldiers + titan by the dome with the player
	# close, and the drill rig next to the laser. Compare across light changes.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	await _build_chain()
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	p.global_position = Vector2(1290, 60)
	for spec in [[2, Vector2(1330, 76)], [2, Vector2(1360, 76)], [0, Vector2(1420, 76)]]:
		var e: Node2D = _spawn(spec[0], spec[1])
		e.speed = 0.0
	cam.zoom = Vector2(3, 3)
	cam.global_position = Vector2(1330, 30)
	await wait(0.8)
	await shot("light_surface")
	for b in root.get_node("BuildSystem")._placed_buildings:
		if b.has_method("_eject_ore"):
			p.global_position = b.global_position + Vector2(-20, -40)
			cam.zoom = Vector2(4, 4)
			cam.global_position = b.global_position + Vector2(0, -20)
	await wait(0.6)
	await shot("light_rig")


func jump_rec() -> void:
	# Recording: the prospector hops right twice, then drops from high up.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1480, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1540, 10)
	await wait(0.6)
	Input.action_press("move_right")
	for i in 70:
		if i == 2 or i == 22:
			Input.action_press("jump")
		if i == 4 or i == 24:
			Input.action_release("jump")
		if i == 40:
			Input.action_release("move_right")
			p.global_position = Vector2(1560, -80)
			p.velocity = Vector2.ZERO
		await _grab(Rect2(Vector2(1440, -70), Vector2(200, 180)), "jp_%03d" % i, -3)
		await wait(0.03)


func smelt_rec() -> void:
	# Recording: close-up of the arc smelter as ore passes through.
	main._wave_timer = -9999.0
	await _build_chain()
	var laser: Node2D = null
	for b in root.get_node("BuildSystem")._placed_buildings:
		if b.has_method("_reroll_arc"):
			laser = b
	if laser == null:
		log_line("no laser")
		return
	main.get_node("Player").global_position = laser.global_position + Vector2(-60, -200)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = laser.global_position
	await wait(0.5)
	for i in 80:
		await _grab(Rect2(laser.global_position + Vector2(-100, -45), Vector2(200, 90)), "sm_%03d" % i, -3)
		await wait(0.02)


func flier_rec() -> void:
	# Recording: an ornithopter flies over the dome, bombs it, comes about.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1100, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1240, 10)
	await wait(0.5)
	var hp0: int = main.dome_hp
	var f: Node2D = _spawn(4, Vector2(1420, -40))
	for i in 110:
		await _grab(Rect2(Vector2(1060, -80), Vector2(380, 180)), "fl_%03d" % i, -2)
		await wait(0.04)
	log_line("flier: dome hp %d -> %d, flier alive=%s" % [hp0, main.dome_hp, is_instance_valid(f)])


func wave3_check() -> void:
	# Force waves 1-3 quickly and report the roster, to catch spawn errors.
	main._wave_timer = -9999.0
	for w in 3:
		await tap(KEY_P)
		await wait(0.5)
	var counts := {}
	for e in get_nodes_in_group("enemies"):
		counts[e.enemy_type] = counts.get(e.enemy_type, 0) + 1
	log_line("after 3 waves: %s (4 = ornithopter)" % [counts])
	await wait(4.0)
	await shot("wave3")


func flier_crash_rec() -> void:
	# Recording: an ornithopter is shot down and crashes.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	main.get_node("Player").global_position = Vector2(1100, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1560, 10)
	await wait(0.5)
	var f: Node2D = _spawn(4, Vector2(1680, -30))
	for i in 60:
		if i == 12 and is_instance_valid(f):
			f.take_damage(99)
		await _grab(Rect2(Vector2(1440, -80), Vector2(240, 180)), "fc_%03d" % i, -3)
		await wait(0.03)


func title() -> void:
	# The title card (normally skipped under the harness): shot, key, shot.
	main._show_title()
	await wait(1.0)
	await shot("title")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(0.8)
	log_line("paused after key: %s" % paused)
	await shot("after_title")


func hit_rec() -> void:
	# Recording: the prospector blasts a titan and a soldier; hit feedback.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1500, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1590, 20)
	await wait(0.5)
	var t: Node2D = _spawn(0, Vector2(1660, 76))
	var s: Node2D = _spawn(2, Vector2(1600, 76))
	t.speed = 0.0
	s.speed = 0.0
	t.hp = 999
	s.hp = 999
	var gun: Node2D = p.get_node("Shotgun")
	for i in 50:
		var aim := Vector2(1700, 40)
		get_root().warp_mouse(main.get_viewport().get_canvas_transform() * aim)
		if i % 8 == 2:
			gun._timer = 0.0
			gun._fire((aim - gun.global_position).normalized())
		await _grab(Rect2(Vector2(1470, -50), Vector2(240, 140)), "hit_%03d" % i, -3)
		await wait(0.02)


func bounce_lab() -> void:
	# Trampoline physics checks (numbers in the log) + a recording.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1300, 60)
	var mk := func(pos: Vector2, ang := 0.0) -> Node2D:
		var t: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
		t.global_position = pos
		t.bounce_angle = ang
		main.add_child(t)
		t._update_visuals()
		return t
	# A: vertical stack, ore shot up from below
	for y in [40, 0, -40]:
		mk.call(Vector2(1500, y))
	var ore: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	ore.global_position = Vector2(1500, 70)
	main.add_child(ore)
	ore.linear_velocity = Vector2(0, -500)
	var top_y := 99999.0
	for i in 60:
		await physics_frame
		top_y = minf(top_y, ore.global_position.y)
	log_line("A stack, shot up at 500 from y70: apex y=%.0f (free flight apex ~ %.0f)" % [top_y, 70 - 500 * 500 / (2 * 980.0)])
	# B: drops onto a flat and a 30-degree trampoline from 120px up
	var flat: Node2D = mk.call(Vector2(1650, 60))
	var tilt: Node2D = mk.call(Vector2(1750, 60), 30.0)
	for t in [flat, tilt]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = t.global_position + Vector2(0, -120)
		main.add_child(o)
		var hit_v := Vector2.ZERO
		var peak := 99999.0
		for i in 90:
			var before := o.linear_velocity
			await physics_frame
			if before.y > 0 and o.linear_velocity.y < 0 and hit_v == Vector2.ZERO:
				hit_v = before
				log_line("B angle %d: in %s -> out %s" % [t.bounce_angle, before.round(), o.linear_velocity.round()])
			if hit_v != Vector2.ZERO:
				peak = minf(peak, o.global_position.y)
		log_line("B angle %d: dropped from %.0f above, rebound apex %.0f above the plate" % [t.bounce_angle, 120, t.global_position.y - peak])
	# C: player falls onto the flat one; then again holding S
	for hold in [false, true]:
		p.global_position = flat.global_position + Vector2(0, -110)
		p.velocity = Vector2.ZERO
		if hold:
			Input.action_press("ui_down")
		var up := false
		for i in 50:
			await physics_frame
			if p.velocity.y < -100:
				up = true
		if hold:
			Input.action_release("ui_down")
		log_line("C player falls on flat, holding S=%s -> bounced=%s" % [hold, up])


func ledges() -> void:
	# Full-bright overview of the underground (ironstone ledges) + a sound sampler.
	main._wave_timer = -9999.0
	main.get_node("CanvasModulate").color = Color(1, 1, 1)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.55, 0.55)
	cam.global_position = Vector2(1200, 560)
	await wait(0.5)
	await shot("underground")
	var sfx := preload("res://scripts/sfx.gd")
	var dir := out_dir + "/sfx"
	DirAccess.make_dir_recursive_absolute(dir)
	var sounds := {"mine_hit": sfx.sfx_mine_hit(), "clink": sfx.sfx_clink(), "shotgun": sfx.sfx_shotgun(),
		"bounce": sfx.sfx_bounce(), "laser": sfx.sfx_laser(), "enemy_hit": sfx.sfx_enemy_hit(),
		"enemy_die": sfx.sfx_enemy_die(), "turret_fire": sfx.sfx_turret_fire(), "ammo_received": sfx.sfx_ammo_received()}
	for n in sounds:
		sounds[n].save_to_wav(dir + "/" + n + ".wav")
	sfx.sfx_mine_break(0).save_to_wav(dir + "/mine_break_dirt.wav")
	sfx.sfx_mine_break(1).save_to_wav(dir + "/mine_break_stone.wav")
	log_line("wrote sounds to " + dir)


func tapper_rec() -> void:
	# Vein tapper: bolt onto a vein, aim, record some shots, then drain it fast.
	main._wave_timer = -9999.0
	main.get_node("CanvasModulate").color = Color(0.55, 0.55, 0.6)
	var tm := tilemap()
	var shading := get_nodes_in_group("tile_shading")[0]
	var target := Vector2i(-1, -1)
	for y in range(9, 40):
		for x in range(50, 100):
			var c := Vector2i(x, y)
			if tm.get_cell_source_id(c) != -1 and tm.get_cell_atlas_coords(c).x in [2, 3]:
				target = c
				break
		if target.x >= 0:
			break
	log_line("vein block at %s" % target)
	for dx in range(-3, 4):
		for dy in range(1, 6):
			var c := target + Vector2i(dx, -dy)
			tm.set_cell(c, -1)
			shading.mark_dirty(c)
	var m: Node2D = preload("res://scenes/miner.tscn").instantiate()
	m.global_position = tm.to_global(tm.map_to_local(target))
	m.eject_angle = 35.0
	m.eject_force = 330.0
	main.add_child(m)
	await wait(0.2)
	log_line("tapper vein: %d blocks, %d ore" % [m._cells.size(), m._ore_remaining()])
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = m.global_position + Vector2(-40, -10)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(3.5, 3.5)
	cam.position_smoothing_enabled = false
	cam.global_position = m.global_position + Vector2(10, -30)
	m._set_selected(true)
	await wait(0.3)
	await shot("tapper_selected")
	m._set_selected(false)
	for i in 50:
		await _grab(Rect2(m.global_position + Vector2(-90, -100), Vector2(180, 130)), "tap_%03d" % i, -4)
		await wait(0.04)
	m.eject_interval = 0.05
	var t := 0.0
	while not m._depleted and t < 20.0:
		await wait(0.2)
		t += 0.2
	var ore_left := 0
	for c in m._cells:
		if tm.get_cell_atlas_coords(c).x in [2, 3]:
			ore_left += 1
	log_line("after draining: depleted=%s, ore blocks still ore=%d of %d" % [m._depleted, ore_left, m._cells.size()])
	await shot("tapper_depleted")


func trap_rec() -> void:
	# Hopper + plate on the path, spiked pit beyond; a soldier walks into both.
	main._wave_timer = -9999.0
	main.get_node("Turret").set_physics_process(false)
	main.get_node("CanvasModulate").color = Color(0.5, 0.5, 0.58)
	var tm := tilemap()
	var shading := get_nodes_in_group("tile_shading")[0]
	for x in range(94, 98):          # pit: 4 wide, 3 deep, just west of the plate
		for y in range(6, 9):
			tm.set_cell(Vector2i(x, y), -1)
			shading.mark_dirty(Vector2i(x, y))
	var sp: Node2D = preload("res://scenes/spikes.tscn").instantiate()
	sp.global_position = tm.to_global(tm.map_to_local(Vector2i(95, 8)))
	main.add_child(sp)
	var sp2: Node2D = preload("res://scenes/spikes.tscn").instantiate()
	sp2.global_position = tm.to_global(tm.map_to_local(Vector2i(96, 8)))
	main.add_child(sp2)
	var hop: Node2D = preload("res://scenes/hopper.tscn").instantiate()
	hop.global_position = Vector2(1680, 22)
	hop.plate_offset_x = 0.0  # the hopper's own plate, placed right under it below
	main.add_child(hop)
	hop.plate_offset_x = 16.0
	hop._place_plate()
	var plate := hop
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1300, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(2.6, 2.6)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1650, 30)
	for k in 6:  # load the hopper
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1676 + (k % 2) * 8, -80 - k * 14)
		main.add_child(o)
	await wait(2.5)
	log_line("hopper holds %d ore, plate at %s" % [hop.stored_count(), hop._plate.global_position])
	var s: Node2D = _spawn(2, Vector2(1790, 76))
	s.hp = 40
	var i := 0
	var dumped_at := -1
	var min_y := 0.0
	while i < 120 and is_instance_valid(s):
		if dumped_at < 0 and hop._open:
			dumped_at = i
			log_line("dump at frame %d, soldier hp %d" % [i, s.hp])
		await _grab(Rect2(Vector2(1500, -40), Vector2(300, 150)), "trap_%03d" % i, -3)
		await wait(0.05)
		min_y = maxf(min_y, s.global_position.y)
		if i % 10 == 0:
			log_line("  f%d soldier %s floor=%s wall=%s" % [i, s.global_position.round(), s.is_on_floor(), s.is_on_wall()])
		i += 1
	for k in 16:
		if not is_instance_valid(s):
			break
		await wait(0.5)
		log_line("  +%.1fs soldier %s wall=%s hp %d" % [k * 0.5, s.global_position.round(), s.is_on_wall(), s.hp])
	if is_instance_valid(s):
		log_line("soldier end: hp %d, x %.0f, deepest y %.0f (surface 96), climbed out=%s" % [s.hp, s.global_position.x, min_y, s.global_position.y < 100 and s.global_position.x < 1500])
	else:
		log_line("soldier destroyed")


func turret_rec() -> void:
	# Funnel turret loaded with ore vs a soldier (clear line of fire); then a
	# hopper with its own plate further right, on the soldier's path.
	main._wave_timer = -9999.0
	var t: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	t.global_position = Vector2(1480, 40)
	main.add_child(t)
	var hop: Node2D = preload("res://scenes/hopper.tscn").instantiate()
	hop.global_position = Vector2(1840, 22)
	main.add_child(hop)
	for k in 5:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1480, -90 - k * 20)
		main.add_child(o)
	for k in 4:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1840, -90 - k * 20)
		main.add_child(o)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1300, 60)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.zoom = Vector2(2.0, 2.0)
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1680, 10)
	await wait(2.5)
	log_line("turret loaded %d, hopper holds %d, plate at %s" % [t._loaded().size(), hop.stored_count(), hop._plate.global_position])
	var s: Node2D = _spawn(2, Vector2(1960, 76))
	s.hp = 60
	var hp0: int = s.hp
	var dumped := false
	for i in 150:
		await _grab(Rect2(Vector2(1440, -100), Vector2(540, 210)), "tur_%03d" % i, -2)
		await wait(0.04)
		if not is_instance_valid(s):
			log_line("soldier destroyed at frame %d" % i)
			break
		if hop._open and not dumped:
			dumped = true
			log_line("hopper dumped at frame %d, soldier x %.0f hp %d" % [i, s.global_position.x, s.hp])
		if i % 15 == 0:
			log_line("  f%d soldier x %.0f y %.0f hp %d | plate overlaps %s | turret ammo %d" % [i, s.global_position.x, s.global_position.y, s.hp, hop._plate_area.get_overlapping_bodies().size(), t._loaded().size()])
	if is_instance_valid(s):
		log_line("soldier hp %d -> %d, x %.0f; turret still loaded %d" % [hp0, s.hp, s.global_position.x, t._loaded().size()])


func showcase() -> void:
	# The sandbox starting layout on the regenerated world: stills + counts.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main.get_node("Turret").set_physics_process(false)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.1, 1.1)
	cam.global_position = Vector2(1250, 0)
	var rx: Node = main.get_node("Receiver")
	var in0: int = rx.buffer
	await wait(9.0)
	await shot("showcase_wide")
	var turret: Node2D = null
	var turrets := []
	var lift: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.has_method("_loaded"):
			turret = n
			turrets.append(n)
		if "passed" in n:
			log_line("splitter sent left/right %s" % [n.passed])
		if "lift_speed" in n:
			lift = n
	var hop: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.has_method("dump"):
			hop = n
	log_line("after 9s: ingots in dome %d -> %d, turret loaded %d, lift holding %d, hopper holds %d" % [in0, rx.buffer, turret._loaded().size() if turret else -1, lift._held_items.size() if lift else -1, hop.stored_count() if hop else -1])
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1060, 10)
	await wait(0.3)
	await shot("showcase_west")
	cam.global_position = Vector2(1480, 10)
	await wait(0.3)
	await shot("showcase_east")
	for t in turrets:
		log_line("turret at %s loaded %d" % [t.global_position, t._loaded().size()])
	cam.global_position = Vector2(1710, -20)
	await wait(0.3)
	await shot("showcase_split")


func stack_check() -> void:
	# Ore dropped into a hopper and a turret should stack, not overlap.
	main._wave_timer = -9999.0
	var hop: Node2D = preload("res://scenes/hopper.tscn").instantiate()
	hop.global_position = Vector2(1500, 22)
	main.add_child(hop)
	var tur: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	tur.global_position = Vector2(1620, 40)
	main.add_child(tur)
	for k in 9:
		for x in [1500, 1620]:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.global_position = Vector2(x + (k % 3 - 1) * 6, -120 - k * 22)
			main.add_child(o)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.4, 3.4)
	cam.global_position = Vector2(1560, 0)
	await wait(4.0)
	var ys := []
	for b in hop._store.get_overlapping_bodies():
		ys.append(int(b.global_position.y))
	ys.sort()
	log_line("hopper holds %d, ore y: %s | turret loaded %d" % [ys.size(), ys, tur._loaded().size()])
	var frozen := 0
	var stored := 0
	for st in [hop._store, tur._store]:
		for b in st.get_overlapping_bodies():
			stored += 1
			if b.freeze:
				frozen += 1
	log_line("stored %d, frozen (costing nothing) %d; loose ore %d" % [stored, frozen, get_nodes_in_group("ore").size() - stored])
	await shot("stacked")


func pile_rec() -> void:
	# Close-up: ore trickling into a hopper and a turret, then the turret
	# firing through its load. For judging how piles look and behave.
	main._wave_timer = -9999.0
	var hop: Node2D = preload("res://scenes/hopper.tscn").instantiate()
	hop.global_position = Vector2(1500, 22)
	main.add_child(hop)
	var tur: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	tur.global_position = Vector2(1600, 40)
	main.add_child(tur)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(4.0, 4.0)
	cam.global_position = Vector2(1550, -10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var i := 0
	for k in 22:
		for x in [1500, 1600]:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.global_position = Vector2(x + rng.randf_range(-14, 14), -110)
			main.add_child(o)
			o.linear_velocity = Vector2(rng.randf_range(-40, 40), rng.randf_range(0, 120))
		for f in 3:
			await _grab(Rect2(Vector2(1440, -90), Vector2(220, 170)), "pile_%03d" % i, -4)
			await wait(0.05)
			i += 1
	for f in 20:
		await _grab(Rect2(Vector2(1440, -90), Vector2(220, 170)), "pile_%03d" % i, -4)
		await wait(0.05)
		i += 1
	var e: Node2D = _spawn(2, Vector2(1840, 76))
	e.hp = 999
	for f in 70:
		await _grab(Rect2(Vector2(1440, -90), Vector2(220, 170)), "pile_%03d" % i, -4)
		await wait(0.05)
		i += 1
	for b in tur._store.get_overlapping_bodies():
		log_line("  in turret: local %s v %s frozen %s contacts %d" % [tur.to_local(b.global_position).round(), b.linear_velocity.round(), b.freeze, b.get_contact_count()])
	var frozen_floating := 0
	for b in tur._store.get_overlapping_bodies():
		if b.freeze and b.get_contact_count() == 0:
			frozen_floating += 1
	log_line("turret stored %d (frozen with no contacts: %d), hopper %d" % [tur._store.get_overlapping_bodies().size(), frozen_floating, hop.stored_count()])


func catapult_rec() -> void:
	# Ore dropped into a catapult's bucket gets flung along its aim.
	main._wave_timer = -9999.0
	var c: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	c.global_position = Vector2(1520, 80)
	c.aim_angle = 35.0
	c.throw_speed = 480.0
	main.add_child(c)
	var c2: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	c2.global_position = Vector2(1700, 80)
	c2.aim_angle = -60.0   # throws back up-left
	c2.throw_speed = 420.0
	main.add_child(c2)
	await wait(0.3)
	log_line("catapult pivot %s, bucket at rest %s" % [c.global_position, c.to_global(c._catch.position)])
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1620, 0)
	c._set_selected(true)
	c2._set_selected(true)
	await wait(0.2)
	await shot("catapults_aim")
	c._set_selected(false)
	c2._set_selected(false)
	var thrown := []
	for k in 3:
		for cat in [c, c2]:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.global_position = cat.to_global(cat._catch.position) + Vector2(0, -60)
			main.add_child(o)
			thrown.append(o)
		for f in 20:
			await _grab(Rect2(Vector2(1400, -120), Vector2(440, 230)), "cat_%03d" % (k * 20 + f), -2)
			await wait(0.04)
	for o in thrown:
		if is_instance_valid(o):
			log_line("  ore at %s v %s" % [o.global_position.round(), o.linear_velocity.round()])


func tramp_aim() -> void:
	# Trampoline selected: handle + bounce arc; then real ore dropped from
	# 90px (arrives ~420px/s, the preview's assumption) to compare.
	main._wave_timer = -9999.0
	var t: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t.global_position = Vector2(1520, 40)
	t.bounce_angle = 25.0
	t.bounce_force = 700.0
	main.add_child(t)
	t._update_visuals()
	t.select()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1640, 0)
	await wait(0.3)
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = t.global_position + Vector2(0, -90)
	main.add_child(o)
	var trail := []
	for f in 90:
		await physics_frame
		if is_instance_valid(o):
			trail.append(o.global_position)
	await shot("tramp_aim")
	var land: Vector2 = trail[-1]
	log_line("real ore after 1.5s at %s (arc drawn from %s with v %s)" % [land.round(), t._arc.origin.round(), t._arc.velocity.round()])


func feed_rec() -> void:
	# The showcase's tapper -> catapult -> hopper feed, close up.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1430, 20)
	var cat: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if "throw_speed" in n:
			cat = n
	var seen := {}
	for f in 400:
		await physics_frame
		var b = cat.last_thrown
		if b and is_instance_valid(b):
			var id: int = b.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				log_line("thrown from %s v %s (aim %s)" % [b.global_position.round(), b.linear_velocity.round(), cat._aim_dir()])
			if f % 6 == 0:
				log_line("   ore %d at %s v %s" % [id % 1000, b.global_position.round(), b.linear_velocity.round()])


func carry_rec() -> void:
	# E picks up the nearest ore; holding shows the throw arc; E throws.
	main._wave_timer = -9999.0
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1480, 70)
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = Vector2(1492, 80)
	main.add_child(o)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1580, 20)
	await wait(0.6)
	await tap(KEY_E)
	await wait(0.2)
	log_line("carrying: %s" % [p._carried == o])
	var aim := Vector2(1560, -30)
	get_root().warp_mouse(main.get_viewport().get_canvas_transform() * aim)
	await wait(0.3)
	await shot("holding")
	var pred: Vector2 = p._throw_arc.velocity
	await tap(KEY_E)
	var t := 0.0
	while t < 2.0 and is_instance_valid(o) and not (o.linear_velocity.length() < 5 and t > 0.3):
		await physics_frame
		t += 1.0 / 60.0
	log_line("thrown with v %s; ore came to rest at %s" % [pred.round(), o.global_position.round()])
	await shot("thrown")


func banner() -> void:
	main._wave_timer = -9999.0
	await wait(0.8)
	await tap(KEY_P)
	await wait(0.6)
	await shot("banner")
	await wait(2.5)
	await shot("offscreen_marker")
	main.damage_dome(200)
	await wait(0.4)
	await shot("game_over")


func chute_rec() -> void:
	# Ore dropped onto a chute sticks, rolls down it and leaves the low end;
	# ore thrown up from underneath passes through (one-way).
	main._wave_timer = -9999.0
	var c: Node2D = preload("res://scenes/chute.tscn").instantiate()
	c.global_position = Vector2(1480, -30)
	c.end_offset = Vector2(130, 52)
	main.add_child(c)
	var c2: Node2D = preload("res://scenes/chute.tscn").instantiate()
	c2.global_position = Vector2(1720, 30)
	c2.end_offset = Vector2(-70, 22)   # a switchback, drawn right to left
	main.add_child(c2)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1600, 10)
	c2._set_selected(true)
	await wait(0.3)
	await shot("chutes")
	c2._set_selected(false)
	var drops := []
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1492 + k * 14, -110 - k * 30)
		main.add_child(o)
		drops.append(o)
	var under: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	under.global_position = Vector2(1560, 70)
	under.linear_velocity = Vector2(0, -420)
	main.add_child(under)
	var under_top := 999.0
	var left_at := {}
	for f in 150:
		await physics_frame
		if is_instance_valid(under):
			under_top = minf(under_top, under.global_position.y)
		for o in drops:
			if is_instance_valid(o) and not left_at.has(o) and o.global_position.x > c.global_position.x + 130:
				left_at[o] = [f, o.global_position.round(), o.linear_velocity.round()]
		if f % 3 == 0 and f < 120:
			await _grab(Rect2(Vector2(1440, -140), Vector2(340, 240)), "chute_%03d" % (f / 3), -2)
	for o in drops:
		log_line("ore left low end: %s" % [left_at.get(o, "never")])
		if is_instance_valid(o):
			log_line("   now at %s" % [o.global_position.round()])
	log_line("ore thrown up from below reached y=%.0f (rail there y~%.0f)" % [under_top, c.global_position.y + 52 * 80 / 130.0])
	await shot("after")


func splitter_rec() -> void:
	# A stream of ore dropped on a splitter alternates left/right; locked
	# modes send everything one way.
	main._wave_timer = -9999.0
	var sp: Node2D = preload("res://scenes/splitter.tscn").instantiate()
	sp.global_position = Vector2(1560, 20)
	main.add_child(sp)
	var lk: Node2D = preload("res://scenes/splitter.tscn").instantiate()
	lk.global_position = Vector2(1680, 20)
	main.add_child(lk)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1620, 10)
	await wait(0.3)
	lk.set_mode(2)  # always right
	await wait(0.2)
	await shot("splitters")
	var ores := []
	for k in 6:
		for s in [sp, lk]:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.global_position = s.global_position + Vector2(randf_range(-3, 3), -90)
			main.add_child(o)
			ores.append([o, s])
		for f in 24:
			await physics_frame
			if f % 4 == 0:
				await _grab(Rect2(Vector2(1500, -80), Vector2(240, 180)), "split_%03d" % (k * 6 + f / 4), -2)
	await wait(1.0)
	log_line("alternating splitter sent left/right: %s" % [sp.passed])
	log_line("locked-right splitter sent left/right: %s" % [lk.passed])
	for pair in ores:
		if is_instance_valid(pair[0]):
			log_line("  %s ore rest dx %+.0f" % ["alt" if pair[1] == sp else "lck", pair[0].global_position.x - pair[1].global_position.x])
	await shot("after")


func probe() -> void:
	var tm := tilemap()
	for c in [Vector2i(84, 7), Vector2i(97, 7), Vector2i(103, 7), Vector2i(117, 6)]:
		log_line("cell %s -> %s" % [c, tm.to_global(tm.map_to_local(c))])


func showcase_wave() -> void:
	# Press P on the starting layout: do the defences hold?
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.3, 1.3)
	cam.global_position = Vector2(1640, -20)
	await wait(6.0)
	await tap(KEY_P)
	var dome0: float = main.dome_hp if "dome_hp" in main else -1.0
	for s in 30:
		await wait(1.0)
		var es := get_nodes_in_group("enemies")
		var desc := []
		for e in es:
			desc.append("%s@%d" % [e.get("enemy_type"), int(e.global_position.x)])
		var ammo := []
		for n in get_nodes_in_group("showcase"):
			if n.has_method("_loaded"):
				ammo.append("%d/%d" % [n._loaded().size(), n.shots])
		log_line("t=%2d enemies %d %s dome %s turrets ammo/shots %s" % [s + 1, es.size(), desc, main.get("dome_hp"), ammo])
		if s % 3 == 0:
			await shot("wave_%02d" % s)


func buildbar() -> void:
	# Tabs: click Production, click its Assembler slot; then press 7 (spikes)
	# and the bar flips to Defence.
	main._wave_timer = -9999.0
	await wait(0.5)
	await shot("bar")
	var bar: Control = null
	for c in main.get_node("CanvasLayer").get_children():
		if c.has_method("_slot_at"):
			bar = c
	var bs := get_root().get_node("BuildSystem")
	# clicks go straight to the bar (window scale varies between runs)
	for at in [bar._tab_rect(1).get_center(), bar._slot_rect(3).get_center()]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = at
		bar._gui_input(ev)
		await wait(0.15)
	log_line("clicked Production tab + 4th slot: tab %d, build=%d (16 = assembler), placed %d" % [bar._cat, bs.current_build, bs._placed_buildings.size()])
	await shot("bar_production")
	await tap(KEY_7)
	await wait(0.2)
	log_line("pressed 7: tab %d (%s), build=%d" % [bar._cat, bar.CATS[bar._cat][0], bs.current_build])
	await shot("bar_defence")
	for k in 2:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_DOWN
		w.pressed = true
		bar._unhandled_input(w)
	log_line("wheel down twice from spikes: build=%d (22 = electromagnet)" % bs.current_build)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	bar._unhandled_input(tab)
	log_line("Tab: tab %d (%s), build=%d (1 = trampoline)" % [bar._cat, bar.CATS[bar._cat][0], bs.current_build])
	await tap(KEY_Q)


func bumper_rec() -> void:
	# A bumper bats back a walking soldier, rebounds dropped ore and flings
	# the player.
	main._wave_timer = -9999.0
	var bm: Node2D = preload("res://scenes/bumper.tscn").instantiate()
	bm.global_position = Vector2(1560, 80)
	main.add_child(bm)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1580, 20)
	await wait(0.3)
	log_line("bumper stands at %s" % [bm.global_position])
	await shot("bumper")
	var e: CharacterBody2D = _spawn(2, Vector2(1640, 60))
	var hp0: int = e.hp
	var min_x := 9999.0
	var max_back := 0.0
	for f in 150:
		await physics_frame
		if not is_instance_valid(e):
			break
		min_x = minf(min_x, e.global_position.x)
		if min_x < 9999:
			max_back = maxf(max_back, e.global_position.x - min_x)
		if f % 5 == 0 and f < 90:
			await _grab(Rect2(Vector2(1500, -40), Vector2(200, 140)), "bump_%03d" % (f / 5), -2)
	log_line("soldier: closest x %.0f, knocked back up to %.0f px, hp %d -> %s, bumper hits %d" % [min_x, max_back, hp0, e.hp if is_instance_valid(e) else "dead", bm.hits])
	if is_instance_valid(e):
		e.queue_free()
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = bm.global_position + Vector2(4, -80)
	main.add_child(o)
	var top := 999.0
	for f in 60:
		await physics_frame
		top = minf(top, o.global_position.y)
		if f > 20 and o.global_position.y < top + 0.1:
			pass
	log_line("ore dropped from 80 px above: v now %s, pos %s (bounced back up to y %.0f after landing)" % [o.linear_velocity.round(), o.global_position.round(), top])
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1520, 70)
	await wait(0.3)
	await hold(KEY_D, 0.6)
	log_line("player after walking into it: %s v %s, bumper hits %d" % [p.global_position.round(), p.velocity.round(), bm.hits])


func pit_trap() -> void:
	# Showcase with the turrets off: do walkers end up in the pit, and does
	# the bumper on the lip keep them there?
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var bm: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.has_method("_loaded"):
			n.set_physics_process(false)
		if n.has_method("_on_touch"):
			bm = n
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1900, 30)
	var es := [_spawn(2, Vector2(2080, 40)), _spawn(0, Vector2(2130, 40)), _spawn(1, Vector2(2040, 40))]
	var names := ["soldier", "titan", "scuttler"]
	for s in 30:
		await wait(1.0)
		var parts := []
		for i in es.size():
			var e = es[i]
			parts.append("%s %s" % [names[i], ("x%d y%d hp%d" % [e.global_position.x, e.global_position.y, e.hp]) if is_instance_valid(e) else "dead"])
		log_line("t=%2d %s | bumper hits %d" % [s + 1, "; ".join(parts), bm.hits])
		if s % 4 == 1:
			await shot("pit_%02d" % s)


func god() -> void:
	# Sandbox god tools: G spawns the chosen enemy at the cursor, H cycles
	# the type, O drops ore (held: pours), K clears enemies.
	main._wave_timer = -9999.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1560, 0)
	await wait(0.3)
	var vp := main.get_viewport()
	get_root().warp_mouse(vp.get_canvas_transform() * Vector2(1600, 40))
	await wait(0.1)
	await tap(KEY_G)
	await tap(KEY_H)
	await tap(KEY_H)
	get_root().warp_mouse(vp.get_canvas_transform() * Vector2(1680, 40))
	await wait(0.1)
	await tap(KEY_G)
	var types := []
	for e in get_nodes_in_group("enemies"):
		types.append("%s@%d" % [e.enemy_type, int(e.global_position.x)])
	log_line("spawned: %s" % [types])
	get_root().warp_mouse(vp.get_canvas_transform() * Vector2(1520, -60))
	await wait(0.1)
	var ore0 := get_nodes_in_group("ore").size()
	await hold(KEY_O, 0.8)
	log_line("ore poured while holding O: %d" % [get_nodes_in_group("ore").size() - ore0])
	await wait(0.4)
	await shot("god")
	await tap(KEY_K)
	await wait(1.5)
	log_line("after K: enemies %d" % get_nodes_in_group("enemies").size())


func knock_rec() -> void:
	# Ore knocks: a single drop on dirt, one onto a chute, then a pour into a
	# turret funnel (the voice cap keeps a pour from becoming noise).
	var S = preload("res://scripts/sfx.gd")
	main._wave_timer = -9999.0
	var ch: Node2D = preload("res://scenes/chute.tscn").instantiate()
	ch.global_position = Vector2(1500, 0)
	main.add_child(ch)
	var tu: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	tu.global_position = Vector2(1700, 40)
	main.add_child(tu)
	await wait(0.3)
	for at in [Vector2(1450, -40), Vector2(1520, -80)]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = at
		main.add_child(o)
		await wait(1.0)
		log_line("drop at %s: knocks played %d" % [at, S.small_played])
	var p0: int = S.small_played
	for k in 20:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1700 + randf_range(-6, 6), -120)
		main.add_child(o)
		await wait(0.07)
	await wait(2.0)
	log_line("pour of 20 into the funnel: knocks played %d, skipped by the cap %d" % [S.small_played - p0, S.small_skipped])


func chute_draw() -> void:
	# Build mode 9: press at the top, drag, release at the end.
	main._wave_timer = -9999.0
	var bs := get_root().get_node("BuildSystem")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1580, 0)
	await wait(0.3)
	await tap(KEY_9)
	var xf := main.get_viewport().get_canvas_transform()
	var a: Vector2 = xf * Vector2(1500, -40)
	var b: Vector2 = xf * Vector2(1640, 20)
	for step in [[a, true], [a.lerp(b, 0.5), null], [b, null], [b, false]]:
		get_root().warp_mouse(step[0])
		await process_frame
		if step[1] != null:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = step[1]
			ev.position = step[0]
			ev.global_position = step[0]
			Input.parse_input_event(ev)
		await wait(0.15)
		if step[1] == null and step[0] == b:
			await shot("dragging")
	var placed = bs._placed_buildings.back() if not bs._placed_buildings.is_empty() else null
	log_line("placed %s at %s end %s" % [placed.name if placed else "nothing", placed.global_position.round() if placed else "", placed.end_offset.round() if placed else ""])
	await tap(KEY_Q)
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = Vector2(1512, -90)
	main.add_child(o)
	await wait(1.2)
	log_line("ore dropped on it now at %s" % [o.global_position.round()])
	await shot("placed")


func belt_rec() -> void:
	# Belts carry ore the way they were drawn: flat, and up a slope.
	main._wave_timer = -9999.0
	var specs := [[Vector2(1440, 40), Vector2(120, 0)], [Vector2(1600, 60), Vector2(140, -50)], [Vector2(1480, -60), Vector2(110, -60)]]
	var belts := []
	for sp in specs:
		var b: Node2D = preload("res://scenes/belt.tscn").instantiate()
		b.global_position = sp[0]
		b.end_offset = sp[1]
		main.add_child(b)
		belts.append(b)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1610, 0)
	await wait(0.3)
	var ores := []
	for b in belts:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = b.global_position + b.end_offset * 0.1 + Vector2(0, -30)
		main.add_child(o)
		ores.append(o)
	var reached := [-1, -1, -1]
	for f in 180:
		await physics_frame
		for i in 3:
			var o: RigidBody2D = ores[i]
			var b: Node2D = belts[i]
			if reached[i] < 0 and is_instance_valid(o) and (o.global_position - b.global_position).dot(b.run_dir()) > b.end_offset.length() - 4:
				reached[i] = f
		if f % 6 == 0 and f < 120:
			await _grab(Rect2(Vector2(1420, -110), Vector2(360, 220)), "belt_%03d" % (f / 6), -2)
	for i in 3:
		var slope := rad_to_deg(-belts[i].run_dir().angle())
		log_line("belt %d (%.0f deg up, %.0f px): ore reached the far end at frame %d; now %s" % [i, slope, belts[i].end_offset.length(), reached[i], ores[i].global_position.round() if is_instance_valid(ores[i]) else "gone"])
	await shot("belts")


func ray_probe() -> void:
	var b: Node2D = preload("res://scenes/belt.tscn").instantiate()
	b.global_position = Vector2(1480, -60)
	b.end_offset = Vector2(110, -60)
	main.add_child(b)
	for c in b.get_children():
		if c is Line2D:
			log_line("post %s" % [c.points])
	await wait(0.3)
	var space: PhysicsDirectSpaceState2D = main.get_world_2d().direct_space_state
	for x in [1590.0, 1500.0, 1300.0]:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, -118), Vector2(x, 102), 1)
		var hit: Dictionary = space.intersect_ray(q)
		log_line("ray at x=%d: %s" % [x, [hit.get("position"), hit.get("collider")] if not hit.is_empty() else "none"])


func save_load() -> void:
	# F5 on the showcase, trash the world, F9: same pieces, same settings,
	# and the chains run again.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	var bs := get_root().get_node("BuildSystem")
	await wait(0.2)
	sc.build(main)
	var ch: Node2D = preload("res://scenes/chute.tscn").instantiate()
	ch.global_position = Vector2(1000, -40)
	ch.end_offset = Vector2(-90, 30)
	main.add_child(ch)
	bs._placed_buildings.append(ch)
	await wait(1.0)
	var tiles0 := tilemap().get_used_cells().size()
	var n0: int = bs._placed_buildings.size()
	await tap(KEY_F5)
	await wait(0.3)
	log_line("saved: %d pieces, %d tiles" % [n0, tiles0])
	# wreck it: new random world, nothing built
	sc.clear(main)
	for b in bs._placed_buildings:
		if is_instance_valid(b):
			b.queue_free()
	bs._placed_buildings.clear()
	tilemap().clear()
	preload("res://scripts/world_gen.gd").generate(tilemap(), 99)
	await wait(0.5)
	log_line("wrecked: %d pieces, %d tiles" % [bs._placed_buildings.size(), tilemap().get_used_cells().size()])
	await tap(KEY_F9)
	await wait(0.5)
	var chute_end = null
	for b in bs._placed_buildings:
		if b.scene_file_path.ends_with("chute.tscn") and b.global_position.x < 1100:
			chute_end = b.end_offset
	log_line("loaded: %d pieces, %d tiles, test chute end %s" % [bs._placed_buildings.size(), tilemap().get_used_cells().size(), chute_end])
	var rx: Node = main.get_node("Receiver")
	var in0: int = rx.buffer
	await wait(9.0)
	var turrets := []
	var sp = null
	for b in bs._placed_buildings:
		if b.has_method("_loaded"):
			turrets.append(b._loaded().size())
		if "passed" in b:
			sp = b.passed
	log_line("after 9s: ingots %d -> %d, turrets loaded %s, splitter %s" % [in0, rx.buffer, turrets, sp])
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.1, 1.1)
	cam.global_position = Vector2(1300, 0)
	await wait(0.3)
	await shot("loaded")


func magpie_rec() -> void:
	# A magpie over the working showcase: does it find loose ore, grab it and
	# make off with it? Then with the turrets on: does a hit make it drop?
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var turrets := []
	for n in get_nodes_in_group("showcase"):
		if n.has_method("_loaded"):
			n.set_physics_process(false)
			turrets.append(n)
	await wait(3.0)
	var m: Node2D = preload("res://scenes/magpie.tscn").instantiate()
	m.global_position = Vector2(1900, -100)
	main.add_child(m)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	var grabbed_at := -1
	for f in 600:
		await physics_frame
		if not is_instance_valid(m):
			log_line("magpie left the map at frame %d" % f)
			break
		cam.global_position = m.global_position
		if grabbed_at < 0 and m._carried:
			grabbed_at = f
			log_line("grabbed ore at frame %d at %s" % [f, m.global_position.round()])
		if f % 60 == 0:
			log_line("  f%d state %d at %s v %s" % [f, m._state, m.global_position.round(), m.velocity.round()])
		if f % 5 == 0 and f < 300:
			await _grab(Rect2(m.global_position - Vector2(120, 80), Vector2(240, 160)), "mag_%03d" % (f / 5), -2)
	# second one, turrets live
	for t in turrets:
		t.set_physics_process(true)
	var m2: Node2D = preload("res://scenes/magpie.tscn").instantiate()
	m2.global_position = Vector2(1750, -100)
	main.add_child(m2)
	var drops := 0
	var was_carrying := false
	var last := ""
	var near := {}
	for f in 900:
		await physics_frame
		if not is_instance_valid(m2):
			log_line("second magpie gone at frame %d: %s" % [f, last])
			break
		last = "hp %d, state %d, stolen %d, x %d" % [m2.hp, m2._state, m2.stolen, m2.global_position.x]
		for o in get_nodes_in_group("ore"):
			if o.linear_velocity.length() > 250 and o.global_position.x > 1500:
				var d: float = o.global_position.distance_to(m2.global_position)
				var id: int = o.get_instance_id()
				near[id] = minf(near.get(id, 9999.0), d)
		if f % 30 == 0:
			var info := []
			for t in turrets:
				var tgt = t._nearest_enemy()
				info.append("shots %d ammo %d tgt %s sol %s" % [t.shots, t._loaded().size(), tgt != null, t._solve(tgt) if tgt else null])
			log_line("  f%d magpie %s | %s" % [f, m2.global_position.round(), info])
		cam.global_position = m2.global_position
		var c: bool = m2._carried != null
		if was_carrying and not c and m2._state != 1:
			drops += 1
		was_carrying = c
	var misses := []
	for k in near:
		if near[k] < 120:
			misses.append(int(near[k]))
	log_line("closest approach of fast ore to the magpie: %s" % [misses])
	log_line("with turrets: magpie %s, hp %s, dropped its load %d times, stole %s" % ["alive" if is_instance_valid(m2) else "gone", m2.hp if is_instance_valid(m2) else "-", drops, m2.stolen if is_instance_valid(m2) else "?"])


func shield_rec() -> void:
	# Ore at the shieldbearer's front glances off; from above or behind it hurts.
	main._wave_timer = -9999.0
	var e: CharacterBody2D = _spawn(5, Vector2(1680, 60))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	await wait(0.8)
	cam.global_position = e.global_position + Vector2(0, -30)
	await shot("walking")
	var tests := [["front", Vector2(-90, -20), Vector2(520, -40)], ["above", Vector2(0, -110), Vector2(0, 150)],
		["behind", Vector2(90, -20), Vector2(-520, -40)], ["front again", Vector2(-90, -24), Vector2(520, -60)]]
	for t in tests:
		var hp0: int = e.hp
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = e.global_position + t[1]
		o.linear_velocity = t[2]
		main.add_child(o)
		for f in 30:
			await physics_frame
			cam.global_position = e.global_position + Vector2(0, -30)
			if f == 9 or f == 12:
				await _grab(Rect2(e.global_position - Vector2(90, 80), Vector2(180, 100)), "shield_%s_%d" % [t[0].replace(" ", "_"), f], -3)
		log_line("%s: hp %d -> %d, ore now moving %s" % [t[0], hp0, e.hp, o.linear_velocity.round() if is_instance_valid(o) else "-"])
		await wait(0.4)


func shield_turret() -> void:
	# A shieldbearer walks at a turret: held fire while it faces it, shots in
	# the back once it has walked past.
	main._wave_timer = -9999.0
	var t: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	t.global_position = Vector2(1560, 40)
	main.add_child(t)
	await wait(0.3)
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = t.global_position + Vector2(0, -90 - k * 16)
		main.add_child(o)
	await wait(2.0)
	var e: CharacterBody2D = _spawn(5, Vector2(1800, 60))
	var passed_at := -1.0
	for s in 40:
		await wait(0.5)
		if not is_instance_valid(e):
			log_line("t=%.1f shieldbearer destroyed" % (s * 0.5))
			break
		if passed_at < 0 and e.global_position.x < t.global_position.x:
			passed_at = s * 0.5
		if s % 4 == 0:
			log_line("t=%.1f bearer x %d hp %d, turret shots %d ammo %d" % [s * 0.5, e.global_position.x, e.hp, t.shots, t._loaded().size()])
	log_line("walked past the turret at t=%s" % passed_at)


func bellows_rec() -> void:
	# A sideways fan carries dropped ore across; an updraft fan holds ore up;
	# a fan pushes a magpie off course.
	main._wave_timer = -9999.0
	var side: Node2D = preload("res://scenes/bellows.tscn").instantiate()
	side.global_position = Vector2(1440, 30)
	side.aim_angle = 90.0
	side.wind_speed = 360.0
	main.add_child(side)
	var up: Node2D = preload("res://scenes/bellows.tscn").instantiate()
	up.global_position = Vector2(1700, 70)
	up.aim_angle = 0.0
	up.wind_speed = 440.0
	main.add_child(up)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1580, -20)
	await wait(0.3)
	up._set_selected(true)
	var a: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	a.global_position = Vector2(1480, -60)   # falls through the sideways stream
	main.add_child(a)
	var b: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	b.global_position = Vector2(1702, -20)   # dropped into the updraft
	main.add_child(b)
	var b_ys := []
	for f in 180:
		await physics_frame
		if f % 30 == 0:
			b_ys.append(int(b.global_position.y))
		if f % 5 == 0 and f < 120:
			await _grab(Rect2(Vector2(1400, -170), Vector2(360, 280)), "fan_%03d" % (f / 5), -2)
	log_line("ore through the side stream: dropped at x 1480, now at %s" % [a.global_position.round()])
	log_line("ore in the updraft (fan at y 70): y every 0.5s %s" % [b_ys])
	await shot("fans")
	up._set_selected(false)
	# a magpie flying into a headwind
	var m: Node2D = preload("res://scenes/magpie.tscn").instantiate()
	m.global_position = Vector2(1650, -40)
	main.add_child(m)
	var fan: Node2D = preload("res://scenes/bellows.tscn").instantiate()
	fan.global_position = Vector2(1540, -40)
	fan.aim_angle = 90.0
	fan.wind_speed = 500.0
	main.add_child(fan)
	a.queue_free()
	b.queue_free()
	await wait(1.5)
	log_line("magpie seeking with a fan blowing at it: at %s v %s" % [m.global_position.round(), m.velocity.round()])


func pendulum_rec() -> void:
	# Ore thrown at a hanging ball sets it swinging; a big swing smashes a
	# soldier walking into it.
	main._wave_timer = -9999.0
	await wait(0.3)   # the harness's cleared showcase is gone by now
	var pd: Node2D = preload("res://scenes/pendulum.tscn").instantiate()
	pd.global_position = Vector2(1700, -40)
	main.add_child(pd)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1700, 20)
	await wait(0.3)
	log_line("chain length %.0f, ball rests at %s" % [pd.length, (pd.global_position + pd.ball_pos()).round()])
	await shot("hanging")
	var max_theta := 0.0
	for k in 5:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = pd.global_position + pd.ball_pos() + Vector2(-70, -6)
		o.linear_velocity = Vector2(480, -40)
		main.add_child(o)
		for f in 25:
			await physics_frame
			max_theta = maxf(max_theta, absf(pd.theta))
	log_line("after 5 ore hits: max swing %.0f deg, omega %.2f" % [rad_to_deg(max_theta), pd.omega])
	# big swing into a walking soldier
	pd.theta = deg_to_rad(-70)
	pd.omega = 0.0
	var e: CharacterBody2D = _spawn(2, Vector2(1760, 60))
	var hp0: int = e.hp
	for f in 120:
		await physics_frame
		if f % 4 == 0 and f < 80:
			await _grab(Rect2(Vector2(1560, -80), Vector2(300, 190)), "pend_%03d" % (f / 4), -2)
	log_line("soldier hp %d -> %s, pendulum smashes %d, soldier now at %s" % [hp0, e.hp if is_instance_valid(e) else "dead", pd.hits, e.global_position.round() if is_instance_valid(e) else "-"])


func iron_rec() -> void:
	# Copper vs iron side by side: trampoline, bumper, and a shieldbearer hit
	# from the front.
	main._wave_timer = -9999.0
	await wait(0.3)
	var t: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t.global_position = Vector2(1560, 60)
	t.bounce_angle = 0.0
	t.bounce_force = 700.0
	main.add_child(t)
	t._update_visuals()
	var peaks := {}
	for k in ["copper", "iron"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = t.global_position + Vector2(0, -80)
		main.add_child(o)
		var top := 999.0
		var bounced := false
		for f in 90:
			await physics_frame
			if o.linear_velocity.y < -50:
				bounced = true
			if bounced:
				top = minf(top, o.global_position.y)
		peaks[k] = t.global_position.y - top
		o.queue_free()
	log_line("trampoline rebound height: copper %.0f px, iron %.0f px (mass %.0f)" % [peaks.copper, peaks.iron, 3.0])
	t.queue_free()
	for k in ["copper", "iron"]:
		var e: CharacterBody2D = _spawn(5, Vector2(1720, 60))
		await wait(0.6)
		var hp0: int = e.hp
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = e.global_position + Vector2(-90, -20)
		o.linear_velocity = Vector2(520, -40)
		main.add_child(o)
		await wait(0.5)
		log_line("%s thrown at a shieldbearer's front: hp %d -> %d" % [k, hp0, e.hp if is_instance_valid(e) else -1])
		if is_instance_valid(e):
			e.queue_free()
		await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(4.0, 4.0)
	cam.global_position = Vector2(1600, 60)
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if k % 2 else "copper"
		o.global_position = Vector2(1570 + k * 12, 70)
		main.add_child(o)
	await wait(0.8)
	await shot("side_by_side")


func wheel_rec() -> void:
	# Ore poured into a gravity wheel's intake turns it; it tips the ore out
	# at the bottom and powers a belt in reach. Then iron.
	main._wave_timer = -9999.0
	await wait(0.3)
	var w: Node2D = preload("res://scenes/gravity_wheel.tscn").instantiate()
	w.global_position = Vector2(1640, 0)
	main.add_child(w)
	var b: Node2D = preload("res://scenes/belt.tscn").instantiate()
	b.global_position = Vector2(1720, 40)
	b.end_offset = Vector2(100, 0)
	main.add_child(b)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = w.global_position + Vector2(40, 0)
	await wait(0.6)
	log_line("wheel axle at %s; idle: omega %.2f power %.2f, belt rate %.2f" % [w.global_position.round(), w.omega, w.power(), b.rate])
	var intake: Vector2 = w.to_global(w._intake.position)
	for kind in ["copper", "iron"]:
		for k in 16:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = kind
			o.global_position = intake + Vector2(randf_range(-2, 2), -50)
			main.add_child(o)
			for f in 24:
				await physics_frame
				if kind == "copper" and k < 6 and f % 6 == 0:
					await _grab(Rect2(w.global_position - Vector2(70, 60), Vector2(200, 110)), "wheel_%03d" % (k * 4 + f / 6), -3)
		log_line("%s stream (2.5/s for 6.4 s): omega %.2f power %.2f, dumped %d, belt rate %.2f" % [kind, w.omega, w.power(), w.dumped, b.rate])
	await wait(4.0)
	log_line("stream stopped 4 s ago: omega %.2f power %.2f belt rate %.2f" % [w.omega, w.power(), b.rate])


func assembler_rec() -> void:
	# Iron ingots into an assembler make iron shot; iron + copper make a gear;
	# copper ore is spat back out. A turret fires the shot.
	main._wave_timer = -9999.0
	await wait(0.3)
	var a: Node2D = preload("res://scenes/assembler.tscn").instantiate()
	a.global_position = Vector2(1620, 60)
	main.add_child(a)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = a.global_position + Vector2(20, -40)
	await wait(0.4)
	var mouth: Vector2 = a.global_position + Vector2(0, -80)
	for k in ["iron", "iron"]:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.kind = k
		ing.global_position = mouth
		main.add_child(ing)
		await wait(0.4)
	var rej: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	rej.global_position = mouth
	main.add_child(rej)
	await wait(0.6)
	log_line("copper ore dropped in: spat out, now at %s v %s" % [rej.global_position.round(), rej.linear_velocity.round()])
	for f in 32:
		await wait(0.25)
		if f == 3:
			await shot("working")
	log_line("shot recipe, unpowered: made %d (2 iron ingots -> expect 8)" % a.made)
	a.recipe = 1
	a._show_recipe()
	for k in ["iron", "copper"]:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.kind = k
		ing.global_position = mouth
		main.add_child(ing)
		await wait(0.4)
	await wait(6.0)
	log_line("gear recipe: made %d total (expect 9)" % a.made)
	var gears := []
	for o in get_nodes_in_group("ore"):
		if o.kind == "gear":
			gears.append(o.global_position.round())
	log_line("gears now at %s" % [gears])
	await shot("made")


func lab_rec() -> void:
	# gear + copper ingot -> a flask (does it survive the spout?); a flask
	# dropped from high shatters; three fed gently to a lab research a level.
	main._wave_timer = -9999.0
	await wait(0.3)
	var Tech = preload("res://scripts/tech.gd")
	Tech.levels.clear()
	var a: Node2D = preload("res://scenes/assembler.tscn").instantiate()
	a.global_position = Vector2(1560, 60)
	a.recipe = 2
	main.add_child(a)
	var lab: Node2D = preload("res://scenes/lab.tscn").instantiate()
	lab.global_position = Vector2(1720, 60)
	main.add_child(lab)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.8, 2.8)
	cam.global_position = Vector2(1640, 20)
	await wait(0.4)
	var g: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	g.kind = "gear"
	g.global_position = a.global_position + Vector2(0, -80)
	main.add_child(g)
	var cu: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	cu.global_position = a.global_position + Vector2(0, -80)
	main.add_child(cu)
	Engine.time_scale = 4.0
	await wait(8.0)
	Engine.time_scale = 1.0
	var flasks := []
	for o in get_nodes_in_group("ore"):
		if o.kind == "flask":
			flasks.append(o)
	log_line("assembler made %d; flasks lying intact: %d" % [a.made, flasks.size()])
	var high: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	high.kind = "flask"
	high.global_position = Vector2(1640, -160)
	main.add_child(high)
	await wait(1.2)
	log_line("flask dropped from 250 px: %s" % ["shattered" if not is_instance_valid(high) else "survived"])
	for k in 3:
		var f: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		f.kind = "flask"
		f.global_position = lab.global_position + Vector2(-11, -70)
		main.add_child(f)
		await wait(0.5)
	await shot("lab")
	Engine.time_scale = 4.0
	await wait(24.0)
	Engine.time_scale = 1.0
	log_line("after 3 flasks: springs level %d, kick mult %.2f; lab label '%s'" % [Tech.level("springs"), Tech.mult("springs"), lab._label.text])
	await shot("researched")


func terrain_look() -> void:
	# Close-ups of the framed terrain: the surface, a dug pocket with a floor,
	# steps, an overhang and a lone pillar, and a cave.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm := tilemap()
	var shading := main.get_node("TileShading")
	var dig := []
	for x in range(70, 80):
		for y in range(9, 13):
			dig.append(Vector2i(x, y))
	for c in [Vector2i(74, 11), Vector2i(74, 12)]:
		dig.erase(c)               # a pillar
	for x in range(80, 84):
		dig.append(Vector2i(x, 12))  # a low tunnel off to the side
	dig.append(Vector2i(69, 12))
	for c in dig:
		tm.set_cell(c, -1)
		shading.mark_dirty(c)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	main.get_node("Player").global_position = Vector2(76 * 16, 12 * 16)
	for spot in [[Vector2(1235, 176), 3.5, "pocket"], [Vector2(1500, 70), 3.0, "surface"], [Vector2(900, 380), 2.5, "cave"]]:
		cam.zoom = Vector2(spot[1], spot[1])
		cam.global_position = spot[0]
		await wait(0.4)
		await shot(spot[2])
		await _grab(Rect2(spot[0] - Vector2(110, 55), Vector2(220, 110)), "px_" + spot[2], -4)


func factory_rec() -> void:
	# The showcase's factory: iron -> laser -> assembler -> shot -> belt -> lift,
	# with a gravity wheel (fed copper) powering the assembler and belt.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var asm: Node2D = null
	var wheel: Node2D = null
	var belt: Node2D = null
	var lift: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.has_method("_finish"):
			asm = n
		if n.has_method("power"):
			wheel = n
		if "rate" in n and n.has_method("run_dir"):
			belt = n
		if "lift_speed" in n:
			lift = n
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(590, 0)
	for s in 12:
		await wait(1.0)
		var shot_on_belt := 0
		for o in get_nodes_in_group("ore"):
			if o.kind == "shot":
				shot_on_belt += 1
		log_line("t=%2d wheel power %.2f dumped %d | assembler held %s made %d rate %.2f | belt rate %.2f | shot loose %d | lift holds %d" % [s + 1, wheel.power(), wheel.dumped, asm._held, asm.made, asm._rate, belt.rate, shot_on_belt, lift._held_items.size()])
		if s == 7:
			await shot("factory")


func tesla_rec() -> void:
	# Two ingots charge a tesla coil; it zaps a cluster of soldiers (chaining)
	# and a magpie overhead.
	main._wave_timer = -9999.0
	await wait(0.3)
	var t: Node2D = preload("res://scenes/tesla.tscn").instantiate()
	t.global_position = Vector2(1600, 60)
	main.add_child(t)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1680, -10)
	await wait(0.4)
	for k in ["iron", "copper"]:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.kind = k
		ing.global_position = t.global_position + Vector2(-14, -70)
		main.add_child(ing)
		await wait(0.5)
	log_line("charge after an iron + a copper ingot: %d (expect 10)" % t.charge)
	var es := [_spawn(2, Vector2(1760, 60)), _spawn(2, Vector2(1790, 60)), _spawn(2, Vector2(1820, 60))]
	var m: Node2D = preload("res://scenes/magpie.tscn").instantiate()
	m.global_position = Vector2(1640, -90)
	main.add_child(m)
	for f in 240:
		await physics_frame
		if f % 6 == 0 and f < 120:
			await _grab(Rect2(Vector2(1540, -140), Vector2(320, 220)), "tesla_%03d" % (f / 6), -2)
	var hps := []
	for e in es:
		hps.append(e.hp if is_instance_valid(e) else "dead")
	log_line("after 4 s: zaps %d, charge left %d, soldiers hp %s (started 8), magpie %s" % [t.zaps, t.charge, hps, ("hp %d" % m.hp) if is_instance_valid(m) else "down"])


func flamer_rec() -> void:
	# Two ore fuel a flamer; a pack of scuttlers runs into the flame and keeps
	# burning; ore lobbed through the flame comes out an ingot.
	main._wave_timer = -9999.0
	await wait(0.3)
	var fl: Node2D = preload("res://scenes/flamer.tscn").instantiate()
	fl.global_position = Vector2(1600, 60)
	main.add_child(fl)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1660, 20)
	await wait(0.4)
	for k in 2:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = fl.global_position + Vector2(-2, -80)
		main.add_child(o)
		await wait(0.5)
	log_line("fuel after 2 copper ore: %.1f s (expect 6)" % fl.fuel)
	var pack := []
	for k in 4:
		pack.append(_spawn(1, Vector2(1740 + k * 14, 60)))
	_spawn(0, Vector2(1700, 60))   # a titan in range keeps it firing for the smelting check
	var lob: RigidBody2D = null
	for f in 300:
		await physics_frame
		if f == 150:
			lob = preload("res://scenes/ore.tscn").instantiate()
			lob.global_position = fl.to_global(fl.PIVOT) + Vector2.from_angle(fl._nozzle.rotation) * 50 + Vector2(0, -40)
			main.add_child(lob)
			log_line("lobbing ore through the flame; firing now: %s, fuel %.1f" % [fl._firing, fl.fuel])
		if f % 6 == 0 and f < 120:
			await _grab(Rect2(Vector2(1560, -60), Vector2(220, 140)), "flame_%03d" % (f / 6), -3)
	var alive := 0
	for e in pack:
		if is_instance_valid(e) and not e._dying:
			alive += 1
	log_line("after 5 s: burn ticks %d, scuttlers left %d/4, ore smelted in the flame %d, fuel left %.1f" % [fl.burned, alive, fl.smelted, fl.fuel])


func sapper_rec() -> void:
	# A sapper tunnels from the right toward the dome and breaches at its rim;
	# a second one runs under a charged tesla coil and gets zapped through the
	# rock. A funnel turret on its path must hold fire while it's buried.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	var ft: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	ft.global_position = Vector2(1560, 80)
	main.add_child(ft)
	var sp: Node2D = preload("res://scenes/sapper.tscn").instantiate()
	sp.global_position = Vector2(1760, 80)
	main.add_child(sp)
	var hp0: int = main.dome_hp
	Engine.time_scale = 3.0
	var t := 0.0
	var shot := 0
	while is_instance_valid(sp) and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		if not is_instance_valid(sp):
			break
		cam.global_position = Vector2(sp.global_position.x - 60, 110)
		if int(t / 3.0) > shot:
			shot = int(t / 3.0)
			log_line("t %4.1f  at (%d, %d)  state %d  dug %d  buried %s  turret fired %d" % [t, sp.global_position.x, sp.global_position.y, sp._state, sp.dug, sp.buried, ft.shots])
			await _grab(Rect2(cam.global_position - Vector2(400, 225), Vector2(800, 450)), "sapper_%02d" % shot, -2)
	log_line("breached after %.1f s: dome %d -> %d" % [t, hp0, main.dome_hp])
	await _grab(Rect2(Vector2(1000, -60), Vector2(800, 450)), "sapper_tunnel", -2)
	# second run: under a tesla coil
	var te: Node2D = preload("res://scenes/tesla.tscn").instantiate()
	te.global_position = Vector2(1500, 80)
	main.add_child(te)
	await wait(0.2)
	te.charge = 30
	var sp2: Node2D = preload("res://scenes/sapper.tscn").instantiate()
	sp2.global_position = Vector2(2100, 80)
	main.add_child(sp2)
	var hp1: int = main.dome_hp
	t = 0.0
	while is_instance_valid(sp2) and not sp2._dying and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
	Engine.time_scale = 1.0
	log_line("second sapper under the tesla: dying %s at x %d after %.1f s, zaps %d, dome %d -> %d" % [is_instance_valid(sp2) and sp2._dying, sp2.global_position.x if is_instance_valid(sp2) else -1, t, te.zaps, hp1, main.dome_hp])


func ditch_rec() -> void:
	# A 4-deep ditch in the enemies' path. The soldier plants a ladder and
	# climbs, the shieldbearer uses the same ladder, the scuttler crawls up
	# the wall, the titan leaps out. Then iron ore knocks the ladder down.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(100, 106):
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(99, 107):
		for y in range(5, 11):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.2, 3.2)
	cam.global_position = Vector2(1650, 90)
	var names := ["soldier", "shieldbearer", "scuttler", "titan"]
	var es := [_spawn(2, Vector2(1730, 60)), _spawn(5, Vector2(1790, 60)), _spawn(1, Vector2(1850, 60)), _spawn(0, Vector2(1960, 60))]
	for f in 1500:
		await physics_frame
		if f % 30 == 0:
			await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "ditch_%03d" % (f / 30), -4)
		if f % 60 == 0:
			var parts := []
			for i in es.size():
				var e = es[i]
				parts.append("%s %s" % [names[i], ("x%d y%d %s w%s f%s h%d" % [e.global_position.x, e.global_position.y, e.get_node("AnimatedSprite2D").animation, e.is_on_wall(), e.is_on_floor(), e._wall_ahead()[0]]) if is_instance_valid(e) else "gone"])
			log_line("t=%4.1f %s | ladders %d" % [f / 60.0, "; ".join(parts), get_nodes_in_group("siege_ladders").size()])
	var got_out := 0
	for e in es:
		if is_instance_valid(e) and e.global_position.x < 1600:
			got_out += 1
	log_line("out of the ditch on the far side: %d/4" % got_out)
	# knock the ladder down with iron
	var lads := get_nodes_in_group("siege_ladders")
	if lads.size() > 0:
		var l: Node2D = lads[0]
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron"
		o.global_position = l.global_position + Vector2(60, -40)
		main.add_child(o)
		o.linear_velocity = Vector2(-300, -20)
		await wait(1.0)
		log_line("after an iron hit: ladder falling %s" % [is_instance_valid(l) and l.falling])
		await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "ditch_knocked", -4)


func bridge_rec() -> void:
	# A bridge engine reaches a 6-wide ditch and lays a bridge; soldiers and a
	# scuttler behind it cross without dropping in. Then iron ore breaks the
	# bridge under a titan, which falls into the ditch.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(100, 106):
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(99, 107):
		for y in range(5, 11):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.2, 3.2)
	cam.global_position = Vector2(1650, 90)
	var br: Node2D = preload("res://scenes/bridger.tscn").instantiate()
	br.global_position = Vector2(1740, 80)
	main.add_child(br)
	var follow := [_spawn(2, Vector2(1800, 60)), _spawn(1, Vector2(1840, 60)), _spawn(2, Vector2(1880, 60))]
	var lowest := 0.0
	for f in 720:
		await physics_frame
		for e in follow:
			if is_instance_valid(e) and e.global_position.x < 1700 and e.global_position.x > 1600:
				lowest = maxf(lowest, e.global_position.y)
		if f % 30 == 0:
			await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "bridge_%03d" % (f / 30), -4)
		if f % 120 == 0:
			log_line("t=%4.1f cart x%d y%d bridges %d | followers %s" % [f / 60.0, br.global_position.x, br.global_position.y, br.bridges,
				", ".join(follow.map(func(e): return ("x%d y%d" % [e.global_position.x, e.global_position.y]) if is_instance_valid(e) else "gone"))])
	log_line("lowest follower y over the ditch: %d (surface ~96, ditch floor ~160)" % lowest)
	var bridge: Node = get_nodes_in_group("field_bridges")[0] if get_nodes_in_group("field_bridges").size() > 0 else null
	var ti := _spawn(0, Vector2(1760, 60))
	for f in 600:
		await physics_frame
		if f % 30 == 0 and f > 0 and bridge and not bridge.broken and ti.global_position.x < 1700:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = "iron"
			o.global_position = Vector2(1650 + randf_range(-20, 20), -40)
			main.add_child(o)
			o.linear_velocity = Vector2(0, 260)
		if f % 30 == 0:
			await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "bridge_b%03d" % (f / 30), -4)
			log_line("  b%d titan x%d y%d bridge dmg %.1f broken %s" % [f / 30, ti.global_position.x if is_instance_valid(ti) else -1, ti.global_position.y if is_instance_valid(ti) else -1, bridge._damage if is_instance_valid(bridge) else -1.0, bridge.broken if is_instance_valid(bridge) else true])
	log_line("after the iron rain: bridge broken %s, titan y %d (in the ditch if > 120)" % [bridge == null or not is_instance_valid(bridge) or bridge.broken, ti.global_position.y if is_instance_valid(ti) else -1])


func mason_rec() -> void:
	# Two masons reach a 6-wide, 4-deep ditch and brick it in from the bottom;
	# a soldier waiting in the ditch must not get bricked over.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(100, 106):
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(99, 107):
		for y in range(5, 11):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.2, 3.2)
	cam.global_position = Vector2(1650, 90)
	var ms := []
	for k in 2:
		var m: Node2D = preload("res://scenes/mason.tscn").instantiate()
		m.global_position = Vector2(1730 + k * 40, 80)
		main.add_child(m)
		ms.append(m)
	var so = _spawn(2, Vector2(1660, 120))
	for f in 1800:
		await physics_frame
		if f % 60 == 0:
			await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "mason_%03d" % (f / 60), -4)
		if f % 180 == 0:
			var filled := 0
			for x in range(100, 106):
				for y in range(6, 10):
					if tm.get_cell_source_id(Vector2i(x, y)) != -1:
						filled += 1
			log_line("t=%4.1f filled %d/24 | masons %s | soldier %s" % [f / 60.0, filled,
				", ".join(ms.map(func(m): return ("x%d bricks %d laid %d" % [m.global_position.x, m.bricks, m.laid]) if is_instance_valid(m) else "gone")),
				("x%d y%d" % [so.global_position.x, so.global_position.y]) if is_instance_valid(so) else "gone"])


func trapdoor_rec() -> void:
	# Two trapdoors cover a 6-wide pit. A soldier, a bridge engine and a mason
	# walk in: the doors spring under each (the cart and the mason take the
	# turf for ground, so no bridge and no bricks), then wind shut.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(100, 106):
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(99, 107):
		for y in range(5, 11):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var doors := []
	for cx in [101, 104]:
		var d: Node2D = preload("res://scenes/trapdoor.tscn").instantiate()
		d.global_position = Vector2(cx * 16 + 8, 6 * 16 + 8)
		main.add_child(d)
		doors.append(d)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.2, 3.2)
	cam.global_position = Vector2(1650, 90)
	await wait(0.5)
	await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "trap_closed", -4)
	var so = _spawn(2, Vector2(1730, 60))
	var br: Node2D = preload("res://scenes/bridger.tscn").instantiate()
	br.global_position = Vector2(1800, 80)
	main.add_child(br)
	var ms: Node2D = preload("res://scenes/mason.tscn").instantiate()
	ms.global_position = Vector2(1870, 80)
	main.add_child(ms)
	for f in 1200:
		await physics_frame
		if f % 20 == 0 and f < 600:
			await _grab(Rect2(Vector2(1560, 20), Vector2(200, 150)), "trap_%03d" % (f / 20), -4)
		if f % 120 == 0:
			log_line("t=%4.1f soldier y%d | cart x%d y%d bridges %d | mason x%d y%d laid %d | doors sprung %d/%d open %s/%s" % [f / 60.0,
				so.global_position.y if is_instance_valid(so) else -1,
				br.global_position.x, br.global_position.y, br.bridges,
				ms.global_position.x, ms.global_position.y, ms.laid,
				doors[0].sprung, doors[1].sprung, doors[0].is_open, doors[1].is_open])


func spring_rec() -> void:
	# Springsteel: rebound height vs copper; one spring vs one copper fired
	# into a line of four soldiers (how many each hits); an assembler turning
	# two iron ingots into three springs.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1700, 20)
	var drops := {}
	for k in ["spring", "copper"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = Vector2(1500 if k == "spring" else 1540, -120)
		main.add_child(o)
		drops[k] = o
	var landed := {"spring": false, "copper": false}
	var peak := {"spring": 999.0, "copper": 999.0}
	for f in 150:
		await physics_frame
		for k in drops:
			var o: RigidBody2D = drops[k]
			if o.linear_velocity.y < -20:
				landed[k] = true
			if landed[k]:
				peak[k] = minf(peak[k], o.global_position.y)
	log_line("dropped from y -120 onto ground ~y 90: first rebound peak y spring %d, copper %d" % [peak.spring, peak.copper])
	# ricochet through a line of soldiers
	for k in ["spring", "copper"]:
		var y0 := 80.0
		var line := []
		for i in 4:
			var s = _spawn(2, Vector2(1700 + i * 26, y0))
			s.speed = 0.0
			line.append(s)
		await wait(0.4)
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = Vector2(1640, line[0].hit_center().y)
		main.add_child(o)
		o.linear_velocity = Vector2(520, -30)
		await wait(2.0)
		var hit := 0
		for s in line:
			if not is_instance_valid(s) or s.hp < 8:
				hit += 1
		log_line("%s fired into 4 soldiers: %d hit" % [k, hit])
		await _grab(Rect2(Vector2(1580, -60), Vector2(300, 170)), "spring_after_" + k, -3)
		for s in line:
			if is_instance_valid(s):
				s.queue_free()
		await wait(0.3)
	var a: Node2D = preload("res://scenes/assembler.tscn").instantiate()
	a.global_position = Vector2(1620, 60)
	a.recipe = 3
	main.add_child(a)
	await wait(0.4)
	for k in 2:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.kind = "iron"
		ing.global_position = a.global_position + Vector2(0, -80)
		main.add_child(ing)
		await wait(0.4)
	await wait(8.0)
	var springs := 0
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "spring":
			springs += 1
	log_line("assembler (springsteel): made %d, springs loose %d (expect 3)" % [a.made, springs])
	await _grab(Rect2(Vector2(1540, -40), Vector2(260, 140)), "spring_assembler", -3)


func crusher_rec() -> void:
	# Ore onto a crusher's rollers comes out as grit (3 each). Then the
	# grinder: a 3-wide pit, a crusher at the bottom, a trapdoor on top; a
	# soldier and two scuttlers walk in.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	var c1: Node2D = preload("res://scenes/crusher.tscn").instantiate()
	c1.global_position = Vector2(1500, 60)
	main.add_child(c1)
	cam.global_position = c1.global_position + Vector2(20, -40)
	await wait(0.4)
	for k in ["copper", "copper", "copper", "iron"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = c1.global_position + Vector2(0, -80)
		main.add_child(o)
		await wait(0.3)
		if k == "copper":
			await _grab(Rect2(c1.global_position + Vector2(-60, -90), Vector2(160, 110)), "crush_feed", -4)
	await wait(7.0)
	var grit := 0
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "grit":
			grit += 1
	log_line("crusher (unpowered): crushed %d (expect 4), grit loose %d (expect 12)" % [c1.crushed, grit])
	await _grab(Rect2(c1.global_position + Vector2(-60, -90), Vector2(160, 110)), "crush_grit", -4)
	# the grinder
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(102, 105):
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(101, 106):
		for y in range(5, 11):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var cr: Node2D = preload("res://scenes/crusher.tscn").instantiate()
	cr.global_position = Vector2(103 * 16 + 8, 150)
	main.add_child(cr)
	var td: Node2D = preload("res://scenes/trapdoor.tscn").instantiate()
	td.global_position = Vector2(103 * 16 + 8, 104)
	main.add_child(td)
	cam.global_position = Vector2(1656, 100)
	await wait(0.4)
	var es := [_spawn(2, Vector2(1740, 60)), _spawn(1, Vector2(1790, 60)), _spawn(1, Vector2(1830, 60))]
	for f in 900:
		await physics_frame
		if f % 30 == 0 and f < 480:
			await _grab(Rect2(Vector2(1576, 30), Vector2(160, 150)), "grinder_%03d" % (f / 30), -4)
		if f % 120 == 0:
			log_line("t=%4.1f chewed %d | %s" % [f / 60.0, cr.chewed, ", ".join(es.map(func(e): return ("x%d y%d hp%d" % [e.global_position.x, e.global_position.y, e.hp]) if is_instance_valid(e) and not e._dying else "dead"))])


func showcase_east() -> void:
	# The showcase's far east on wave 3: the grinder (trapdoor pit + crusher),
	# the tesla coil and the flame turret meet the wave first.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(2070, 40)
	await wait(1.0)
	var cr: Node2D = null
	var td: Node2D = null
	var te: Node2D = null
	var fl: Node2D = null
	for n in get_nodes_in_group("showcase"):
		match n.get_script().resource_path.get_file():
			"crusher.gd": cr = n
			"trapdoor.gd": td = n
			"tesla.gd": te = n
			"flamer.gd": fl = n
	await shot("east_ready")
	main.wave_number = 2
	await tap(KEY_P)
	for s in 24:
		await wait(1.0)
		log_line("t=%2d enemies %d | trapdoor sprung %d, crusher chewed %d, tesla zaps %d (charge %d), flamer burn ticks %d (fuel %.0f) | dome %d" % [s + 1,
			get_nodes_in_group("enemies").size(), td.sprung, cr.chewed, te.zaps, te.charge, fl.burned, fl.fuel, main.dome_hp])
		if s % 2 == 0:
			await shot("east_%02d" % s)
		if s == 23:
			for e in get_nodes_in_group("enemies"):
				log_line("  left: %s at %s dying %s" % [e.get_script().resource_path.get_file() + ":" + str(e.get("enemy_type")), e.global_position.round(), e.get("_dying")])


func sapper_east() -> void:
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	await wait(0.5)
	var sp: Node2D = preload("res://scenes/sapper.tscn").instantiate()
	sp.global_position = Vector2(2360, 80)
	main.add_child(sp)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	for s in 20:
		await wait(1.0)
		if not is_instance_valid(sp):
			log_line("gone")
			break
		var ahead: Vector2 = sp.global_position + sp._heading * 13.0
		var c := tm.local_to_map(tm.to_local(ahead))
		log_line("t=%d at %s state %d dug %d dig %.2f ahead cell %s tile %d" % [s + 1, sp.global_position.round(), sp._state, sp.dug, sp._dig, c, tm.get_cell_atlas_coords(c).x])


func magnet_rec() -> void:
	# An electromagnet hung over the path: soldiers and a scuttler are hauled
	# up and dropped (fall damage) every pulse; iron ore flies up to its face,
	# copper ore ignores it.
	main._wave_timer = -9999.0
	await wait(0.3)
	var mg: Node2D = preload("res://scenes/magnet.tscn").instantiate()
	mg.global_position = Vector2(1650, -40)
	main.add_child(mg)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1650, 30)
	for k in ["iron", "iron", "copper", "spring"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = Vector2(1600 + randf_range(0, 100), 70)
		main.add_child(o)
	var es := [_spawn(2, Vector2(1700, 60)), _spawn(2, Vector2(1730, 60)), _spawn(1, Vector2(1760, 60)), _spawn(0, Vector2(1800, 60))]
	var names := ["soldier", "soldier", "scuttler", "titan"]
	for f in 720:
		await physics_frame
		if f % 15 == 0 and f < 360:
			await _grab(Rect2(Vector2(1560, -50), Vector2(200, 150)), "mag_%03d" % (f / 15), -4)
		if f % 60 == 0:
			var near := 0
			for o in get_nodes_in_group("ore"):
				if o.get("kind") in ["iron", "spring"] and o.global_position.distance_to(mg.to_global(mg.FACE)) < 16:
					near += 1
			var parts := []
			for i in es.size():
				var e = es[i]
				parts.append("%s %s" % [names[i], ("y%d hp%d" % [e.global_position.y, e.hp]) if is_instance_valid(e) and not e._dying else "dead"])
			log_line("t=%4.1f magnet %s lifted %d, iron at face %d | %s" % [f / 60.0, "ON " if mg.on else "off", mg.lifted, near, "; ".join(parts)])


func strata_look() -> void:
	# Wide full-bright views of the rock layer boundaries (dirt/stone, stone/deep).
	main._wave_timer = -9999.0
	await wait(0.3)
	await tap(KEY_L)   # full bright
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	for spot in [[Vector2(700, 420), 1.0, "dirt_stone"], [Vector2(1700, 1050), 1.0, "stone_deep"], [Vector2(900, 420), 2.5, "seam_close"]]:
		cam.zoom = Vector2(spot[1], spot[1])
		cam.global_position = spot[0]
		await wait(0.4)
		await shot(spot[2])


func scrap_rec() -> void:
	# Destroyed automatons burst into scrap: a titan, two soldiers, a scuttler,
	# a bridge engine. Counts the pieces and grabs the scatter.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1650, 30)
	var es := [_spawn(0, Vector2(1600, 60)), _spawn(2, Vector2(1650, 60)), _spawn(2, Vector2(1680, 60)), _spawn(1, Vector2(1710, 60))]
	var br: Node2D = preload("res://scenes/bridger.tscn").instantiate()
	br.global_position = Vector2(1740, 80)
	main.add_child(br)
	es.append(br)
	await wait(1.0)
	for e in es:
		e.take_damage(99)
	for f in 8:
		await wait(0.12)
		await _grab(Rect2(Vector2(1540, -60), Vector2(240, 150)), "scrap_%d" % f, -4)
	var n := 0
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "scrap":
			n += 1
	log_line("scrap on the ground: %d (expect 4 + 2 + 2 + 1 + 3 = 12)" % n)


func foundry_rec() -> void:
	# The Foundry Engine walks into a 5-wide, 3-deep ditch and grinds its way
	# out, stops in range of the dome, flings slag at it, lets scuttlers out
	# of its hatch; then it's shot down and bursts into scrap.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var WG := preload("res://scripts/world_gen.gd")
	for x in range(100, 105):
		for y in range(6, 9):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(99, 106):
		for y in range(5, 10):
			WG.reframe_around(tm, Vector2i(x, y))
			get_root().get_tree().call_group("tile_shading", "mark_dirty", Vector2i(x, y))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	var fe: Node2D = preload("res://scenes/foundry.tscn").instantiate()
	fe.global_position = Vector2(1780, 40)
	main.add_child(fe)
	var hp0: int = main.dome_hp
	Engine.time_scale = 2.0
	for s in 40:
		await wait(1.0)
		cam.global_position = Vector2(fe.global_position.x - 120, -10)
		if s % 2 == 0:
			log_line("t=%2d foundry x%d y%d anim %s | ground %d, flung %d, hatched %d | dome %d" % [s * 2, fe.global_position.x, fe.global_position.y, fe._spr.animation, fe.ground, fe.flung, fe.hatched, main.dome_hp])
		if s % 4 == 1:
			await shot("foundry_%02d" % s)
	Engine.time_scale = 1.0
	log_line("dome %d -> %d" % [hp0, main.dome_hp])
	for k in 9:
		fe.take_damage(10)
		await wait(0.2)
	await wait(1.0)
	await shot("foundry_dead")
	await wait(0.8)
	var n := 0
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "scrap":
			n += 1
	log_line("destroyed: valid %s, scrap %d" % [is_instance_valid(fe), n])


func meteor_rec() -> void:
	# F6 on the showcase with a few walkers out east: a meteor shower.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.9, 0.9)
	cam.global_position = Vector2(1500, -60)
	await wait(1.0)
	var es := []
	for k in 6:
		es.append(_spawn(2 if k % 2 else 1, Vector2(1700 + k * 60, 60)))
	var ore0 := get_nodes_in_group("ore").size()
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var cells0 := tm.get_used_cells().size()
	await tap(KEY_F6)
	for s in 12:
		await wait(1.0)
		if s % 2 == 1:
			await shot("meteor_%02d" % s)
	var hurt := 0
	for e in es:
		if not is_instance_valid(e) or e._dying or e.hp < (8 if e.enemy_type == 2 else 2):
			hurt += 1
	log_line("meteors %d | ore %d -> %d | tiles cratered %d | walkers hurt or dead %d/6 | dome %d" % [main.meteors, ore0, get_nodes_in_group("ore").size(), cells0 - tm.get_used_cells().size(), hurt, main.dome_hp])


func grapple_rec() -> void:
	# The hook: (1) from the bottom of the dome shaft, fired at the lip above,
	# reels the prospector up and out; (2) fired at a soldier, yanks it; (3)
	# fired at a loose ore, drags it back.
	main._wave_timer = -9999.0
	await wait(0.3)
	var p: CharacterBody2D = main.get_node("Player")
	var g = null
	for c in p.get_children():
		if c.has_method("fire"):
			g = c
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	log_line("player at %s" % p.global_position.round())
	cam.global_position = p.global_position + Vector2(0, -80)
	await wait(0.5)
	var y0 := p.global_position.y
	g.fire(Vector2(p.global_position.x + 60, 100))
	for f in 60:
		await physics_frame
		if f % 6 == 0:
			await _grab(Rect2(cam.global_position - Vector2(130, 80), Vector2(260, 160)), "hook_%02d" % (f / 6), -4)
	log_line("reel: state %d (2 = hanging on), reels %d, player y %d -> %d, hook y %d" % [g.state, g.reels, y0, p.global_position.y, g.hook.y])
	g.release()
	await wait(1.5)
	# yank a soldier, up on the surface
	p.global_position = Vector2(1500, 70)
	await wait(0.6)
	cam.global_position = p.global_position + Vector2(40, -30)
	var so = _spawn(2, p.global_position + Vector2(150, -10))
	await wait(1.0)
	var sx: float = so.global_position.x
	g.fire(so.hit_center())
	await wait(0.6)
	log_line("yank: yanks %d, soldier moved %d px toward the player" % [g.yanks, sx - so.global_position.x if p.global_position.x < sx else so.global_position.x - sx])
	# drag an ore
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = p.global_position + Vector2(-120, -30)
	main.add_child(o)
	await wait(1.0)
	var d0 := o.global_position.distance_to(p.global_position)
	g.fire(o.global_position)
	await wait(1.0)
	log_line("drag: ore distance %d -> %d" % [d0, o.global_position.distance_to(p.global_position)])


func airship_rec() -> void:
	# An airship crosses over a ditch, hovers short of the dome and lowers
	# three troops; a second one is shot down and crashes.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1600, -40)
	var ab: Node2D = preload("res://scenes/airship.tscn").instantiate()
	ab.global_position = Vector2(1900, -150)
	main.add_child(ab)
	Engine.time_scale = 2.0
	for s in 14:
		await wait(1.0)
		cam.global_position = Vector2(ab.global_position.x - 60, -40) if is_instance_valid(ab) else cam.global_position
		log_line("t=%2d airship x%d state %d dropped %d" % [s * 2, ab.global_position.x if is_instance_valid(ab) else -1, ab._state if is_instance_valid(ab) else -1, ab.dropped if is_instance_valid(ab) else -1])
		if s % 2 == 1:
			await shot("air_%02d" % s)
	Engine.time_scale = 1.0
	var ab2: Node2D = preload("res://scenes/airship.tscn").instantiate()
	ab2.global_position = Vector2(1800, -150)
	main.add_child(ab2)
	cam.global_position = Vector2(1760, -40)
	await wait(1.0)
	ab2.take_damage(99)
	for f in 8:
		await wait(0.35)
		if f % 2 == 0:
			await shot("air_fall_%d" % f)
	log_line("shot down: valid %s" % is_instance_valid(ab2))


func harpoon_rec() -> void:
	# A harpoon ballista fed three scrap: an airship comes over and is
	# harpooned and winched down; a magpie after it.
	main._wave_timer = -9999.0
	await wait(0.3)
	var hb: Node2D = preload("res://scenes/harpoon.tscn").instantiate()
	hb.global_position = Vector2(1560, 60)
	main.add_child(hb)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1620, -40)
	await wait(0.4)
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "scrap"
		o.global_position = hb.global_position + Vector2(-17, -70)
		main.add_child(o)
		await wait(0.4)
	log_line("ammo after 3 scrap: %d" % hb.ammo)
	var ab: Node2D = preload("res://scenes/airship.tscn").instantiate()
	ab.global_position = Vector2(1950, -150)
	main.add_child(ab)
	for s in 24:
		await wait(0.5)
		if s % 3 == 0:
			await shot("harp_%02d" % s)
		if s % 4 == 0:
			log_line("t=%4.1f airship %s | fired %d downed %d ammo %d" % [s * 0.5, ("x%d y%d hp%d" % [ab.global_position.x, ab.global_position.y, ab.hp]) if is_instance_valid(ab) and not ab._dying else "down", hb.fired, hb.downed, hb.ammo])
	var mp: Node2D = preload("res://scenes/magpie.tscn").instantiate()
	mp.global_position = Vector2(1700, -100)
	main.add_child(mp)
	await wait(5.0)
	log_line("magpie: %s | fired %d downed %d" % ["down" if not is_instance_valid(mp) or mp._dying else "flying", hb.fired, hb.downed])


func storm_rec() -> void:
	# F7 on the showcase: a thunderstorm over the east front (tesla coil,
	# walkers, loose ore).
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.3, 1.3)
	cam.global_position = Vector2(1900, -20)
	await wait(1.0)
	var te: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.get_script().resource_path.get_file() == "tesla.gd":
			te = n
	te.charge = 2
	for k in 4:
		_spawn(2 if k % 2 else 1, Vector2(1980 + k * 50, 60))
	await tap(KEY_F7)
	var st = main.storm
	for s in 14:
		await wait(1.0)
		if s % 4 == 0:
			st._strike()
			await physics_frame
			await shot("storm_bolt_%02d" % s)
	log_line("storm: strikes %d, tesla charged by lightning %d (charge now %d), ore smelted %d" % [st.strikes if is_instance_valid(st) else -1, st.charged if is_instance_valid(st) else -1, te.charge, st.smelted if is_instance_valid(st) else -1])


func shell_rec() -> void:
	# Blast shells: the assembler packs 1 iron ingot + 3 grit into 2 shells;
	# a shell dropped on three soldiers; a shell dropped onto a row of four
	# resting shells (chain reaction).
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	var a: Node2D = preload("res://scenes/assembler.tscn").instantiate()
	a.global_position = Vector2(1450, 60)
	a.recipe = 4
	main.add_child(a)
	cam.global_position = Vector2(1480, 20)
	await wait(0.4)
	var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ing.kind = "iron"
	ing.global_position = a.global_position + Vector2(0, -80)
	main.add_child(ing)
	for k in 3:
		await wait(0.3)
		var g: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		g.kind = "grit"
		g.global_position = a.global_position + Vector2(0, -80)
		main.add_child(g)
	await wait(8.0)
	var shells := 0
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "shell":
			shells += 1
	log_line("assembler (blast shell): made %d, shells loose %d (expect 2)" % [a.made, shells])
	await _grab(Rect2(Vector2(1380, -30), Vector2(200, 110)), "shell_made", -4)
	# onto soldiers
	var es := [_spawn(2, Vector2(1640, 60)), _spawn(2, Vector2(1665, 60)), _spawn(2, Vector2(1690, 60))]
	for e in es:
		e.speed = 0.0
	cam.global_position = Vector2(1665, 20)
	await wait(1.0)
	var s1: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	s1.kind = "shell"
	s1.global_position = Vector2(1665, -120)
	main.add_child(s1)
	for f in 50:
		await physics_frame
		if f % 5 == 0:
			await _grab(Rect2(Vector2(1580, -60), Vector2(180, 120)), "shell_boom_%02d" % (f / 5), -4)
	var hurt := []
	for e in es:
		hurt.append(("hp%d" % e.hp) if is_instance_valid(e) and not e._dying else "dead")
	log_line("shell onto 3 soldiers (hp 8): %s" % ", ".join(hurt))
	# chain reaction
	var row := []
	for k in 4:
		var s: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		s.kind = "shell"
		s.global_position = Vector2(1820 + k * 30, 70)
		main.add_child(s)
		row.append(s)
	await wait(1.5)
	var s2: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	s2.kind = "shell"
	s2.global_position = Vector2(1820, -120)
	main.add_child(s2)
	cam.global_position = Vector2(1860, 20)
	for f in 60:
		await physics_frame
		if f % 6 == 0:
			await _grab(Rect2(Vector2(1770, -60), Vector2(180, 120)), "shell_chain_%02d" % (f / 6), -4)
	var left := 0
	for s in row:
		if is_instance_valid(s):
			left += 1
	log_line("chain: %d of 4 resting shells left (0 = all went up)" % left)


func tall_lift_rec() -> void:
	# The expandable upstream: a lift on the ground, extended twice by
	# building on its top (3 segments, 360px); ore tipped in at the bottom
	# rides all the way up and stacks at the new top.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs := get_root().get_node("BuildSystem")
	var lift: Node2D = preload("res://scenes/upstream_shaft.tscn").instantiate()
	lift.global_position = Vector2(1500, 36)
	main.add_child(lift)
	bs._placed_buildings.append(lift)
	await wait(0.2)
	for k in 2:
		var hit = bs._lift_below(Vector2(1502, lift.top_y() - 20))
		log_line("build on top #%d: found lift %s -> extend %s, segments %d, top y %d" % [k + 1, hit != null, hit.extend() if hit else false, lift.segments, lift.top_y()])
	var miss = bs._lift_below(Vector2(1502, lift.top_y() - 200))
	log_line("far above the top: extends? %s" % (miss != null))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1500, -110)
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1500 + randf_range(-6, 6), 60)
		main.add_child(o)
		await wait(0.3)
	await wait(4.0)
	var ys := []
	for o in get_nodes_in_group("ore"):
		ys.append(int(o.global_position.y))
	ys.sort()
	log_line("ore heights (top of lift at %d): %s" % [lift.top_y(), ys])
	await shot("tall_lift")


func lift_spill_rec() -> void:
	# A two-segment lift set to spill right: ore tipped in at the bottom rides
	# up and is tipped off the cap to the right, one at a time.
	main._wave_timer = -9999.0
	await wait(0.3)
	var lift: Node2D = preload("res://scenes/upstream_shaft.tscn").instantiate()
	lift.global_position = Vector2(1500, 36)
	lift.segments = 2
	lift.spill = 1
	main.add_child(lift)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1540, -40)
	for k in 5:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1500 + randf_range(-6, 6), 60)
		main.add_child(o)
		await wait(0.3)
	for s in 6:
		await wait(1.0)
		if s == 2:
			await shot("lift_spill")
	var right := 0
	for o in get_nodes_in_group("ore"):
		if o.global_position.x > 1525:
			right += 1
	log_line("spilled %d, ore now right of the lift %d/5" % [lift.spilled, right])


func fog_rec() -> void:
	# Fog of war: the view from the dome shaft before and after the
	# prospector walks down and around a dug tunnel.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm := tilemap()
	var shading := main.get_node("TileShading")
	for x in range(75, 96):
		for y in range(14, 17):
			tm.set_cell(Vector2i(x, y), -1)
			shading.mark_dirty(Vector2i(x, y))
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1350, 200)
	await tap(KEY_L)   # full bright, so what is seen is the fog alone
	main.get_node("Fog").visible = true
	p.global_position = Vector2(1200, 150)
	await wait(0.5)
	await shot("fog_start")
	for x in range(1200, 1540, 8):
		p.global_position = Vector2(x, 250)
		await physics_frame
	await wait(0.5)
	await shot("fog_explored")
	log_line("revealed at the tunnel's end: %s, far east underground: %s" % [main.get_node("Fog").is_revealed(Vector2(1530, 250)), main.get_node("Fog").is_revealed(Vector2(2100, 400))])


func tech_rec() -> void:
	# The new techs: a lab set to Packed charges gets 5 flasks and researches
	# it; a blast shell after that hits harder than one before. The lab's
	# cycle reaches every tech.
	main._wave_timer = -9999.0
	await wait(0.3)
	var T := preload("res://scripts/tech.gd")
	log_line("techs: %d (%s)" % [T.TECHS.size(), ", ".join(T.TECHS.map(func(t): return t.id))])
	var boom := func(x: float) -> int:
		var s = _spawn(2, Vector2(x, 60))
		s.speed = 0.0
		await wait(0.8)
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "shell"
		o.global_position = Vector2(x + 30, 70)
		main.add_child(o)
		await wait(0.2)
		o.explode()
		await wait(0.3)
		return 8 - (s.hp if is_instance_valid(s) and not s._dying else 0)
	var before: int = await boom.call(1500.0)
	var lab: Node2D = preload("res://scenes/lab.tscn").instantiate()
	lab.global_position = Vector2(1700, 60)
	lab.research = T.TECHS.map(func(t): return t.id).find("charges")
	main.add_child(lab)
	await wait(0.4)
	for k in 5:
		var f: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		f.kind = "flask"
		f.global_position = lab.global_position + Vector2(-11, -80)
		main.add_child(f)
		await wait(0.5)
	Engine.time_scale = 4.0
	await wait(45.0)
	Engine.time_scale = 1.0
	log_line("Packed charges level %d (mult %.2f)" % [T.level("charges"), T.mult("charges")])
	var after: int = await boom.call(1900.0)
	log_line("blast shell damage to a soldier 30px away: before %d, after %d" % [before, after])


func tech_panel_rec() -> void:
	# The research screen: open it on a lab (one tech part-done, one level
	# researched), then pick a tech from it.
	main._wave_timer = -9999.0
	await wait(0.3)
	var T := preload("res://scripts/tech.gd")
	T.levels["barrels"] = 1
	T.levels["lamps"] = 2
	preload("res://scenes/lab.gd").progress["hook"] = 2
	var lab: Node2D = preload("res://scenes/lab.tscn").instantiate()
	lab.global_position = Vector2(1500, 60)
	main.add_child(lab)
	await wait(0.4)
	lab.open_panel()
	await wait(0.3)
	await shot("tech_panel")
	var panel = main.get_node("TechPanel")
	var i := T.TECHS.map(func(t): return t.id).find("harpoons")
	panel._on_row_input(_click(), i)
	await wait(0.2)
	log_line("picked row %d: lab research now %s, panel open %s" % [i, T.TECHS[lab.research].id, panel.visible])


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func cache_rec() -> void:
	# Salvage caches: scattered on a fresh world; the player walks into one.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scenes/cache.gd").scatter(main, tilemap())
	await wait(0.2)
	var caches := get_nodes_in_group("caches")
	log_line("caches placed: %d at %s" % [caches.size(), ", ".join(caches.map(func(c): return str(c.global_position.round())))])
	var c: Node2D = caches[0]
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = c.global_position + Vector2(0, -30)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = c.global_position + Vector2(-60, -20)
	await wait(0.6)
	await shot("cache_closed")
	p.global_position = c.global_position + Vector2(0, -16)
	await wait(0.3)
	await shot("cache_open")
	await wait(1.2)
	await shot("cache_haul")
	log_line("opened %s, haul %d" % [c.opened, c.haul])


func title_live() -> void:
	# Attract mode: the showcase at work behind the title, the camera
	# drifting across it; two shots 5 s apart, then a key starts the game.
	preload("res://scripts/sandbox_showcase.gd").build(main)
	await wait(0.5)
	main._show_title()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	await wait(2.0)
	var x0 := cam.global_position.x
	await shot("title_live_a")
	await wait(5.0)
	await shot("title_live_b")
	log_line("world running under the title: %s | camera x %.0f -> %.0f | ore in play %d" % [not paused, x0, cam.global_position.x, get_nodes_in_group("ore").size()])
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	main._on_title_input(ev)
	await wait(0.8)
	log_line("after the key: title gone %s, drift stopped %s, camera back on the player %s" % [main._title == null, main._title_drift == null, not cam.top_level])


func title_modes() -> void:
	# The title screen's two ways in; then survival: showcase gone, god
	# tools gone, waves waiting on the first ingot.
	preload("res://scripts/sandbox_showcase.gd").build(main)
	await wait(0.5)
	var built := get_nodes_in_group("showcase").size()
	main._show_title()
	for k in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/title_modes.png")
	var ev := InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	main._on_title_input(ev)
	for k in 40:
		await process_frame
	await wait(0.5)
	log_line("survival: sandbox %s, showcase pieces %d -> %d, god label %s, waves started %s, label '%s', paused %s" % [main.sandbox, built, get_nodes_in_group("showcase").size(), main._god_label != null, main._waves_started, main._wave_label.text, paused])


func music_rec() -> void:
	# The soundtrack loads, loops, plays, and F8 pauses it.
	await wait(0.3)
	var m: AudioStreamPlayer = main._music
	var st := m.stream as AudioStreamWAV
	m.play()
	await wait(1.0)
	log_line("music: %s, loop mode %d, length %.1f s, playing %s at %.2f s" % [st.resource_path.get_file(), st.loop_mode, st.get_length(), m.playing, m.get_playback_position()])
	main.toggle_music()
	log_line("after F8: paused %s" % m.stream_paused)


func seesaw_rec() -> void:
	# A seesaw with three copper ore resting on its left end and a soldier
	# on it; iron dropped from high onto the right end flings them.
	main._wave_timer = -9999.0
	await wait(0.3)
	var ss: Node2D = preload("res://scenes/seesaw.tscn").instantiate()
	ss.global_position = Vector2(1560, 60)
	main.add_child(ss)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1560, 0)
	await wait(0.5)
	var coppers := []
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = ss.global_position + Vector2(-26 + k * 6, -40 - k * 10)
		main.add_child(o)
		coppers.append(o)
	await wait(1.5)
	log_line("plank tilt with copper on the left: %.1f deg" % rad_to_deg(ss._plank.rotation))
	var ys := coppers.map(func(o): return o.global_position.y)
	var drop: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	drop.kind = "iron"
	drop.global_position = ss.global_position + Vector2(28, -200)
	main.add_child(drop)
	var top := {}
	for f in 90:
		await physics_frame
		for o in coppers:
			if is_instance_valid(o):
				top[o] = minf(top.get(o, 9999.0), o.global_position.y)
		if f % 6 == 0 and f > 20 and f < 70:
			await _grab(Rect2(Vector2(1470, -40), Vector2(180, 140)), "seesaw_%02d" % (f / 6), -4)
	log_line("copper rest y %s -> highest y %s" % [ys.map(func(y): return int(y)), coppers.map(func(o): return int(top.get(o, 0)))])
	log_line("plank tilt after the iron: %.1f deg" % rad_to_deg(ss._plank.rotation))


func perf_rec() -> void:
	# The full showcase with wave 5 (the Foundry) under way: frame rate,
	# frame time, physics time and object counts every 2 s.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.0, 1.0)
	cam.global_position = Vector2(1700, -20)
	await wait(3.0)
	main.wave_number = 4
	await tap(KEY_P)
	for s in 12:
		await wait(2.0)
		log_line("t=%2d fps %d | process %.1f ms physics %.1f ms | ore %d, enemies %d, nodes %d, bodies %d" % [s * 2,
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			get_nodes_in_group("ore").size(), get_nodes_in_group("enemies").size(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)])


func spawn_cost() -> void:
	# How long spawning each enemy type takes (first and second time).
	main._wave_timer = -9999.0
	await wait(0.5)
	for t in 6:
		for k in 2:
			var t0 := Time.get_ticks_usec()
			var e := _spawn(t, Vector2(1700 + t * 40, 40))
			log_line("type %d spawn #%d: %.1f ms" % [t, k + 1, (Time.get_ticks_usec() - t0) / 1000.0])
			await physics_frame
	for n in ["magpie", "sapper", "bridger", "mason", "foundry", "airship"]:
		var t0 := Time.get_ticks_usec()
		var x: Node2D = load("res://scenes/%s.tscn" % n).instantiate()
		x.global_position = Vector2(1500, 40)
		main.add_child(x)
		log_line("%s spawn: %.1f ms" % [n, (Time.get_ticks_usec() - t0) / 1000.0])
		await physics_frame
	var t1 := Time.get_ticks_usec()
	main._spawn_wave()
	log_line("a whole wave (%d): %.1f ms" % [main.wave_number, (Time.get_ticks_usec() - t1) / 1000.0])


func light_cost() -> void:
	var L := preload("res://scripts/light_textures.gd")
	for k in 3:
		var t0 := Time.get_ticks_usec()
		L.create_radial_light(256)
		var t1 := Time.get_ticks_usec()
		L.create_radial_light(128)
		log_line("radial light #%d: 256px %.1f ms, 128px %.1f ms" % [k + 1, (t1 - t0) / 1000.0, (Time.get_ticks_usec() - t1) / 1000.0])


func hitch_rec() -> void:
	# Every frame slower than 40 ms in the 4 s after pressing P on the
	# showcase (wave 5), with what was happening.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.global_position = Vector2(1700, -20)
	await wait(3.0)
	main.wave_number = 4
	var t_p := Time.get_ticks_usec()
	await tap(KEY_P)
	var last := Time.get_ticks_usec()
	var added := {}
	var on_add := func(n: Node):
		var k: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		added[k] = added.get(k, 0) + 1
	main.get_tree().node_added.connect(on_add)
	while Time.get_ticks_usec() - t_p < 16_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		if now - last > 40000:
			log_line("hitch %.0f ms at %.2f s after P | physics %.1f ms, process %.1f ms | enemies %d | added this frame: %s" % [(now - last) / 1000.0, (now - t_p) / 1e6,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				get_nodes_in_group("enemies").size(), added])
		added.clear()
		last = now
	main.get_tree().node_added.disconnect(on_add)


func sfx_cost() -> void:
	var S := preload("res://scripts/sfx.gd")
	var fns := {
		"mine_hit": func(): return S.sfx_mine_hit(), "mine_break0": func(): return S.sfx_mine_break(0),
		"mine_break1": func(): return S.sfx_mine_break(1), "clink": func(): return S.sfx_clink(),
		"knock_metal": func(): return S.sfx_ore_knock("metal"), "knock_ore": func(): return S.sfx_ore_knock("ore"),
		"knock_ground": func(): return S.sfx_ore_knock("ground"), "knock_wood": func(): return S.sfx_ore_knock("wood"),
		"shotgun": func(): return S.sfx_shotgun(), "bounce": func(): return S.sfx_bounce(),
		"bumper": func(): return S.sfx_bumper(), "laser": func(): return S.sfx_laser(),
		"enemy_hit": func(): return S.sfx_enemy_hit(), "enemy_die": func(): return S.sfx_enemy_die(),
		"turret_fire": func(): return S.sfx_turret_fire(), "ammo": func(): return S.sfx_ammo_received(),
	}
	for n in fns:
		var t0 := Time.get_ticks_usec()
		fns[n].call()
		var t1 := Time.get_ticks_usec()
		fns[n].call()
		log_line("%s: first %.1f ms, again %.2f ms" % [n, (t1 - t0) / 1000.0, (Time.get_ticks_usec() - t1) / 1000.0])


func gilded_rec() -> void:
	# A gilded titan and soldier next to a plain soldier: health, the look,
	# and what they drop.
	main._wave_timer = -9999.0
	await wait(0.3)
	var mk := func(t: int, x: float, g: bool) -> Node:
		var e = preload("res://scenes/enemy.tscn").instantiate()
		e.add_to_group("enemies")
		e.setup(t)
		e.gilded = g
		e.global_position = Vector2(x, 60)
		e.direction = -1.0
		main.add_child(e)
		e.speed = 0.0
		return e
	var ti = mk.call(0, 1560.0, true)
	var so = mk.call(2, 1640.0, true)
	var plain = mk.call(2, 1690.0, false)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1620, 20)
	await wait(1.0)
	await shot("gilded")
	log_line("hp: gilded titan %d, gilded soldier %d, plain soldier %d" % [ti.hp, so.hp, plain.hp])
	for e in [ti, so, plain]:
		e.take_damage(999)
	await wait(0.5)
	var scrap := 0
	var gears := 0
	for o in get_nodes_in_group("ore"):
		scrap += 1 if o.get("kind") == "scrap" else 0
		gears += 1 if o.get("kind") == "gear" else 0
	log_line("drops: scrap %d (expect 8 + 4 + 2 = 14), gears %d (expect 2)" % [scrap, gears])


func tube_rec() -> void:
	# A pneumatic tube from a funnel on the ground up and over to an outlet
	# 200px right and 140px up: ore dropped in rides it and shoots out.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tb: Node2D = preload("res://scenes/tube.tscn").instantiate()
	tb.global_position = Vector2(1480, 80)
	tb.end_offset = Vector2(200, -140)
	main.add_child(tb)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1590, 10)
	var ores := []
	for k in 5:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if k % 2 else "copper"
		o.global_position = tb.global_position + Vector2(0, -60)
		main.add_child(o)
		ores.append(o)
		await wait(0.35)
		if k == 2:
			await shot("tube_riding")
	await wait(2.0)
	await shot("tube_out")
	var out := 0
	for o in ores:
		if is_instance_valid(o) and o.global_position.x > 1600:
			out += 1
	log_line("tube sent %d; ore now past the outlet side %d/5" % [tb.sent, out])


func keg_rec() -> void:
	# Three powder kegs in a row east of the dome; soldiers march into the
	# first, its fuse burns, it goes up and takes the other two with it.
	# Then a lone keg hit by a fast ore chunk goes off at once.
	main._wave_timer = -9999.0
	await wait(0.3)
	var kegs := []
	for x in [1640, 1720, 1800]:
		var k: Node2D = preload("res://scenes/keg.tscn").instantiate()
		k.global_position = Vector2(x, 40)
		main.add_child(k)
		kegs.append(k)
	var solid := func() -> int:
		var n := 0
		for cx in range(95, 120):
			for cy in range(0, 12):
				if tilemap().get_cell_source_id(Vector2i(cx, cy)) != -1:
					n += 1
		return n
	var before: int = solid.call()
	var foes := []
	for k in 5:
		var e = _spawn(2, Vector2(1900 + k * 30, 40))
		foes.append(e)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1760, 0)
	await shot("keg_row")
	var lit := false
	for t in 80:
		await wait(0.1)
		if not lit and kegs[2].fuse > 0:
			lit = true
			log_line("fuse lit at t=%.1f" % (t * 0.1))
			await shot("keg_fuse")
		if kegs.all(func(k): return not is_instance_valid(k)):
			break
	await wait(0.15)
	await shot("keg_boom")
	await wait(1.0)
	await shot("keg_after")
	var alive := foes.filter(func(e): return is_instance_valid(e) and not e._dying).size()
	log_line("kegs left %d/3 | soldiers alive %d/5 | tiles blown %d" % [kegs.filter(func(k): return is_instance_valid(k)).size(), alive, before - solid.call()])
	# fast ore into a lone keg
	var k2: Node2D = preload("res://scenes/keg.tscn").instantiate()
	k2.global_position = Vector2(1500, 40)
	main.add_child(k2)
	await wait(0.3)
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "iron"
	o.global_position = k2.center() + Vector2(-60, -4)
	o.linear_velocity = Vector2(420, -20)
	main.add_child(o)
	await wait(0.6)
	log_line("fast ore into a keg: blown %s" % (not is_instance_valid(k2)))


func gremlin_rec() -> void:
	# Two machines east of the dome, a gremlin from the east: it should
	# unscrew the nearer one, then the other, then head for the dome.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs = main.get_node("/root/BuildSystem")
	var ms := []
	for spec in [["res://scenes/crusher.tscn", 1720], ["res://scenes/catapult.tscn", 1600]]:
		var n: Node2D = load(spec[0]).instantiate()
		n.global_position = Vector2(spec[1], 60)
		main.add_child(n)
		bs._placed_buildings.append(n)
		ms.append(n)
	var gr: Node2D = preload("res://scenes/gremlin.tscn").instantiate()
	gr.global_position = Vector2(1950, 40)
	main.add_child(gr)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1700, 20)
	var shot_work := false
	for t in 140:
		await wait(0.1)
		if not shot_work and gr._work > 1.8:
			shot_work = true
			await shot("gremlin_wrench")
		if not is_instance_valid(gr) or gr.wrecked >= 2:
			break
	log_line("gremlin alive %s wrecked %s/2 | crusher gone %s, catapult gone %s" % [is_instance_valid(gr), gr.wrecked if is_instance_valid(gr) else -1, not is_instance_valid(ms[0]), not is_instance_valid(ms[1])])
	await wait(1.5)
	await shot("gremlin_after")
	if not is_instance_valid(gr):
		return
	# now shoot it
	gr.take_damage(5)
	log_line("gremlin now at x %.0f (heading %s)" % [gr.global_position.x, "to the dome" if gr.direction < 0 else "away"])


func snare_rec() -> void:
	# A soldier walks onto a snare and is held (its x barely moves for ~3 s),
	# then tears free and walks on; the snare winds back open. A chunk of
	# ore dropped on a second snare is flipped high.
	main._wave_timer = -9999.0
	await wait(0.3)
	var sn: Node2D = preload("res://scenes/snare.tscn").instantiate()
	sn.global_position = Vector2(1680, 60)
	main.add_child(sn)
	var sn2: Node2D = preload("res://scenes/snare.tscn").instantiate()
	sn2.global_position = Vector2(1560, 60)
	main.add_child(sn2)
	var so = _spawn(2, Vector2(1780, 40))
	var hp0: int = so.hp
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1650, 20)
	var t_snap := -1.0
	var xs := []
	for t in 90:
		await wait(0.1)
		if t_snap < 0 and sn.snapped > 0:
			t_snap = t * 0.1
			await shot("snare_held")
		if t_snap >= 0 and is_instance_valid(so):
			xs.append(so.global_position.x)
		if t_snap >= 0 and t * 0.1 > t_snap + 4.0:
			break
	log_line("snapped at t=%.1f, soldier hp %d -> %d" % [t_snap, hp0, so.hp if is_instance_valid(so) else -1])
	if xs.size() > 32:
		log_line("soldier x over the hold: %.0f .. %.0f (drift %.0f); 1 s after release %.0f" % [xs[0], xs[25], absf(xs[25] - xs[0]), xs[xs.size() - 1]])
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "copper"
	o.global_position = sn2.global_position + Vector2(0, -40)
	main.add_child(o)
	var top := 9999.0
	for t in 20:
		await wait(0.05)
		if is_instance_valid(o):
			top = minf(top, o.global_position.y)
	log_line("ore flipped %d; rose to %.0f px above the snare" % [sn2.flipped, sn2.global_position.y - top])
	await wait(3.5)
	log_line("snare 1 state %d (0 = set again), snapped %d, t %.2f, soldier x %.0f" % [sn._state, sn.snapped, sn._t, so.global_position.x if is_instance_valid(so) else -1.0])


func mortar_rec() -> void:
	# A mortar crab from the east marches to its range, plants and shells
	# the dome over a ditch; then it's killed.
	main._wave_timer = -9999.0
	await wait(0.3)
	var mo: Node2D = preload("res://scenes/mortar.tscn").instantiate()
	mo.global_position = Vector2(1950, 40)
	main.add_child(mo)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.1, 1.1)
	cam.global_position = Vector2(1450, -60)
	var dome0: int = main.dome_hp
	var shot_arc := false
	for t in 300:
		await wait(0.1)
		if not shot_arc and mo.fired >= 1:
			await wait(0.6)
			shot_arc = true
			await shot("mortar_arc")
		if mo.fired >= 5:
			break
	await wait(3.0)
	log_line("mortar planted at x %.0f (dome x %.0f), fired %d, dome %d -> %d" % [mo.global_position.x, main.get_node("DomeZone").global_position.x, mo.fired, dome0, main.dome_hp])
	mo.take_damage(20)
	log_line("killed: %s" % mo._dying)


func tripwire_rec() -> void:
	# A tripwire across the path east of the dome, a powder keg 100px behind
	# it (out of the walkers' way, on a ledge) and a pendulum by the far
	# stake. A soldier walks through the wire: the keg should go up and the
	# pendulum swing. Then the wire restrings.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tw: Node2D = preload("res://scenes/tripwire.tscn").instantiate()
	tw.global_position = Vector2(1700, 70)
	tw.end_offset = Vector2(60, 0)
	main.add_child(tw)
	var kg: Node2D = preload("res://scenes/keg.tscn").instantiate()
	kg.global_position = Vector2(1735, 60)   # right under the wire
	main.add_child(kg)
	var pd: Node2D = preload("res://scenes/pendulum.tscn").instantiate()
	pd.global_position = Vector2(1800, -40)
	main.add_child(pd)
	var so = _spawn(2, Vector2(1880, 40))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1730, 20)
	await shot("tripwire_set")
	for t in 80:
		await wait(0.1)
		if tw.tripped > 0:
			break
	log_line("tripped %d | keg blown %s | pendulum omega %.2f | soldier %s" % [tw.tripped, not is_instance_valid(kg), pd.omega, "dead" if not is_instance_valid(so) or so._dying else "hp %d" % so.hp])
	await wait(0.1)
	await shot("tripwire_snap")
	await wait(3.5)
	log_line("restrung: %s" % (tw._cut <= 0))


func plate_rec() -> void:
	# A pressure plate east of the dome wired to a charged tesla coil and a
	# drop hopper full of ore. First a dropped ore chunk presses it (the
	# hopper dumps); then three soldiers walk over it and the coil overloads.
	main._wave_timer = -9999.0
	await wait(0.3)
	var pl: Node2D = preload("res://scenes/plate.tscn").instantiate()
	pl.global_position = Vector2(1720, 60)
	main.add_child(pl)
	var ts: Node2D = preload("res://scenes/tesla.tscn").instantiate()
	ts.global_position = Vector2(1640, 60)
	main.add_child(ts)
	var hp: Node2D = preload("res://scenes/hopper.tscn").instantiate()
	hp.global_position = Vector2(1790, -10)
	main.add_child(hp)
	await wait(0.3)
	ts.charge = 10
	for k in 4:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "copper"
		o.global_position = hp.global_position + Vector2(randf_range(-6, 6), -50 - k * 14)
		main.add_child(o)
	await wait(2.0)
	var stored0: int = hp.stored_count()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1720, 10)
	var o2: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o2.kind = "iron"
	o2.global_position = pl.global_position + Vector2(0, -30)
	main.add_child(o2)
	await wait(0.6)
	log_line("ore on the plate: tripped %d, hopper stored %d -> %d" % [pl.tripped, stored0, hp.stored_count()])
	if is_instance_valid(o2):
		o2.queue_free()
	await wait(0.8)
	ts._cool = 999.0        # no zapping on its own now: only the overload
	var z0: int = ts.zaps
	var foes := []
	for k in 3:
		foes.append(_spawn(2, Vector2(1800 + k * 26, 40)))
	var t0: int = pl.tripped
	for t in 60:
		await wait(0.1)
		if pl.tripped > t0:
			break
	await wait(0.1)
	await shot("plate_overload")
	log_line("walkers on the plate: tripped %d, tesla overload zaps %d (charge now %d)" % [pl.tripped, ts.zaps - z0, ts.charge])


func gate_rec() -> void:
	# Wave 3 into the showcase: the gate's tripwire should blow its kegs
	# under the front of the pack; snares then pin walkers for the coil.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(2050, 0)
	await wait(2.0)
	var wire = null
	var snares := []
	var coil = null
	for n in get_nodes_in_group("showcase"):
		match n.get_script().resource_path.get_file():
			"tripwire.gd": wire = n
			"snare.gd": snares.append(n)
			"tesla.gd": coil = n
	await shot("gate_set")
	main.wave_number = 2
	await tap(KEY_P)
	var n0 := get_nodes_in_group("enemies").size()
	var boomed := false
	for t in 40:
		await wait(0.5)
		if not boomed and wire.tripped > 0:
			boomed = true
			await wait(0.1)
			await shot("gate_boom")
			log_line("gate tripped at t=%.1f: enemies %d -> %d, kegs left %d" % [t * 0.5, n0, get_nodes_in_group("enemies").size(), get_nodes_in_group("kegs").size()])
		if t == 24:
			await shot("gate_snares")
	log_line("after 20 s: snares snapped %s | coil zaps %d | enemies %d | dome %d" % [snares.map(func(s): return s.snapped), coil.zaps, get_nodes_in_group("enemies").size(), main.dome_hp])


func latch_rec() -> void:
	# A catapult with a pressure plate 90px away is wired: ore dropped in its
	# bucket stays there, cocked, until something presses the plate. An
	# unwired catapult far away throws at once, as always.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cat: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	cat.aim_angle = 40.0
	cat.throw_speed = 420.0
	cat.global_position = Vector2(1600, 80)
	main.add_child(cat)
	var pl: Node2D = preload("res://scenes/plate.tscn").instantiate()
	pl.global_position = Vector2(1690, 60)
	main.add_child(pl)
	var free_cat: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	free_cat.global_position = Vector2(2000, 80)
	main.add_child(free_cat)
	await wait(0.3)
	for c in [cat, free_cat]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "copper"
		o.global_position = c.to_global(c._bucket_at(c._arm.rotation)) + Vector2(0, -24)
		main.add_child(o)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = Vector2(1640, 40)
	await wait(2.0)
	await shot("latch_cocked")
	log_line("after 2 s: wired cocked %s (thrown %s) | unwired thrown %s" % [cat.cocked, cat.last_thrown != null, free_cat.last_thrown != null])
	var w: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	w.kind = "iron"
	w.global_position = pl.global_position + Vector2(0, -24)
	main.add_child(w)
	await wait(0.5)
	await shot("latch_fired")
	log_line("plate pressed: tripped %d, wired thrown %s, cocked %s" % [pl.tripped, cat.last_thrown != null, cat.cocked])


func ruins_rec() -> void:
	# A ruin: the prospector walks in through a doorway, the sentinel wakes
	# and shoots; it's destroyed, the chest unseals, the prospector opens it
	# and gets a relic (a free research level).
	main._wave_timer = -9999.0
	await wait(0.3)
	var ruin: Node2D = preload("res://scripts/ruins.gd").build(main, tilemap())
	await wait(0.2)
	var s = null
	var chest = null
	for n in get_nodes_in_group("ruins"):
		if n.get_script() == null:
			continue
		match n.get_script().resource_path.get_file():
			"sentinel.gd": s = n
			"cache.gd": chest = n
	log_line("ruin at %s | sentinel %s, chest sealed %s relic %s" % [ruin.room, s != null, chest.sealed, chest.relic])
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = ruin.room.get_center()
	await tap(KEY_L)
	# stand in the left doorway
	p.global_position = Vector2(ruin.room.position.x - 8, ruin.room.end.y - 4)
	await wait(0.4)
	await shot("ruin_doorway")
	p.global_position = Vector2(ruin.room.position.x + 40, ruin.room.end.y - 4)
	var hp0: int = p.hp
	await wait(3.0)
	await shot("ruin_sentinel")
	log_line("sentinel awake %s, player hp %d -> %d" % [s.awake, hp0, p.hp])
	p.global_position = chest.global_position + Vector2(0, -4)
	await wait(0.3)
	log_line("touched while sealed: opened %s" % chest.opened)
	p.global_position = Vector2(ruin.room.position.x + 40, ruin.room.end.y - 4)
	await wait(0.2)
	var lv0 := {}
	for t in preload("res://scripts/tech.gd").TECHS:
		lv0[t.id] = preload("res://scripts/tech.gd").level(t.id)
	s.take_damage(40)
	await wait(0.6)
	log_line("sentinel down: chest sealed %s" % chest.sealed)
	p.global_position = chest.global_position + Vector2(0, -4)
	await wait(0.6)
	await shot("ruin_relic")
	log_line("opened %s, haul %d, granted %s (level %d -> %d)" % [chest.opened, chest.haul, chest.granted, lv0.get(chest.granted, -1), preload("res://scripts/tech.gd").level(chest.granted) if chest.granted != "" else -1])


func borer_rec() -> void:
	# A steam borer set down east of the dome facing down sinks a shaft; it's
	# turned to face right and tunnels. Tiles cut, ore out, where it ends up.
	main._wave_timer = -9999.0
	await wait(0.3)
	var b: Node2D = preload("res://scenes/borer.tscn").instantiate()
	b.mode = 2   # DOWN
	b.global_position = Vector2(1560, 60)
	main.add_child(b)
	await wait(0.2)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1660, 180)
	await tap(KEY_L)
	var ore0 := get_nodes_in_group("ore").size()
	for t in 60:
		await wait(0.2)
		if b.travelled >= 10:
			break
	log_line("down: travelled %d tiles, bored %d, at %s" % [b.travelled, b.bored, b.global_position])
	await shot("borer_shaft")
	b.turn(0)   # RIGHT
	for t in 120:
		await wait(0.2)
		if b.travelled >= 14 or b.stopped:
			break
	await shot("borer_tunnel")
	log_line("right: travelled %d, bored %d total, at %s | loose ore/grit now %d (was %d)" % [b.travelled, b.bored, b.global_position, get_nodes_in_group("ore").size(), ore0])


func grenadier_rec() -> void:
	# A grenadier walks toward the dome and lobs bombs at it. First with
	# nothing in the way; then with a trampoline in the bombs' path, angled
	# back east, and two soldiers walking behind the grenadier.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1400, 0)
	var g: Node2D = preload("res://scenes/grenadier.tscn").instantiate()
	g.global_position = Vector2(1700, 40)
	main.add_child(g)
	var dome0: int = main.dome_hp
	for t in 100:
		await wait(0.1)
		if g.thrown >= 1:
			break
	var bomb = null
	for o in get_nodes_in_group("ore"):
		if o.get("kind") == "bomb":
			bomb = o
	for k in 14:
		if not is_instance_valid(bomb):
			log_line("  bomb gone at step %d" % k)
			break
		log_line("  bomb at %s fuse %.2f queued %s" % [bomb.global_position, bomb.fuse, bomb.is_queued_for_deletion()])
		if k == 2:
			await shot("grenadier_bomb")
		await wait(0.25)
	await wait(0.5)
	log_line("grenadier at x %.0f threw %d, dome %d -> %d" % [g.global_position.x, g.thrown, dome0, main.dome_hp])
	await wait(4.0)
	log_line("after 2 more throws window: thrown %d, dome now %d" % [g.thrown, main.dome_hp])
	# the return: a lit bomb dropped on a trampoline angled east, into a
	# pair of soldiers walking in
	g.queue_free()
	var t: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t.bounce_angle = 40.0
	t.bounce_force = 330.0
	t.global_position = Vector2(1480, 40)
	main.add_child(t)
	t._update_visuals()
	var foes := [_spawn(2, Vector2(1640, 40)), _spawn(2, Vector2(1670, 40))]
	for f in foes:
		f.speed = 0.0
	cam.global_position = Vector2(1560, 0)
	await wait(0.3)
	var hp0: Array = foes.map(func(f): return f.hp)
	var b2: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	b2.kind = "bomb"
	b2.global_position = t.global_position + Vector2(0, -90)
	main.add_child(b2)
	for k in 14:
		await wait(0.2)
		if not is_instance_valid(b2):
			log_line("  (return) bomb gone at %d" % k)
			break
		log_line("  (return) bomb at %s v %s fuse %.2f" % [b2.global_position.round(), b2.linear_velocity.round(), b2.fuse])
		if k == 5:
			await shot("grenadier_return")
	await wait(0.3)
	await shot("grenadier_boom")
	log_line("bomb off a trampoline into the pack: soldier hp %s -> %s" % [hp0, foes.map(func(f): return f.hp if is_instance_valid(f) and not f._dying else 0)])


func gust_rec() -> void:
	# A bellows aimed east along the ground, a pressure plate beside it, a
	# soldier standing in the stream: pressing the plate gusts it away.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bw: Node2D = preload("res://scenes/bellows.tscn").instantiate()
	bw.aim_angle = 90.0
	bw.wind_speed = 300.0
	bw.global_position = Vector2(1560, 70)
	main.add_child(bw)
	var pl: Node2D = preload("res://scenes/plate.tscn").instantiate()
	pl.global_position = Vector2(1520, 60)
	main.add_child(pl)
	var so = _spawn(2, Vector2(1640, 60))
	so.speed = 0.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1620, 30)
	await wait(1.0)
	var x0: float = so.global_position.x
	var w: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	w.kind = "iron"
	w.global_position = pl.global_position + Vector2(0, -20)
	main.add_child(w)
	await wait(0.2)
	await shot("gust")
	await wait(0.8)
	log_line("plate tripped %d, gust %.2f | soldier x %.0f -> %.0f" % [pl.tripped, bw._gust, x0, so.global_position.x])


func firedamp_rec() -> void:
	# Mine gas: scattered in the deep caves. The prospector stands in one
	# (choking); a second pocket is placed next to it; a soldier waits inside;
	# then a shot is fired into the first: both should go up.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scenes/firedamp.gd").scatter(main, tilemap())
	await wait(0.2)
	var gs := get_nodes_in_group("firedamp")
	log_line("pockets placed: %d" % gs.size())
	var g: Node2D = gs[0]
	var g2: Node2D = preload("res://scenes/firedamp.tscn").instantiate()
	g2.global_position = g.global_position + Vector2(90, 0)
	main.add_child(g2)
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = g.global_position + Vector2(45, 0)
	await tap(KEY_L)
	p.global_position = g.global_position
	var hp0: int = p.hp
	await wait(3.0)
	log_line("choking: player hp %d -> %d in 3 s" % [hp0, p.hp])
	await shot("firedamp_haze")
	p.global_position = g.global_position + Vector2(-260, 0)   # well clear
	var so = _spawn(2, g.global_position + Vector2(10, 0))
	so.speed = 0.0
	await wait(0.2)
	var c0 := tilemap().local_to_map(g.global_position)
	var gpos := g.global_position
	var solid := func() -> int:
		var n := 0
		for dy in range(-6, 7):
			for dx in range(-6, 14):
				n += 1 if tilemap().get_cell_source_id(c0 + Vector2i(dx, dy)) != -1 else 0
		return n
	var before: int = solid.call()
	var b: Area2D = preload("res://scenes/bullet.tscn").instantiate()
	b.global_position = g.global_position + Vector2(-60, 0)
	b.velocity = Vector2(500, 0)
	main.add_child(b)
	await wait(0.25)
	await shot("firedamp_fireball")
	await wait(0.6)
	log_line("shot in (at %s): first lit %s, second lit %s | soldier %s | tiles blown %d" % [gpos, not is_instance_valid(g) or g.lit, not is_instance_valid(g2) or g2.lit, "dead" if not is_instance_valid(so) or so._dying else "hp %d" % so.hp, before - solid.call()])


func colossus_rec() -> void:
	# The Colossus: walks at a 3-wide, 3-deep ditch east of the dome (it
	# should stride over, not fall in), stomps at the prospector standing
	# past it, then is brought down.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm := tilemap()
	for x in range(104, 107):         # ditch at x ~1664..1712
		for y in range(6, 9):
			tm.set_cell(Vector2i(x, y), -1)
	preload("res://scripts/world_gen.gd").reframe_all(tm)
	var co = preload("res://scenes/enemy.tscn").instantiate()
	co.add_to_group("enemies")
	co.setup(0)
	co.colossus = true
	co.direction = -1.0
	co.global_position = Vector2(1880, 0)
	main.add_child(co)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1480, 80)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.3, 1.3)
	cam.global_position = Vector2(1640, -20)
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1520 + k * 14, 70)
		main.add_child(o)
	await wait(1.0)
	await shot("colossus_walk")
	var hp0: int = p.hp
	var deepest := 0.0
	var crossed_at := -1.0
	var stomped := false
	var hp_after := 0
	for t in 300:
		await wait(0.1)
		deepest = maxf(deepest, co.global_position.y)
		if crossed_at < 0 and co.global_position.x < 1650:
			crossed_at = t * 0.1
			await shot("colossus_crossed")
		if p.hp < hp0 and not stomped:
			stomped = true
			await wait(0.15)
			await shot("colossus_stomp")
		if stomped:
			p.global_position = Vector2(900, 80)   # then get well clear
		else:
			p.global_position.x = 1480.0   # stand your ground
		if crossed_at >= 0 and t * 0.1 > crossed_at + 1.0:
			break
	log_line("colossus hp %d, stomped %s, crossed the ditch at t=%.1f, deepest y %.0f (ground ~96; ditch floor ~144) | player hp %d -> %d" % [co.hp, stomped, crossed_at, deepest, hp0, p.hp])
	co.take_damage(400)
	await wait(1.2)
	await shot("colossus_down")
	log_line("down: dying %s, scrap loose %d" % [co._dying, get_nodes_in_group("ore").filter(func(o): return o.get("kind") == "scrap").size()])


func lantern_rec() -> void:
	# Lanterns in a cave: one placed near a ceiling (hangs), one out in the
	# middle (stands on a pole). Screenshot with the prospector's lamp off.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scenes/crawler.gd").scatter(main, tilemap())
	await wait(0.2)
	var c: Node2D = get_nodes_in_group("crawlers")[0]
	var at := c.global_position
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = at + Vector2(0, 40)
	var p: Node2D = main.get_node("Player")
	p.global_position = at + Vector2(-600, 0)
	await wait(0.4)
	await shot("lantern_before")
	var bs = main.get_node("/root/BuildSystem")
	var lanterns := []
	for off in [Vector2(-70, 10), Vector2(70, 60)]:
		var l: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		l.global_position = at + off
		main.add_child(l)
		bs._placed_buildings.append(l)
		lanterns.append(l)
	await wait(1.0)
	await shot("lantern_after")
	log_line("lanterns: %s" % [lanterns.map(func(l): return "at %s pole %.0f" % [l.global_position.round(), l._pole])])


func roller_rec() -> void:
	# Rollers: one rolls at a narrow (2-wide) ditch and should jump it; a
	# second meets a wide deep pit and should be trapped; a third is bumped.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tm := tilemap()
	for x in range(112, 114):          # narrow ditch, x ~1792..1824
		for y in range(6, 9):
			tm.set_cell(Vector2i(x, y), -1)
	for x in range(96, 101):           # wide pit, x ~1536..1616, 4 deep
		for y in range(6, 10):
			tm.set_cell(Vector2i(x, y), -1)
	preload("res://scripts/world_gen.gd").reframe_all(tm)
	var r1: RigidBody2D = preload("res://scenes/roller.tscn").instantiate()
	r1.global_position = Vector2(2100, 70)
	main.add_child(r1)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1760, 20)
	var deepest := 0.0
	var shot_jump := false
	for t in 120:
		await wait(0.1)
		if r1.global_position.x < 1830:
			deepest = maxf(deepest, r1.global_position.y)
		if not shot_jump and r1.global_position.x < 1830:
			shot_jump = true
			await shot("roller_ditch")
		if r1.global_position.x < 1700:
			break
	await wait(2.0)
	log_line("roller in the ditch: plugged %s at %s (span %s)" % [r1.plugged, r1.global_position.round(), r1._span])
	await shot("roller_plug")
	# a soldier walks over the plug
	var so = _spawn(2, Vector2(1900, 40))
	for t in 100:
		await wait(0.1)
		if so.global_position.x < 1760:
			break
	log_line("soldier walking over: x %.0f, deepest y %.0f (ground ~83)" % [so.global_position.x, so.global_position.y])
	await shot("roller_crossed")
	r1.take_damage(30)
	await wait(0.3)
	log_line("plug destroyed: roller gone %s; ditch cell (112,6) empty %s" % [not is_instance_valid(r1), tm.get_cell_source_id(Vector2i(112, 6)) == -1])


func sentry_rec() -> void:
	# A brass sentry set down east of the dome; three soldiers walk into its
	# beat. Then it's worn down to nothing and an ingot winds it back up.
	main._wave_timer = -9999.0
	await wait(0.3)
	var st: CharacterBody2D = preload("res://scenes/sentry.tscn").instantiate()
	st.global_position = Vector2(1600, 60)
	main.add_child(st)
	var foes := []
	for k in 3:
		foes.append(_spawn(2, Vector2(1820 + k * 40, 40)))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1640, 20)
	var shot_fight := false
	for t in 150:
		await wait(0.1)
		if not shot_fight and st.hits >= 2:
			shot_fight = true
			await shot("sentry_fight")
		if foes.all(func(f): return not is_instance_valid(f) or f._dying):
			break
	log_line("sentry: hits %d, hp %d/%d, soldiers left %d/3, sentry x %.0f (home 1600)" % [st.hits, st.hp, st.MAX_HP, foes.filter(func(f): return is_instance_valid(f) and not f._dying).size(), st.global_position.x])
	st.hp = 1
	var so = _spawn(2, st.global_position + Vector2(10, -20))
	so.speed = 0.0
	for t in 30:
		await wait(0.1)
		if st.wound_down:
			break
	so.queue_free()
	log_line("worn out: wound down %s" % st.wound_down)
	await shot("sentry_down")
	var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ing.global_position = st.global_position + Vector2(0, -50)
	main.add_child(ing)
	await wait(1.0)
	log_line("ingot dropped on it: wound down %s, hp %d" % [st.wound_down, st.hp])


func depths_rec() -> void:
	# The depths on a fresh world: seams and pools. Stand by a pool with the
	# lamp off; drop copper ore in (should come back up as an ingot); step in.
	main._wave_timer = -9999.0
	await wait(0.3)
	var d: Node2D = preload("res://scripts/depths.gd").build(main, tilemap())
	await wait(0.3)
	var pools := get_nodes_in_group("magma")
	log_line("magma pools: %d, widths %s" % [pools.size(), pools.map(func(q): return q.width)])
	if pools.is_empty():
		return
	var pool: Node2D = pools[0]
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = pool.global_position + Vector2(pool.width * 0.5, -30)
	p.global_position = pool.global_position + Vector2(-60, -40)
	await wait(0.6)
	await shot("depths_pool")
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "copper"
	o.global_position = pool.global_position + Vector2(pool.width * 0.5, -40)
	main.add_child(o)
	await wait(1.2)
	var ingots := get_nodes_in_group("ingots").filter(func(i): return i.global_position.distance_to(pool.global_position) < 160)
	log_line("copper dropped in: melted %d, ingots nearby %d" % [pool.melted, ingots.size()])
	var hp0: int = p.hp
	p.global_position = pool.global_position + Vector2(pool.width * 0.5, -2)
	await wait(1.2)
	log_line("standing in it: hp %d -> %d" % [hp0, p.hp])
	await shot("depths_burn")
	# the bats: stand under one; it swoops, bites, goes back to its roost
	var bats := get_nodes_in_group("cinderbats")
	log_line("cinder bats: %d" % bats.size())
	if bats.is_empty():
		return
	var bat: Node2D = bats[0]
	var roost: Vector2 = bat.global_position
	p.global_position = roost + Vector2(40, 60)
	cam.global_position = roost + Vector2(20, 30)
	var hp1: int = p.hp
	var swooped := false
	for t in 40:
		await wait(0.1)
		if not swooped and bat._state == 1:
			swooped = true
			await wait(0.2)
			await shot("depths_bat")
		if bat.bites > 0:
			break
	p.global_position = roost + Vector2(-500, 0)     # out of its reach
	await wait(2.5)
	log_line("bat: swooped %s, bites %d (player hp %d -> %d), back on its roost %s" % [swooped, bat.bites, hp1, p.hp, bat._state == 0])


func timer_rec() -> void:
	# A clockwork timer (2 s) wired to a pendulum and a latched catapult fed
	# by hand: over ~7 s it should trip 3 times, keep the pendulum swinging,
	# and fire the catapult each time it's loaded.
	main._wave_timer = -9999.0
	await wait(0.3)
	var tmr: Node2D = preload("res://scenes/timer.tscn").instantiate()
	tmr.mode = 0
	tmr.global_position = Vector2(1640, 60)
	main.add_child(tmr)
	var pd: Node2D = preload("res://scenes/pendulum.tscn").instantiate()
	pd.global_position = Vector2(1690, -10)
	main.add_child(pd)
	var cat: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	cat.aim_angle = 40.0
	cat.throw_speed = 380.0
	cat.global_position = Vector2(1580, 80)
	main.add_child(cat)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1660, 10)
	var thrown := 0
	var max_swing := 0.0
	for t in 70:
		await wait(0.1)
		max_swing = maxf(max_swing, absf(pd.theta))
		if t % 20 == 5:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.global_position = cat.to_global(cat._bucket_at(cat._arm.rotation)) + Vector2(0, -20)
			main.add_child(o)
		if cat.last_thrown != null:
			thrown += 1
			cat.last_thrown = null
		if t == 45:
			await shot("timer")
	log_line("timer tripped %d | pendulum max swing %.0f deg | catapult throws %d" % [tmr.tripped, rad_to_deg(max_swing), thrown])


func wyrm_rec() -> void:
	# The Magma Wyrm: build the depths, walk up to its pool, let it hunt
	# for a while, then bring it down.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scripts/depths.gd").build(main, tilemap())
	await wait(0.3)
	var ws := get_nodes_in_group("wyrms")
	log_line("wyrms: %d" % ws.size())
	if ws.is_empty():
		return
	for b in get_nodes_in_group("cinderbats"):
		b.queue_free()       # just the wyrm for this one
	var w: Node2D = ws[0]
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = w.global_position + Vector2(0, -60)
	await tap(KEY_L)
	p.global_position = w.global_position + Vector2(-150, -30)
	var hp0: int = p.hp
	for t in 60:
		await wait(0.1)
		if w._state == 1 and t > 12 and t % 20 == 0:
			await shot("wyrm_%d" % t)
		p.global_position.x = w._home.x - 150    # stand your ground
	log_line("wyrm state %d, bites %d, player hp %d -> %d, head at %s (home %s)" % [w._state, w.bites, hp0, p.hp, w.global_position.round(), w._home.round()])
	var lv := 0
	for t in preload("res://scripts/tech.gd").TECHS:
		lv += preload("res://scripts/tech.gd").level(t.id)
	w.take_damage(100)
	await wait(1.6)
	await shot("wyrm_dead")
	var lv2 := 0
	for t in preload("res://scripts/tech.gd").TECHS:
		lv2 += preload("res://scripts/tech.gd").level(t.id)
	log_line("dead: gone %s, research levels %d -> %d" % [not is_instance_valid(w), lv, lv2])
	preload("res://scripts/tech.gd").levels.clear()


func cleared_rec() -> void:
	# A wave on the showcase: when the last of it falls, a "cleared" banner
	# and fireworks over the dome.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1250, -60)
	await wait(2.0)
	main.wave_number = 1
	await tap(KEY_P)
	for t in 400:
		await wait(0.1)
		if t > 60 and t % 50 == 0:
			# hurry any stragglers along
			for e in get_nodes_in_group("enemies"):
				if e.has_method("take_damage") and not e.is_in_group("crawlers") and not e.is_in_group("cinderbats") and not e.is_in_group("wyrms"):
					e.take_damage(99)
		if main.waves_cleared > 0:
			break
	await wait(2.6)
	await shot("cleared_fireworks")
	var fw = null
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.get_file() == "fireworks.gd":
			fw = c
	log_line("wave cleared %d | fireworks launched %d, burst %d" % [main.waves_cleared, fw.launched if fw else -1, fw.burst if fw else -1])


func dock_rec() -> void:
	# A drone dock with a funnel turret nearby; loose copper and ingots
	# scattered about. The drones should carry ore to the turret and ingots
	# to the dome.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs = main.get_node("/root/BuildSystem")
	var dk: Node2D = preload("res://scenes/dock.tscn").instantiate()
	dk.global_position = Vector2(1480, 60)
	main.add_child(dk)
	bs._placed_buildings.append(dk)
	var tu: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	tu.global_position = Vector2(1640, 40)
	main.add_child(tu)
	bs._placed_buildings.append(tu)
	var pieces := []
	for k in 4:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "copper"
		o.lifetime = 120.0
		o.global_position = Vector2(1360 + k * 60, 60)
		main.add_child(o)
		pieces.append(o)
	for k in 2:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.global_position = Vector2(1400 + k * 90, 60)
		main.add_child(ing)
		pieces.append(ing)
	var buf0: int = main._receiver.buffer
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1440, 0)
	for t in 300:
		await wait(0.1)
		if t == 40:
			await shot("dock_busy")
		if dk.delivered() >= 6:
			break
	await wait(1.5)
	var in_turret := 0
	for o in get_nodes_in_group("ore"):
		if is_instance_valid(o) and o.has_meta("store_material"):
			in_turret += 1
	log_line("drones delivered %d | ore in the turret magazine %d | dome stock %d -> %d" % [dk.delivered(), in_turret, buf0, main._receiver.buffer])
	for o in pieces:
		if not is_instance_valid(o):
			log_line("  piece: gone")
		else:
			log_line("  piece %s at %s v %.0f freeze %s metas %s" % [o.get("kind"), o.global_position.round(), o.linear_velocity.length(), o.freeze, o.get_meta_list()])
	for d in dk._drones:
		log_line("  drone state %d at %s target %s carried %s" % [d._state, d.global_position.round(), d._target, d._carried])


func lift_shorten_rec() -> void:
	# A 3-segment lift: right-click its upper part twice (the removal path
	# with the mouse there), then once more on the base: 3 -> 2 -> 1 -> gone.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs = main.get_node("/root/BuildSystem")
	var lift: Node2D = preload("res://scenes/upstream_shaft.tscn").instantiate()
	lift.segments = 3
	lift.global_position = Vector2(1560, 36)
	main.add_child(lift)
	bs._placed_buildings.append(lift)
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.0, 1.0)
	cam.global_position = Vector2(1560, -100)
	await wait(0.2)
	var seq := []
	for k in 3:
		var aim := Vector2(1560, lift.top_y() + 10) if lift.segments > 1 else lift.global_position
		var screen: Vector2 = root.get_viewport().get_canvas_transform() * aim
		root.get_viewport().warp_mouse(screen)
		await process_frame
		bs._remove_building_at_mouse()
		await wait(0.2)
		seq.append(lift.segments if is_instance_valid(lift) and not lift.is_queued_for_deletion() else 0)
	log_line("right-clicks on a 3-segment lift: segments %s (expect [2, 1, 0])" % [seq])
	var c := Color(0.62, 0.74, 1.0)
	log_line("colossus tint %s" % c)


func barricade_rec() -> void:
	# A barricade with a pressure plate 60px east of it: soldiers step on
	# the plate, the wall springs up, they're held at it; then it sinks.
	main._wave_timer = -9999.0
	await wait(0.3)
	var br: Node2D = preload("res://scenes/barricade.tscn").instantiate()
	br.global_position = Vector2(1600, 60)
	main.add_child(br)
	var pl: Node2D = preload("res://scenes/plate.tscn").instantiate()
	pl.global_position = Vector2(1660, 60)
	main.add_child(pl)
	var foes := []
	for k in 3:
		foes.append(_spawn(2, Vector2(1760 + k * 30, 40)))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1640, 20)
	var up_at := -1.0
	var held_x := 99999.0
	for t in 120:
		await wait(0.1)
		if up_at < 0 and br.raised > 0:
			up_at = t * 0.1
		if up_at >= 0 and t * 0.1 < up_at + 3.5:
			for f in foes:
				if is_instance_valid(f):
					held_x = minf(held_x, f.global_position.x)
		if up_at >= 0 and absf(t * 0.1 - (up_at + 1.5)) < 0.05:
			await shot("barricade_up")
	log_line("barricade raised %d at t=%.1f | while up, the pack got no further west than x %.0f (wall at 1600) | after it sank, lead soldier x %.0f" % [br.raised, up_at, held_x, foes.map(func(f): return f.global_position.x if is_instance_valid(f) else 0.0).min()])


func build_tabs_rec() -> void:
	# The build bar's four tabs: a shot of each.
	main._wave_timer = -9999.0
	await wait(0.4)
	var bar = null
	for c in main.get_node("CanvasLayer").get_children():
		if c.get_script() and c.get_script().resource_path.get_file() == "build_bar.gd":
			bar = c
	for k in bar.CATS.size():
		bar._cat = k
		bar._layout()
		bar.queue_redraw()
		await wait(0.2)
		await shot("tab_%d" % k)
	log_line("bar size %s, tabs %s" % [bar.size, bar.CATS.map(func(c): return "%s:%d" % [c[0], c[1].size()])])


func poses_rec() -> void:
	# The prospector's new action poses: firing the gun standing still, and
	# holding a chunk of ore overhead.
	main._wave_timer = -9999.0
	await wait(0.3)
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.zoom = Vector2(4, 4)
	await wait(1.2)       # settled on the ground
	var gun = p.get_node("Shotgun")
	gun._fire(Vector2.RIGHT)
	await wait(0.05)
	var a: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	log_line("after a shot: anim %s frame %d" % [a.animation, a.frame])
	await shot("pose_shoot")
	await wait(0.5)
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = p.global_position + Vector2(8, -6)
	main.add_child(o)
	await wait(0.3)
	p._pick_up()
	await wait(0.3)
	log_line("carrying %s: anim %s" % [p._carried != null, a.animation])
	await shot("pose_carry")


func night_eyes_rec() -> void:
	# A wave walking in at midnight, then the same at noon: eye lamps glow
	# only in the dark.
	main._wave_timer = -9999.0
	await wait(0.3)
	var dn = main.get_node("DayNight")
	dn.paused = true
	dn.clock = 0.0
	dn.apply()
	for k in 6:
		_spawn(k % 4 if k % 4 != 3 else 2, Vector2(1640 + k * 34, 40))
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1700, 10)
	await wait(0.8)
	await shot("eyes_midnight")
	log_line("midnight: night factor %.2f" % main.get_node("NightEyes")._night())
	dn.clock = 0.5
	dn.apply()
	await wait(0.3)
	await shot("eyes_noon")
	log_line("noon: night factor %.2f" % main.get_node("NightEyes")._night())


func engine_rec() -> void:
	# A steam engine next to a conveyor belt: cold, the belt runs at 35%;
	# fed 3 copper it lights and drives the belt at full power; when the
	# fuel's gone it runs down again.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs = main.get_node("/root/BuildSystem")
	var en: Node2D = preload("res://scenes/steam_engine.tscn").instantiate()
	en.global_position = Vector2(1560, 60)
	main.add_child(en)
	bs._placed_buildings.append(en)
	var belt: Node2D = preload("res://scenes/belt.tscn").instantiate()
	belt.end_offset = Vector2(140, 0)
	belt.global_position = Vector2(1620, 86)
	main.add_child(belt)
	bs._placed_buildings.append(belt)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1610, 30)
	await wait(1.0)
	var cold: float = preload("res://scripts/power.gd").rate_at(main.get_tree(), belt.global_position)
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "copper"
		o.global_position = en.global_position + en.FUNNEL + Vector2(0, -30 - k * 14)
		main.add_child(o)
	await wait(2.5)
	var hot: float = preload("res://scripts/power.gd").rate_at(main.get_tree(), belt.global_position)
	await shot("engine_lit")
	log_line("engine fuel %.1f s, power %.2f | belt rate cold %.2f -> lit %.2f" % [en.fuel, en.power(), cold, hot])


func domino_rec() -> void:
	# A row of dominoes ending at a pressure plate wired to a powder keg:
	# a nudge to the first, the chain falls, the plate trips, the keg blows.
	# Then the row is reset.
	main._wave_timer = -9999.0
	await wait(0.3)
	var row: Node2D = preload("res://scenes/dominoes.tscn").instantiate()
	row.end_offset = Vector2(195, 0)
	row.global_position = Vector2(1500, 70)
	main.add_child(row)
	var pl: Node2D = preload("res://scenes/plate.tscn").instantiate()
	pl.global_position = Vector2(1712, 70)
	main.add_child(pl)
	var kg: Node2D = preload("res://scenes/keg.tscn").instantiate()
	kg.global_position = Vector2(1790, 70)
	main.add_child(kg)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1640, 40)
	await wait(1.0)
	log_line("slabs %d standing" % row.slabs.size())
	var first: RigidBody2D = row.slabs[0]
	first.apply_impulse(Vector2(40, 0), Vector2(0, -12))
	for t in 60:
		await wait(0.1)
		if t == 12:
			await shot("domino_falling")
		if pl.tripped > 0:
			break
	log_line("fallen %d/%d | plate tripped %d | keg blown %s" % [row.fallen(), row.slabs.size(), pl.tripped, not is_instance_valid(kg)])
	await wait(0.3)
	await shot("domino_boom")
	row.stand_up()
	await wait(1.0)
	log_line("after reset: fallen %d/%d" % [row.fallen(), row.slabs.size()])


func traits_rec() -> void:
	# Wave traits: an IRONCLAD wave 4 (soldiers should arrive with 12 hp
	# not 8), then a SWARM wave 6 (extra scuttlers), then a BLACKOUT wave.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = Vector2(1900, -40)
	main.force_trait = "IRONCLAD"
	main.wave_number = 3
	await tap(KEY_P)
	await wait(4.0)
	var hps := []
	for e in get_nodes_in_group("enemies"):
		if e.get("enemy_type") == 2 and not e._dying:
			hps.append(e.hp)
	log_line("IRONCLAD wave %d: soldier hp %s (normally 8)" % [main.wave_number, hps])
	await shot("trait_ironclad")
	main.get_tree().call_group("enemies", "queue_free")
	await wait(0.5)
	main.force_trait = "SWARM"
	main.wave_number = 5
	await tap(KEY_P)
	await wait(6.0)
	var sc := get_nodes_in_group("enemies").filter(func(e): return e.get("enemy_type") == 1).size()
	log_line("SWARM wave %d: scuttlers %d" % [main.wave_number, sc])
	main.get_tree().call_group("enemies", "queue_free")
	await wait(0.5)
	main.force_trait = "BLACKOUT"
	main.get_node("DayNight").clock = 0.5
	main.wave_number = 6
	await tap(KEY_P)
	await wait(0.5)
	log_line("BLACKOUT wave %d: clock %.2f (0 = midnight)" % [main.wave_number, main.get_node("DayNight").clock])
	main.force_trait = ""


func personal_tech_rec() -> void:
	# Gunsmith 2: a shot throws 7 pellets (5 + 2), faster. Boilers 1: three
	# steam jumps in the air instead of two.
	main._wave_timer = -9999.0
	await wait(1.2)
	var T := preload("res://scripts/tech.gd")
	var p: CharacterBody2D = main.get_node("Player")
	var count := func() -> int: return get_nodes_in_group("bullets").size() if false else main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "bullet.gd").size()
	p.get_node("Shotgun")._fire(Vector2.RIGHT)
	await physics_frame
	var base: int = count.call()
	await wait(1.0)
	T.levels["gunsmith"] = 2
	p.get_node("Shotgun")._timer = 0.0
	p.get_node("Shotgun")._fire(Vector2.RIGHT)
	await physics_frame
	var up: int = count.call()
	log_line("pellets per shot: %d, with Gunsmith 2: %d" % [base, up])
	T.levels["boilers"] = 1
	await wait(1.0)
	log_line("steam max %.1f (steam now %.1f)" % [p.steam_max(), p.steam])
	var n0: int = p.steam_jumps
	p.velocity.y = -300
	await wait(0.15)
	for k in 4:
		if p.steam >= p.STEAM_COST:
			p.steam_jump()
		await wait(0.12)
	log_line("steam jumps in one flight: %d (expect 3)" % (p.steam_jumps - n0))
	T.levels.clear()


func domino_timer_rec() -> void:
	# A domino row with a 2 s clockwork timer by its first slab: it should
	# fall, stand back up, fall again on its own.
	main._wave_timer = -9999.0
	await wait(0.3)
	var row: Node2D = preload("res://scenes/dominoes.tscn").instantiate()
	row.end_offset = Vector2(120, 0)
	row.global_position = Vector2(1560, 70)
	main.add_child(row)
	var tm: Node2D = preload("res://scenes/timer.tscn").instantiate()
	tm.mode = 0
	tm.global_position = Vector2(1530, 70)
	main.add_child(tm)
	var seen := []
	for t in 90:
		await wait(0.1)
		if t % 5 == 0:
			seen.append(row.fallen())
	log_line("fallen count every 0.5 s: %s" % [seen])


func sparrows_rec() -> void:
	# The flock lands on the grass over time; the prospector walks into a
	# landed bird and it takes off; a blast scatters the rest.
	main._wave_timer = -9999.0
	var dn = main.get_node("DayNight")
	dn.paused = true
	dn.clock = 0.5
	dn.apply()
	var sp = main.get_node("Sparrows")
	for b in sp._birds:
		b[3] = randf_range(0.2, 1.5)      # come in sooner for the test
	for t in 60:
		await wait(0.25)
		if sp.grounded() >= 5:
			break
	log_line("birds on the ground: %d" % sp.grounded())
	var landed = null
	for b in sp._birds:
		if b[1] == 0:
			landed = b
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = landed[0].global_position + Vector2(0, -20)
	await wait(0.3)
	await shot("sparrows_ground")
	var p: Node2D = main.get_node("Player")
	p.global_position = landed[0].global_position + Vector2(30, -10)
	await wait(0.4)
	await shot("sparrows_flee")
	log_line("walked up to one: scattered %d, grounded now %d" % [sp.scattered, sp.grounded()])
	preload("res://scripts/fx.gd").shake(p, 8.0, 0.2)
	await wait(0.2)
	log_line("after a blast by the player: scattered %d" % sp.scattered)


func save_new_pieces_rec() -> void:
	# The newer pieces through F5 / F9: one of each, some with non-default
	# settings; save, load, and compare what came back.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bs = main.get_node("/root/BuildSystem")
	var specs := [
		["res://scenes/keg.tscn", Vector2(1500, 60), {}],
		["res://scenes/snare.tscn", Vector2(1540, 60), {}],
		["res://scenes/plate.tscn", Vector2(1580, 60), {}],
		["res://scenes/timer.tscn", Vector2(1620, 60), {"mode": 2}],
		["res://scenes/barricade.tscn", Vector2(1660, 60), {}],
		["res://scenes/sentry.tscn", Vector2(1700, 60), {}],
		["res://scenes/lantern.tscn", Vector2(1740, 40), {}],
		["res://scenes/dock.tscn", Vector2(1800, 60), {}],
		["res://scenes/steam_engine.tscn", Vector2(1880, 60), {"fuel": 40.0}],
		["res://scenes/tesla.tscn", Vector2(1440, 60), {"charge": 18}],
		["res://scenes/borer.tscn", Vector2(1960, 60), {"mode": 2}],
		["res://scenes/tripwire.tscn", Vector2(2000, 72), {"end_offset": Vector2(50, 0)}],
		["res://scenes/dominoes.tscn", Vector2(2080, 70), {"end_offset": Vector2(90, 0)}],
	]
	for sp in specs:
		var n: Node2D = load(sp[0]).instantiate()
		for k in sp[2]:
			n.set(k, sp[2][k])
		n.global_position = sp[1]
		main.add_child(n)
		bs._placed_buildings.append(n)
	await wait(0.5)
	var before := {}
	for b in bs._placed_buildings:
		if is_instance_valid(b):
			var f: String = b.scene_file_path.get_file()
			before[f] = [b.get("mode"), b.get("end_offset"), int(b.get("charge")) if b.get("charge") != null else null, b.get("fuel") != null and b.fuel > 20.0]
	var saved: int = preload("res://scripts/sandbox_save.gd").save(main)
	await preload("res://scripts/sandbox_save.gd").load_into(main)
	await wait(1.0)
	var after := {}
	for b in bs._placed_buildings:
		if is_instance_valid(b):
			var f: String = b.scene_file_path.get_file()
			after[f] = [b.get("mode"), b.get("end_offset"), int(b.get("charge")) if b.get("charge") != null else null, b.get("fuel") != null and b.fuel > 20.0]
	var missing := before.keys().filter(func(k): return not after.has(k))
	var changed := before.keys().filter(func(k): return after.has(k) and str(after[k]) != str(before[k]))
	log_line("saved %s pieces | after load: %d kinds (before %d) | missing %s | settings changed %s" % [saved, after.size(), before.size(), missing, changed])
	var dom = bs._placed_buildings.filter(func(b): return is_instance_valid(b) and b.scene_file_path.get_file() == "dominoes.tscn")
	log_line("domino slabs standing after load: %d | slabs in the world: %d" % [dom[0].slabs.size() if dom.size() > 0 else -1, get_nodes_in_group("domino_slabs").size()])


func gale_rec() -> void:
	# A chunk dropped from a height with no wind, then the same drop in a
	# gale: it should land well downwind.
	main._wave_timer = -9999.0
	await wait(0.3)
	var land := func() -> float:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1600, -200)
		main.add_child(o)
		for t in 40:
			await wait(0.05)
			if o.global_position.y > 60:
				break
		var x := o.global_position.x
		o.queue_free()
		return x
	var calm: float = await land.call()
	main.start_gale()
	await wait(3.0)       # let the banner go
	var g = main.gale
	g.direction = 1.0
	g._t = 8.0          # well into it
	await wait(0.1)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1650, -60)
	var windy: float = await land.call()
	await shot("gale")
	log_line("drop from x 1600: lands at x %.0f calm, %.0f in the gale (strength %.2f)" % [calm, windy, g.strength()])


func marble_parts_rec() -> void:
	# Each marble-machine element on its own, in the open air east of the
	# dome.
	main._wave_timer = -9999.0
	await wait(0.3)
	var ore := func(kind: String, at: Vector2, v := Vector2.ZERO) -> RigidBody2D:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = kind
		o.lifetime = 120.0
		o.global_position = at
		o.linear_velocity = v
		main.add_child(o)
		return o
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	# 1. the beam + an iron tap
	var bm: Node2D = preload("res://scenes/beam.tscn").instantiate()
	bm.depth = 260.0
	bm.spill = 1
	bm.global_position = Vector2(1500, -200)
	main.add_child(bm)
	var tp: Node2D = preload("res://scenes/beam_tap.tscn").instantiate()
	tp.mode = 1          # iron
	tp.global_position = Vector2(1490, -60)
	main.add_child(tp)
	await wait(0.2)
	var a = ore.call("copper", Vector2(1500, 40))
	var b = ore.call("iron", Vector2(1500, 30))
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1500, -90)
	await wait(1.6)
	await shot("beam")
	await wait(1.0)
	log_line("beam: flung %d from the crown | tap took out %d (iron) | copper at %s, iron at %s" % [bm.carried, tp.tapped, a.global_position.round(), b.global_position.round()])
	# 2. flip-flop
	var rk: Node2D = preload("res://scenes/rocker.tscn").instantiate()
	rk.global_position = Vector2(1700, 40)
	main.add_child(rk)
	var rk_ores := []
	for k in 6:
		rk_ores.append(ore.call("copper", Vector2(1700, 0)))
		await wait(0.7)
	await wait(0.6)
	log_line("flip-flop: sent left/right %s | ore x %s" % [rk.sent, rk_ores.map(func(o): return int(o.global_position.x) if is_instance_valid(o) else -1)])
	# 3. tipping bucket
	var tb: Node2D = preload("res://scenes/tipping_bucket.tscn").instantiate()
	tb.global_position = Vector2(1850, 50)
	main.add_child(tb)
	cam.global_position = Vector2(1800, 0)
	cam.zoom = Vector2(2.4, 2.4)
	var c0: int = 0
	for k in 7:
		ore.call("copper", Vector2(1850, 0))
		await wait(0.5)
		if k == 4:
			c0 = tb.count()
			await shot("bucket_full")
	await wait(0.4)
	log_line("tipping bucket: held %d before, tipped %d times, poured %d" % [c0, tb.tipped, tb.poured])
	# 4. sieve
	var sv: Node2D = preload("res://scenes/sieve.tscn").instantiate()
	sv.end_offset = Vector2(140, 45)
	sv.global_position = Vector2(1300, -20)
	main.add_child(sv)
	var g = ore.call("grit", Vector2(1305, -34))
	var cu = ore.call("copper", Vector2(1310, -34))
	await wait(1.4)
	log_line("sieve: grit at %s (fell through if y > %d), copper at %s (rolled to the end if x > 1420)" % [g.global_position.round(), -20, cu.global_position.round()])
	# 5. escapement on a chute
	var ch: Node2D = preload("res://scenes/chute.tscn").instantiate()
	ch.end_offset = Vector2(120, 30)
	ch.global_position = Vector2(1900, -120)
	main.add_child(ch)
	var es: Node2D = preload("res://scenes/escapement.tscn").instantiate()
	es.global_position = Vector2(2020, -90)
	es.mode = 1
	main.add_child(es)
	var queued := []
	for k in 5:
		queued.append(ore.call("copper", Vector2(1910 + k * 4, -140)))
		await wait(0.1)
	var past := func() -> int: return queued.filter(func(o): return o.global_position.y > -60).size()   # off the chute
	await wait(2.0)
	var p1: int = past.call()
	await wait(4.0)
	var p2: int = past.call()
	log_line("escapement (1.2 s, ~1.6 s unpowered): through after 2 s %d, after 6 s %d (of 5)" % [p1, p2])
	# 6. arm
	var am: Node2D = preload("res://scenes/arm.tscn").instantiate()
	am.global_position = Vector2(980, 90)
	am.mode = 2    # iron
	main.add_child(am)
	var ir = ore.call("iron", am.global_position + am.pick + Vector2(0, -20))
	var cp = ore.call("copper", am.global_position + am.pick + Vector2(6, -40))
	cam.global_position = Vector2(980, 50)
	await wait(2.2)
	await shot("arm")
	log_line("arm (iron): moved %d | iron at %s, copper at %s (pick %s, drop %s)" % [am.moved, ir.global_position.round(), cp.global_position.round(), am.global_position + am.pick, am.global_position + am.drop])


func marble_works_rec() -> void:
	# The Marble Works demo: built, then watched for 30 s. Counters from
	# every element, shots along the way.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_marble_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1290, 360)
	var find := func(file: String) -> Array:
		return main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == file)
	for k in 6:
		await wait(5.0)
		await shot("marble_works_%02d" % k)
		var bm = find.call("beam.gd")[0]
		var tp = find.call("beam_tap.gd")[0]
		var rk = find.call("rocker.gd")[0]
		var tb = find.call("tipping_bucket.gd")[0]
		var es = find.call("escapement.gd")[0]
		var am = find.call("arm.gd")[0]
		var wh = find.call("gravity_wheel.gd")
		var sc = find.call("screw.gd")
		var st = find.call("stair_lift.gd")
		var fl = find.call("ferris_lift.gd")
		var jp = find.call("jump.gd")
		log_line("t=%d | beam flung %d | iron tapped %d | flip-flop %s | bucket tipped %d | escapement %d | arm moved %d | screw lifted %d | stair strokes %d | ferris lifted %d | jump landed/fell %s | wheels power %s | ore %d" % [(k + 1) * 5,
			bm.carried, tp.tapped, rk.sent, tb.tipped, es.released, am.moved, sc[0].lifted if sc.size() > 0 else -1, st[0].strokes if st.size() > 0 else -1, fl[0].lifted if fl.size() > 0 else -1, [jp[0].landed, jp[0].fell] if jp.size() > 0 else [],wh.map(func(w): return snappedf(w.power(), 0.01)), get_nodes_in_group("ore").size()])


func counter_works_rec() -> void:
	# The Binary Counter world: the count, bit by bit, every 5 s for 20 s,
	# plus where the marbles are (queued, in the screw, lost).
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_counter_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1220, 370)
	var ro = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "bit_readout.gd")[0]
	var sc = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "screw.gd")[0]
	var es = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "escapement.gd")[0]
	for k in 4:
		await wait(5.0)
		if k % 2 == 1:
			await shot("counter_%02d" % k)
		var ore := get_nodes_in_group("ore").filter(func(o): return is_instance_valid(o))
		var stray := ore.filter(func(o): return o.global_position.y > 580 or o.global_position.x < 930 or o.global_position.x > 1650)
		var bits: Array = ro.bits.map(func(b): return 1 if b.tilt > 0 else 0)
		var sent: Array = ro.bits.map(func(b): return b.sent)
		var bell = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "bell.gd")
		log_line("t=%d | count %d bits %s | bell rang %d | released %d | screw lifted %d | marbles %d (stray %d) | per-bit sent L/R %s" % [(k + 1) * 5, ro.counted, bits, bell[0].rings if bell.size() > 0 else -1, es.released, sc.lifted, ore.size(), stray.size(), sent])


func galton_rec() -> void:
	# The Galton board world: the bins every 5 s for 20 s, and a shot.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_galton_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.25, 1.25)
	cam.global_position = Vector2(1290, 400)
	var g = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "galton.gd")[0]
	for k in 4:
		await wait(5.0)
		if k % 2 == 1:
			await shot("galton_%02d" % k)
		var stray := get_nodes_in_group("ore").filter(func(o): return is_instance_valid(o) and (o.global_position.y > 590 or absf(o.global_position.x - 1290) > 200))
		log_line("t=%d | dropped %d | bins %s (sum %d) | stray %d" % [(k + 1) * 5, g.dropped, g.bins, g.bins.reduce(func(a, b): return a + b, 0), stray.size()])


func hoop_rec() -> void:
	# Loop-the-loop: four marbles sent along the rail at rising speeds, one
	# at a time. It needs v^2 >= 5gR (about 330 px/s) to make it round.
	main._wave_timer = -9999.0
	await wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(main)
	await preload("res://scripts/marble_works.gd").carve(main, false)
	var lp: Node2D = preload("res://scenes/loop.tscn").instantiate()
	lp.global_position = Vector2(1300, 562)
	main.add_child(lp)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3, 3)
	cam.global_position = Vector2(1300, 520)
	for v in [250.0, 330.0, 380.0, 450.0]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1250, 555)
		main.add_child(o)
		o.linear_velocity = Vector2(v, 0)
		await wait(0.12)
		if v == 380.0:
			await shot("loop_%d" % int(v))
		await wait(1.3)
		log_line("sent at %d px/s: looped %d, fell %d" % [int(v), lp.looped, lp.fell])
	await shot("loop_end")


func coaster_rec() -> void:
	# The Coaster world: loop / jump / bell counts every 5 s for 20 s.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_coaster_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1250, 340)
	var find := func(file: String): return main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == file)[0]
	var lp = find.call("loop.gd")
	var jp = find.call("jump.gd")
	var bl = find.call("bell.gd")
	var beam = find.call("beam.gd")
	for k in 4:
		await wait(1.0 if k == 0 else 5.0)
		if k % 2 == 1:
			await shot("coaster_%02d" % k)
		log_line("t=%d | loop round %d fell %d | jump landed %d short %d | bell %d | beam carried %d" % [(k + 1) * 5, lp.looped, lp.fell, jp.landed, jp.fell, bl.rings, beam.carried])
		log_line("   loop entry speeds %s (needs ~300)" % [lp.entry_speeds])
		log_line("   marbles at %s" % [get_nodes_in_group("ore").map(func(o): return Vector2i(o.global_position))])


func puzzle_rec() -> void:
	# The Marble Puzzle world: unsolved for 3 s (marbles pile on the floor),
	# then two chutes over the wall, and the cup should fill.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_puzzle_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.4, 1.4)
	cam.global_position = Vector2(1260, 380)
	var cup = get_nodes_in_group("goal_cups")[0]
	await wait(3.0)
	log_line("before: cup %d / %d" % [cup.count, cup.target])
	var MW = preload("res://scripts/marble_works.gd")
	MW._chute(main, Vector2(985, 225), Vector2(1296, 392))
	MW._chute(main, Vector2(1302, 420), Vector2(1516, 548))
	for k in 3:
		await wait(4.0)
		if k == 1:
			await shot("puzzle_%d" % k)
		log_line("t+%d: cup %d / %d done %s" % [(k + 1) * 4, cup.count, cup.target, cup.done])
	await shot("puzzle_end")


func buildbar_rec() -> void:
	# The build bar's marble tabs: each shown, with a hover name.
	main._wave_timer = -9999.0
	await wait(0.3)
	var bar: Control = main.get_node("CanvasLayer").get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "build_bar.gd")[0]
	for c in [4, 5]:
		bar._cat = c
		bar._layout()
		bar._name_label.text = bar.PIECES[bar._types()[0]][1]
		bar._name_label.visible = true
		await wait(0.3)
		await shot("buildbar_%d" % c)


func scale_rec() -> void:
	# Weigh scale: copper and iron dropped in turn; iron should go right
	# (heavy_side), copper left.
	main._wave_timer = -9999.0
	await wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(main)
	await preload("res://scripts/marble_works.gd").carve(main, false)
	var sc: Node2D = preload("res://scenes/weigh_scale.tscn").instantiate()
	sc.global_position = Vector2(1300, 500)
	main.add_child(sc)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3, 3)
	cam.global_position = Vector2(1300, 500)
	var went := []
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if k % 2 == 1 else "copper"
		o.global_position = Vector2(1300 + randf_range(-2, 2), 440)
		main.add_child(o)
		await wait(0.25)
		if k == 1:
			await shot("scale_iron")
		await wait(0.75)
		went.append("%s->%s" % [o.kind, "R" if o.global_position.x > 1300 else "L"])
	log_line("scale: %s | heavy %d light %d sent L/R %s" % [went, sc.heavy, sc.light, sc.sent])


func puzzle2_rec() -> void:
	# Puzzle level 2: solve level 1, see copper spoil the iron-only cup,
	# then put a weigh scale in the route and see it fill with iron.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_puzzle_works()
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1400, 470)
	var cup = get_nodes_in_group("goal_cups")[0]
	var MW = preload("res://scripts/marble_works.gd")
	MW._chute(main, Vector2(985, 225), Vector2(1296, 392))
	var c2 = MW._chute(main, Vector2(1302, 420), Vector2(1516, 548))
	var tries := 0
	while cup.accept == "" and tries < 40:
		await wait(0.5)
		tries += 1
		if tries % 6 == 0:
			log_line("  waiting: cup %d/%d done %s" % [cup.count, cup.target, cup.done])
		if tries == 12:
			await shot("puzzle2_level1")
	log_line("level 2 began (cup %d/%d %s)" % [cup.count, cup.target, cup.accept])
	await wait(5.0)
	log_line("plain chutes, 5 s: cup %d, spoiled %d" % [cup.count, cup.spoiled])
	c2.queue_free()
	MW._piece(main, "res://scenes/weigh_scale.tscn", Vector2(1330, 440), {"heavy_side": 1.0})
	MW._chute(main, Vector2(1330 + 14, 440 + 14), Vector2(1516, 548))
	var sp0: int = cup.spoiled
	for k in 3:
		await wait(4.0)
		if k == 1:
			await shot("puzzle2_%d" % k)
		log_line("with scale +%d s: cup %d/%d done %s, spoiled since %d" % [(k + 1) * 4, cup.count, cup.target, cup.done, cup.spoiled - sp0])


func marble_trace_rec() -> void:
	# Where the Marble Works' streams actually go: iron after the tap, drops
	# below the escapement, pieces around the arm's shelf.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_marble_works()
	var iron_x := []
	var esc_x := []
	var shelf := []
	for t in 200:
		await wait(0.1)
		for o in get_nodes_in_group("ore"):
			if not is_instance_valid(o):
				continue
			var p: Vector2 = o.global_position
			if o.get("kind") == "iron" and p.x > 1440 and p.y > 440 and p.y < 520:
				iron_x.append(int(p.x))
			if p.x > 1100 and p.x < 1180 and p.y > 480 and p.y < 520:
				esc_x.append(int(p.x))
			if p.x > 1330 and p.x < 1460 and p.y > 270 and p.y < 330 and o.linear_velocity.length() < 60:
				shelf.append(Vector2i(p))
	log_line("iron passing y 440-520 (bucket at 1530, cup 1515-1545): x %s" % [iron_x.slice(0, 40)])
	log_line("drops near wheel 2 (intake ~1130,513): x %s" % [esc_x.slice(0, 40)])
	log_line("slow pieces around the shelf: %s" % [shelf.slice(0, 30)])


func marble_bucket_rec() -> void:
	# The iron line into the tipping bucket, traced: the bucket's fill and
	# where the iron near it is, every 2 s.
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_marble_works()
	var tb = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "tipping_bucket.gd")[0]
	for t in 16:
		await wait(2.0)
		var near := []
		for o in get_nodes_in_group("ore"):
			if is_instance_valid(o) and o.get("kind") == "iron" and o.global_position.distance_to(tb.global_position) < 90:
				near.append("%s v%d%s" % [Vector2i(o.global_position), int(o.linear_velocity.length()), " z" if o.sleeping else ""])
		log_line("t=%d bucket at %s count %d tipped %d | iron near: %s" % [(t + 1) * 2, tb.global_position, tb.count(), tb.tipped, near])
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3, 3)
	cam.global_position = tb.global_position + Vector2(-20, -20)
	await wait(0.2)
	await shot("bucket_close")


func marble_tap_rec() -> void:
	# Iron just after the tap: where does it go?
	main._wave_timer = -9999.0
	await wait(0.3)
	await main.start_marble_works()
	var tp = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "beam_tap.gd")[0]
	var seen := {}
	for t in 300:
		await wait(0.1)
		for o in get_nodes_in_group("ore"):
			if is_instance_valid(o) and o.get("kind") == "iron" and o.global_position.y < 470 and o.global_position.x > 1150:
				var id: int = o.get_instance_id()
				if not seen.has(id):
					seen[id] = []
				if seen[id].size() < 12:
					seen[id].append("%s%s" % [Vector2i(o.global_position), "B" if o.has_meta("in_beam") else ""])
		if seen.size() >= 3 and t > 150:
			break
	log_line("tap at %s tapped %d" % [tp.global_position, tp.tapped])
	for id in seen:
		log_line("  iron: %s" % [seen[id]])


func ambience_rec() -> void:
	# Cave life: the camera on a cavern for a few seconds.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1480, 490)
	await tap(KEY_L)
	await wait(4.0)
	var amb = main.get_node("Ambience")
	log_line("moths %d, drips %d" % [amb._moths.size(), amb._drips.size()])
	var v: Rect2 = amb._view()
	var air := 0
	var ceil := 0
	for k in 400:
		var p := Vector2(randf_range(v.position.x, v.end.x), randf_range(v.position.y, v.end.y))
		var c := tilemap().local_to_map(p)
		if tilemap().get_cell_source_id(c) == -1:
			air += 1
			for j in 12:
				if tilemap().get_cell_source_id(c + Vector2i.UP) != -1:
					ceil += 1
					break
				c += Vector2i.UP
	log_line("view %s | of 400 points: air %d, found a ceiling above %d" % [v, air, ceil])
	await shot("cave_life")


func tinker_rec() -> void:
	# A tinker behind two wounded soldiers welds them back up; then it's
	# killed and the welding stops.
	main._wave_timer = -9999.0
	await wait(0.3)
	var so1 = _spawn(2, Vector2(1600, 60))
	var so2 = _spawn(2, Vector2(1640, 60))
	for s in [so1, so2]:
		s.speed = 0.0
	var tk: Node2D = preload("res://scenes/tinker.tscn").instantiate()
	tk.global_position = Vector2(1700, 60)
	main.add_child(tk)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.8, 2.8)
	cam.global_position = Vector2(1650, 30)
	await wait(0.8)
	so1.take_damage(5)
	so2.take_damage(3)
	log_line("wounded: soldiers hp %d, %d" % [so1.hp, so2.hp])
	for f in 300:
		await physics_frame
		if tk._arc_t > 0.35 and f < 200:
			await _grab(Rect2(Vector2(1570, -20), Vector2(170, 100)), "tinker_weld_%03d" % f, -4)
	log_line("after 5 s: soldiers hp %d, %d | tinker healed %d" % [so1.hp, so2.hp, tk.healed])
	so1.take_damage(3)
	tk.take_damage(99)
	await wait(4.0)
	log_line("tinker destroyed; wounded soldier stays at hp %d" % so1.hp)


func manual_rec() -> void:
	await wait(0.3)
	for t in 4:
		main.open_manual() if t == 0 else null
		main.get_node("Manual")._tab = t
		main.get_node("Manual")._build()
		await wait(0.3)
		await shot("manual_%d" % t)


func daynight_rec() -> void:
	# Stills of the showcase across a day: midnight, dawn, noon, dusk.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	main._wave_timer = -9999.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = Vector2(1300, -60)
	var dn = main.get_node("DayNight")
	dn.paused = true
	for spec in [[0.0, "midnight"], [0.29, "dawn"], [0.5, "noon"], [0.71, "dusk"]]:
		dn.clock = spec[0]
		dn.apply()
		await wait(0.4)
		log_line("%s: daylight %.2f warm %.2f" % [spec[1], dn.daylight(), dn.warmth()])
		await shot("day_" + spec[1])


func geyser_rec() -> void:
	# Ore geysers: scattered on a fresh world; one watched through an
	# eruption (forced soon) with a soldier standing on its vent.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scenes/geyser.gd").scatter(main, tilemap())
	await wait(0.2)
	var gs := get_nodes_in_group("geysers")
	log_line("geysers placed: %d at %s" % [gs.size(), ", ".join(gs.map(func(g): return str(g.global_position.round())))])
	var g: Node2D = gs[0]
	g._t = 3.0
	var so = _spawn(2, g.global_position + Vector2(0, -24))
	so.speed = 0.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = g.global_position + Vector2(0, -100)
	await tap(KEY_L)
	var ore0 := get_nodes_in_group("ore").size()
	var so_top := 9999.0
	for f in 330:
		await physics_frame
		if is_instance_valid(so):
			so_top = minf(so_top, so.global_position.y)
		if f in [120, 175, 195, 230]:
			await shot("geyser_%03d" % f)
	log_line("eruptions %d, ore spewed %d, thrown %d, soldier rose to %d px above the vent" % [g.eruptions, get_nodes_in_group("ore").size() - ore0, g.thrown, int(g.global_position.y - so_top)])


func seesaw_walker() -> void:
	# A soldier walks onto a level seesaw: the plank tips under it.
	main._wave_timer = -9999.0
	await wait(0.3)
	var ss: Node2D = preload("res://scenes/seesaw.tscn").instantiate()
	ss.global_position = Vector2(1560, 60)
	main.add_child(ss)
	await wait(0.5)
	log_line("empty plank: %.1f deg" % rad_to_deg(ss._plank.rotation))
	var so = _spawn(2, Vector2(1640, 40))
	var most := 0.0
	for f in 240:
		await physics_frame
		most = maxf(most, absf(rad_to_deg(ss._plank.rotation)))
	log_line("with a soldier walking over: tipped up to %.1f deg" % most)


func steam_jump_rec() -> void:
	# Jump, then two steam bursts in the air: how high does the prospector get,
	# and a third burst is refused until landing refills the boiler.
	main._wave_timer = -9999.0
	await wait(0.3)
	var p: CharacterBody2D = main.get_node("Player")
	p.global_position = Vector2(1500, 70)
	await wait(0.6)
	var y0 := p.global_position.y
	var top := y0
	p.velocity.y = -p.jump_force
	for f in 150:
		await physics_frame
		top = minf(top, p.global_position.y)
		if f in [22, 44, 66]:
			if p.steam >= p.STEAM_COST:
				p.steam_jump()
			else:
				log_line("third burst refused: steam %.2f" % p.steam)
		if f == 40:
			await _grab(Rect2(p.global_position + Vector2(-80, -60), Vector2(160, 120)), "steam", -4)
	log_line("plain jump peaks ~%d px; with two steam bursts it reached %d px above the ground (bursts %d)" % [int(p.jump_force * p.jump_force / (2 * 980.0)), int(y0 - top), p.steam_jumps])
	await wait(1.0)
	log_line("landed: steam refilled to %.2f" % p.steam)


func quake_rec() -> void:
	# F4 over a cavern with loose ore and two soldiers in it.
	main._wave_timer = -9999.0
	await wait(0.3)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1480, 470)
	await tap(KEY_L)
	var tm := tilemap()
	var cells0 := tm.get_used_cells().size()
	for k in 8:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = Vector2(1400 + k * 20, 440)
		main.add_child(o)
	await wait(1.0)
	await tap(KEY_F4)
	for s in 10:
		await wait(1.0)
		if s in [3, 5]:
			await shot("quake_%d" % s)
	var q = main.quake
	log_line("quake: ceiling falls %d, tiles gone %d, jolts %d" % [q.falls if is_instance_valid(q) else -1, cells0 - tm.get_used_cells().size(), q.jolts if is_instance_valid(q) else -1])


func dreadnought_rec() -> void:
	# The Dreadnought cruises in, parks short of the dome, bombs and launches
	# ornithopters; then it's shot down and crashes.
	main._wave_timer = -9999.0
	await wait(0.3)
	var dn: Node2D = preload("res://scenes/dreadnought.tscn").instantiate()
	dn.global_position = Vector2(1900, -120)
	main.add_child(dn)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	Engine.time_scale = 2.0
	for s in 24:
		await wait(1.0)
		cam.global_position = Vector2(dn.global_position.x, -20)
		if s % 4 == 3:
			await shot("dread_%02d" % s)
	Engine.time_scale = 1.0
	log_line("state %d at x %d | bombs %d, ornithopters launched %d, dome %d" % [dn._state, dn.global_position.x, dn.bombs, dn.launched, main.dome_hp])
	dn.take_damage(999)
	for s in 6:
		await wait(0.6)
		if is_instance_valid(dn):
			cam.global_position = Vector2(dn.global_position.x, 0)
		if s % 2 == 1:
			await shot("dread_fall_%d" % s)
	var scrap := 0
	for o in get_nodes_in_group("ore"):
		scrap += 1 if o.get("kind") == "scrap" else 0
	log_line("crashed: %s, scrap %d" % [not is_instance_valid(dn), scrap])


func wave10_rec() -> void:
	# Wave 10 (the Dreadnought plus the pack) against the showcase defences.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.9, 0.9)
	cam.global_position = Vector2(1500, -60)
	await wait(4.0)
	main.wave_number = 9
	await tap(KEY_P)
	Engine.time_scale = 2.0
	var dn = null
	for s in 45:
		await wait(2.0)
		if dn == null:
			for n in get_nodes_in_group("enemies"):
				if n.get_script().resource_path.get_file() == "dreadnought.gd":
					dn = n
		var near := []
		for n in get_nodes_in_group("enemies"):
			if absf(n.global_position.x - 1200) < 260:
				near.append(n.get_script().resource_path.get_file().get_basename() + ":" + str(n.get("enemy_type")))
		log_line("t=%3d | near dome %s" % [s * 2, near])
		log_line("t=%3d | dreadnought %s | enemies %d | dome %d" % [s * 2, ("hp %d x %d state %d" % [dn.hp, dn.global_position.x, dn._state]) if is_instance_valid(dn) and not dn._dying else "down", get_nodes_in_group("enemies").size(), main.dome_hp])
		if s % 8 == 4:
			await shot("w10_%02d" % s)
		if main.dome_hp <= 0 or (dn != null and not is_instance_valid(dn)):
			break
	Engine.time_scale = 1.0


func wave5_rec() -> void:
	# Wave 10 (the Dreadnought plus the pack) against the showcase defences.
	var sc := preload("res://scripts/sandbox_showcase.gd")
	await wait(0.2)
	sc.build(main)
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.9, 0.9)
	cam.global_position = Vector2(1500, -60)
	await wait(4.0)
	main.wave_number = 4
	await tap(KEY_P)
	Engine.time_scale = 2.0
	var dn = null
	for s in 45:
		await wait(2.0)
		if dn == null:
			for n in get_nodes_in_group("enemies"):
				if n.get_script().resource_path.get_file() == "foundry.gd":
					dn = n
		var near := []
		for n in get_nodes_in_group("enemies"):
			if absf(n.global_position.x - 1200) < 260:
				near.append(n.get_script().resource_path.get_file().get_basename() + ":" + str(n.get("enemy_type")))
		log_line("t=%3d | near dome %s" % [s * 2, near])
		log_line("t=%3d | dreadnought %s | enemies %d | dome %d" % [s * 2, ("hp %d x %d flung %d hatched %d" % [dn.hp, dn.global_position.x, dn.flung, dn.hatched]) if is_instance_valid(dn) and not dn._dying else "down", get_nodes_in_group("enemies").size(), main.dome_hp])
		if s % 8 == 4:
			await shot("w5_%02d" % s)
		if main.dome_hp <= 0 or (dn != null and not is_instance_valid(dn)):
			break
	Engine.time_scale = 1.0
	log_line("left at the end: %s" % [get_nodes_in_group("enemies").map(func(n): return "%s@%s%s" % [n.get_script().resource_path.get_file().get_basename(), n.global_position.round(), " plugged" if n.get("plugged") else ""])])


func reclaim_rec() -> void:
	# The assembler's reclaimed-flask recipe: 3 scrap in, 1 science flask out.
	main._wave_timer = -9999.0
	await wait(0.3)
	var a: Node2D = preload("res://scenes/assembler.tscn").instantiate()
	a.global_position = Vector2(1450, 60)
	a.recipe = 5
	main.add_child(a)
	await wait(0.4)
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "scrap"
		o.global_position = a.global_position + Vector2(0, -80)
		main.add_child(o)
		await wait(0.4)
	await wait(9.0)
	var flasks := 0
	for o in get_nodes_in_group("ore"):
		flasks += 1 if o.get("kind") == "flask" else 0
	log_line("recipe '%s': made %d, flasks loose %d" % [a.RECIPES[5].name, a.made, flasks])


func dome_repair_rec() -> void:
	# A damaged dome with 5 ingots in stock repairs itself, one ingot a go.
	main._wave_timer = -9999.0
	await wait(0.3)
	main.damage_dome(30)
	for k in 5:
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.global_position = Vector2(1200, 40)
		main.add_child(ing)
		await wait(0.3)
	var r = main.get_node("Receiver") if main.has_node("Receiver") else main._receiver
	log_line("dome %d, stock %d" % [main.dome_hp, r.buffer])
	await wait(10.0)
	log_line("after 10 s: dome %d, stock %d, repaired %d" % [main.dome_hp, r.buffer, main.repaired])


func goals_rec() -> void:
	# Survival's goal chain: start survival, then satisfy each goal in turn.
	await wait(0.3)
	main.start_survival()
	await wait(0.5)
	var g = main.get_node("Goals")
	log_line("goal 1: %s" % g._label.text)
	await shot("goals_start")
	var tm := tilemap()
	var ore := Vector2i.ZERO
	for c in tm.get_used_cells():
		if tm.get_cell_atlas_coords(c).x in [2, 3]:
			ore = c
			break
	main.get_node("Player").global_position = tm.to_global(tm.map_to_local(ore)) + Vector2(0, -24)
	await wait(0.8)
	log_line("after walking up to ore: step %d" % g.step)
	var bs := get_root().get_node("BuildSystem")
	var m: Node2D = preload("res://scenes/miner.tscn").instantiate()
	m.global_position = tm.to_global(tm.map_to_local(ore))
	main.add_child(m)
	bs._placed_buildings.append(m)
	await wait(0.8)
	var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ing.global_position = Vector2(1400, 40)
	main.add_child(ing)
	await wait(0.8)
	var ing2: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ing2.global_position = Vector2(1200, 40)
	main.add_child(ing2)
	await wait(1.5)
	var t: Node2D = preload("res://scenes/funnel_turret.tscn").instantiate()
	t.global_position = Vector2(1500, 60)
	main.add_child(t)
	bs._placed_buildings.append(t)
	await wait(0.8)
	log_line("after the core loop: step %d of %d, waves started %s, label '%s'" % [g.step, g.GOALS.size(), main._waves_started, g._label.text])
	main._wave_timer = -9999.0
	# the later goals, each satisfied in turn
	main.wave_number = 4
	await wait(0.8)
	log_line("wave 4: step %d, crates %d, next '%s'" % [g.step, g.crates, g._label.text])
	await wait(2.6)
	await shot("goals_crate")
	preload("res://scripts/tech.gd").levels["lamps"] = 1
	await wait(0.8)
	var st: Node2D = preload("res://scenes/sentry.tscn").instantiate()
	st.global_position = Vector2(1500, 60)
	main.add_child(st)
	bs._placed_buildings.append(st)
	await wait(0.8)
	log_line("research + sentry: step %d, crates %d, next '%s'" % [g.step, g.crates, g._label.text])
	var ruin: Node2D = preload("res://scripts/ruins.gd").build(main, tm)
	main.get_node("Player").global_position = ruin.room.get_center()
	await wait(0.8)
	log_line("found the vault: step %d, next '%s'" % [g.step, g._label.text])
	for n in get_nodes_in_group("ruins"):
		if n.get_script() and n.get_script().resource_path.get_file() == "sentinel.gd":
			n.take_damage(99)
	await wait(0.6)
	for c in get_nodes_in_group("caches"):
		if c.get("relic"):
			c.open()
	await wait(0.8)
	main.wave_number = 6
	await wait(0.8)
	log_line("all done: step %d of %d, supply crates %d, label '%s'" % [g.step, g.GOALS.size(), g.crates, g._label.text])
	preload("res://scripts/tech.gd").levels.clear()


func starter_veins() -> void:
	# Shallow ore near the dome on a few seeds.
	await wait(0.3)
	for seed in [1, 2, 3, 4]:
		tilemap().clear()
		preload("res://scripts/world_gen.gd").generate(tilemap(), seed)
		var near := []
		for c in tilemap().get_used_cells():
			if tilemap().get_cell_atlas_coords(c).x in [2, 3] and c.y <= 14 and absi(c.x - 75) <= 32:
				near.append(c)
		log_line("seed %d: ore cells within 8 rows of the surface and 32 tiles of the dome: %d" % [seed, near.size()])


func dmg_numbers() -> void:
	main._wave_timer = -9999.0
	await wait(0.3)
	var so = _spawn(0, Vector2(1600, 60))
	so.speed = 0.0
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = Vector2(1600, 20)
	await wait(0.6)
	var s2 = _spawn(2, Vector2(1660, 60))
	s2.speed = 0.0
	await wait(0.3)
	for a in [2, 4, 3]:
		so.take_damage(a)
		await wait(0.12)
	s2.take_damage(5)
	await wait(0.1)
	log_line("bars node %s, recent hits %d" % [main.has_node("HealthBars"), preload("res://scripts/fx.gd").recent_hits.size()])
	await shot("dmg_numbers")


func crawler_rec() -> void:
	# Cave crawlers: scattered on a fresh world; the player walks under one.
	main._wave_timer = -9999.0
	await wait(0.3)
	preload("res://scenes/crawler.gd").scatter(main, tilemap())
	await wait(0.2)
	var cs := get_nodes_in_group("crawlers")
	log_line("crawlers placed: %d" % cs.size())
	var c: Node2D = cs[0]
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = c.global_position + Vector2(0, 10)
	await tap(KEY_L)
	# stand the player on the floor below it
	var tm := tilemap()
	var cell := tm.local_to_map(c.global_position)
	while tm.get_cell_source_id(cell + Vector2i.DOWN) == -1 and cell.y < 78:
		cell.y += 1
	p.global_position = tm.to_global(tm.map_to_local(cell)) + Vector2(80, 0)   # outside its trigger
	await wait(0.5)
	await shot("crawler_hanging")
	var hp0: int = p.hp
	p.global_position.x = c.global_position.x + 6
	await physics_frame
	log_line("player below the crawler by %d px" % int(p.global_position.y - c.global_position.y))
	for f in 120:
		await physics_frame
		if f == 20:
			await shot("crawler_drop")
	log_line("crawler state %d, player hp %d -> %d" % [c._state if is_instance_valid(c) else -1, hp0, p.hp])
