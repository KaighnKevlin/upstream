extends RefCounted
## Agent playtester harness: the game is driven one step at a time from files,
## so an outside agent plays it from screenshots with a person's inputs only.
## Starts on the title screen and presses F (Factory mode); START_SAVE=<file>
## then presses F9 to load that save (F5/F9 use <out>/save.json, never the
## game's own slot).
##
## Each step: screenshot <out>/step_NNN.png and <out>/state.json, then the
## game freezes (Engine.time_scale = 0) and polls <out>/cmd.json. The command
## runs, cmd.json is deleted, the game runs on for the command's "then"
## seconds (default 0.5), and the loop repeats. Every step is appended to
## <out>/steps.jsonl; REPLAY=<steps.jsonl> plays a logged run back instead of
## polling (and REPLAY_THEN=poll carries on live from where it ends). No cmd
## for IDLE seconds (default 600): the scenario quits.
##
## One small 1280x720-pixel window, off-screen. The real cursor is never
## moved: Pointer.fake makes the game read the mouse from Pointer.screen_pos,
## which the click/drag/move helpers set.
##
## Only what a person can do (screen pixels, 1280x720, origin top left):
##   {"action":"key",    "key":"D"}                     tap a key by name
##   {"action":"hold",   "key":"D", "sec":1.5}          hold a key down
##   ("D+J": a chord, the keys pressed together)
##   {"action":"click",  "x":640, "y":360, "button":"left"|"right"}
##   {"action":"drag",   "x":100, "y":100, "x2":300, "y2":200, "button":"left", "sec":0.4}
##   {"action":"move",   "x":640, "y":360}              hover the mouse
##   {"action":"scroll", "x":640, "y":360, "dir":"up"|"down", "n":1}
##   {"action":"zoom",   "dir":"in"|"out", "n":1}       the = / - keys
##   {"action":"wait",   "sec":2}
##   {"action":"quit"}
##   {"action":"seq",    "steps":[{...}, {...}]}        up to 10 commands in one turn
## Any command takes "then": seconds to let the game run after it, and
## "keys_down": ["Shift"] held through it. Waits are capped at 120 s.
##
## While the game runs, frames are grabbed every 0.25 s: a step that ran at
## least 1 s also gets step_NNN_motion.png, six of them in a 3x2 sheet.
## state.json also carries what a QA tester would watch: "perf" (fps, the
## worst frame, physics bodies, riders), "game" (researched techs, lab
## progress, the Beam's gauge, pieces placed) and "errors" (new ERROR lines
## in <out>/godot.log). perf.csv samples once a second for the whole run
## (a process_ms spike right after a step is the harness saving its PNG).

const Tech = preload("res://scripts/tech.gd")
const Lab = preload("res://scenes/lab.gd")
const Save = preload("res://scripts/sandbox_save.gd")
const MAX_SEC := 120.0
const FRAME_EVERY := 0.25
const SIZE := Vector2i(1280, 720)


