extends RefCounted
## Grapeshot mortar at x 1000. First, with nothing in range, a trigger must
## hold the load. Then per round a walker comes in from the right, 8 pieces
## are dropped into the mouth and a tally wheel wired to it fires once:
## the burst's damage (hp padded to 60 so it all counts), and how many of the 8 came down within 40 px of it.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var mt: Node2D = preload("res://scenes/grapeshot_mortar.tscn").instantiate()
	mt.global_position = Vector2(1000, 576)
	t.main.add_child(mt)
	var tl: Node2D = preload("res://scenes/tally.tscn").instantiate()
	tl.wire_to = Vector2.ZERO
	tl.global_position = Vector2(1060, 470)
	t.main.add_child(tl)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1160, 480)
	var feed := func(kind: String, n: int) -> void:
		for k in n:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = kind
			o.global_position = mt.global_position + Vector2(8 + randf_range(-3, 3), -90)
			t.main.add_child(o)
			await t.wait(0.1)
	# no target: it keeps its load
	await feed.call("copper", 3)
	await t.wait(0.5)
	tl.fire()
	await t.wait(0.2)
	t.log_line("grapeshot: no walker in range, trigger -> still loaded %d, bursts %d" % [mt.loaded.size(), mt.fired])
	await feed.call("copper", 5)
	await t.wait(0.4)
	var out := []
	for round in [[2, "copper", 1330.0], [0, "iron", 1400.0], [5, "copper", 1330.0]]:
		var e = t._spawn(round[0], Vector2(round[2], 560))
		if round[1] == "iron":
			await feed.call("iron", 8)
		await t.wait(0.5)
		var hp_real: int = e.hp
		e.hp = 60   # padded, to read the whole burst's damage
		var hp0: int = e.hp
		var n: int = mt.loaded.size()
		var b0: int = mt.fired
		tl.fire()   # the wire: everything triggerable in reach
		var landed := 0
		var shot_ids := {}
		for o in t.get_nodes_in_group("ore"):
			shot_ids[o.get_instance_id()] = true
		for f in 22:
			await t.wait(0.1)
			if f == 7 and round[0] == 2:
				await t.shot("grapeshot_copper")
			if f == 8 and round[0] == 0:
				await t.shot("grapeshot_iron")
		for o in t.get_nodes_in_group("ore"):
			if is_instance_valid(e) and absf(o.global_position.x - e.global_position.x) < 40:
				landed += 1
		var alive: bool = is_instance_valid(e) and not e._dying
		out.append("%d %s vs %s: burst %s, damage %s (its real hp %d), %d pieces lying within 40 px" % [
			n, round[1], ["titan", "", "soldier", "", "", "shieldbearer"][round[0]], mt.fired > b0,
			str(hp0 - e.hp) if alive else "all", hp_real, landed])
		if is_instance_valid(e):
			e.queue_free()
		for o in t.get_nodes_in_group("ore"):
			o.queue_free()
		await t.wait(0.2)
		if round[0] == 0:
			await feed.call("copper", 8)
	for line in out:
		t.log_line("grapeshot: " + line)
	t.log_line("grapeshot: bursts %d, pieces fired %d" % [mt.fired, mt.shots])
