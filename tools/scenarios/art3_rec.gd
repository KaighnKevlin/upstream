extends RefCounted
## Art gallery for the marble cannon, bell, chime bar, plunger, flywheel,
## counterweight lift and tally wheel: each placed in open air, close up,
## so a sprite pass can be compared before and after. `-- art3_rec <outdir>`


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	# frame 1: cannons, bells, plunger, flywheel
	var c1: Node2D = MW._piece(t.main, "res://scenes/cannon.tscn", Vector2(1080, 310), {"side": 1.0})
	MW._piece(t.main, "res://scenes/cannon.tscn", Vector2(1150, 310), {"side": -1.0})
	var b1: Node2D = MW._piece(t.main, "res://scenes/bell.tscn", Vector2(1110, 220), {"wire_to": Vector2(40, 40)})
	MW._piece(t.main, "res://scenes/bell.tscn", Vector2(1190, 220), {"muffled": true})
	MW._piece(t.main, "res://scenes/plunger.tscn", Vector2(1240, 300))
	var fw: Node2D = MW._piece(t.main, "res://scenes/flywheel.tscn", Vector2(1300, 250))
	fw.spin = 0.6
	# frame 2: chime bars, tally, counterweight
	for k in 4:
		MW._piece(t.main, "res://scenes/chime.tscn", Vector2(1060 + k * 20, 390 + k * 30), {"note": [0, 2, 4, 7][k], "end_offset": Vector2(80, 16 + k * 4)})
	MW._piece(t.main, "res://scenes/chime.tscn", Vector2(1160, 545), {"note": 5, "end_offset": Vector2(-60, -30)})
	var ty: Node2D = MW._piece(t.main, "res://scenes/tally.tscn", Vector2(1200, 410), {"mode": 1, "wire_to": Vector2(40, 40)})
	ty.count = 2
	MW._piece(t.main, "res://scenes/counterweight.tscn", Vector2(1340, 360))
	await t.wait(1.0)
	b1.ring(1.0)
	await t.wait(0.15)
	c1._kick = 1.0
	cam.zoom = Vector2(3.4, 3.4)
	cam.global_position = Vector2(1190, 260)
	await t.shot("art_a")
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1230, 450)
	await t.wait(0.1)
	await t.shot("art_b")
	# the build bar's tabs that hold these pieces (production: flywheel;
	# defence: cannon; lifts: counterweight, plunger, chime; logic: the rest)
	var bar: Control = t.main.get_node("CanvasLayer").get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.get_file() == "build_bar.gd")[0]
	for c in [1, 2, 5, 6]:
		bar._cat = c
		bar._layout()
		await t.wait(0.1)
		await t.shot("art_bar_%d" % c)
	t.log_line("art3 gallery done")