static func run(t) -> void:
	var out: String = t.out_dir
	var cmd_path := out + "/cmd.json"
	var log_path := out + "/steps.jsonl"
	var replay: Array = []
	if OS.has_environment("REPLAY"):
		for line in FileAccess.get_file_as_string(OS.get_environment("REPLAY")).split("\n", false):
			var rec = JSON.parse_string(line)
			if rec is Dictionary and rec.get("cmd") is Dictionary and not rec.cmd.is_empty():
				replay.append(rec.cmd)
		t.log_line("replaying %d commands" % replay.size())
	# project.godot asks for fullscreen and wins over --windowed: leaving it
	# takes the macOS animation, then one small window off-screen
	for k in 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await t.wait(0.6)
		DisplayServer.window_set_size(SIZE)
		DisplayServer.window_set_position(Vector2i(4000, 4000))
		await t.wait(0.3)
	Pointer.fake = true
	Pointer.screen_pos = Vector2(SIZE) / 2.0
	t.log_line("window %s at %s" % [DisplayServer.window_get_size(), DisplayServer.window_get_position()])
	DirAccess.remove_absolute(cmd_path)
	FileAccess.open(log_path, FileAccess.WRITE).close()
	Save.path = out + "/save.json"
	if OS.has_environment("START_SAVE"):
		DirAccess.copy_absolute(OS.get_environment("START_SAVE"), Save.path)
	var live := {"frames": [], "worst_ms": 0.0, "fps_sum": 0.0, "fps_n": 0, "log_at": 0, "on": true}
	_perf(t, out, live)
	_hitches(t, live)
	if OS.get_environment("FILM") != "0":   # FILM=0: clean perf numbers, no motion sheets
		_film(t, live)

	# the way a player starts: the title screen, then F (and F9 for a save)
	t.main._show_title()
	await t.wait(1.0)
	await t.tap(KEY_F)
	await t.wait(1.5)
	if OS.has_environment("START_SAVE"):
		await t.tap(KEY_F9)
		await t.wait(2.0)

	var step := 0
	var result := "start: title screen, pressed F"
	var cmd: Dictionary = {}
	var t0 := Time.get_ticks_msec()
	var idle_limit := float(OS.get_environment("IDLE")) if OS.has_environment("IDLE") else 600.0   # s without a cmd
	var game_s := 2.5   # the title and the F above
	while true:
		var shot := await _shot(t, step)
		var motion := _sheet(t, step, live)
		var st := _state(t, step, result, shot, game_s, live)
		st["motion"] = motion
		_write(out + "/state.json", JSON.stringify(st, "  "))
		var rec := {"step": step, "cmd": cmd, "result": result, "shot": shot,
			"game_s": st.game_s, "status": st.status, "perf": st.perf, "researched": st.game.researched,
			"errors": st.errors.size()}
		var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(rec))
		f.close()
		t.log_line("step %d: %s -> %s" % [step, JSON.stringify(cmd), result])

		# freeze and wait for the next command
		Engine.time_scale = 0.0
		cmd = {}
		var waited := 0.0
		if not replay.is_empty():
			cmd = replay.pop_front()
		elif OS.has_environment("REPLAY") and OS.get_environment("REPLAY_THEN") != "poll":
			cmd = {"action": "quit"}
		while cmd.is_empty():
			if FileAccess.file_exists(cmd_path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(cmd_path))
				if parsed is Dictionary:
					cmd = parsed
					DirAccess.remove_absolute(cmd_path)
					break
				# half-written, or junk: give it a moment, then report it
				if waited > 2.0:
					DirAccess.remove_absolute(cmd_path)
					cmd = {"action": "invalid"}
					break
			await t.create_timer(0.1, true, false, true).timeout
			waited += 0.1
			if waited > idle_limit:
				t.log_line("no cmd for %d s: giving up" % int(idle_limit))
				cmd = {"action": "quit"}
		Engine.time_scale = 1.0
		if cmd.get("action") == "quit":
			t.log_line("quit after %d steps, %.0f s wall" % [step, (Time.get_ticks_msec() - t0) / 1000.0])
			break
		live.frames.clear()
		live.worst_ms = 0.0
		live.fps_sum = 0.0
		live.fps_n = 0
		var run_from := Time.get_ticks_msec()
		var then := clampf(float(cmd.get("then", 0.5)), 0.0, MAX_SEC)
		result = await _do(t, cmd)
		await t.wait(then)
		game_s += (Time.get_ticks_msec() - run_from) / 1000.0
		step += 1
	live.on = false
	Engine.time_scale = 1.0
	Save.path = Save.PATH
	Pointer.fake = false


## Grabs a small frame every FRAME_EVERY s of running game (not while frozen).
static func _film(t, live: Dictionary) -> void:
	while live.on:
		await t.create_timer(FRAME_EVERY, true, false, true).timeout
		if Engine.time_scale > 0.0 and DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)   # macOS doesn't draw an off-screen window
			var img: Image = t.root.get_texture().get_image()
			img.resize(426, 240, Image.INTERPOLATE_BILINEAR)
			live.frames.append(img)
			if live.frames.size() > 480:   # 2 min of frames
				live.frames.pop_front()


