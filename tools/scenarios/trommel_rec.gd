extends RefCounted
## Trommel: two rigs, each a dispenser dropping 12 pieces (copper, grit,
## iron, grit, scrap, grit in turn) down a chute into a trommel's mouth.
## The right one has power (a stand-in wheel at full power), the left runs
## on its own. Every grit should fall out through the holes somewhere along
## the drum, every bigger piece out of the low end; the powered one sooner.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1250, 490)
	var src := GDScript.new()
	src.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
	src.reload()
	var wheel := Node2D.new()
	wheel.set_script(src)
	wheel.global_position = Vector2(1420, 430)
	t.main.add_child(wheel)
	var drums := []
	for x in [990.0, 1300.0]:
		MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(x, 420), {"mode": 0, "kinds": ["copper", "grit", "iron", "grit", "scrap", "grit"], "limit": 12})
		MW._chute(t.main, Vector2(x - 12, 452), Vector2(x + 50, 478))
		drums.append(MW._piece(t.main, "res://scenes/trommel.tscn", Vector2(x + 58, 492), {"end_offset": Vector2(150, 16)}))
	var marks := []
	for k in 18:
		await t.wait(1.0)
		marks.append("%d+%d/%d+%d" % [drums[0].sifted, drums[0].tumbled, drums[1].sifted, drums[1].tumbled])
		if k == 5:
			await t.shot("trommel")
		if k == 10:
			await t.shot("trommel_mid")
	t.log_line("trommel out each second, sifted+tumbled (unpowered/powered): %s" % [marks])
	for i in 2:
		var dr = drums[i]
		var wrong: int = dr.sifted_kinds.filter(func(k): return k != "grit").size() + dr.tumbled_kinds.filter(func(k): return k == "grit").size()
		t.log_line("trommel %s: 12 mixed in -> %d grit out the holes (at %s px along), %d ore out the end %s in %s s, %d wrong, %d still inside" % [["unpowered", "powered"][i], dr.sifted, dr.sift_at, dr.tumbled, dr.tumbled_kinds, dr.transit, wrong, dr._riders.size()])
	await t.shot("trommel_end")
