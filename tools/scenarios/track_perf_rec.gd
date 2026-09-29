extends RefCounted
## Track net performance: a long looping network (a serpentine of rails,
## powered rows and gravity rows joined by drops, and a powered lift back to
## the top, ~63000 px of track, ~330 rails) with 200 / 1000 / 3000 riders
## going round it; then the same counts as physics ore raining into a wide
## cavern (the perf_ore_rec method), measured while they fall and once
## they've settled. Physics / process ms per frame, FPS, the net's own tick.

const MW = preload("res://scripts/marble_works.gd")
const Showcase = preload("res://scripts/sandbox_showcase.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const XL := 150.0
const XR := 2250.0
const Y0 := 170.0
const DY := 50.0
const ROWS := 28
const COUNTS := [200, 1000, 3000]


static func _measure(t, label: String, net: Node) -> void:
	var ph := 0.0
	var pr := 0.0
	var fps := 0.0
	var us := 0.0
	var ru := 0.0
	for k in 20:
		await t.wait(0.05)
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		fps += Performance.get_monitor(Performance.TIME_FPS)
		if net != null:
			us += net.tick_usec
			ru += net.render_usec
	var extra := ""
	if net != null:
		var moving := 0
		for tr in net.tracks:
			for i in tr.count():
				if absf(tr.rv[i]) > 20.0:
					moving += 1
		extra = " | net tick %.2f ms, draw update %.2f ms | moving %d of %d" % [us / 20000.0, ru / 20000.0, moving, net.rider_count()]
	t.log_line("perf %s | physics %.2f ms/frame | process %.2f ms | %.0f fps | active bodies %d%s" % [
		label, ph / 20, pr / 20, fps / 20, Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), extra])


static func _loop_points() -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in ROWS:
		var y := Y0 + i * DY
		var powered := i % 2 == 0
		var drop := 6.0 if powered else 24.0
		var right := i % 2 == 0
		var xa := XL if right else XR
		var xb := XR if right else XL
		if i == 0:
			xa = XL - 40.0
		if i == ROWS - 1:
			xb = XL - 40.0
		p.append(Vector2(xa, y))
		p.append(Vector2(xb, y + drop))
	return p


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await Showcase.clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(0.55, 0.55)
	cam.global_position = Vector2(1200, 700)
	await t.wait(0.3)
	await _measure(t, "baseline (nothing)", null)
	# the loop: rows (each ends where the next row's drop starts), then the lift
	var corners := _loop_points()
	var legs := []   # [a, b, drive]
	for i in ROWS:
		var a: Vector2 = corners[i * 2]
		var b: Vector2 = corners[i * 2 + 1]
		legs.append([a, b, 150.0 if i % 2 == 0 else 0.0])
		if i < ROWS - 1:
			legs.append([b, corners[i * 2 + 2], 0.0])   # the drop onto the next row
	var bottom: Vector2 = corners[corners.size() - 1]
	legs.append([bottom, corners[0], 150.0])             # the lift
	var rails := []
	for leg in legs:
		var a: Vector2 = leg[0]
		var b: Vector2 = leg[1]
		var k := int(ceil(a.distance_to(b) / 200.0))
		for j in k:
			var p0 := a.lerp(b, float(j) / k)
			var p1 := a.lerp(b, float(j + 1) / k)
			var r: Node2D = load("res://scenes/track_rail.tscn").instantiate()
			r.end_offset = p1 - p0
			r.drive = leg[2]
			rails.append(Showcase._add_node(t.main, r, p0))
	await t.wait(0.2)
	var net: Node = rails[0]._net
	var total := 0.0
	for tr in net.tracks:
		total += tr.length
	t.log_line("perf: loop of %d rails, %.0f px of track" % [rails.size(), total])
	await _measure(t, "track, 0 riders", net)
	for n in COUNTS:
		var tries := 0
		while net.rider_count() < n and tries < 20:
			# spread them evenly round the loop
			var step: float = total / n
			var at := step * (tries * 0.37)
			for tr in net.tracks:
				while at < tr.length and net.rider_count() < n:
					net.add_rider(tr, at, 100.0, "copper" if net.rider_count() % 2 == 0 else "iron")
					at += step
				at -= tr.length
			tries += 1
		await t.wait(2.0)
		await _measure(t, "track %4d riders" % net.rider_count(), net)
		if n == COUNTS[COUNTS.size() - 1]:
			await t.shot("track_3000")
	# the same counts as physics ore
	for tr in net.tracks:
		tr.clear_riders()
	for r in rails:
		r.queue_free()
	await t.wait(0.3)
	var tm: TileMapLayer = t.main.get_node("TileMapLayer")
	var shading: Node = t.main.get_node_or_null("TileShading")
	var decor: Node = t.main.get_node_or_null("CaveDecor")
	for y in range(9, 36):
		for x in range(8, 142):
			Showcase._clear(tm, Vector2i(x, y), shading, decor)
	for x in range(7, 143):
		WorldGen.set_tile(tm, Vector2i(x, 36), WorldGen.TILE_STONE)
	for y in range(9, 36):
		WorldGen.set_tile(tm, Vector2i(7, y), WorldGen.TILE_STONE)
		WorldGen.set_tile(tm, Vector2i(142, y), WorldGen.TILE_STONE)
	WorldGen.reframe_all(tm)
	await t.main.get_tree().physics_frame
	await t.main.get_tree().physics_frame
	cam.global_position = Vector2(1200, 400)
	var spawned := 0
	for n in COUNTS:
		while spawned < n:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.lifetime = 1.0e9
			o.kind = "copper" if spawned % 2 == 0 else "iron"
			o.global_position = Vector2(150 + randf() * 2100, 170 + randf() * 200)
			t.main.add_child(o)
			spawned += 1
		await t.wait(0.2)
		await _measure(t, "physics %4d ore, falling" % n, null)
		await t.wait(3.0)
		await _measure(t, "physics %4d ore, settled" % n, null)
		if n == COUNTS[COUNTS.size() - 1]:
			await t.shot("physics_3000")
