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
		# scenarios start clean: drop the sandbox showcase built on the old world
		preload("res://scripts/sandbox_showcase.gd").clear(main)
		var decor := main.get_node_or_null("CaveDecor")
		if decor:  # re-dress the regenerated caves
			for c in decor.get_children():
				c.free()
			decor._by_support.clear()
			decor.setup(tilemap())
		main.get_node("Player").global_position = Vector2(1200, 150)
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
	var e: CharacterBody2D = _spawn(2, Vector2(1760, 60))
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
