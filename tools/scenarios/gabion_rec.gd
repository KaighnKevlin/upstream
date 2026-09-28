extends RefCounted
## Gabion: a cage on the cavern floor at x 1400 filled by 12 dropped pieces;
## a soldier walks in from the right. Does it stop at the wall, how long
## does the wall hold, and with a feed (a piece every 1.2 s) does it hold?


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var g: Node2D = preload("res://scenes/gabion.tscn").instantiate()
	g.global_position = Vector2(1400, 560)
	t.main.add_child(g)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1430, 500)
	for feed in [false, true]:
		for k in 12:
			_drop(t, g)
			await t.wait(0.12)
		await t.wait(1.0)
		t.log_line("gabion filled: %d in, wall %d px" % [g.kinds.size(), int(g.height())])
		var e = t._spawn(2, Vector2(1560, 560))
		var held := 0.0
		var min_x := 99999.0
		var clock := 0.0
		var next_feed := 0.0
		while clock < 12.0 and is_instance_valid(e) and not e._dying:
			await t.wait(0.1)
			clock += 0.1
			min_x = minf(min_x, e.global_position.x)
			if e.global_position.x > g.global_position.x:
				held = clock
			if feed and clock >= next_feed:
				next_feed = clock + 1.2
				_drop(t, g)
			if clock > 3.0 and clock < 3.15 and not feed:
				await t.shot("gabion")
		t.log_line("gabion %s: soldier held on the right for %.1f s of %.1f (closest x %d, gabion at %d); knocked out %d, left in it %d" % [
			"fed" if feed else "unfed", held, clock, int(min_x), int(g.global_position.x), g.knocked, g.kinds.size()])
		if is_instance_valid(e):
			e.queue_free()
		for o in t.get_nodes_in_group("ore"):
			o.queue_free()
		await t.wait(0.5)


static func _drop(t, g) -> void:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.global_position = g.global_position + Vector2(0, -90)
	t.main.add_child(o)
