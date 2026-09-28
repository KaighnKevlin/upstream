extends RefCounted
## Bowl feeder on the cavern floor at x 1300, exit lip to the right,
## unpowered. A mixed handful (8 copper/iron + 3 grit) dumped in its mouth
## at once: how many leave the lip, how evenly (their gaps in time), and is
## the grit spat out the reject hole on the left.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var bf = MW._piece(t.main, "res://scenes/bowl_feeder.tscn", Vector2(1300, 576), {"side": 1.0})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2, 2)
	cam.global_position = Vector2(1300, 520)
	await t.wait(0.5)
	var ms := []
	for k in 11:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.kind = "grit" if k % 4 == 2 else ("iron" if k % 3 == 1 else "copper")
		o.global_position = Vector2(1292 + (k % 4) * 5, 470 - (k / 4) * 12)
		t.main.add_child(o)
		ms.append(o)
	await t.wait(4.0)
	await t.shot("bowl_feeder")
	await t.wait(3.0)
	await t.shot("bowl_feeder_late")
	await t.wait(12.0)
	var gaps: Array = []
	for i in range(1, bf.exit_times.size()):
		gaps.append(snappedf(bf.exit_times[i] - bf.exit_times[i - 1], 0.01))
	var grit: Array = ms.filter(func(o): return is_instance_valid(o) and o.kind == "grit")
	var big: Array = ms.filter(func(o): return is_instance_valid(o) and o.kind != "grit")
	t.log_line("bowl feeder: fed %d of 8 | gaps s %s | grit rejected %d of 3" % [bf.fed, gaps, bf.rejected])
	t.log_line("bowl feeder: pieces at x %s (lip end x 1337) | grit at x %s (hole x 1281)" % [big.map(func(o): return int(o.global_position.x)), grit.map(func(o): return int(o.global_position.x))])
	await t.shot("bowl_feeder_done")
