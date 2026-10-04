extends RefCounted
## Blind playtester harness: the game is driven one step at a time from files,
## so an outside agent can play it from screenshots alone, the way a person
## would. Starts on the title screen and presses F (Factory mode).
##
## Each step: screenshot <out>/step_NNN.png and <out>/state.json, then the
## game freezes (Engine.time_scale = 0) and polls <out>/cmd.json. The command
## runs, cmd.json is deleted, the game runs on for the command's "then"
## seconds (default 0.5), and the loop repeats. Every step is appended to
## <out>/steps.jsonl; REPLAY=<steps.jsonl> plays a logged run back instead of
## polling. No cmd for 10 minutes: the scenario quits.
##
## The window is one small 1280x720-pixel window in the screen's bottom right
## corner, not off-screen: placing pieces reads the real OS cursor, which
## macOS won't move into an off-screen window. A mouse command borrows the
## cursor for the command (and the shot after it) and then puts it back.
##
## Only what a person can do (screen pixels, 1280x720, origin top left):
##   {"action":"key",    "key":"D"}                     tap a key by name
##   {"action":"hold",   "key":"D", "sec":1.5}          hold a key down
##   {"action":"click",  "x":640, "y":360, "button":"left"|"right"}
##   {"action":"drag",   "x":100, "y":100, "x2":300, "y2":200, "button":"left", "sec":0.4}
##   {"action":"move",   "x":640, "y":360}              hover the mouse
##   {"action":"scroll", "x":640, "y":360, "dir":"up"|"down", "n":1}
##   {"action":"zoom",   "dir":"in"|"out", "n":1}       the = / - keys
##   {"action":"wait",   "sec":2}
##   {"action":"quit"}
## Any command takes "then": seconds to let the game run after it (max 30).

const Tech = preload("res://scripts/tech.gd")
const IDLE_LIMIT := 600.0   # s without a cmd before giving up
const MAX_SEC := 30.0
const MOUSE := ["click", "drag", "move", "scroll"]
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
	# takes the macOS animation, then one small window in the corner
	for k in 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await t.wait(0.6)
		var usable := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_size(SIZE)
		DisplayServer.window_set_position(usable.end - SIZE)
		await t.wait(0.3)
	t.log_line("window %s at %s" % [DisplayServer.window_get_size(), DisplayServer.window_get_position()])
	DirAccess.remove_absolute(cmd_path)
	FileAccess.open(log_path, FileAccess.WRITE).close()

	# the way a player starts: the title screen, then F
	t.main._show_title()
	await t.wait(1.0)
	await t.tap(KEY_F)
	await t.wait(1.5)

	var step := 0
	var result := "start: title screen, pressed F"
	var cmd: Dictionary = {}
	var t0 := Time.get_ticks_msec()
	var game_s := 2.5   # the title and the F above
	var agent_mouse := Vector2(-1, -1)   # where the player's mouse is
	var user_mouse := Vector2i(-1, -1)   # Kaighn's cursor, while it's borrowed
	while true:
		if cmd.get("action") in MOUSE and user_mouse.x < 0:
			user_mouse = DisplayServer.mouse_get_position()
			t.root.warp_mouse(agent_mouse)
			await t.process_frame
			await t.process_frame
		var shot := await _shot(t, step)
		if user_mouse.x >= 0:
			Input.warp_mouse(Vector2(user_mouse - DisplayServer.window_get_position()))
			user_mouse = Vector2i(-1, -1)
		var st := _state(t, step, result, shot, game_s)
		_write(out + "/state.json", JSON.stringify(st, "  "))
		var rec := {"step": step, "cmd": cmd, "result": result, "shot": shot,
			"game_s": st.game_s, "status": st.status, "goal_routing": Tech.researched("routing")}
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
		elif OS.has_environment("REPLAY"):
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
			if waited > IDLE_LIMIT:
				t.log_line("no cmd for %d s: giving up" % int(IDLE_LIMIT))
				cmd = {"action": "quit"}
		Engine.time_scale = 1.0
		if cmd.get("action") == "quit":
			t.log_line("quit after %d steps, %.0f s wall" % [step, (Time.get_ticks_msec() - t0) / 1000.0])
			break
		var run_from := Time.get_ticks_msec()
		var then := clampf(float(cmd.get("then", 0.5)), 0.0, MAX_SEC)
		if cmd.get("action") in MOUSE:
			user_mouse = DisplayServer.mouse_get_position()
			agent_mouse = Vector2(float(cmd.get("x2", cmd.get("x", 640))), float(cmd.get("y2", cmd.get("y", 360)))) \
				if cmd.get("action") == "drag" else Vector2(float(cmd.get("x", 640)), float(cmd.get("y", 360)))
		result = await _do(t, cmd)
		if user_mouse.x >= 0 and then > 1.0:   # don't hold the cursor through a long wait
			Input.warp_mouse(Vector2(user_mouse - DisplayServer.window_get_position()))
			user_mouse = Vector2i(-1, -1)
		await t.wait(then)
		game_s += (Time.get_ticks_msec() - run_from) / 1000.0
		step += 1
	Engine.time_scale = 1.0


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


static func _state(t, step: int, result: String, shot: String, game_s: float) -> Dictionary:
	var st := {"step": step, "shot": shot, "game_s": snappedf(game_s, 0.1),
		"last_result": result, "status": t.status()}
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
	var a := str(cmd.get("action", ""))
	var sec := clampf(float(cmd.get("sec", 0.5)), 0.0, MAX_SEC)
	var at := Vector2(float(cmd.get("x", 640)), float(cmd.get("y", 360)))
	match a:
		"key", "hold":
			var k := _keycode(str(cmd.get("key", "")))
			if k == KEY_NONE:
				return "unknown key '%s'" % cmd.get("key", "")
			if a == "key":
				await t.tap(k)
			else:
				await t.hold(k, sec)
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
		"invalid":
			return "cmd.json was not valid JSON"
	return "unknown action '%s'" % a
