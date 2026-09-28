extends RefCounted
## Pop bumpers: marbles dropped onto a triangle of three; kicks, and how the
## pieces fan out (landing spread) compared with no bumpers.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var bumpers := []
	for p in [Vector2(1300, 380), Vector2(1270, 430), Vector2(1330, 430)]:
		bumpers.append(MW._piece(t.main, "res://scenes/pop_bumper.tscn", p))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1300, 450)
	var pcs := []
	for k in 8:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(1300 + randf_range(-3, 3), 300)
		t.main.add_child(o)
		pcs.append(o)
		await t.wait(0.4)
		if k == 3:
			await t.shot("pop_bumper")
	await t.wait(2.5)
	var xs: Array = pcs.map(func(o): return int(o.global_position.x))
	xs.sort()
	t.log_line("pop bumpers: kicks %s | 8 dropped at x 1300 landed at x %s (spread %d px)" % [bumpers.map(func(b): return b.kicks), xs, xs[-1] - xs[0]])
