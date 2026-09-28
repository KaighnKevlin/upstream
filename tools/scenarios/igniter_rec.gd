extends RefCounted
## Igniter: a bowling ramp at x 1300 rolls ore along the floor under an
## igniter. First with nobody there (they burst on their fuse), then with a
## soldier walking in (they burst on it). Lit / burst counts and hp.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var br: Node2D = preload("res://scenes/bowling_ramp.tscn").instantiate()
	br.global_position = Vector2(1300, 576)
	t.main.add_child(br)
	var ig: Node2D = preload("res://scenes/igniter.tscn").instantiate()
	ig.global_position = Vector2(1350, 556)
	t.main.add_child(ig)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1430, 500)
	await t.wait(0.5)
	for k in 2:
		_drop(t, br)
		await t.wait(0.8)
	await t.wait(2.5)
	t.log_line("igniter alone: lit %d, burst %d, ore left %d" % [ig.lit, ig.burst, t.get_nodes_in_group("ore").size()])
	var e = t._spawn(2, Vector2(1560, 560))
	await t.wait(0.3)
	var hp0: int = e.hp
	for k in 3:
		_drop(t, br)
		await t.wait(0.5)
		if k == 1:
			await t.wait(0.3)
			await t.shot("igniter")
	await t.wait(2.0)
	t.log_line("igniter vs soldier: lit %d, burst %d, hp %d->%s" % [ig.lit, ig.burst, hp0, str(e.hp) + ("" if not e._dying else " (dying)") if is_instance_valid(e) else "destroyed"])


static func _drop(t, br) -> void:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.global_position = br.global_position + Vector2(0, -150)
	t.main.add_child(o)
