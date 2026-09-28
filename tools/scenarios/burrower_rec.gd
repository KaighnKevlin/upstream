extends RefCounted
## Burrower. In the carved cavern (x 930..1650, floor 576): a gravity wheel
## (x 1500) and a plain chute (x 1150). A burrower starts on the surface at
## x 1760 and digs down for the wheel. Logs tiles dug, when it broke into
## the cavern, when it reached and wrecked the wheel; then, walking for the
## chute, an iron piece dropped fast onto it (how much a hit takes off).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	const MW = preload("res://scripts/marble_works.gd")
	var chute := MW._chute(t.main, Vector2(1120, 545), Vector2(1180, 565))
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1500, 540))
	for lx in [1150, 1350, 1550]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 440)
		t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = Vector2(1560, 330)
	await t.wait(0.3)
	var b: Node2D = preload("res://scenes/burrower.tscn").instantiate()
	b.global_position = Vector2(1760, 80)
	t.main.add_child(b)
	var t0 := Time.get_ticks_msec() / 1000.0
	var now := func() -> float: return Time.get_ticks_msec() / 1000.0 - t0
	var broke_in := -1.0
	var reached := -1.0
	var wrecked := -1.0
	var dug_in := 0
	var shot_chew := false
	for f in 260:
		await t.wait(0.1)
		if not is_instance_valid(b):
			break
		if f == 30:
			await t.shot("burrower_digging")
		if f % 20 == 0:
			t.log_line("  t=%.0f pos %s dug %d buried %s state %d" % [now.call(), b.global_position.round(), b.dug, b.buried, b._state])
		if broke_in < 0 and b.dug > 0 and not b.buried and b.global_position.y > 300:
			broke_in = now.call()
			dug_in = b.dug
		if reached < 0 and b._state == 1:
			reached = now.call()
			cam.global_position = Vector2(1480, 470)
			cam.zoom = Vector2(2.0, 2.0)
		if reached > 0 and not shot_chew and now.call() - reached > 1.5:
			shot_chew = true
			await t.shot("burrower_chewing")
		if b.chewed >= 1:
			wrecked = now.call()
			break
	t.log_line("burrower: dug %d tiles to break into the cavern after %.1f s; reached the wheel at %.1f s, wrecked it at %.1f s (chew %.1f s); %d tiles dug in all; wheel gone: %s" % [
		dug_in, broke_in, reached, wrecked, wrecked - reached, b.dug, not is_instance_valid(wheel) or wheel.is_queued_for_deletion()])
	await t.wait(1.0)
	cam.zoom = Vector2(1.8, 1.8)
	cam.global_position = Vector2(1680, 250)
	# full bright (the L cheat) to show the tunnel it left
	var dark: Color = t.main._canvas_mod.color
	t.main._canvas_mod.color = Color.WHITE
	t.main.get_node("Fog").visible = false
	await t.shot("burrower_tunnel")
	t.main._canvas_mod.color = dark
	t.main.get_node("Fog").visible = true
	# walking for the chute: drop an iron piece on it
	var hp0: int = b.hp
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "iron"
	o.global_position = b.global_position + Vector2(0, -40)
	o.linear_velocity = Vector2(0, 600)
	t.main.add_child(o)
	await t.wait(0.25)
	t.log_line("burrower: iron dropped on it: hp %d -> %s (target now %s)" % [hp0, str(b.hp) if is_instance_valid(b) and not b._dying else "destroyed", str(b._target.name) if is_instance_valid(b) and b._target else "-"])
	await t.wait(0.3)
	if is_instance_valid(b) and not b._dying:
		b.take_damage(b.hp)
	await t.wait(0.1)
	await t.shot("burrower_dead")