## Six frames of the last step, evenly spread, in a 3x2 sheet.
static func _sheet(t, step: int, live: Dictionary) -> String:
	var fr: Array = live.frames
	if fr.size() < 4:
		return ""
	var sheet := Image.create(1278, 480, false, Image.FORMAT_RGB8)
	for i in 6:
		var img: Image = fr[roundi(i * (fr.size() - 1) / 5.0)]
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 426, 240), Vector2i((i % 3) * 426, (i / 3) * 240))
	var name := "step_%03d_motion.png" % step
	sheet.save_png(t.out_dir + "/" + name)
	return name


## Real frame times while the game runs: the worst one each step.
static func _hitches(t, live: Dictionary) -> void:
	var last := Time.get_ticks_usec()
	while live.on:
		await t.process_frame
		var now := Time.get_ticks_usec()
		if Engine.time_scale > 0.0:
			live.worst_ms = maxf(live.worst_ms, (now - last) / 1000.0)
		last = now


## perf.csv: one row a second of running game.
static func _perf(t, out: String, live: Dictionary) -> void:
	var f := FileAccess.open(out + "/perf.csv", FileAccess.WRITE)
	f.store_line("wall_s,fps,process_ms,physics_ms,objects,nodes,bodies_2d,riders,loose_ore,draw_calls")
	f.close()
	while live.on:
		await t.create_timer(1.0, true, false, true).timeout
		if Engine.time_scale <= 0.0:
			continue
		var fps := Engine.get_frames_per_second()
		live.fps_sum += fps
		live.fps_n += 1
		var p := _perf_now(t)
		f = FileAccess.open(out + "/perf.csv", FileAccess.READ_WRITE)
		f.seek_end()
		f.store_line("%.1f,%d,%.2f,%.2f,%d,%d,%d,%d,%d,%d" % [Time.get_ticks_msec() / 1000.0, fps,
			p.process_ms, p.physics_ms, p.objects, p.nodes, p.bodies_2d, p.riders, p.loose_ore, p.draw_calls])
		f.close()


static func _perf_now(t) -> Dictionary:
	var net = t.main.get_meta("track_net") if t.main.has_meta("track_net") else null
	return {
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"bodies_2d": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"riders": net.rider_count() if net != null and is_instance_valid(net) else 0,
		"loose_ore": t.get_nodes_in_group("ore").size(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}


## New ERROR / SCRIPT ERROR lines in godot.log since the last step.
static func _errors(t, live: Dictionary) -> Array:
	var f := FileAccess.open(t.out_dir + "/godot.log", FileAccess.READ)
	if f == null:
		return []
	f.seek(live.log_at)
	var lines := f.get_buffer(f.get_length() - live.log_at).get_string_from_utf8().split("\n", false)
	live.log_at = f.get_length()
	var out := []
	for i in lines.size():
		if lines[i].contains("ERROR"):
			var at := lines[i + 1].strip_edges() if i + 1 < lines.size() and lines[i + 1].strip_edges().begins_with("at:") else ""
			out.append((lines[i] + "  " + at).strip_edges())
	if out.size() > 20:
		out = out.slice(0, 20) + ["... %d more" % (out.size() - 20)]
	return out


static func _write(path: String, s: String) -> void:
	# write then rename, so a reader never sees half a file
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	f.store_string(s)
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)


static func _shot(t, step: int) -> String:
	await t.shot("agent")
	var name := "step_%03d.png" % step
	var src := "%s/%02d_agent.png" % [t.out_dir, t.shot_n]
	# shots in the same pixels as the commands (the window may be HiDPI)
	var img := Image.load_from_file(src)
	if img.get_size() != Vector2i(1280, 720):
		img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
	img.save_png(t.out_dir + "/" + name)
	DirAccess.remove_absolute(src)
	return name


