extends RefCounted
## Stamp press at x 1450 (walkers stop to hit the dome, far overhead,
## within ~60 px of x 1200). Unpowered: one copper lifts it (lift time), a
## soldier walks under and gets stamped. Then belted to a stand-in wheel at
## full power: two pieces in the hopper, a titan walks under; lift time,
## stamps and damage, and whether a scuttler darts out from under.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var sp: Node2D = preload("res://scenes/stamp_press.tscn").instantiate()
	sp.global_position = Vector2(1450, 576)
	t.main.add_child(sp)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1470, 500)
	var feed := func(kind: String) -> void:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = kind
		o.global_position = sp.global_position + Vector2(0, -210)
		t.main.add_child(o)
	# unpowered
	feed.call("copper")
	var e = t._spawn(2, Vector2(1570, 560))
	var hp0: int = e.hp
	var t0 := Time.get_ticks_msec() / 1000.0
	for f in 60:
		await t.wait(0.1)
		if f == 20:
			await t.shot("stamp_raised")
		if sp.stamps > 0:
			break
	await t.shot("stamp_down")
	t.log_line("stamp: unpowered rate %.2f, lift %.2f s, soldier hp %d -> %s after %d stamp(s), %.1f s after the feed" % [
		sp.rate, sp.last_lift, hp0, str(e.hp) if is_instance_valid(e) and not e._dying else "destroyed", sp.stamps, Time.get_ticks_msec() / 1000.0 - t0])
	if is_instance_valid(e):
		e.queue_free()
	# powered: a stand-in wheel always at full power, in belt reach
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
	gs.reload()
	var wheel := Node2D.new()
	wheel.set_script(gs)
	wheel.global_position = Vector2(1350, 540)
	t.main.add_child(wheel)
	await t.wait(0.4)
	feed.call("iron")
	await t.wait(0.3)
	feed.call("copper")
	var ti = t._spawn(0, Vector2(1550, 560))
	var hp1: int = ti.hp
	var times := []
	var s0: int = sp.stamps
	t0 = Time.get_ticks_msec() / 1000.0
	for f in 70:
		await t.wait(0.1)
		if sp.stamps > s0 + times.size():
			times.append("%.1f" % (Time.get_ticks_msec() / 1000.0 - t0))
			if times.size() == 1:
				await t.shot("stamp_titan")
		if times.size() >= 2 or not is_instance_valid(ti) or ti._dying:
			break
	t.log_line("stamp: powered rate %.2f, lift %.2f s, titan hp %d -> %s, stamps at %s s" % [
		sp.rate, sp.last_lift, hp1, str(ti.hp) if is_instance_valid(ti) and not ti._dying else "destroyed", times])
	if is_instance_valid(ti):
		ti.queue_free()
	# a scuttler at full tilt
	feed.call("copper")
	await t.wait(1.6)
	var sc = t._spawn(1, Vector2(1550, 560))
	var h0: int = sp.hits
	s0 = sp.stamps
	for f in 25:
		await t.wait(0.1)
		if sp.stamps > s0:
			break
	await t.wait(0.3)
	t.log_line("stamp: scuttler, stamps %d, hit %s" % [sp.stamps - s0, sp.hits > h0])
	t.log_line("stamp: total stamps %d, hits %d, damage %d" % [sp.stamps, sp.hits, sp.damage_done])
