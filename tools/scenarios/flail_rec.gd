extends RefCounted
## Flail on the cavern floor at x 1400. A soldier walks in from the right,
## first with the flail unpowered, then with a full-power source in reach
## (a stand-in wheel). Hits, hp lost, and how far back it was knocked.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var f: Node2D = preload("res://scenes/flail.tscn").instantiate()
	f.global_position = Vector2(1400, 560)
	t.main.add_child(f)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1440, 500)
	for powered in [false, true]:
		var src: Node2D = null
		if powered:
			var sc := GDScript.new()
			sc.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\n"
			sc.reload()
			src = Node2D.new()
			src.set_script(sc)
			src.global_position = Vector2(1460, 540)
			t.main.add_child(src)
			await t.wait(2.0)
		var e = t._spawn(2, Vector2(1560, 560))
		var hp0: int = e.hp
		var h0: int = f.hits
		var min_x := 99999.0
		for k in 60:
			await t.wait(0.1)
			if not is_instance_valid(e) or e._dying:
				break
			min_x = minf(min_x, e.global_position.x)
			if powered and k == 18:
				await t.shot("flail")
		var alive: bool = is_instance_valid(e) and not e._dying
		t.log_line("flail %s: hits %d, hp %d -> %s, closest x %d (post at 1400)" % [
			"powered" if powered else "unpowered", f.hits - h0, hp0, str(e.hp) if alive else "destroyed", int(min_x)])
		if is_instance_valid(e):
			e.queue_free()
		await t.wait(0.3)
