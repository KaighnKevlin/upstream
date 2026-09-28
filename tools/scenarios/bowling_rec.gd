extends RefCounted
## Bowling ramp: a ramp at x 1000 bowling right along the floor. A soldier
## (then a shieldbearer) walks in from the right; two pieces of one kind are
## fed into the mouth. Per kind: exit speed, hp lost, and how far each hit
## shoved it back (its x after the hit, over its x at the hit).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(960, 540)
	var br: Node2D = preload("res://scenes/bowling_ramp.tscn").instantiate()
	br.global_position = Vector2(1000, 576)
	t.main.add_child(br)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1130, 500)
	await t.wait(0.5)
	var out := []
	for who in [2, 5]:
		for kind in ["copper", "iron"]:
			var e = t._spawn(who, Vector2(1230, 560))
			await t.wait(0.4)
			var hp0: int = e.hp
			var hits0: int = br.hits
			var shoves := []
			for k in 2:
				var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
				o.kind = kind
				o.global_position = br.global_position + Vector2(0, -150)
				t.main.add_child(o)
				# follow the walker: its x when struck, and the farthest back it goes
				var at_hit := -1.0
				var back := 0.0
				var h0: int = br.hits
				for f in 24:
					await t.wait(0.05)
					if not is_instance_valid(e) or e._dying:
						break
					if at_hit < 0 and br.hits > h0:
						at_hit = e.global_position.x
						if k == 0 and not (who == 5 and kind == "copper"):
							await t.shot("bowl_%s_%s" % [kind, "soldier" if who == 2 else "shield"])
					if who == 5 and kind == "copper" and k == 0 and f == 16:
						await t.shot("bowl_copper_shield")
					if at_hit >= 0:
						back = maxf(back, e.global_position.x - at_hit)
				shoves.append(int(back) if at_hit >= 0 else -1)
			var alive: bool = is_instance_valid(e) and not e._dying
			var hp1: int = e.hp if is_instance_valid(e) else -99
			out.append("%s vs %s: exit %d px/s, hits %d, hp %d->%d%s, shoved back %s px, last %s" % [
				kind, "soldier" if who == 2 else "shieldbearer", int(br.last_speed), br.hits - hits0,
				hp0, hp1, "" if alive else " (destroyed)", shoves, br.last_hit])
			if is_instance_valid(e):
				e.queue_free()
			for o in t.get_nodes_in_group("ore"):
				o.queue_free()
			await t.wait(0.2)
	for line in out:
		t.log_line("bowling: " + line)
	t.log_line("bowling: bowled %d, hits %d, damage %d" % [br.bowled, br.hits, br.damage_done])
