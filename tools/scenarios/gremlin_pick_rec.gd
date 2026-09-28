extends RefCounted
## Gremlin target choice. In the carved cavern: a plain chute close to it
## (x 1150), an escapement (a power user, x 1300) and a gravity wheel (a
## power source, x 1500). It should go for the wheel first, then the
## escapement, passing the chute. Then a second gremlin on the surface over
## the (roofed) cavern, with only buried pieces left: it should give up on
## them within ~GIVE_UP s rather than pace about over them forever.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	const MW = preload("res://scripts/marble_works.gd")
	var chute := MW._chute(t.main, Vector2(1120, 545), Vector2(1180, 565))
	chute.name = "Chute"
	var esc := MW._piece(t.main, "res://scenes/escapement.tscn", Vector2(1300, 560))
	esc.name = "Escapement"
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1500, 540))
	wheel.name = "GravityWheel"
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1250, 480)
	await t.wait(0.3)
	var g: Node2D = preload("res://scenes/gremlin.tscn").instantiate()
	g.global_position = Vector2(1000, 560)
	t.main.add_child(g)
	for lx in [1050, 1250, 1450]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 440)
		t.main.add_child(ln)
	var names := {wheel: "GravityWheel", esc: "Escapement", chute: "Chute"}
	var order := []
	var t0 := Time.get_ticks_msec() / 1000.0
	var first_target := ""
	for f in 120:
		await t.wait(0.1)
		if first_target == "" and g._target:
			first_target = str(g._target.name)
		for n in names.keys():
			if not is_instance_valid(n) or n.is_queued_for_deletion():
				order.append("%s@%.1fs" % [names[n], Time.get_ticks_msec() / 1000.0 - t0])
				names.erase(n)
		if f == 40:
			await t.shot("gremlin_wrench")
		if order.size() >= 2:
			break
	t.log_line("gremlin: first target %s; wrecked in order %s (chute still standing: %s)" % [
		first_target, order, is_instance_valid(chute) and not chute.is_queued_for_deletion()])
	g.queue_free()
	# on the surface over the buried chute: gives up rather than pacing forever
	var g2: Node2D = preload("res://scenes/gremlin.tscn").instantiate()
	g2.global_position = Vector2(1150, 70)
	t.main.add_child(g2)
	cam.global_position = Vector2(1150, 200)
	t0 = Time.get_ticks_msec() / 1000.0
	var gave := -1.0
	for f in 100:
		await t.wait(0.1)
		if not is_instance_valid(g2):
			t.log_line("gremlin 2 gone after %.1f s" % (Time.get_ticks_msec() / 1000.0 - t0))
			break
		if f % 10 == 0:
			t.log_line("g2 at %s hp %d target %s" % [g2.global_position.round(), g2.hp, str(g2._target.name) if g2._target else "-"])
		if gave < 0 and not g2._skip.is_empty():
			gave = Time.get_ticks_msec() / 1000.0 - t0
			await t.shot("gremlin_gave_up")
			break
	t.log_line("gremlin on the surface over a buried chute: %s" % (
		("gave up after %.1f s, now heading for %s" % [gave, str(g2._target.name) if g2._target else "the dome"]) if gave >= 0 else "did not give up"))
