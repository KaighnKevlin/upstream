extends RefCounted
## Walkers hit the dome from the surface beside it, not from a cave below.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	t.main.get_node("Player").global_position = Vector2(700, 60)
	var hp0: int = t.main.dome_hp
	t._spawn(2, Vector2(1290, 76))            # a soldier on the surface, walking in
	await t.wait(8.0)
	t.log_line("surface soldier: dome %d -> %d" % [hp0, t.main.dome_hp])
	for e in t.get_nodes_in_group("enemies"):
		e.queue_free()
	await t.wait(0.3)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	var hp1: int = t.main.dome_hp
	t._spawn(2, Vector2(1290, 560))           # one in the cavern beneath the dome
	await t.wait(8.0)
	t.log_line("cavern soldier: dome %d -> %d" % [hp1, t.main.dome_hp])
