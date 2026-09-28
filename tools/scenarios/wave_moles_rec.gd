extends RefCounted
## A real wave 8 with a powered machine standing: burrowers and a rust-mite
## swarm should come with it (and nothing should error).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var wh: Node2D = MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1300, 540))
	t.main.get_node("/root/BuildSystem")._placed_buildings.append(wh)
	t.main.wave_number = 7
	t.main._spawn_wave()
	await t.wait(3.0)
	t.log_line("wave %d: burrowers %d, rust mites %d, enemies %d" % [t.main.wave_number,
		t.get_nodes_in_group("enemies").filter(func(e): return e.get_script() and e.get_script().resource_path.get_file() == "burrower.gd").size(),
		t.get_nodes_in_group("rust_mites").size(), t.get_nodes_in_group("enemies").size()])
