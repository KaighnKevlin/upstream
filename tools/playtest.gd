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
	# Same working chain as economy(): miner → laser → 2 trampolines.
	var ore := find_ore_near(1200)
	var ore_pos := tile_center(ore)
	var tm := tilemap()
	for y in range(6, ore.y):
		tm.set_cell(Vector2i(ore.x, y), -1)
	var p: CharacterBody2D = main.get_node("Player")
	zoom(0.5)
	await wait(0.2)
	for step in [[KEY_2, 0], [KEY_3, -48], [KEY_1, -130], [KEY_1, -260]]:
		await tap(step[0])
		await click_world(ore_pos + Vector2(0, step[1]))
		await tap(KEY_Q)
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

