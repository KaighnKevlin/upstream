extends RefCounted
## Spring trap on the cavern floor at x 1400. A soldier walks on from the
## right: flung back? Then two pieces in the hopper re-arm it and a second
## soldier gets the same.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var s: Node2D = preload("res://scenes/spring_trap.tscn").instantiate()
	s.global_position = Vector2(1400, 560)
	t.main.add_child(s)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1440, 480)
	await t.wait(0.5)
	for round in 2:
		var e = t._spawn(2, Vector2(1480, 560))
		var hp0: int = e.hp
		var top := 9999.0
		var sprung_x := -1.0
		var shot := false
		for k in 70:
			await t.wait(0.05)
			if not is_instance_valid(e):
				break
			top = minf(top, e.global_position.y)
			if sprung_x < 0 and not s.armed:
				sprung_x = e.global_position.x
			if round == 0 and not shot and not s.armed and e.global_position.y < 470:
				shot = true
				await t.shot("spring_trap")
		t.log_line("spring trap round %d: flung %d, sprung at x %d, peak y %d (floor ~560), now x %d, hp %d -> %d" % [
			round + 1, s.flung, int(sprung_x), int(top), int(e.global_position.x) if is_instance_valid(e) else -1, hp0, e.hp if is_instance_valid(e) else -99])
		if is_instance_valid(e):
			e.queue_free()
		for k in 2:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.lifetime = 1.0e9
			o.global_position = s._hopper() + Vector2(0, -30)
			t.main.add_child(o)
			await t.wait(0.6)
		await t.wait(0.5)
		t.log_line("spring trap: after 2 pieces armed=%s" % s.armed)
