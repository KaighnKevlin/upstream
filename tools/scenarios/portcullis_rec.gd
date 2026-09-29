extends RefCounted
## Portcullis on the cavern floor at x 1400, raised. A soldier walks in from
## the right and the gate is dropped when it's 40 px off: how long is it
## held, how many blows jam it up? Then the gate's dropped again and four
## pieces in the bucket haul it up; then it's dropped right on a second
## soldier (hurt and flung?).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var g: Node2D = preload("res://scenes/portcullis.tscn").instantiate()
	g.global_position = Vector2(1400, 560)
	t.main.add_child(g)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1420, 490)
	await t.wait(0.5)
	t.log_line("portcullis at %s, raised=%s lift %.2f" % [str(g.global_position), g.raised, g.lift])
	await t.shot("portcullis_raised")

	# 1: dropped in front of a soldier; held until the jam forces it up
	var e = t._spawn(2, Vector2(1560, 560))
	var hp0: int = e.hp
	for k in 200:
		await t.wait(0.05)
		if e.global_position.x - g.global_position.x < 40.0:
			g.trigger()
			break
	t.log_line("dropped with the soldier at x %d (gate %d)" % [int(e.global_position.x), int(g.global_position.x)])
	var held := 0.0
	var min_x := 99999.0
	var clock := 0.0
	var shot_taken := false
	var up_at := -1.0
	while clock < 14.0 and is_instance_valid(e) and not e._dying:
		await t.wait(0.1)
		clock += 0.1
		min_x = minf(min_x, e.global_position.x)
		if e.global_position.x > g.global_position.x:
			held = clock
		if not shot_taken and g.hacked >= 2:
			shot_taken = true
			await t.shot("portcullis_hacked")
		if up_at < 0.0 and g.raised:
			up_at = clock
		if e.global_position.x < g.global_position.x - 60:
			break
	t.log_line("held on the right for %.1f s (closest x %d, gate %d); blows %d, forced up at %.1f s, soldier hp %d -> %d, raised=%s" % [
		held, int(min_x), int(g.global_position.x), g.hacked, up_at, hp0, e.hp if is_instance_valid(e) else -1, g.raised])
	if is_instance_valid(e):
		e.queue_free()
	await t.wait(1.0)

	# 2: down again, four pieces in the bucket haul it up
	g.trigger()
	await t.wait(0.5)
	t.log_line("dropped empty: lift %.2f, height %d, bucket at %s" % [g.lift, int(g.height()), str(g._bucket())])
	for k in 4:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = g._bucket() + Vector2(0, -30)
		t.main.add_child(o)
		await t.wait(1.0)
		t.log_line("piece %d: in bucket %d, lift %.2f, raised=%s" % [k + 1, g._load.size(), g.lift, g.raised])
		if k == 1:
			await t.wait(0.4)
			await t.shot("portcullis_midraise")
	await t.wait(2.0)
	var on_floor := 0
	for o in t.get_nodes_in_group("ore"):
		if is_instance_valid(o) and o.global_position.y > g.global_position.y - 12:
			on_floor += 1
	t.log_line("after 4 pieces: raised=%s lift %.2f, bucket holds %d, pieces on the floor %d" % [g.raised, g.lift, g._load.size(), on_floor])
	await t.shot("portcullis_tipped")

	# 3: dropped right on a second soldier
	var e2 = t._spawn(2, Vector2(1560, 560))
	var hp2: int = e2.hp
	for k in 200:
		await t.wait(0.05)
		if absf(e2.global_position.x - g.global_position.x) < 3.0:
			g.trigger()
			break
	var x_at: float = e2.global_position.x
	await t.wait(0.12)
	await t.shot("portcullis_crush")
	await t.wait(1.0)
	var alive: bool = is_instance_valid(e2) and not e2._dying
	t.log_line("dropped on soldier 2 at x %d: crushed %d, hp %d -> %s, now x %d (flung %d px), gate down=%s" % [
		int(x_at), g.crushed, hp2, str(e2.hp) if alive else "destroyed",
		int(e2.global_position.x) if is_instance_valid(e2) else -1,
		int(e2.global_position.x - x_at) if is_instance_valid(e2) else 0, not g.raised])
	await t.wait(2.0)
	t.log_line("soldier 2 after 2 s: x %d, blows so far %d" % [int(e2.global_position.x) if is_instance_valid(e2) else -1, g.hacked])
