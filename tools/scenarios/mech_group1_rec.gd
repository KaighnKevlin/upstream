extends RefCounted
## The group-1 track pieces as marble-machine mechanisms, each on its own
## short line at a readable zoom (2.5), marbles passing, shot mid-action:
## the flip-flop's see-saw mid-tip (its detent spring squashed), the
## splitter's T rocking over, the escapement's pallet with B up and A down
## (and the other way), the points' ball lever mid-throw, the overflow gate's
## flap yielded with its counterweight up. Logs each piece's counts and
## where it sits on screen (crop boxes for close-ups: CROP lines).

const MW = preload("res://scripts/marble_works.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(1300, 540)
	var P := func(path: String, at: Vector2, props := {}) -> Node2D:
		return MW._piece(t.main, "res://scenes/%s.tscn" % path, at, props)
	var bin := func(at: Vector2, cap := 90) -> Node2D:
		return MW._piece(t.main, "res://scenes/track_bin.tscn", at, {"cap": cap})
	# a source and a chute down to `end`
	var line := func(x: float, end: Vector2, mode := 1) -> Node2D:
		var src: Node2D = P.call("track_source", Vector2(x, 200), {"mode": mode, "kinds": ["copper", "iron"]})
		MW._chute(t.main, src.spout_end(), end)
		return src

	# 1. flip-flop
	var ff_feed := Vector2(1000, 260)
	line.call(930, ff_feed)
	var ff: Node2D = P.call("rocker", ff_feed + Vector2(16, 28))
	MW._chute(t.main, ff.branch_end(0), Vector2(975, 350))
	MW._chute(t.main, ff.branch_end(1), Vector2(1045, 350))
	bin.call(Vector2(975, 350))
	bin.call(Vector2(1045, 350))
	# 2. splitter
	var sp_feed := Vector2(1150, 260)
	line.call(1080, sp_feed)
	var sp: Node2D = P.call("splitter", sp_feed + Vector2(16, 28))
	MW._chute(t.main, sp.branch_end(0), Vector2(1125, 350))
	MW._chute(t.main, sp.branch_end(1), Vector2(1195, 350))
	bin.call(Vector2(1125, 350))
	bin.call(Vector2(1195, 350))
	# 3. escapement (1.2 s) part way down a chute, into a bin
	var es_src: Node2D = P.call("track_source", Vector2(1215, 200), {"mode": 0, "kinds": ["copper", "iron"]})
	var es_end := Vector2(1345, 262)
	MW._chute(t.main, es_src.spout_end(), es_end)
	var es_at: Vector2 = es_src.spout_end().lerp(es_end, 0.62)
	var es: Node2D = P.call("escapement", es_at, {"mode": 1, "side": 1.0})
	bin.call(es_end + Vector2(0, 0))
	# 4. points, thrown by the scenario every 1.6 s
	var pt_feed := Vector2(1445, 260)
	line.call(1375, pt_feed)
	var pt: Node2D = P.call("points", pt_feed + Vector2(16, 28))
	MW._chute(t.main, pt.branch_end(0), Vector2(1420, 350))
	MW._chute(t.main, pt.branch_end(1), Vector2(1490, 350))
	bin.call(Vector2(1420, 350))
	bin.call(Vector2(1490, 350))
	# 5. overflow gate: primary right into a small bin (fills, backs up)
	var og_feed := Vector2(1545, 260)
	line.call(1500, og_feed, 0)
	var og: Node2D = P.call("overflow_gate", og_feed + Vector2(16, 28), {"side": 1.0, "watch": Vector2(64, -46), "full": 4})
	var og_p: Node2D = bin.call(og.global_position + Vector2(64, 62), 4)
	var og_pc = MW._chute(t.main, og.branch_end(1), og.global_position + Vector2(64, 62))
	MW._chute(t.main, og.branch_end(0), Vector2(1525, 350))
	bin.call(Vector2(1525, 350))

	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.1, 1.1)
	cam.global_position = Vector2(1260, 280)
	await t.wait(3.0)
	await t.shot("overview")
	t.log_line("linked: flip-flop %s splitter %s escapement %s/%s points %s overflow %s" % [
		ff._fork.linked(), sp._fork.linked(), es._mark.linked(), es._mark_a.linked(), pt._fork.linked(), og._fork.linked()])
	cam.zoom = Vector2(2.5, 2.5)

	var crop := func(label: String, n: Node2D, box: Rect2) -> void:
		var a: Vector2 = t.world_to_screen(n.global_position + box.position)
		var b: Vector2 = t.world_to_screen(n.global_position + box.end)
		t.log_line("CROP %s %d %d %d %d" % [label, a.x, a.y, b.x, b.y])
	var watch_for := func(label: String, n: Node2D, box: Rect2, cond: Callable, limit: float) -> bool:
		var el := 0.0
		while el < limit:
			await t.physics_frame
			el += 1.0 / 60.0
			if cond.call():
				crop.call(label, n, box)
				await t.shot(label)
				return true
		t.log_line("%s: not caught in %.1f s" % [label, limit])
		return false

	# flip-flop: mid-tip, and at rest
	cam.global_position = ff.global_position + Vector2(0, 10)
	await t.wait(1.0)
	var box_ff := Rect2(-34, -44, 68, 64)
	await watch_for.call("flipflop_rest", ff, box_ff, func(): return absf(ff._vis) > 0.5 and ff._fork.net.tick >= ff._next - 5, 3.0)
	await watch_for.call("flipflop_mid_tip", ff, box_ff, func(): return absf(ff._vis) < 0.2, 3.0)
	await t.wait(0.13)
	await watch_for.call("flipflop_mid_tip2", ff, box_ff, func(): return absf(ff._vis) < 0.3, 3.0)
	t.log_line("flip-flop sent L/R %s" % [ff.sent])

	# splitter: T mid-rock
	cam.global_position = sp.global_position + Vector2(0, 10)
	await t.wait(1.0)
	var box_sp := Rect2(-30, -40, 60, 60)
	await watch_for.call("splitter_rest", sp, box_sp, func(): return absf(sp._tilt) > 0.44, 2.0)
	await watch_for.call("splitter_mid_rock", sp, box_sp, func(): return absf(sp._tilt) < 0.2, 3.0)
	t.log_line("splitter passed L/R %s" % [sp.passed])
	sp.set_mode(2)
	await t.wait(1.0)
	await t.shot("splitter_locked_right")
	crop.call("splitter_locked_right", sp, box_sp)
	sp.set_mode(0)

	# escapement: B up (release), then A up (next one coming down)
	cam.global_position = es.global_position + Vector2(-6, -18)
	await t.wait(2.5)
	var box_es := Rect2(-36, -60, 64, 72)
	await watch_for.call("escapement_release", es, box_es, func(): return es._swing > 0.12 and es._swing < 0.4, 4.0)
	await watch_for.call("escapement_swing_back", es, box_es, func(): return es._swing > PI * 0.95 and es._swing < PI * 1.1, 4.0)
	await watch_for.call("escapement_mid", es, box_es, func(): return es._swing > PI * 1.45 and es._swing < PI * 1.55, 4.0)
	es.mode = 2
	es._pose()
	await t.wait(0.4)
	await t.shot("escapement_weight_high")
	crop.call("escapement_weight_high", es, box_es)
	es.mode = 1
	t.log_line("escapement let by %d, beats %d" % [es.let_by, es.released])

	# points: thrown mid-way
	cam.global_position = pt.global_position + Vector2(0, 10)
	await t.wait(0.8)
	var box_pt := Rect2(-34, -44, 68, 64)
	await t.shot("points_left" if pt.tilt < 0 else "points_right")
	crop.call("points_rest", pt, box_pt)
	for k in 2:
		await t.wait(0.1)            # (a shot's long frame would skip the swing)
		for q in 3:
			await t.process_frame
		pt.trigger()
		await watch_for.call("points_mid_throw_%d" % k, pt, box_pt, func(): return absf(pt._vis) < 0.45, 1.0)
		await t.wait(0.5)
		await t.shot("points_thrown_%d" % k)
		crop.call("points_thrown_%d" % k, pt, box_pt)
		await t.wait(0.9)
	t.log_line("points sent L/R %s" % [pt.sent])

	# overflow gate: primary filling, then yielding
	cam.global_position = og.global_position + Vector2(20, 20)
	og_p.empty()
	await t.wait(0.3)
	var box_og := Rect2(-34, -56, 112, 128)
	await watch_for.call("overflow_primary", og, box_og, func(): return og.tilt == og.side and absf(og._vis - og._pose_angle()) < 0.02, 3.0)
	await watch_for.call("overflow_yielded", og, box_og, func(): return og.tilt != og.side and absf(og._vis - og._pose_angle()) < 0.02, 12.0)
	og_p.empty()                 # room on the primary side: the weight swings it back
	await watch_for.call("overflow_swinging", og, box_og, func(): return absf(og._vis) < 0.2, 6.0)
	var b1 = og._fork.branches[1]
	t.log_line("overflow branch outs %d open %s sink %s | primary chute riders %d, released %d" % [b1.outs.size(), b1.ends_open, og_pc.track.sink, og_pc.track.count(), og._fork.net.released])
	t.log_line("overflow primary %d overflowed %d, primary bin %d" % [og.primary, og.overflowed, og_p.contents.size()])
