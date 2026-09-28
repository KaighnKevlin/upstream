extends RefCounted
## Ground listener. In the carved cavern (x 930..1650, floor 576): a gravity
## wheel (x 1480) and, against the right wall on the floor, a powder keg with
## a ground listener beside it (range 5 tiles). A burrower starts deep in the
## rock right of the cavern (x 1840, floor level) and digs straight in for
## the wheel. A second listener far over on the left of the cavern (range 12)
## is the control: it must hear nothing. Logs when and how far off the near
## listener heard it, the arrow's direction, whether the keg went up and the
## burrower died, and the wheel standing. Then a second mole digs up from
## under the floor: heard again, the arrow points down.

const MW = preload("res://scripts/marble_works.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1480, 540))
	var keg := MW._piece(t.main, "res://scenes/keg.tscn", Vector2(1636, 570))
	var ear := MW._piece(t.main, "res://scenes/ground_listener.tscn", Vector2(1606, 576), {"mode": 0, "wire_to": Vector2(24, -10)})
	var far := MW._piece(t.main, "res://scenes/ground_listener.tscn", Vector2(1000, 576), {"mode": 2, "wire_to": Vector2.ZERO})
	for lx in [1400, 1600]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 470)
		t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.2, 2.2)
	cam.global_position = Vector2(1640, 520)
	await t.wait(0.3)
	await t.shot("listener_set")
	var b: Node2D = preload("res://scenes/burrower.tscn").instantiate()
	b.global_position = Vector2(1840, 562)
	t.main.add_child(b)
	var t0 := Time.get_ticks_msec() / 1000.0
	var heard_t := -1.0
	var heard_d := 0.0
	var dug_then := 0
	var shot_arrow := false
	for f in 200:
		await t.wait(0.1)
		var now := Time.get_ticks_msec() / 1000.0 - t0
		if f % 10 == 0 and is_instance_valid(b):
			t.log_line("  t=%.1f mole %s dug %d buried %s; listener heard %d fired %d" % [now, b.global_position.round(), b.dug, b.buried, ear.heard, ear.fired])
		if not is_instance_valid(ear):
			t.log_line("listener: eaten")
			break
		if heard_t < 0 and ear.fired > 0:
			heard_t = now
			heard_d = ear.heard_dist
			dug_then = b.dug if is_instance_valid(b) else -1
			await t.wait(0.05)
			await t.shot("listener_fired")
		if heard_t > 0 and not shot_arrow and now > heard_t + 0.6:
			shot_arrow = true
			await t.shot("listener_arrow")
		if heard_t > 0 and now > heard_t + 2.0:
			break
		if not is_instance_valid(wheel):
			break
	var dead: bool = not is_instance_valid(b) or b._dying
	t.log_line("listener: heard the burrower dig %.0f px (%.1f tiles) out at %.1f s (it had dug %d tiles), arrow %s; fired %d, keg blown %s; burrower %s; wheel standing %s; far listener heard %d fired %d" % [
		heard_d, heard_d / 16.0, heard_t, dug_then, str(ear._dir.snapped(Vector2(0.01, 0.01))), ear.fired,
		not is_instance_valid(keg) or keg.blown, "killed" if dead else "alive (hp %d)" % b.hp,
		is_instance_valid(wheel) and not wheel.is_queued_for_deletion(), far.heard, far.fired])
	# a second mole, no keg left: it still hears it and points the way
	var b2: Node2D = preload("res://scenes/burrower.tscn").instantiate()
	b2.global_position = Vector2(1560, 700)
	t.main.add_child(b2)
	ear.mode = 2   # listening out to 12 tiles now
	var h0: int = ear.heard
	var f0: int = ear.fired
	for f in 80:
		await t.wait(0.1)
		if ear.heard > h0:
			break
	await t.wait(0.3)
	await t.shot("listener_below")
	t.log_line("listener: second mole under the floor: heard %d digs, fired %d more, arrow %s (%.0f px off)" % [ear.heard - h0, ear.fired - f0, str(ear._dir.snapped(Vector2(0.01, 0.01))), ear.heard_dist])
	if is_instance_valid(b2):
		b2.take_damage(99)
