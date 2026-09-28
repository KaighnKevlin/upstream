extends RefCounted
## Volcano: pieces dropped into the cup one at a time. At 5 it should erupt
## all five at once, straight up and fanned; 10 dropped: 2 eruptions. Then
## at 3 (mode 0): 3 more, one eruption. Then 2 and a trigger. Heights,
## spread, and that none fall back in.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var at := Vector2(1300, 540)
	var vc: Node2D = MW._piece(t.main, "res://scenes/volcano.tscn", at, {"mode": 1})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1300, 460)
	var out := []
	var plan := [[1, 10], [0, 3], [0, 2]]
	var kinds := ["copper", "iron", "grit", "copper", "scrap"]
	for step in plan:
		vc.mode = step[0]
		var e0: int = vc.erupted
		var l0: int = vc.launched
		var mine := []
		var counts := []
		var peak := 9999.0
		for k in step[1]:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = kinds[k % kinds.size()]
			o.lifetime = 1.0e9
			o.global_position = at + Vector2(randf_range(-5, 5), -70)
			t.main.add_child(o)
			mine.append(o)
			for w in 8:
				var before: int = vc.erupted
				await t.wait(0.05)
				if vc.erupted > before and step[1] == 10 and vc.erupted == 1:
					await t.wait(0.15)
					await t.shot("volcano_erupt")
			counts.append(vc._held.size())
			if k == 3 and step[1] == 10:
				await t.shot("volcano_filling")
		if step[1] == 2:
			vc.trigger()
		for k in 36:
			await t.wait(0.05)
			for o in mine:
				if is_instance_valid(o) and vc.erupted > e0:
					peak = minf(peak, o.global_position.y)
		var xs := []
		for o in mine:
			xs.append(int(o.global_position.x - at.x))
		xs.sort()
		out.append("need %d, %d dropped%s: held %s, erupted %d times, threw %d, rose to %d px above the cup, landed at dx %s" % [vc.need(), step[1], " + trigger" if step[1] == 2 else "", counts, vc.erupted - e0, vc.launched - l0, int(at.y - peak), xs])
	t.log_line("volcano: %d eruptions, %d thrown, %d left in the cup | %s" % [vc.erupted, vc.launched, vc._held.size(), out])
