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
	var lift: Node2D = null
	for n in get_nodes_in_group("showcase"):
		if n.has_method("_loaded"):
			turret = n
		if "lift_speed" in n:
			lift = n
	log_line("after 9s: ingots in dome %d -> %d, turret loaded %d, lift holding %d" % [in0, rx.buffer, turret._loaded().size() if turret else -1, lift._held_items.size() if lift else -1])
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1060, 10)
	await wait(0.3)
	await shot("showcase_west")
	cam.global_position = Vector2(1480, 10)
	await wait(0.3)
	await shot("showcase_east")


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
