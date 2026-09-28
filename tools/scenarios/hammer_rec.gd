extends RefCounted
## Hammer: rounds of (a piece dropped onto the ledge, then one dropped onto
## the paddle from above). The ledge piece should fly off sideways (right),
## the dropped one carry on down (left of the pivot). Last, one struck by a
## trigger with nothing dropped.


static func _ore(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	t.main.add_child(o)
	return o


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var at := Vector2(1100, 490)
	var hm: Node2D = MW._piece(t.main, "res://scenes/hammer.tscn", at, {"side": 1.0})
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1170, 480)
	var out := []
	var rounds := [["copper", "copper"], ["iron", "copper"], ["copper", "iron"]]
	for r in rounds.size():
		var drop_k: String = rounds[r][0]
		var ledge_k: String = rounds[r][1]
		var n0: int = hm.struck
		var target := _ore(t, ledge_k, at + hm.ledge_point() + Vector2(0, -40))
		await t.wait(0.8)
		var loaded: bool = hm._loaded == target
		var drop := _ore(t, drop_k, at + hm.paddle_point() + Vector2(0, -90))
		var land_x := -1
		var peak := 9999.0
		var shot_done := false
		for k in 40:
			await t.wait(0.03 if r == 1 else 0.05)
			if hm.struck > n0:
				peak = minf(peak, target.global_position.y)
				if land_x < 0 and target.global_position.y > 560:
					land_x = int(target.global_position.x)
			if r == 1 and hm.struck > n0 and not shot_done:
				shot_done = true
				await t.shot("hammer_strike")
		out.append("%s on %s: loaded %s, struck at %d px/s, landed x %d (%d right of the ledge), dropped one at %s" % [drop_k, ledge_k, loaded, int(hm.last_speed) if hm.struck > n0 else 0, land_x, land_x - int(at.x + hm.ledge_point().x), Vector2i(drop.global_position)])
		for o in [target, drop]:
			o.queue_free()
	# a trigger, nothing dropped
	var n1: int = hm.struck
	var tg := _ore(t, "copper", at + hm.ledge_point() + Vector2(0, -40))
	await t.wait(0.8)
	hm.trigger()
	await t.wait(0.6)
	out.append("trigger: struck %d, piece at %s" % [hm.struck - n1, Vector2i(tg.global_position)])
	await t.shot("hammer_after")
	t.log_line("hammer: struck %d of 4, swings %d | %s" % [hm.struck, hm.swings, out])
