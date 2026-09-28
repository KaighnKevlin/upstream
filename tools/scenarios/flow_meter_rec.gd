extends RefCounted
## Flow meter: three rigs, each a dispenser (copper, iron, scrap in turn)
## down a long chute. A: one a second, a meter over its chute: should read
## ~60/min, ~20 by kind. B: the same rig with no meter: its pieces should
## leave the chute exactly as A's do (the meter disturbs nothing). C: one
## every two seconds, metered: ~30/min.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1250, 470)
	var xs := [960.0, 1180.0, 1400.0]
	var meters := {}
	for i in 3:
		var x: float = xs[i]
		MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(x, 400), {"mode": 1 if i == 2 else 0, "kinds": ["copper", "iron", "scrap"]})
		MW._chute(t.main, Vector2(x - 12, 432), Vector2(x + 160, 480))
		if i != 1:
			# over the chute's middle: its line is at y 456 at x+76
			meters[i] = MW._piece(t.main, "res://scenes/flow_meter.tscn", Vector2(x + 76, 438), {})
	# every piece's speed as it leaves each chute's low end, in order
	var exits := [[], [], []]
	var seen := {}
	var reads := []
	for k in 280:
		await t.wait(0.05)
		for o in t.get_nodes_in_group("ore"):
			for i in 3:
				var ex: float = xs[i] + 160.0
				if not seen.has(o.get_instance_id()) and absf(o.global_position.x - ex) < 60 and o.global_position.x > ex:
					seen[o.get_instance_id()] = true
					exits[i].append(int(o.linear_velocity.length()))
		if k % 20 == 19:
			reads.append("%d/%d" % [int(round(meters[0].per_minute())), int(round(meters[2].per_minute()))])
		if k == 200:
			await t.shot("flow_meter")
	t.log_line("flow meter reading each second (1/s rig / 1-per-2s rig): %s" % [reads])
	var m: Node2D = meters[0]
	var by := []
	for mode in 3:
		m.mode = mode
		by.append("%s %d" % [m.LABELS[mode], int(round(m.per_minute()))])
	m.mode = 1
	await t.wait(0.2)
	await t.shot("flow_meter_copper")
	m.mode = 0
	t.log_line("flow meter: 1/s dispenser reads %d/min (%s); 1-per-2s reads %d/min; counted %d and %d" % [int(round(m.per_minute())), ", ".join(by), int(round(meters[2].per_minute())), m.passed, meters[2].passed])
	var same := 0
	var n := mini(exits[0].size(), exits[1].size())
	for j in n:
		if absi(exits[0][j] - exits[1][j]) <= 2:
			same += 1
	t.log_line("flow meter disturbs nothing: exit speeds metered %s vs unmetered %s -> %d of %d the same (within 2 px/s)" % [exits[0].slice(0, 8), exits[1].slice(0, 8), same, n])
