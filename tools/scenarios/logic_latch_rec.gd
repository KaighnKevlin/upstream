extends RefCounted
## Latch. Part one, on the bench: tally wheels with their wires dropped on
## the SET post, the RESET post and the body (fired by hand: each reaches
## both posts, LINK being 150, so the latch has to work out which was
## meant); two latches wired into each other both ways (must not ping-pong);
## mouse clicks on the body and posts.
## Part two, a real machine: a dispenser drops copper on a points switch.
## Left goes down a chute into a load cell (the "bin", full at 2), right
## down a chute under a tally wheel (every 5). The load cell's wire is on
## the latch's SET post, the tally's on its RESET; the latch's output wire
## is on the points. The test plays a turret eating from the bin while
## the stream is sent right (one piece every 1.2 s). Expect: left till the
## bin is full, right for five, back left, and so on. Logs the routing
## sequence with the latch's changes marked.

const LATCH := "res://scenes/latch.tscn"
const TALLY := "res://scenes/tally.tscn"


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
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1300, 330)

	# ── part one: the bench ──
	var la: Node2D = MW._piece(t.main, LATCH, Vector2(1300, 300), {"wire_to": Vector2(0, -120)})
	var ty_s: Node2D = MW._piece(t.main, TALLY, Vector2(1220, 360))
	var ty_r: Node2D = MW._piece(t.main, TALLY, Vector2(1380, 360))
	var ty_b: Node2D = MW._piece(t.main, TALLY, Vector2(1300, 390))
	await t.wait(0.2)
	ty_s.wire_to = la.global_position + la.SET_AT - ty_s.global_position
	ty_r.wire_to = la.global_position + la.RESET_AT - ty_r.global_position
	ty_b.wire_to = la.global_position - ty_b.global_position
	var bench := []
	for step in [["S", ty_s], ["S", ty_s], ["R", ty_r], ["R", ty_r], ["S", ty_s], ["body", ty_b], ["body", ty_b], ["body", ty_b]]:
		step[1].fire()
		await t.wait(0.2)
		bench.append("%s->%s" % [step[0], "on" if la.on else "off"])
	await t.shot("latch_bench")
	t.log_line("latch bench: %s | changes %d fired %d, sets %d resets %d flips %d" % [" ".join(bench), la.changes, la.fired, la.sets, la.resets, la.flips])
	for n in [ty_s, ty_r, ty_b]:
		n.queue_free()
	await t.wait(0.1)
	# mouse: body toggles, S sets, R resets
	var clicks := []
	await _click(t, la.global_position + Vector2(2, -2))
	clicks.append("body->%s" % ("on" if la.on else "off"))
	await _click(t, la.global_position + Vector2(2, -2))
	clicks.append("body->%s" % ("on" if la.on else "off"))
	await _click(t, la.global_position + la.SET_AT)
	clicks.append("S->%s" % ("on" if la.on else "off"))
	await _click(t, la.global_position + la.SET_AT)
	clicks.append("S->%s" % ("on" if la.on else "off"))
	await _click(t, la.global_position + la.RESET_AT)
	clicks.append("R->%s" % ("on" if la.on else "off"))
	t.log_line("latch clicks: %s" % " ".join(clicks))
	# two latches wired into each other's bodies (a flip each way): without a
	# guard this would flip back and forth every frame for ever
	var lb: Node2D = MW._piece(t.main, LATCH, Vector2(1300, 520))
	la.wire_to = lb.global_position - la.global_position
	lb.wire_to = la.global_position - lb.global_position
	await t.wait(0.3)
	var f0: int = la.fired + lb.fired
	la.set_on(not la.on)
	await t.wait(1.0)
	t.log_line("latch loop (A body <-> B body): outputs in 1 s after one flip: %d (A on %s, B on %s, dropped A %d B %d)" % [la.fired + lb.fired - f0, la.on, lb.on, la.dropped, lb.dropped])
	# and SET-to-SET: A's output on B's SET, B's on A's SET
	la.wire_to = lb.global_position + lb.SET_AT - la.global_position
	lb.wire_to = la.global_position + la.SET_AT - lb.global_position
	la.set_on(false)
	lb.set_on(false)
	await t.wait(0.3)
	f0 = la.fired + lb.fired
	la.set_on(true)
	await t.wait(1.0)
	t.log_line("latch loop (A->B.SET, B->A.SET): outputs in 1 s after A set: %d (A on %s, B on %s)" % [la.fired + lb.fired - f0, la.on, lb.on])
	la.queue_free()
	lb.queue_free()
	await t.wait(0.2)

	# ── part two: the machine ──
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1290, 350), {"mode": 0, "limit": 30, "kinds": ["copper"]})
	var pt: Node2D = MW._piece(t.main, "res://scenes/points.tscn", Vector2(1290, 410), {"tilt": -1.0})
	var lch = MW._chute(t.main, Vector2(1280, 430), Vector2(1125, 505))
	lch.has_lip = false
	lch._rebuild()
	var rch = MW._chute(t.main, Vector2(1300, 430), Vector2(1500, 505))
	rch.has_lip = false
	rch._rebuild()
	var lc: Node2D = MW._piece(t.main, "res://scenes/load_cell.tscn", Vector2(1092, 545), {"mode": 0})
	var ty: Node2D = MW._piece(t.main, TALLY, Vector2(1450, 479), {"mode": 1})
	var lt: Node2D = MW._piece(t.main, LATCH, Vector2(1440, 290))
	await t.wait(0.1)
	lt.wire_to = pt.global_position - lt.global_position
	lc.wire_to = lt.global_position + lt.SET_AT - lc.global_position
	ty.wire_to = lt.global_position + lt.RESET_AT - ty.global_position
	cam.zoom = Vector2(1.7, 1.7)
	cam.global_position = Vector2(1290, 400)
	var seq := ""
	var last := [0, 0]
	var was_on: bool = lt.on
	var eat := 0.0
	var eaten := 0
	var shots := 0
	for k in 250:
		await t.wait(0.05)
		if lt.on != was_on:
			was_on = lt.on
			seq += "|" + ("SET" if lt.on else "RESET") + "|"
			if shots < 2:
				shots += 1
				await t.wait(0.3)
				await t.shot("latch_machine_%s" % ("set" if lt.on else "reset"))
		if pt.sent[0] > last[0]:
			seq += "L"
		if pt.sent[1] > last[1]:
			seq += "R"
		last = pt.sent.duplicate()
		# the turret eats from the bin while the stream is elsewhere
		eat -= 0.05
		if lt.on and eat <= 0:
			for b in lc._pan.get_overlapping_bodies():
				if b is RigidBody2D and not b.is_queued_for_deletion():
					b.queue_free()
					eaten += 1
					eat = 1.2
					break
	await t.shot("latch_machine_end")
	t.log_line("latch machine: %s" % seq)
	t.log_line("latch machine: sent L %d R %d | load cell fired %d, tally fired %d (count %d) | latch sets %d resets %d flips %d changes %d | eaten from bin %d" % [pt.sent[0], pt.sent[1], lc.fired, ty.fired, ty.count, lt.sets, lt.resets, lt.flips, lt.changes, eaten])
