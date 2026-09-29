extends RefCounted
## Performance: how the physics frame grows with loose pieces (and with the
## pieces that scan every piece each frame). Spawns N ore raining onto the
## cavern floor, logs physics/process frame times and FPS.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	# a few scanners, like a real base
	for i in 10:
		MW._piece(t.main, "res://scenes/magnet_rail.tscn", Vector2(1000 + i * 50, 300))
	var total := 0
	for n in [100, 300, 600, 1000]:
		while total < n:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.lifetime = 1.0e9
			o.global_position = Vector2(960 + randf() * 640, 200 + randf() * 150)
			t.main.add_child(o)
			total += 1
		await t.wait(2.0)
		var ph := 0.0
		var pr := 0.0
		var fps := 0.0
		for k in 20:
			await t.wait(0.05)
			ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			fps += Performance.get_monitor(Performance.TIME_FPS)
		t.log_line("perf: %d ore | physics %.1f ms/frame | process %.1f ms | %.0f fps | active bodies %d" % [n, ph / 20, pr / 20, fps / 20, Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)])
