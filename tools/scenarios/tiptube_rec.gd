extends RefCounted
## Tiptube: a dispenser feeds a mixed stream down a chute into the tube's
## mouth (heading right); each should be tipped out under it heading left
## onto the chute below. Counts, pour velocity, where they all end up.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var tt: Node2D = MW._piece(t.main, "res://scenes/tiptube.tscn", Vector2(1300, 440), {"side": 1.0})
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1165, 360), {"mode": 0, "limit": 5, "kinds": ["copper", "iron", "grit", "copper", "scrap"]})
	MW._chute(t.main, Vector2(1150, 395), Vector2(1292, 447))
	var outc = MW._chute(t.main, Vector2(1292, 484), Vector2(1100, 540))
	outc.has_lip = false
	outc._rebuild()
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1240, 460)
	var shots := 0
	for k in 180:
		await t.wait(0.05)
		if tt._state == 2 and shots < 2 and tt._angle > 0.9 + shots * 0.8:
			shots += 1
			await t.shot("tiptube_%d" % shots)
		if k == 60:
			await t.shot("tiptube_line")
	var ends := []
	var below := 0
	for o in t.get_nodes_in_group("ore"):
		ends.append("%s@%s" % [o.kind, Vector2i(o.global_position)])
		if o.global_position.x < 1250 and o.global_position.y > 490:
			below += 1
	t.log_line("tiptube: tipped %d | last pour v %s | %d of %d ended left and below | %s" % [tt.tipped, Vector2i(tt.last_out), below, ends.size(), ends])
