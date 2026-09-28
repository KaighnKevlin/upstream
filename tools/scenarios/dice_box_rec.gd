extends RefCounted
## Dice box: a dispenser feeds a two-way box down a chute (the look of it),
## then 300 pieces are dropped straight into a two-way box and 300 into a
## three-way one, fast. Each outlet should get about its share: a chi-
## square under the 5% line (3.84 for two ways, 5.99 for three), and no
## piece sent out of an outlet that isn't in use.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1250, 480)
	# the look of it: a dispenser over a chute into a two-way box, catch
	# chutes carrying each side away
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1100, 400), {"mode": 0, "kinds": ["copper", "iron"], "limit": 12})
	MW._chute(t.main, Vector2(1088, 432), Vector2(1150, 456))
	var show: Node2D = MW._piece(t.main, "res://scenes/dice_box.tscn", Vector2(1160, 480), {"outlets": 3})
	var shot_done := false
	for k in 45:
		await t.wait(0.1)
		if not shot_done and show._roll > 0.1 and show.sent[0] + show.sent[1] + show.sent[2] >= 3:
			await t.shot("dice_box_roll")
			shot_done = true
	await t.wait(1.0)
	await t.shot("dice_box")
	t.log_line("dice box (fed by chute, 3-way): outlets L/D/R %s" % [show.sent])
	# the count: 300 through each kind of box
	for n in [2, 3, 2, 3]:
		var box: Node2D = MW._piece(t.main, "res://scenes/dice_box.tscn", Vector2(1380, 470), {"outlets": n})
		for i in 300:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = ["copper", "iron", "grit"][i % 3]
			o.lifetime = 1.5
			o.global_position = box.global_position + Vector2(randf_range(-4, 4), -30)
			t.main.add_child(o)
			o.linear_velocity = Vector2(0, 200)
			if i % 4 == 3:
				await t.wait(0.02)
		await t.wait(0.6)
		var got := []
		for k in box.ways():
			got.append(box.sent[k])
		var total := 0
		for g in got:
			total += g
		var exp := total / float(n)
		var chi := 0.0
		for g in got:
			chi += (g - exp) * (g - exp) / exp
		var unused: int = box.sent[1] if n == 2 else 0
		var crit := 3.84 if n == 2 else 5.99
		t.log_line("dice box %d-way: 300 dropped in -> %d sent, outlets %s, chi-square %.2f (%s under %.2f), %d out of an unused outlet" % [n, total, got, chi, "ok" if chi < crit else "NOT", crit, unused])
		box.queue_free()
		await t.wait(0.3)
