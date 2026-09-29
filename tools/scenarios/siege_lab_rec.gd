extends RefCounted
## Layout lab for Marble Siege: the machine alone (no waves), watched.
## LAB_SECS, LAB_ZOOM, LAB_AT=x,y (camera) from the environment.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	var d: Node2D = await preload("res://scripts/siege_works.gd").build(t.main)
	d.waves = []
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	var secs := float(OS.get_environment("LAB_SECS")) if OS.has_environment("LAB_SECS") else 40.0
	var zoom := OS.get_environment("LAB_ZOOM")
	cam.zoom = Vector2(1.15, 1.15) if zoom == "" else Vector2(float(zoom), float(zoom))
	var at := OS.get_environment("LAB_AT")
	cam.global_position = Vector2(1616, 420) if at == "" else Vector2(float(at.split(",")[0]), float(at.split(",")[1]))
	t.main.get_node("Player").global_position = Vector2(1200, 640)
	var p: Dictionary = d.parts
	var clock := 0.0
	var dbg := OS.get_environment("LAB_DEBUG")
	while clock < secs:
		if dbg != "":
			var r := Rect2(float(dbg.split(",")[0]), float(dbg.split(",")[1]), float(dbg.split(",")[2]), float(dbg.split(",")[3]))
			for k in 10:
				await t.physics_frame
				for o in t.get_nodes_in_group("ore"):
					if r.has_point(o.global_position):
						t.log_line("  %s at %s v %s grav %.1f" % [o.kind, o.global_position.round(), o.linear_velocity.round(), o.gravity_scale])
			await t.wait(0.84)
		else:
			await t.wait(1.0)
		clock += 1.0
		if int(clock) % 5 == 0:
			var s := "t=%d" % int(clock)
			for k in p:
				s += " %s=%s" % [k, _count(p[k])]
			s += " ore=%d" % t.get_nodes_in_group("ore").size()
			t.log_line(s)
		if int(clock) % 10 == 0:
			await t.shot("lab_%d" % int(clock))


static func _count(n) -> String:
	if n is Array:
		return str(n.map(func(x): return _count(x)))
	if not (n is Node) or not is_instance_valid(n):
		return "?"
	var out := []
	for f in ["dropped", "fed", "thrown", "lifted", "carried", "looped", "fell", "landed", "kicks", "turned", "took", "sent", "primary", "overflowed", "lit", "burst", "flung", "releases", "drops", "shots", "armed", "raised", "tripped", "_held", "entry_speeds", "loaded", "_queue"]:
		if f in n:
			out.append("%s:%s" % [f, str(n.get(f))])
	return "{" + ",".join(out) + "}"
