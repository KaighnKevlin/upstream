extends RefCounted
## Check valve on a level rail (opens right): pieces rolled right pass it,
## pieces rolled left bounce back.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var rail = MW._chute(t.main, Vector2(1150, 450), Vector2(1350, 452))
	rail.has_lip = false
	rail._rebuild()
	var cv: Node2D = MW._piece(t.main, "res://scenes/check_valve.tscn", Vector2(1250, 444), {"side": 1.0})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3, 3)
	cam.global_position = Vector2(1250, 430)
	var out := []
	for spec in [[1180.0, 200.0], [1320.0, -200.0], [1180.0, 300.0], [1320.0, -300.0]]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(spec[0], 440)
		t.main.add_child(o)
		o.linear_velocity = Vector2(spec[1], 0)
		await t.wait(0.25)
		if out.size() == 1:
			await t.shot("check_valve")
		await t.wait(0.9)
		var through: bool = (o.global_position.x > 1250) == (spec[0] < 1250)
		out.append("%s at %d: %s (x %d)" % ["right" if spec[1] > 0 else "left", int(absf(spec[1])), "through" if through else "stopped", int(o.global_position.x)])
		o.queue_free()
	t.log_line("check valve (opens right): %s | passed %d stopped %d" % [out, cv.passed, cv.stopped])
