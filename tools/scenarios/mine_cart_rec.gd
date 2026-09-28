extends RefCounted
## Mine cart: a dispenser drops 10 ore into its loading end (loads of 5);
## it should run two trips and tip all 10 at the far end.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var mc: Node2D = MW._piece(t.main, "res://scenes/mine_cart.tscn", Vector2(1050, 520), {"end_offset": Vector2(380, 40), "mode": 1})
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1050, 440), {"mode": 0, "limit": 10})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1240, 480)
	var log := []
	for k in 16:
		await t.wait(1.0)
		log.append("%d:%d/%d" % [k + 1, mc.trips, mc.delivered])
		if k == 6:
			await t.shot("mine_cart")
	var far: int = t.get_nodes_in_group("ore").filter(func(o): return o.global_position.x > 1400).size()
	t.log_line("mine cart (loads of 5), s:trips/delivered %s | ore now past the far end: %d" % [log, far])
