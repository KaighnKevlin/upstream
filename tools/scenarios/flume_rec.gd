extends RefCounted
## Flume from (1250,480) running right 180 px. Copper and iron dropped in
## near the head: copper should float over the weir, iron pile behind it;
## then a flush lets the iron out.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var f: Node2D = preload("res://scenes/flume.tscn").instantiate()
	f.global_position = Vector2(1250, 480)
	f.end_offset = Vector2(180, 0)
	t.main.add_child(f)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1350, 490)
	await t.wait(0.5)
	var ms := []
	for k in 8:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.kind = "iron" if k % 2 == 1 else "copper"
		o.global_position = Vector2(1270 + (k % 3) * 8, 440)
		t.main.add_child(o)
		ms.append(o)
		await t.wait(0.3)
		if k == 6:
			await t.shot("flume")
	await t.wait(3.5)
	var iron: Array = ms.filter(func(o): return o.kind == "iron").map(func(o): return int(o.global_position.x))
	var cu: Array = ms.filter(func(o): return o.kind == "copper").map(func(o): return int(o.global_position.x))
	t.log_line("flume: floated over %d | copper at x %s | iron at x %s (weir at 1430)" % [f.floated, cu, iron])
	await t.shot("flume_held")
	f.trigger()
	await t.wait(2.5)
	iron = ms.filter(func(o): return o.kind == "iron").map(func(o): return int(o.global_position.x))
	t.log_line("flume flush: flushed %d | iron now at x %s" % [f.flushed, iron])
