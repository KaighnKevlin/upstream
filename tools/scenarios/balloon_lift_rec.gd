extends RefCounted
## Balloon lift on the cavern floor at x 1300, pin at 160 px, tossing right
## onto a chute from (1312,440). 6 marbles rolled into the basket in quick
## succession: how many lifted, and do they arrive at the chute's low end.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var bl = MW._piece(t.main, "res://scenes/balloon_lift.tscn", Vector2(1300, 576))
	var ch = MW._chute(t.main, Vector2(1312, 440), Vector2(1470, 476))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1360, 480)
	await t.wait(0.5)
	var ms := []
	for k in 6:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.kind = "iron" if k % 3 == 2 else "copper"
		o.global_position = Vector2(1300, 540)
		t.main.add_child(o)
		ms.append(o)
		await t.wait(0.3)
	await t.wait(2.4)
	await t.shot("balloon_lift")
	await t.wait(4.0)
	t.log_line("balloon lift: lifted %d of 6 | pieces now at x %s y %s (chute low end x 1470 y 470)" % [bl.lifted, ms.map(func(o): return int(o.global_position.x)), ms.map(func(o): return int(o.global_position.y))])
