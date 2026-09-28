extends RefCounted
## Sling: marbles dropped into its cup, whirled and thrown up-right, then
## (aim turned) straight right; how many thrown, how fast, where they land.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var s = MW._piece(t.main, "res://scenes/sling.tscn", Vector2(1200, 320))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = Vector2(1400, 380)
	for aim in [7, 0]:
		s.aim = aim
		var pcs := []
		for k in 3:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.lifetime = 1.0e9
			o.global_position = Vector2(1200, 250)
			t.main.add_child(o)
			pcs.append(o)
			await t.wait(1.3)
			if k == 1 and aim == 7:
				await t.shot("sling")
		await t.wait(2.0)
		t.log_line("sling aim %d: thrown %d, last v %s, landed x %s" % [aim, s.thrown, s.last_v.round(), pcs.map(func(o): return int(o.global_position.x))])
