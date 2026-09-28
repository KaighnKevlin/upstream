extends RefCounted
## Wrecking ball hung at (1400,470), cocked right (side +1). A soldier walks
## in from the right; the ball is let go as it passes under; then four
## pieces dropped in the winch bucket re-arm it.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var w: Node2D = preload("res://scenes/wrecking_ball.tscn").instantiate()
	w.global_position = Vector2(1400, 470)
	t.main.add_child(w)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1420, 500)
	await t.wait(0.5)
	var e = t._spawn(2, Vector2(1520, 560))
	var hp0: int = e.hp
	for k in 80:
		await t.wait(0.05)
		if e.global_position.x < 1420:
			w.trigger()
			break
	await t.wait(0.3)
	await t.shot("wrecking_ball")
	await t.wait(1.3)
	var alive: bool = is_instance_valid(e) and not e._dying
	t.log_line("wrecking ball: released %d, hits %d, soldier hp %d -> %s, x %d" % [w.releases, w.hits, hp0, str(e.hp) if alive else "destroyed", int(e.global_position.x) if is_instance_valid(e) else -1])
	await t.wait(3.0)
	for k in 4:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = w._bucket() + Vector2(0, -30)
		t.main.add_child(o)
		await t.wait(0.6)
	await t.wait(3.0)
	t.log_line("wrecking ball: after 4 pieces in the winch armed=%s (angle %.2f)" % [w.armed, w._th])
	await t.shot("wrecking_ball_rearmed")
