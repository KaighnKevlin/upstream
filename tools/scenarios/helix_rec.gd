extends RefCounted
## Helix: a dispenser feeds a mixed stream down a chute into the coil's
## top mouth (3 turns); each should come out the bottom heading right at
## the same steady speed, onto a chute below. Then 4 turns, and pieces
## thrown in fast and slow by hand: the exit speed shouldn't care.


static func _ore(t, kind: String, at: Vector2, v: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	o.linear_velocity = v
	t.main.add_child(o)
	return o


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var at := Vector2(1300, 400)
	var hx: Node2D = MW._piece(t.main, "res://scenes/helix.tscn", at, {"side": 1.0, "turns": 3})
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1165, 320), {"mode": 0, "limit": 6, "kinds": ["copper", "iron", "grit", "copper", "scrap", "iron"]})
	MW._chute(t.main, Vector2(1150, 355), Vector2(1298, 400))
	var outc = MW._chute(t.main, Vector2(1302, 520), Vector2(1500, 560))
	outc.has_lip = false
	outc._rebuild()
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1320, 450)
	# phase A: 3 turns, the dispenser's six
	var speeds := []
	var times := {}
	var ins := {}
	var last := 0
	for k in 180:
		await t.wait(0.05)
		for id in hx._riders:
			if not ins.has(id):
				ins[id] = Time.get_ticks_msec() / 1000.0
		if hx.spun > last:
			last = hx.spun
			speeds.append(int(hx.last_out.length()))
		for id in ins:
			if not hx._riders.has(id) and not times.has(id):
				times[id] = snappedf(Time.get_ticks_msec() / 1000.0 - ins[id], 0.05)
		if k == 70:
			await t.shot("helix_3turns")
	var right := 0
	for o in t.get_nodes_in_group("ore"):
		if o.global_position.x > 1330 and o.global_position.y > 500:
			right += 1
	var a := "3 turns (%d px drop): %d of 6 came out the bottom at %s px/s, %s s each in the coil, %d ended on the chute right and below" % [hx.depth(), hx.spun, speeds, times.values(), right]
	for o in t.get_nodes_in_group("ore"):
		o.queue_free()
	# phase B: 4 turns, one flung in fast, one slow, one heavy
	hx.turns = 4
	outc.global_position = Vector2(1302, 546)
	hx.queue_redraw()
	await t.wait(0.2)
	var s0: int = hx.spun
	var speeds_b := []
	var kicks := [["copper", 380.0], ["copper", 70.0], ["iron", 220.0]]
	for kk in kicks:
		_ore(t, kk[0], at + Vector2(-8, -6), Vector2(kk[1], 0))
		var before: int = hx.spun
		for w in 60:
			await t.wait(0.05)
			if w == 20 and kk[1] == 380.0:
				await t.shot("helix_4turns")
			if hx.spun > before:
				speeds_b.append("%s in at %d -> out at %d" % [kk[0], int(kk[1]), int(hx.last_out.length())])
				break
	var b := "4 turns (%d px drop): %d of 3 out | %s" % [hx.depth(), hx.spun - s0, speeds_b]
	await t.wait(0.8)
	await t.shot("helix_after")
	t.log_line("helix: %s || %s" % [a, b])
