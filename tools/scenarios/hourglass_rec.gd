extends RefCounted
## Hourglass standing on the cavern floor at x 1400, wired to a delay
## relay. 5 grit dropped on its top: all caught, and it should fire ~2 s
## after the last goes in. Copper dropped on it is turned aside (lands off
## the glass). trigger() turns it over: 0.4 s turn + 2 s run, fires again.
## Then its wire's end on the glass itself: it keeps turning itself over,
## one run per ~2.4 s. Last, a pile of grit: it takes 20 and no more.


static func _drop(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.kind = kind
	o.global_position = at
	t.main.add_child(o)
	return o


static func _state(h: Node2D) -> String:
	return "up %d / down %d, taken %d, refused %d, fired %d, flips %d" % [h.upper, h.lower, h.taken, h.refused, h.fired, h.flips]


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(1100, 540)
	var hx := 1400.0
	var hy := 576.0 - 31.0        # the stand's foot on the floor
	var relay: Node2D = MW._piece(t.main, "res://scenes/delay_relay.tscn", Vector2(1480, 520), {"wire_to": Vector2(300, -400)})
	var h: Node2D = MW._piece(t.main, "res://scenes/hourglass.tscn", Vector2(hx, hy), {"wire_to": Vector2(1480, 520) - Vector2(hx, hy)})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = Vector2(1425, 520)
	await t.wait(0.5)
	# run 1: 5 grit, a little staggered
	for k in 5:
		_drop(t, "grit", Vector2(hx - 2 + (k % 3) * 2, hy - 60 - k * 7))
	var shot := false
	for f in 250:
		await t.wait(0.02)
		if h.fired > 0:
			break
		if not shot and h.taken == 5 and h.upper <= 3:
			shot = true
			await t.shot("hourglass_run")
	t.log_line("run 1: %s | last grit in -> fired: %.2f s (expect ~2.0) | relay triggered %d" % [_state(h), h.fired_at - h.took_at, relay.triggered])
	# copper is turned aside
	var cu := [_drop(t, "copper", Vector2(hx, hy - 60)), _drop(t, "copper", Vector2(hx + 3, hy - 90))]
	await t.wait(1.5)
	var where: Array = cu.map(func(o): return "(%d,%d)" % [int(o.global_position.x), int(o.global_position.y)])
	var on_top: bool = cu.any(func(o): return absf(o.global_position.x - hx) < 12 and o.global_position.y < hy - 20)
	t.log_line("copper: %s | copper now at %s, resting on the glass: %s" % [_state(h), where, on_top])
	for o in cu:
		o.queue_free()
	# run 2: turned over by a signal
	var f0: int = h.fired
	var t0: float = h.age
	h.trigger()
	var mid := false
	for f in 250:
		await t.wait(0.02)
		if h.fired > f0:
			break
		if not mid and h.age - t0 > 0.2:
			mid = true
			await t.shot("hourglass_flip")
	t.log_line("run 2 (trigger): %s | trigger -> fired: %.2f s (expect ~2.4) | relay triggered %d" % [_state(h), h.fired_at - t0, relay.triggered])
	# its wire's end on its own glass: a clock
	h.wire_to = Vector2(0, 4)
	f0 = h.fired
	var fl0: int = h.flips
	t0 = h.age
	h.trigger()
	var beats := []
	var last := t0
	for f in 500:
		await t.wait(0.02)
		if h.fired > f0 + beats.size():
			beats.append("%.2f" % (h.fired_at - last))
			last = h.fired_at
		if beats.size() >= 3:
			break
	t.log_line("self-wired: %s | beats %s s apart (expect ~2.4 each), flips +%d" % [_state(h), beats, h.flips - fl0])
	# stop the clock, then overfill
	h.wire_to = Vector2(0, -60)
	await t.wait(2.8)
	var before: int = h.taken
	for k in 22:
		_drop(t, "grit", Vector2(hx - 3 + (k % 4) * 2, hy - 60 - k * 6))
	await t.wait(3.0)
	t.log_line("overfill (+22 grit): %s | took %d more, glass holds %d (cap 20)" % [_state(h), h.taken - before, h.upper + h.lower])
	await t.shot("hourglass_full")
