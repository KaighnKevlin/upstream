extends RefCounted
## Gear stamp: two stamps, each fed down a chute with 4 iron ingots and
## then a copper one. The right one has power (a stand-in wheel at full
## power), the left runs on its own. Every iron ingot should come out as
## one gear, the powered one sooner; the copper ingot is pushed on
## through untouched.


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
	var src := GDScript.new()
	src.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
	src.reload()
	var wheel := Node2D.new()
	wheel.set_script(src)
	wheel.global_position = Vector2(1480, 470)
	t.main.add_child(wheel)
	var stamps := []
	for x in [1080.0, 1400.0]:
		MW._chute(t.main, Vector2(x - 90, 510), Vector2(x - 14, 548))
		stamps.append(MW._piece(t.main, "res://scenes/gear_stamp.tscn", Vector2(x, 576), {"side": 1.0}))
	var copper := []
	var marks := []
	for k in 11:
		if k < 5:
			for s in stamps:
				var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
				ing.kind = "copper" if k == 4 else "iron"
				ing.lifetime = 1.0e9
				ing.global_position = s.global_position + Vector2(-82, -76)
				t.main.add_child(ing)
				if k == 4:
					copper.append(ing)
		await t.wait(1.0)
		marks.append("%d/%d" % [stamps[0].stamped, stamps[1].stamped])
		if k == 3:
			await t.shot("gear_stamp")
	await t.wait(1.5)
	await t.shot("gear_stamp_after")
	t.log_line("gear stamp stamped each second (unpowered/powered): %s" % [marks])
	for i in 2:
		t.log_line("gear stamp %s: 4 iron ingots in -> %d taken -> %d gears; copper ingot passed=%d, at x=%d (anvil ends %d)" % [["unpowered", "powered"][i], stamps[i].taken, stamps[i].stamped, stamps[i].passed, int(copper[i].global_position.x) if is_instance_valid(copper[i]) else -1, int(stamps[i].global_position.x + 12)])
	var gears: int = t.get_nodes_in_group("ore").filter(func(o): return o.kind == "gear").size()
	t.log_line("gear stamp: gears loose in world %d, ingots %d" % [gears, t.get_nodes_in_group("ingots").size()])
