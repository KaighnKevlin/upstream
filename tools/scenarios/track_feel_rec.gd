extends RefCounted
## Track net feel: the same run built twice, one above the other: physics
## chutes on top, track rails below. A steep drop, a near-level stretch, a
## gentle downhill, an uphill kick off the end. The same marble is let go
## at rest at the top of each; logs time and speed at matching points along
## the run, and how it leaves the kick. Copper, then iron.

const MW = preload("res://scripts/marble_works.gd")
# the run, relative to its top: drop, level, gentle, kick
const RUN := [Vector2(0, 0), Vector2(70, 70), Vector2(230, 72), Vector2(430, 92), Vector2(470, 80)]
const CHECK := [1015.0, 1060.0, 1110.0, 1170.0, 1250.0, 1330.0, 1375.0, 1415.0]
const TOP_PHYS := Vector2(960, 180)
const TOP_TRACK := Vector2(960, 360)


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var rails := []
	for i in RUN.size() - 1:
		MW._piece(t.main, "res://scenes/chute.tscn", TOP_PHYS + RUN[i], {"end_offset": RUN[i + 1] - RUN[i], "has_lip": false})
		rails.append(MW._piece(t.main, "res://scenes/track_rail.tscn", TOP_TRACK + RUN[i], {"end_offset": RUN[i + 1] - RUN[i]}))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1210, 330)
	await t.wait(0.3)
	var net: Node = rails[0]._net
	var errs := []
	for kind in ["copper", "iron"]:
		var r: float = preload("res://scenes/ore.gd").KINDS[kind].radius
		var t0: Vector2 = (RUN[1] - RUN[0]).normalized()
		var n0 := Vector2(t0.y, -t0.x)
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = kind
		o.lifetime = 1.0e9
		o.global_position = TOP_PHYS + t0 * 10.0 + n0 * r
		t.main.add_child(o)
		net.add_rider(rails[0].track, 10.0, 0.0, kind)
		var ph := {}   # checkpoint -> [time, speed]
		var tk := {}
		var ph_exit := Vector2.ZERO
		var tk_exit := Vector2.ZERO
		var ph_roll := []
		var start_ms := Time.get_ticks_msec()
		var released0: int = net.released
		var frames := 0
		var tk_last_x := 0.0
		var ph_last_x := o.global_position.x
		var shot_taken := false
		while frames < 60 * 6:
			await t.main.get_tree().physics_frame
			frames += 1
			var ft := frames / 60.0
			# physics marble
			if is_instance_valid(o):
				var x := o.global_position.x
				for c in CHECK:
					if ph_last_x < c and x >= c and not ph.has(c):
						ph[c] = [ft, o.linear_velocity.length()]
						ph_roll.append(absf(o.angular_velocity) * r / maxf(o.linear_velocity.length(), 1.0))
				if ph_last_x < TOP_PHYS.x + RUN[4].x and x >= TOP_PHYS.x + RUN[4].x:
					ph_exit = o.linear_velocity
				ph_last_x = x
			# track marble (a rider, then physics ore once it's off the kick)
			var rd: Array = net.riders_near(TOP_TRACK + Vector2(240, 40), 400.0)
			var x2 := tk_last_x
			var sp := 0.0
			if not rd.is_empty():
				x2 = rd[0].pos.x
				sp = absf(rd[0].v)
			elif net.released > released0 and is_instance_valid(net.last_released):
				x2 = net.last_released.global_position.x
				sp = net.last_released.linear_velocity.length()
				if tk_exit == Vector2.ZERO:
					tk_exit = net.last_released.linear_velocity
			if OS.has_environment("TRK_DEBUG") and frames % 6 == 0 and not rd.is_empty():
				t.log_line("dbg f%d x %.1f v %.1f track %d" % [frames, x2, sp, rd[0].track.id])
			for c in CHECK:
				if tk_last_x < c and x2 >= c and not tk.has(c):
					tk[c] = [ft, sp]
			tk_last_x = x2
			if kind == "copper" and not shot_taken and ft >= 0.9:
				shot_taken = true
				await t.shot("feel_mid_run")
		t.log_line("feel %s: point   physics t/speed   |  track t/speed   | speed diff" % kind)
		for c in CHECK:
			if ph.has(c) and tk.has(c):
				var d: float = (tk[c][1] - ph[c][1]) / maxf(ph[c][1], 1.0) * 100.0
				errs.append(absf(d))
				t.log_line("  x=%4d   %.2fs %4d px/s   |  %.2fs %4d px/s  | %+5.1f%%" % [c, ph[c][0], ph[c][1], tk[c][0], tk[c][1], d])
			else:
				t.log_line("  x=%4d   phys %s  track %s" % [c, ph.get(c, "-"), tk.get(c, "-")])
		t.log_line("  kick exit: physics (%d,%d) %d px/s  track (%d,%d) %d px/s | physics roll ratio w*r/v %s" % [
			ph_exit.x, ph_exit.y, ph_exit.length(), tk_exit.x, tk_exit.y, tk_exit.length(),
			str(ph_roll.map(func(v): return snappedf(v, 0.01)))])
		if is_instance_valid(o):
			o.queue_free()
		if is_instance_valid(net.last_released):
			net.last_released.queue_free()
		await t.wait(0.3)
	errs.sort()
	t.log_line("feel: speed diff at checkpoints: median %.1f%%, max %.1f%% (n=%d)" % [errs[errs.size() / 2] if errs.size() > 0 else -1.0, errs.max() if errs.size() > 0 else -1.0, errs.size()])
	await t.shot("feel_end")
