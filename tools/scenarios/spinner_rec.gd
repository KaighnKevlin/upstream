extends RefCounted
## Spinner: marbles rolled along the floor under a spinner, one every 0.8 s.
## Its power as the line runs and after it stops; a sling nearby throws one
## unpowered (before) and one on the spinner's power (after).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var sp = MW._piece(t.main, "res://scenes/spinner.tscn", Vector2(1330, 558))
	var sl = MW._piece(t.main, "res://scenes/sling.tscn", Vector2(1420, 470))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1400, 500)
	await t.wait(0.5)
	_drop(t, sl)
	await t.wait(3.0)
	var v0: int = int(sl.last_v.length())
	var pw := []
	for k in 10:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(1260, 566)
		t.main.add_child(o)
		o.linear_velocity = Vector2(260, 0)
		await t.wait(0.8)
		pw.append(snappedf(sp.power(), 0.01))
		if k == 6:
			_drop(t, sl)
		if k == 7:
			await t.shot("spinner")
	var v1: int = int(sl.last_v.length())
	await t.wait(3.0)
	t.log_line("spinner: passes %d, power as the line ran %s, 3 s after %.2f | sling throw %d unpowered -> %d on the spinner" % [sp.passes, pw, sp.power(), v0, v1])


static func _drop(t, sl) -> void:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.global_position = sl.global_position + Vector2(0, -60)
	t.main.add_child(o)
