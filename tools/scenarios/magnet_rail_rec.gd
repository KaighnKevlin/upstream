extends RefCounted
## Magnet rail: a bar from (1200,440) sloping down to the right; iron and
## copper tossed up under it from the floor. Iron should be carried off the
## far end (landing right of ~1400), copper fall back near where it rose.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var m: Node2D = preload("res://scenes/magnet_rail.tscn").instantiate()
	m.global_position = Vector2(1200, 440)
	m.end_offset = Vector2(220, 40)
	t.main.add_child(m)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1330, 480)
	var pcs := []
	for k in 8:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = "iron" if k % 2 == 0 else "copper"
		o.lifetime = 1.0e9
		o.global_position = Vector2(1240 + k * 6, 565)
		t.main.add_child(o)
		o.linear_velocity = Vector2(20, -470)
		pcs.append(o)
		await t.wait(0.35)
		if k == 5:
			await t.shot("magnet_rail")
	await t.wait(3.0)
	var iron := []
	var copper := []
	for o in pcs:
		if is_instance_valid(o):
			(iron if o.kind == "iron" else copper).append(int(o.global_position.x))
	t.log_line("magnet rail: carried %d | iron landed x %s | copper landed x %s (rail ends x %d)" % [m.carried, iron, copper, int(m.global_position.x + m.end_offset.x)])
