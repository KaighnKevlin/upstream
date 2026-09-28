extends RefCounted
## Grit down a long chute: where it goes, sampled every 0.1 s (does it stay on
## the rail all the way?).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var ch = MW._chute(t.main, Vector2(1100, 400), Vector2(1270, 430))
	var fm: Node2D = MW._piece(t.main, "res://scenes/flow_meter.tscn", Vector2(1185, 395))
	var out := []
	for kind in ["grit", "copper", "grit"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = kind
		o.lifetime = 1.0e9
		o.global_position = Vector2(1110, 385)
		t.main.add_child(o)
		var path := []
		for k in 20:
			await t.wait(0.1)
			# height above the rail at this x (rail y = 400 + (x-1100)*30/170)
			var rail_y: float = 400.0 + (o.global_position.x - 1100.0) * 30.0 / 170.0
			path.append("%d:%+d" % [int(o.global_position.x), int(o.global_position.y - rail_y)])
		out.append("%s %s" % [kind, " ".join(path)])
	for l in out:
		t.log_line(l)
	t.log_line("flow meter over the middle counted %d of 3 (hits %s)" % [fm.passed, fm._hits.map(func(h): return h[1])])
