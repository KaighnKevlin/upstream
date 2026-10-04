extends RefCounted
## Factory's one lift: entering Factory stands the Beam in the starter pit;
## it takes in at most its budget (2/s) and the rest wait at its foot, in
## play (not despawning); leaving Factory takes it away again.
## Logs "FAIL ..." per broken check and "factory beam: ALL OK" if none.

const Tech = preload("res://scripts/tech.gd")


static func run(t) -> void:
	var fails := []
	Tech.levels.clear()
	t.main._show_title()
	await t.wait(0.6)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F
	t.main._on_title_input(ev)
	await t.wait(1.5)
	var bm = t.main.get_node_or_null("FactoryBeam")
	if bm == null:
		t.log_line("FAIL no FactoryBeam in Factory")
		return
	t.log_line("beam: crown %s depth %.0f budget %.1f/s, START has the lift: %s" % [bm.global_position, bm.depth, bm.budget(), Tech.START.has(4)])
	if Tech.START.has(4):
		fails.append("buildable lift still in START")

	# 24 ore dropped at the foot at once: ~2/s go up, the rest wait
	var foot := Vector2(bm.global_position.x, bm.bottom_y() - 20.0)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = bm.global_position + Vector2(0, bm.depth * 0.5)
	var ores := []
	for k in 24:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = foot + Vector2(randf_range(-8, 8), -k * 3.0)
		t.main.add_child(o)
		ores.append(o)
	await t.wait(1.0)
	var c0: int = bm.carried
	await t.wait(5.0)
	var lifted: int = bm.carried - c0
	var alive := ores.filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion()).size()
	t.log_line("in 5 s: %d over the crown (budget 10), %d waiting, usage %.2f, %d of 24 still in play" % [lifted, bm.waiting, bm.usage, alive])
	await t.shot("factory_beam")
	if lifted < 8 or lifted > 12:
		fails.append("lifted %d in 5 s, want ~10" % lifted)
	if bm.waiting < 1:
		fails.append("nothing waiting at the foot")
	if bm.usage < 0.7:
		fails.append("gauge usage %.2f while saturated" % bm.usage)

	# leaving Factory takes the beam away
	t.main.leave_factory()
	await t.wait(0.2)
	if t.main.has_node("FactoryBeam"):
		fails.append("beam left behind in the sandbox")

	for f in fails:
		t.log_line("FAIL " + f)
	if fails.is_empty():
		t.log_line("factory beam: ALL OK")
