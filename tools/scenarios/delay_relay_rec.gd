extends RefCounted
## Delay relay. Bench, all at once: relays at 1 s, 3 s and 5 s each fired
## once; a 1 s relay fired twice 0.6 s apart (the wait restarts: one output,
## 1.6 s after the first signal); two 1 s relays wired in a ring (a clock:
## about one output a second, never faster); one wired back onto itself
## (fires once, never itself). Logs when each fired. A click on the face
## cycles the setting. Then a machine: a tally wheel (every 3) on one line
## wired to a 1 s relay, the relay wired to a sluice holding back a second
## line; each sluice opening should come 1 s after the wheel fires.

const RELAY := "res://scenes/delay_relay.tscn"


static func _click(t, world: Vector2) -> void:
	var screen: Vector2 = t.main.get_viewport().get_canvas_transform() * world
	Input.warp_mouse(screen)
	await t.wait(0.05)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)
	await t.wait(0.05)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await t.wait(0.1)


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.7, 1.7)
	cam.global_position = Vector2(1290, 360)

	# ── bench: a row of single-shot relays (wires down into the floor, clear
	# of everything), a ring of two above, and one wired onto itself ──
	var named := {}
	named["1s"] = MW._piece(t.main, RELAY, Vector2(960, 420), {"mode": 0, "wire_to": Vector2(0, 160)})
	named["3s"] = MW._piece(t.main, RELAY, Vector2(1120, 420), {"mode": 1, "wire_to": Vector2(0, 160)})
	named["5s"] = MW._piece(t.main, RELAY, Vector2(1280, 420), {"mode": 2, "wire_to": Vector2(0, 160)})
	named["1s x2"] = MW._piece(t.main, RELAY, Vector2(1440, 420), {"mode": 0, "wire_to": Vector2(0, 160)})
	var ra: Node2D = MW._piece(t.main, RELAY, Vector2(1100, 200), {"mode": 0})
	var rb: Node2D = MW._piece(t.main, RELAY, Vector2(1400, 200), {"mode": 0})
	ra.wire_to = rb.global_position - ra.global_position
	rb.wire_to = ra.global_position - rb.global_position
	named["ring A"] = ra
	named["ring B"] = rb
	named["self"] = MW._piece(t.main, RELAY, Vector2(1600, 250), {"mode": 0, "wire_to": Vector2(4, 4)})
	await t.wait(0.1)
	var t0: float = Time.get_ticks_msec() / 1000.0
	for k in ["1s", "3s", "5s", "1s x2", "ring A", "self"]:
		named[k].trigger()
	var times := {}
	var seen := {}
	for k in named:
		times[k] = []
		seen[k] = 0
	var again := false
	for i in 112:
		await t.wait(0.05)
		var now: float = Time.get_ticks_msec() / 1000.0 - t0
		if not again and now >= 0.6:
			again = true
			named["1s x2"].trigger()
		for k in named:
			while named[k].fired > seen[k]:
				seen[k] += 1
				times[k].append("%.2f" % now)
		if i == 50:
			await t.shot("delay_bench")
	var out := []
	for k in named:
		out.append("%s fired at %s" % [k, times[k]])
	t.log_line("delay bench (s after the signal): %s" % " | ".join(out))
	t.log_line("delay bench: '1s x2' took %d signals, %d restart, %d output; 'self' took %d signal(s), fired %d" % [named["1s x2"].triggered, named["1s x2"].restarts, named["1s x2"].fired, named["self"].triggered, named["self"].fired])
	var d: Node2D = named["1s"]
	var ms := [d.mode]
	for c in 3:
		await _click(t, d.global_position)
		ms.append(d.mode)
	t.log_line("delay clicks on the face: mode %s (1/3/5 s)" % [ms])
	for k in named:
		named[k].queue_free()
	await t.wait(0.2)

	# ── machine ──
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1010, 300), {"mode": 0, "limit": 10})
	MW._chute(t.main, Vector2(995, 330), Vector2(1140, 370))
	var ty: Node2D = MW._piece(t.main, "res://scenes/tally.tscn", Vector2(1080, 342), {"mode": 0})
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1400, 300), {"mode": 0, "limit": 12, "kinds": ["iron"]})
	MW._chute(t.main, Vector2(1385, 330), Vector2(1560, 400))
	var sl: Node2D = MW._piece(t.main, "res://scenes/sluice.tscn", Vector2(1530, 388), {"side": 1.0})
	var dr: Node2D = MW._piece(t.main, RELAY, Vector2(1260, 240), {"mode": 0})
	await t.wait(0.1)
	ty.wire_to = dr.global_position - ty.global_position
	dr.wire_to = sl.global_position - dr.global_position
	var tf := []
	var so := []
	var f0 := 0
	var o0 := 0
	var t1: float = Time.get_ticks_msec() / 1000.0
	var shot := false
	for i in 200:
		await t.wait(0.05)
		var now: float = Time.get_ticks_msec() / 1000.0 - t1
		if ty.fired > f0:
			f0 = ty.fired
			tf.append(now)
		if sl.opened > o0:
			o0 = sl.opened
			so.append(now)
		if dr.waiting and not shot and dr._left < 0.5:
			shot = true
			await t.shot("delay_machine_winding")
	var gaps := []
	for k in mini(tf.size(), so.size()):
		gaps.append("%.2f" % (so[k] - tf[k]))
	t.log_line("delay machine: wheel fired %d at %s | sluice opened %d | gap wheel->sluice %s s | released %d" % [ty.fired, tf.map(func(x): return "%.2f" % x), sl.opened, gaps, sl.released])
	await t.shot("delay_machine_end")
