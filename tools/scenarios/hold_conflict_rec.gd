extends RefCounted
## Cross-piece holding conflicts: two pieces that each grab ore and steer it
## kinematically, placed so they overlap, and one piece dropped in. Logged
## per test: who ends up holding it (from each holder's own lists), how far
## it strays from where its holders want it (the tug of war), where it ends
## up, and its gravity_scale.
##
## A  mine cart's loading end under a magnet rail's field: iron falls into
##    the cart, which holds it right in the rail's field.
## B  balloon lift rising through a magnet rail's field.
## C  magnet rail carrying iron along a flume's water.
## D  a magnet rail removed while it's carrying: what happens to the piece.


static func _ore(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	t.main.add_child(o)
	return o


static func _rail(t, at: Vector2, off: Vector2) -> Node2D:
	var m: Node2D = preload("res://scenes/magnet_rail.tscn").instantiate()
	m.global_position = at
	m.end_offset = off
	t.main.add_child(m)
	return m


static func _in_rail(m, o) -> bool:
	return is_instance_valid(m) and m._held.any(func(h): return h[0] == o)


## Per physics frame for `frames`: the biggest per-frame jump in velocity
## direction (the tug of war shows as a velocity that flips back and forth)
## and how many frames the piece was in two holders' lists at once.
static func _watch(t, o, frames: int, holders: Callable) -> Dictionary:
	var flips := 0
	var both := 0
	var prev := Vector2.ZERO
	var path := []
	for f in frames:
		await t.main.get_tree().physics_frame
		if not is_instance_valid(o):
			break
		var v: Vector2 = o.linear_velocity
		if prev.length() > 5 and v.length() > 5 and prev.dot(v) < 0:
			flips += 1
		prev = v
		var hs: Array = holders.call()
		if hs.size() >= 2:
			both += 1
		if f % 15 == 0:
			path.append("%d,%d%s" % [int(o.global_position.x), int(o.global_position.y), "/".join(hs)])
	return {"flips": flips, "both": both, "path": path}


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.3, 1.3)
	cam.global_position = Vector2(1250, 440)

	# ── A: mine cart + magnet rail ──
	var mc: Node2D = MW._piece(t.main, "res://scenes/mine_cart.tscn", Vector2(1000, 520), {"end_offset": Vector2(200, 40), "mode": 1})
	var ra := _rail(t, Vector2(985, 505), Vector2(140, 0))
	await t.wait(0.3)
	var a := _ore(t, "iron", Vector2(1000, 470))
	var wa: Dictionary = await _watch(t, a, 150, func():
		var hs := []
		if a in mc._load or a in mc._hopper: hs.append("cart")
		if _in_rail(ra, a): hs.append("rail")
		return hs)
	t.log_line("A cart+rail: frames in both %d, velocity flips %d | cart load %d, rail carried %d | piece at (%d,%d) grav %.1f | path %s" % [wa.both, wa.flips, mc._load.size(), ra.carried, int(a.global_position.x), int(a.global_position.y), a.gravity_scale, wa.path])
	await t.shot("hold_A")

	# ── B: balloon lift + magnet rail ──
	var bl = MW._piece(t.main, "res://scenes/balloon_lift.tscn", Vector2(1300, 576))
	var rb := _rail(t, Vector2(1270, 470), Vector2(150, 0))
	await t.wait(0.3)
	var b := _ore(t, "iron", Vector2(1300, 540))
	var wb: Dictionary = await _watch(t, b, 300, func():
		var hs := []
		if b in bl._wait or bl._up.any(func(u): return u[0] == b): hs.append("balloon")
		if _in_rail(rb, b): hs.append("rail")
		return hs)
	await t.wait(1.0)
	t.log_line("B balloon+rail: frames in both %d, velocity flips %d | balloon lifted %d, rail carried %d | piece at (%d,%d) grav %.1f | path %s" % [wb.both, wb.flips, bl.lifted, rb.carried, int(b.global_position.x), int(b.global_position.y), b.gravity_scale, wb.path])
	await t.shot("hold_B")

	# ── C: magnet rail over a flume (C1 flume placed first, C2 rail first:
	# which of them steers last each frame depends on tree order) ──
	for k in 2:
		var base := Vector2(1450, 430) if k == 0 else Vector2(1100, 330)
		var fl: Node2D = preload("res://scenes/flume.tscn").instantiate()
		fl.global_position = base
		fl.end_offset = Vector2(170, 0)
		var rc: Node2D
		if k == 0:
			t.main.add_child(fl)
			rc = _rail(t, base + Vector2(5, -26), Vector2(150, 0))
		else:
			rc = _rail(t, base + Vector2(5, -26), Vector2(150, 0))
			t.main.add_child(fl)
		await t.wait(0.3)
		var c := _ore(t, "iron", base + Vector2(30, -50))
		# how far the piece trails the point the rail is steering it to
		var lag := 0.0
		var grav := []
		for f in 120:
			await t.main.get_tree().physics_frame
			for h in rc._held:
				if h[0] == c:
					var want: Vector2 = rc.global_position + Vector2(h[1], 0)
					lag = maxf(lag, absf(c.global_position.x - want.x))
					if not grav.has(snappedf(c.gravity_scale, 0.1)):
						grav.append(snappedf(c.gravity_scale, 0.1))
		t.log_line("C%d rail+flume (%s first): rail carried %d, max lag behind the rail %.1f px, gravity seen while held %s | piece at (%d,%d) grav %.1f" % [k + 1, "flume" if k == 0 else "rail", rc.carried, lag, grav, int(c.global_position.x), int(c.global_position.y), c.gravity_scale])
	await t.shot("hold_C")

	# ── D: a holder removed mid-carry ──
	var rd := _rail(t, Vector2(1000, 250), Vector2(300, 0))
	await t.wait(0.3)
	var d := _ore(t, "iron", Vector2(1030, 290))
	d.linear_velocity = Vector2(0, -200)
	await t.wait(0.4)
	var was := _in_rail(rd, d)
	var y0 := d.global_position.y
	rd.queue_free()
	await t.wait(2.0)
	t.log_line("D rail removed while holding=%s: piece y %d -> %d, grav %.1f" % [was, int(y0), int(d.global_position.y), d.gravity_scale])
	await t.shot("hold_D")
