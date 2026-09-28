extends RefCounted
## The showcase's marble yard, in the chamber under the dome's east
## approach: the whole showcase is rebuilt (the harness clears it), then the
## yard runs for a minute on its own. Every 10 s: what each piece has done
## (tappers in, net, paddle wheel and flywheel, drum, tally and points,
## silo, turn, brake, furnace, pipe) and the dome's intake; shots framing
## the yard. The flow is proven by the furnace's ingots arriving at the
## dome's intake out of the pipe.


static func _find(t, path: String) -> Array:
	var out := []
	for n in t.get_nodes_in_group("showcase"):
		if is_instance_valid(n) and n.get_script() and n.get_script().resource_path.ends_with(path):
			out.append(n)
	return out


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	var sc := preload("res://scripts/sandbox_showcase.gd")
	sc.build(t.main)
	t.main.get_node("Turret").set_physics_process(false)
	var p: Node2D = t.main.get_node("Player")
	p.global_position = Vector2(900, 60)     # out of the way, on the west surface
	var cam: Camera2D = p.get_node("Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = Vector2(1488, 488)   # the whole chamber, above the build bar
	await t.wait(0.5)
	var net: Node2D = _find(t, "catch_net.gd")[0]
	var paddle: Node2D = _find(t, "paddle_wheel.gd")[0]
	var fly: Node2D = _find(t, "flywheel.gd")[0]
	var drum: Node2D = _find(t, "magnet_drum.gd")[0]
	var tally: Node2D = _find(t, "tally.gd")[0]
	var points: Node2D = _find(t, "points.gd")[0]
	var silo: Node2D = _find(t, "silo.gd")[0]
	var turns: Array = _find(t, "banked_turn.gd")
	var brake: Node2D = _find(t, "brake.gd")[0]
	var furnace: Node2D = _find(t, "furnace_rail.gd")[0]
	var pipe: Node2D = _find(t, "tube.gd")[0]
	var rx: Node = t.main.get_node("Receiver")
	# what the pipe delivers: ingots arriving at the intake from its outlet
	# (shot up into it from below; the west laser's ingots fall in from above)
	var piped := {"ingots": 0, "raw": 0}
	rx.body_entered.connect(func(b):
		if b is RigidBody2D and b.linear_velocity.y < 0.0:
			piped["ingots" if b.is_in_group("ingots") else "raw"] += 1)
	var shots := 0
	var rounds := 7   # YARD_SECONDS=240 to watch it longer
	if OS.has_environment("YARD_SECONDS"):
		rounds = int(OS.get_environment("YARD_SECONDS")) / 10 + 1
	for k in rounds:
		if k > 0:
			await t.wait(10.0)
		rx.buffer = 0   # keep the intake taking them (it holds 20)
		var loose := 0
		for o in t.get_nodes_in_group("ore") + t.get_nodes_in_group("ingots"):
			if is_instance_valid(o) and o.global_position.x > 1280 and o.global_position.x < 1700 \
					and o.global_position.y > 208 and o.global_position.y < 690 and o.linear_velocity.length() < 5:
				loose += 1
		t.log_line("yard t=%ds: net %d, paddle knocks %d (power %.2f), flywheel %.2f, drum pulled %d, tally %d/fired %d, points sent %s, silo in %d out %d, turns %d+%d, brake %d, furnace smelted %d, pipe sent %d, into the dome %d ingots / %d raw, lying still in the chamber %d" % [
			k * 10, net.caught, paddle.knocks, paddle.power(), fly.spin, drum.pulled, tally.count, tally.fired,
			str(points.sent), silo.let_out + silo.stored.size(), silo.let_out, turns[0].turned, turns[1].turned, brake.braked,
			furnace.smelted, pipe.sent, piped.ingots, piped.raw, loose])
		if k == 2 or k == rounds - 1:
			shots += 1
			await t.shot("yard_%d" % shots)
	# a closer look at each half
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1490, 400)
	await t.wait(0.2)
	await t.shot("yard_top")
	cam.global_position = Vector2(1510, 610)
	await t.wait(0.2)
	await t.shot("yard_bottom")
	cam.zoom = Vector2(1.0, 1.0)
	cam.global_position = Vector2(1300, 300)
	await t.wait(0.2)
	await t.shot("yard_and_dome")
