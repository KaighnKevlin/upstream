extends RefCounted
## Fuse cord: A (120 px, from (1250,500) to the right) chained to B (80 px
## on from A's end, down-right), and B's detonator on the start cap of a
## third cord C (the counter: it should light). Lit by trigger(): A's end
## fires ~3 s later and lights B, B's end ~5 s after the start and lights
## C. A lit again while burning / ash is ignored. After the re-knit, an
## igniter over a chute lights a copper piece that rolls off the chute's
## end and falls across cord A: that lights it.


static func _state(n: String, c: Node2D) -> String:
	return "%s lit %d fired %d ignored %d" % [n, c.lit, c.fired, c.ignored]


## A cord's event time on A's clock (the cords were placed together, but
## don't count on the same frame).
static func _on_a(c: Node2D, at: float, A: Node2D) -> float:
	return at - c.age + A.age


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(1000, 540)
	var a0 := Vector2(1250, 500)
	var a_end := Vector2(120, 0)
	var b_end := Vector2(80, 0).rotated(PI * 0.25)
	var c_end := Vector2(60, -10)
	var A: Node2D = MW._piece(t.main, "res://scenes/fuse_cord.tscn", a0, {"end_offset": a_end})
	var B: Node2D = MW._piece(t.main, "res://scenes/fuse_cord.tscn", a0 + a_end, {"end_offset": b_end})
	var C: Node2D = MW._piece(t.main, "res://scenes/fuse_cord.tscn", a0 + a_end + b_end, {"end_offset": c_end})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = Vector2(1340, 520)
	await t.wait(0.5)
	# 1: lit by a signal
	var t0: float = A.age
	A.trigger()
	await t.wait(0.3)
	A.trigger()                      # already burning: ignored
	var mid := false
	for f in 400:
		await t.wait(0.02)
		if not mid and A.age - t0 > 1.5:
			mid = true
			await t.shot("fuse_cord_burn")
		if C.lit > 0:
			break
	t.log_line("trigger: A lit->A fired %.2f s (expect 3.0) | B lit at +%.2f | B fired at +%.2f (expect ~5.0) | C lit at +%.2f" % [
			A.fired_at - A.lit_at, _on_a(B, B.lit_at, A) - t0, _on_a(B, B.fired_at, A) - t0, _on_a(C, C.lit_at, A) - t0])
	t.log_line("  %s | %s | %s" % [_state("A", A), _state("B", B), _state("C", C)])
	await t.wait(0.4)
	await t.shot("fuse_cord_chain")
	A.trigger()                      # ash: ignored
	await t.wait(3.0)
	t.log_line("after re-knit: A burning %s, ash %.2f | %s" % [A.burning, A._ash, _state("A", A)])
	# 2: lit by an igniter's piece falling across it
	var ch: Node2D = MW._chute(t.main, Vector2(1150, 420), Vector2(1262, 452))
	ch.has_lip = false
	ch._rebuild()
	var ig: Node2D = MW._piece(t.main, "res://scenes/igniter.tscn", Vector2(1195, 431), {"mode": 2})
	cam.global_position = Vector2(1280, 470)
	await t.wait(0.4)
	var lit0: int = A.lit
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.global_position = Vector2(1160, 390)
	t.main.add_child(o)
	for f in 200:
		await t.wait(0.02)
		if A.lit > lit0:
			break
	var at := o.global_position if is_instance_valid(o) else Vector2.ZERO
	t.log_line("igniter: ore lit by igniter %d | A lit by the falling piece: %s (ore at (%d,%d)) | %s" % [ig.lit, A.lit > lit0, int(at.x), int(at.y), _state("A", A)])
	await t.wait(0.8)
	await t.shot("fuse_cord_ore")
	await t.wait(3.0)
	t.log_line("ore-lit run: %s | %s | %s" % [_state("A", A), _state("B", B), _state("C", C)])
