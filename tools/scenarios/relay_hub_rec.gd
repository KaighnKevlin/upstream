extends RefCounted
## Relay hub. Bench: a hub wired to three points switches, fired once:
## each should be thrown once. Then two of its ends on the same switch
## (thrown once, not twice), a parked wire (fires nothing), a wire back
## onto the hub itself (never fires itself), two hubs wired into each
## other (one output each, no ping-pong), a click on the box (fires by
## hand) and a mouse drag of a wire's end (moves it; dropped on the box it
## parks). Then a machine: a tally wheel (every 3) on the feed wired to a
## hub; the hub's wires on the points switch the feed runs onto, on a
## sluice holding back a second line and on a latch's SET post. Each wheel
## firing should throw the points, open the sluice and (first time) set
## the latch, all in the same beat.

const HUB := "res://scenes/relay_hub.tscn"
const POINTS := "res://scenes/points.tscn"


static func _screen(t, world: Vector2) -> Vector2:
	return t.main.get_viewport().get_canvas_transform() * world


static func _button(t, world: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _screen(t, world)
	ev.global_position = ev.position
	Input.warp_mouse(ev.position)
	await t.wait(0.05)
	Input.parse_input_event(ev)
	await t.wait(0.05)


static func _move(t, world: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _screen(t, world)
	ev.global_position = ev.position
	Input.warp_mouse(ev.position)
	Input.parse_input_event(ev)
	await t.wait(0.05)


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
	cam.global_position = Vector2(1270, 380)

	# ── bench ──
	var hub: Node2D = MW._piece(t.main, HUB, Vector2(1250, 250))
	var ps := []
	for at in [Vector2(1000, 450), Vector2(1250, 500), Vector2(1500, 450)]:
		ps.append(MW._piece(t.main, POINTS, at))
	await t.wait(0.1)
	hub.wire_1 = ps[0].global_position - hub.global_position
	hub.wire_2 = ps[1].global_position - hub.global_position
	hub.wire_3 = ps[2].global_position - hub.global_position
	var tilts := func() -> String:
		return "".join(ps.map(func(p): return "L" if p.tilt < 0 else "R"))
	var log := ["start %s" % tilts.call()]
	hub.trigger()
	await t.wait(0.2)
	log.append("fired: %s (machines hit %d)" % [tilts.call(), hub.hit])
	await t.shot("hub_bench")
	hub.wire_2 = ps[0].global_position + Vector2(6, -4) - hub.global_position
	var h0: int = hub.hit
	hub.trigger()
	await t.wait(0.2)
	log.append("ends 1+2 both on the first switch: %s (hit %d)" % [tilts.call(), hub.hit - h0])
	hub.wire_2 = Vector2.ZERO
	hub.wire_3 = Vector2.ZERO
	h0 = hub.hit
	hub.trigger()
	await t.wait(0.2)
	log.append("wires 2,3 parked: %s (hit %d)" % [tilts.call(), hub.hit - h0])
	hub.wire_1 = Vector2(3, 3)
	var tr0: int = hub.triggered
	var f0: int = hub.fired
	hub.trigger()
	await t.wait(0.3)
	log.append("wire onto itself: signals taken %d, outputs %d, dropped %d" % [hub.triggered - tr0, hub.fired - f0, hub.dropped])
	t.log_line("hub bench: %s" % " | ".join(log))
	# two hubs, each wired to the other
	var hb: Node2D = MW._piece(t.main, HUB, Vector2(1250, 400), {"wire_1": Vector2.ZERO, "wire_2": Vector2.ZERO, "wire_3": Vector2.ZERO})
	await t.wait(0.1)
	hub.wire_1 = hb.global_position - hub.global_position
	hb.wire_1 = hub.global_position - hb.global_position
	var fa: int = hub.fired
	var fb: int = hb.fired
	hub.trigger()
	await t.wait(1.0)
	t.log_line("hub loop (A <-> B): outputs in 1 s after one signal: A %d, B %d (dropped A %d)" % [hub.fired - fa, hb.fired - fb, hub.dropped])
	hb.queue_free()
	# (ends a little above the switches: a click right on a switch throws it)
	hub.wire_1 = ps[0].global_position + Vector2(0, -40) - hub.global_position
	await t.wait(0.1)
	# mouse: a click on the box fires by hand; drag wire 3 out of its hook
	# to the third switch, then drag wire 1 back onto the box (parked)
	var before: String = tilts.call()
	f0 = hub.fired
	await _button(t, hub.global_position + Vector2(-4, 0), true)
	await _button(t, hub.global_position + Vector2(-4, 0), false)
	var clicked := "click on the box: outputs %d, switches %s -> %s" % [hub.fired - f0, before, tilts.call()]
	var hook: Vector2 = hub.global_position + hub.HOOKS[2]
	await _button(t, hook, true)
	var drop: Vector2 = ps[2].global_position + Vector2(0, -40)
	for k in 6:
		await _move(t, hook.lerp(drop, (k + 1) / 6.0))
	await _button(t, drop, false)
	var dragged := "wire 3 dragged from its hook to %s (dropped at %s)" % [Vector2i(hub.global_position + hub.wire_3), Vector2i(drop)]
	var e1: Vector2 = hub.global_position + hub.wire_1
	await _button(t, e1, true)
	for k in 6:
		await _move(t, e1.lerp(hub.global_position + Vector2(2, 2), (k + 1) / 6.0))
	await _button(t, hub.global_position + Vector2(2, 2), false)
	t.log_line("hub mouse: %s | %s | wire 1 dropped on the box: %s" % [clicked, dragged, "parked" if hub.wire_1 == Vector2.ZERO else "at %s" % hub.wire_1])
	await t.shot("hub_bench_dragged")
	hub.queue_free()
	for p in ps:
		p.queue_free()
	await t.wait(0.2)

	# ── machine ──
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(960, 200), {"mode": 0, "limit": 12})
	MW._chute(t.main, Vector2(945, 230), Vector2(1100, 280))
	var ty: Node2D = MW._piece(t.main, "res://scenes/tally.tscn", Vector2(1000, 241), {"mode": 0})
	MW._chute(t.main, Vector2(1090, 300), Vector2(1250, 350))
	var pt: Node2D = MW._piece(t.main, POINTS, Vector2(1272, 392))
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1500, 180), {"mode": 0, "limit": 14, "kinds": ["iron"]})
	MW._chute(t.main, Vector2(1485, 210), Vector2(1640, 260))
	var sl: Node2D = MW._piece(t.main, "res://scenes/sluice.tscn", Vector2(1610, 250), {"side": 1.0})
	var lt: Node2D = MW._piece(t.main, "res://scenes/latch.tscn", Vector2(1450, 450), {"wire_to": Vector2(100, 90)})
	var h: Node2D = MW._piece(t.main, HUB, Vector2(1180, 200))
	await t.wait(0.1)
	ty.wire_to = h.global_position - ty.global_position
	h.wire_1 = pt.global_position - h.global_position
	h.wire_2 = sl.global_position - h.global_position
	h.wire_3 = lt.global_position + lt.SET_AT - h.global_position
	cam.zoom = Vector2(1.7, 1.7)
	cam.global_position = Vector2(1290, 335)
	var seq := ""
	var last := [0, 0]
	var tf := 0
	var beats := []
	var shot := false
	for i in 240:
		await t.wait(0.05)
		if ty.fired > tf:
			tf = ty.fired
			await t.wait(0.05)
			beats.append("wheel#%d: hub out %d, points %s, sluice opened %d, latch %s" % [tf, h.fired, "L" if pt.tilt < 0 else "R", sl.opened, "on" if lt.on else "off"])
			seq += "|"
			if not shot:
				shot = true
				await t.shot("hub_machine_beat")
		if pt.sent[0] > last[0]:
			seq += "L"
		if pt.sent[1] > last[1]:
			seq += "R"
		last = pt.sent.duplicate()
	t.log_line("hub machine: %s" % " ; ".join(beats))
	t.log_line("hub machine: routing %s (| = wheel fired) | sent L %d R %d | sluice released %d | hub hit %d machines over %d outputs" % [seq, pt.sent[0], pt.sent[1], sl.released, h.hit, h.fired])
	await t.shot("hub_machine_end")
