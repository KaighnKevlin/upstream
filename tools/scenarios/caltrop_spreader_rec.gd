extends RefCounted
## Caltrop spreader on the cavern floor at x 1300, throwing right. First a
## soldier walks from x 1560 past it with nothing on the floor (the time
## to reach x 1320). Then four pieces (iron, iron, copper, grit) go in the
## hopper: caltrop count and spread. Then a second soldier walks the same
## way over the field: hp, caltrops spent, and the time against the first.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var s: Node2D = preload("res://scenes/caltrop_spreader.tscn").instantiate()
	s.global_position = Vector2(1300, 560)
	t.main.add_child(s)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1400, 520)
	await t.wait(0.5)
	t.log_line("caltrop spreader at (%d, %d)" % [int(s.global_position.x), int(s.global_position.y)])
	var base: Array = await _walk(t, s, false, false)
	t.log_line("unobstructed: reached x 1320 in %.2f s, hp %d -> %s" % [base[0], base[1], str(base[2])])
	await _feed(t, s)
	var xs: Array = []
	var ys: Array = []
	for c in t.get_nodes_in_group("caltrops"):
		xs.append(int(c.global_position.x))
		ys.append(int(c.global_position.y))
	xs.sort()
	t.log_line("fed %d pieces: thrown %d, live %d, x %s..%s (offset %d..%d), floor y %s" % [
		s.took, s.thrown, s.live_count(), str(xs.min()), str(xs.max()),
		int(xs.min()) - 1300 if xs.size() else -1, int(xs.max()) - 1300 if xs.size() else -1, str(ys.min()) + ".." + str(ys.max()) if ys.size() else "-"])
	t.log_line("caltrop xs: %s" % str(xs))
	await t.shot("caltrop_field")
	var live0: int = s.live_count()
	var run2: Array = await _walk(t, s, true, false)
	t.log_line("over the field: reached x 1320 in %s s (unobstructed %.2f), hp %d -> %s, caltrops spent %d (live %d -> %d)" % [
		"%.2f" % run2[0] if run2[0] > 0 else "never", base[0], run2[1], str(run2[2]), live0 - s.live_count(), live0, s.live_count()])
	# the same field again, walked by a soldier too tough to die on it, to
	# time the crossing
	for c in t.get_nodes_in_group("caltrops"):
		c.vanish()
	await _feed(t, s)
	var live1: int = s.live_count()
	var run3: Array = await _walk(t, s, false, true)
	t.log_line("timing (soldier hp 99) over a fresh %d-caltrop field: x 1320 in %s s vs %.2f s unobstructed, hp %d -> %s, spent %d" % [
		live1, "%.2f" % run3[0] if run3[0] > 0 else "never", base[0], run3[1], str(run3[2]), live1 - s.live_count()])
	# the cap: 8 more iron = 32 more caltrops, never more than 24 out
	for k in 8:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron"
		o.lifetime = 1.0e9
		o.global_position = s._hopper() + Vector2(0, -40)
		t.main.add_child(o)
		await t.wait(0.35)
	await t.wait(4.0)
	t.log_line("cap: thrown %d total, live %d, in group %d (cap 24)" % [s.thrown, s.live_count(), t.get_nodes_in_group("caltrops").size()])


## A soldier from x 1560 to x 1320: [seconds or -1, hp before, hp after].
static func _walk(t, s, shoot: bool, tough: bool) -> Array:
	var e = t._spawn(2, Vector2(1560, 560))
	await t.wait(0.05)
	if tough:
		e.hp = 99
	var hp0: int = e.hp
	var took := -1.0
	var shot := false
	var slow_seen := false
	for k in 600:
		await t.wait(0.05)
		if not is_instance_valid(e) or e._dying:
			break
		if e.speed < 29.0 and not slow_seen:
			slow_seen = true
			t.log_line("  limping at x %d: speed %.1f" % [int(e.global_position.x), e.speed])
		if shoot and not shot and slow_seen:
			shot = true
			await t.shot("caltrop_soldier")
		if e.global_position.x <= 1320:
			took = (k + 1) * 0.05
			break
	var hp1 = "destroyed"
	if is_instance_valid(e):
		hp1 = str(e.hp) + (" (dying)" if e._dying else "")
		if shoot:
			await t.wait(1.7)
			if is_instance_valid(e):
				t.log_line("  speed after: %.1f (limp meta %s)" % [e.speed, str(e.get_meta("caltrop_limp", 0))])
		if is_instance_valid(e):
			e.queue_free()
	await t.wait(0.3)
	return [took, hp0, hp1]


## Iron, iron, copper, grit into the hopper, and time to throw them all.
static func _feed(t, s) -> void:
	for k in ["iron", "iron", "copper", "grit"]:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = k
		o.lifetime = 1.0e9
		o.global_position = s._hopper() + Vector2(0, -40)
		t.main.add_child(o)
		await t.wait(0.7)
	await t.wait(1.5)
