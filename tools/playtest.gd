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
