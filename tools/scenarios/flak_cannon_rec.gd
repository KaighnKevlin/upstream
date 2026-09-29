extends RefCounted
## Flak cannon on the cavern floor at x 1400. An ornithopter is sent across
## the cavern overhead (its altitude pinned at y 390, ~160 px over the
## muzzle), right to left. Three runs:
##  A. 4 iron + 2 copper loaded, fuse auto, the flier's hp padded to 40 so
##     every burst's damage shows: shots, bursts, hits, hp over time.
##  B. the same load, fuse 200 px, the flier at its real hp (3): downed?
##  C. the hopper empty: no shots, hp untouched.
## A burst is screenshotted in run A.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	var turret: Node = t.main.get_node_or_null("Turret")
	if turret:
		turret.set_physics_process(false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var fk: Node2D = preload("res://scenes/flak_cannon.tscn").instantiate()
	fk.global_position = Vector2(1400, 560)
	t.main.add_child(fk)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1400, 450)
	await t.wait(0.4)
	t.log_line("flak: cannon at (%d, %d)" % [int(fk.global_position.x), int(fk.global_position.y)])
	# A
	await _feed(t, fk, ["iron", "iron", "iron", "iron", "copper", "copper"])
	t.log_line("flak A: loaded %s" % str(fk.loaded))
	await _pass(t, fk, "A", 40, 0, true)
	# B
	await _feed(t, fk, ["iron", "iron", "iron", "iron", "copper", "copper"])
	fk.mode = 2
	t.log_line("flak B: loaded %s, fuse %d px" % [str(fk.loaded), int(fk.FUSES[fk.mode])])
	await _pass(t, fk, "B", -1, 2, false)
	# C
	fk.loaded.clear()
	fk.mode = 0
	await _pass(t, fk, "C", -1, 0, false)


static func _feed(t, fk: Node2D, kinds: Array) -> void:
	for k in kinds:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.global_position = fk.global_position + fk.HOPPER + Vector2(randf_range(-2, 2), -50)
		t.main.add_child(o)
		await t.wait(0.25)
	await t.wait(0.6)


static func _pass(t, fk: Node2D, tag: String, pad_hp: int, _fuse: int, grab: bool) -> void:
	var s0: int = fk.shots
	var b0: int = fk.bursts
	var h0: int = fk.hits
	var d0: int = fk.downed
	var f: Node2D = t._spawn(4, Vector2(1720, 390))
	f._fly_y = 390.0
	if pad_hp > 0:
		f.hp = pad_hp
	var hp_start: int = f.hp
	var hp_log: Array = []
	var shot_taken := false
	var last_s: int = s0
	var last_b: int = b0
	for i in 200:   # 10 s
		await t.wait(0.05)
		var alive: bool = is_instance_valid(f) and not f._dying
		if fk.shots != last_s:
			last_s = fk.shots
			t.log_line("flak %s: shot %d (%s left) at flier x %d" % [tag, fk.shots - s0, fk.loaded.size(),
				int(f.global_position.x) if alive else -1])
		if fk.bursts != last_b:
			last_b = fk.bursts
			t.log_line("flak %s: burst %d at (%d, %d), %d px up; flier at (%s), hp %s" % [tag, fk.bursts - b0,
				int(fk.last_burst.x), int(fk.last_burst.y), int(fk.last_height),
				("%d, %d" % [int(f.hit_center().x), int(f.hit_center().y)]) if alive else "-",
				str(f.hp) if alive else "down"])
			if grab and not shot_taken:
				shot_taken = true
				await t.wait(0.06)
				await t.shot("flak_burst")
		if i % 5 == 0:
			hp_log.append("%.2fs:%s" % [i * 0.05, str(f.hp) if alive else "down"])
		if not alive and i % 5 == 0 and hp_log.size() > 2 and hp_log[-2].ends_with("down"):
			break
	var alive2: bool = is_instance_valid(f) and not f._dying
	t.log_line("flak %s: hp over time %s" % [tag, " ".join(hp_log)])
	t.log_line("flak %s: shots %d, bursts %d, hits %d, downed %d; flier hp %d -> %s, %s" % [tag,
		fk.shots - s0, fk.bursts - b0, fk.hits - h0, fk.downed - d0, hp_start,
		str(f.hp) if alive2 else "0", "DOWNED" if not alive2 else "still flying at x %d" % int(f.global_position.x)])
	if is_instance_valid(f):
		f.queue_free()
	await t.wait(0.5)
