extends RefCounted
## Rope bridge slung (1350,470)-(1550,470), 100 px over the cavern floor.
## Marbles dropped on it; a soldier walks on at the right end; the bridge is
## cut under it mid-span; it knits back; a second soldier crosses all the way.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var br: Node2D = preload("res://scenes/rope_bridge.tscn").instantiate()
	br.global_position = Vector2(1350, 470)
	br.end_offset = Vector2(200, 0)
	t.main.add_child(br)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1450, 490)
	await t.wait(0.8)
	var ms := []
	for x in [1400, 1450, 1500]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(x, 440)
		t.main.add_child(o)
		ms.append(o)
	await t.wait(1.2)
	t.log_line("rope bridge: marbles resting at y %s (deck 470), sag mid %d px" % [ms.map(func(o): return int(o.global_position.y)), int(br._p[br._p.size() / 2].y)])
	var e = t._spawn(2, Vector2(1535, 450))
	var cut_at := -1.0
	for f in 60:
		await t.wait(0.1)
		if cut_at < 0 and e.global_position.x < 1460:
			cut_at = e.global_position.x
			t.log_line("rope bridge: soldier on the deck at y %d, x %d: cut" % [int(e.global_position.y), int(cut_at)])
			await t.shot("rope_bridge_loaded")
			br.trigger()
			await t.wait(0.4)
			await t.shot("rope_bridge_cut")
			break
	await t.wait(1.5)
	t.log_line("rope bridge: after the cut soldier at y %d, marbles at y %s" % [int(e.global_position.y), ms.map(func(o): return int(o.global_position.y))])
	e.queue_free()
	await t.wait(CUT_WAIT)
	var e2 = t._spawn(2, Vector2(1535, 450))
	var max_y := 0.0
	var reached := false
	for f in 120:
		await t.wait(0.1)
		if e2.global_position.x > 1360:
			max_y = maxf(max_y, e2.global_position.y)
		elif not reached:
			reached = true
			t.log_line("rope bridge knit: second soldier crossed to x %d, lowest y on the deck %d" % [int(e2.global_position.x), int(max_y)])
			await t.shot("rope_bridge_crossed")
			break
	if not reached:
		t.log_line("rope bridge knit: second soldier did NOT cross (x %d y %d)" % [int(e2.global_position.x), int(e2.global_position.y)])
	t.log_line("rope bridge: cuts %d" % br.cuts)

const CUT_WAIT := 6.0