static func _state(t, step: int, result: String, shot: String, game_s: float, live: Dictionary) -> Dictionary:
	var st := {"step": step, "shot": shot, "game_s": snappedf(game_s, 0.1),
		"last_result": result, "status": t.status()}
	var pf := _perf_now(t)
	pf["fps_avg"] = roundi(live.fps_sum / live.fps_n) if live.fps_n > 0 else Engine.get_frames_per_second()
	pf["worst_frame_ms"] = snappedf(live.worst_ms, 0.1)
	pf.process_ms = snappedf(pf.process_ms, 0.01)
	pf.physics_ms = snappedf(pf.physics_ms, 0.01)
	st["perf"] = pf
	var researched := []
	for tech in Tech.TREE:
		if Tech.researched(tech.id):
			researched.append(tech.id)
	var beam := {}
	for b in t.get_nodes_in_group("beams"):
		beam = {"per_second": b.per_second, "usage": 0.0 if is_nan(b.usage) else snappedf(b.usage, 0.01), "waiting": b.waiting}
	var bs = t.main.get_node("/root/BuildSystem")
	st["game"] = {"factory": t.main.factory, "researched": researched, "lab_progress": Lab.tree_progress.duplicate(true),
		"beam": beam, "pieces": bs._placed_buildings.filter(func(b): return is_instance_valid(b)).size()}
	st["errors"] = _errors(t, live)
	for kv in t.status().split(" ", false):
		var p: PackedStringArray = kv.split("=")
		if p.size() == 2:
			st[p[0]] = p[1] if p[1].begins_with("(") else int(p[1])
	return st


static func _keycode(name: String) -> Key:
	var k := OS.find_keycode_from_string(name)
	if k == KEY_NONE and name.length() == 1:
		k = OS.find_keycode_from_string(name.to_upper())
	return k


static func _button(cmd: Dictionary) -> MouseButton:
	return MOUSE_BUTTON_RIGHT if str(cmd.get("button", "left")) == "right" else MOUSE_BUTTON_LEFT


static func _do(t, cmd: Dictionary) -> String:
	var held: Array[Key] = []
	for n in cmd.get("keys_down", []):
		var k := _keycode(str(n))
		if k == KEY_NONE:
			return "unknown key '%s'" % n
		held.append(k)
		t.key(k, true)
	var r := await _do_one(t, cmd)
	for k in held:
		t.key(k, false)
	return r


static func _do_one(t, cmd: Dictionary) -> String:
	var a := str(cmd.get("action", ""))
	var sec := clampf(float(cmd.get("sec", 0.5)), 0.0, MAX_SEC)
	var at := Vector2(float(cmd.get("x", 640)), float(cmd.get("y", 360)))
	match a:
		"key", "hold":
			var keys: Array[Key] = []
			for n in str(cmd.get("key", "")).split("+", false):
				var k := _keycode(n.strip_edges())
				if k == KEY_NONE:
					return "unknown key '%s'" % n
				keys.append(k)
			if keys.is_empty():
				return "no key given"
			for k in keys:
				t.key(k, true)
			if a == "key":
				await t.physics_frame
				await t.physics_frame
			else:
				await t.wait(sec)
			for k in keys:
				t.key(k, false)
			await t.physics_frame
			return "ok"
		"click":
			await t.click_screen(at, _button(cmd))
			return "ok"
		"drag":
			await t.drag_screen(at, Vector2(float(cmd.get("x2", at.x)), float(cmd.get("y2", at.y))), _button(cmd), sec)
			return "ok"
		"move":
			await t.move_screen(at)
			return "ok"
		"scroll":
			var b := MOUSE_BUTTON_WHEEL_DOWN if str(cmd.get("dir", "down")) == "down" else MOUSE_BUTTON_WHEEL_UP
			for i in clampi(int(cmd.get("n", 1)), 1, 10):
				await t.click_screen(at, b)
			return "ok"
		"zoom":
			var k := KEY_EQUAL if str(cmd.get("dir", "in")) == "in" else KEY_MINUS
			for i in clampi(int(cmd.get("n", 1)), 1, 10):
				await t.tap(k)
			return "ok"
		"wait":
			await t.wait(sec)
			return "ok"
		"seq":
			var steps: Array = cmd.get("steps", [])
			if steps.size() > 10:
				return "seq: at most 10 steps"
			var res := []
			for sub in steps:
				if not sub is Dictionary or sub.get("action") in ["seq", "quit"]:
					res.append("skipped")
					continue
				res.append(await _do(t, sub))
				await t.wait(clampf(float(sub.get("then", 0.1)), 0.0, MAX_SEC))
			return "seq: " + ", ".join(res)
		"invalid":
			return "cmd.json was not valid JSON"
	return "unknown action '%s'" % a
