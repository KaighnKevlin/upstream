extends RefCounted
## Grindstone: two rigs, each a dispenser dropping 6 ore (copper / iron
## in turn) down a chute into a grindstone. The right one has power (a
## stand-in wheel at full power), the left runs on its own. Every piece
## should come out as 3 grit, the powered one sooner. Then an ingot goes
## through the powered one untouched.


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
	cam.global_position = Vector2(1230, 500)
	# a stand-in power source at full power, only in reach of the right rig
	var src := GDScript.new()
	src.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
	src.reload()
	var wheel := Node2D.new()
	wheel.set_script(src)
	wheel.global_position = Vector2(1480, 470)
	t.main.add_child(wheel)
	var stones := []
	for x in [1000.0, 1360.0]:
		MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(x, 420), {"mode": 0, "kinds": ["copper", "iron"], "limit": 6})
		MW._chute(t.main, Vector2(x - 12, 460), Vector2(x + 64, 519))
		stones.append(MW._piece(t.main, "res://scenes/grindstone.tscn", Vector2(x + 86, 520), {"side": 1.0}))
	var marks := []
	for k in 10:
		await t.wait(1.0)
		marks.append("%d/%d" % [stones[0].ground, stones[1].ground])
		if k == 4:
			await t.shot("grindstone")
	t.log_line("grindstone ground each second (unpowered/powered): %s" % [marks])
	for i in 2:
		t.log_line("grindstone %s: 6 ore in -> %d ground, %d grit out, %d passed raw" % [["unpowered", "powered"][i], stones[i].ground, stones[i].grit_out, stones[i].passed])
	# an ingot is pushed on through, not ground
	var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ing.kind = "iron"
	ing.global_position = Vector2(1440, 500)
	t.main.add_child(ing)
	await t.wait(1.5)
	await t.shot("grindstone_after")
	var grit: int = t.get_nodes_in_group("ore").filter(func(o): return o.kind == "grit").size()
	t.log_line("grindstone: ingot passed=%d, now at x=%d (bed ends 1466) | grit loose in world %d" % [stones[1].passed, int(ing.global_position.x) if is_instance_valid(ing) else -1, grit])
