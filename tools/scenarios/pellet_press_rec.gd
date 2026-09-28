extends RefCounted
## Pellet press: left, unpowered, 9 grit dropped straight in (should make
## 3 shot), then a copper ore that should be thrown back out. Right, a
## powered chain: 3 copper down a chute into a grindstone, its grit down a
## second chute into a press (3 copper -> 9 grit -> 3 shot).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1230, 480)
	# a stand-in power source at full power, only in reach of the right rig
	var src := GDScript.new()
	src.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
	src.reload()
	var wheel := Node2D.new()
	wheel.set_script(src)
	wheel.global_position = Vector2(1480, 470)
	t.main.add_child(wheel)
	# left: grit straight into an unpowered press
	var d: Node2D = MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1030, 420), {"mode": 0, "kinds": ["grit"], "limit": 9})
	var pa: Node2D = MW._piece(t.main, "res://scenes/pellet_press.tscn", Vector2(1030, 576), {"side": 1.0})
	# right: copper -> grindstone -> press, powered
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1250, 380), {"mode": 0, "kinds": ["copper"], "limit": 3})
	MW._chute(t.main, Vector2(1238, 420), Vector2(1314, 469))
	var gs: Node2D = MW._piece(t.main, "res://scenes/grindstone.tscn", Vector2(1336, 470), {"side": 1.0})
	MW._chute(t.main, Vector2(1358, 472), Vector2(1438, 504))
	var pb: Node2D = MW._piece(t.main, "res://scenes/pellet_press.tscn", Vector2(1452, 576), {"side": 1.0})
	var marks := []
	for k in 11:
		await t.wait(1.0)
		marks.append("%d:%d/%d" % [pa.held, pa.pressed, pb.pressed])
		if k == 6:
			await t.shot("pellet_press")
	# a copper ore into the left hopper: not grit, thrown back out
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = Vector2(1030, 500)
	t.main.add_child(o)
	await t.wait(1.5)
	await t.shot("pellet_press_after")
	t.log_line("pellet press each second (left held:left shot/right shot): %s" % [marks])
	t.log_line("pellet press unpowered: %d grit dropped -> %d taken -> %d shot, %d held; copper rejected %d (ore now at x=%d)" % [d.dropped, pa.taken, pa.pressed, pa.held, pa.rejected, int(o.global_position.x) if is_instance_valid(o) else -1])
	t.log_line("pellet press chain (powered): 3 copper -> %d ground -> %d grit -> press took %d -> %d shot, %d held" % [gs.ground, gs.grit_out, pb.taken, pb.pressed, pb.held])
	var shot: int = t.get_nodes_in_group("ore").filter(func(x): return x.kind == "shot").size()
	t.log_line("pellet press: shot loose in world %d" % shot)
