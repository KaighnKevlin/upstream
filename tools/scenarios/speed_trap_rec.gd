extends RefCounted
## Speed trap (>250): pieces passed under it at 150/200/350/400 px/s; it
## should read each speed and fire for the fast two only.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var rail = MW._chute(t.main, Vector2(1050, 450), Vector2(1550, 452))
	rail.has_lip = false
	rail._rebuild()
	var st: Node2D = MW._piece(t.main, "res://scenes/speed_trap.tscn", Vector2(1200, 428), {"mode": 1})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1270, 440)
	var out := []
	for v in [150.0, 200.0, 350.0, 400.0]:
		var f0: int = st.fired
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(1170, 438)
		t.main.add_child(o)
		o.gravity_scale = 0.0          # a clean pass at a known speed
		o.linear_velocity = Vector2(v, 0)
		await t.wait(0.12)
		if v == 350.0:
			await t.shot("speed_trap")
		await t.wait(2.0)
		out.append("%d: clocked %d, %s" % [int(v), int(st.last), "FIRED" if st.fired > f0 else "quiet"])
		o.queue_free()
	t.log_line("speed trap >250: %s | fired %d" % [out, st.fired])
