extends RefCounted
## Water wheel: one over a flume, one standing dry beside it; a sling in
## reach of the wet one. Their power after 4 s, and the sling's throw.
## The flume still floats copper under the wheel and over the weir.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var f: Node2D = preload("res://scenes/flume.tscn").instantiate()
	f.global_position = Vector2(1250, 520)
	f.end_offset = Vector2(200, 0)
	t.main.add_child(f)
	var wet = MW._piece(t.main, "res://scenes/water_wheel.tscn", Vector2(1330, 505))
	var dry = MW._piece(t.main, "res://scenes/water_wheel.tscn", Vector2(1000, 505))
	var sl = MW._piece(t.main, "res://scenes/sling.tscn", Vector2(1400, 400))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1360, 470)
	await t.wait(4.0)
	var ms := []
	for k in 3:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(1270, 490)
		t.main.add_child(o)
		ms.append(o)
		await t.wait(0.4)
	var d: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	d.lifetime = 1.0e9
	d.global_position = sl.global_position + Vector2(0, -60)
	t.main.add_child(d)
	await t.wait(0.6)
	await t.shot("water_wheel")
	await t.wait(3.0)
	t.log_line("water wheel: wet power %.2f, dry power %.2f | sling throw %d (340 unpowered) | flume floated over %d of 3" % [wet.power(), dry.power(), int(sl.last_v.length()), f.floated])
