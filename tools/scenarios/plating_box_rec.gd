extends RefCounted
## Iron plating, boxed in. In the carved cavern (x 930..1650, floor 576): a
## gravity wheel (x 1500) boxed in with plating on all four sides, a chute
## outside the box on the far side (x 1370), and a second mole comes in through the right
## wall: it must give the wheel up (not dig through) and go for the chute.

const MW = preload("res://scripts/marble_works.gd")
const Plating = preload("res://tools/scenarios/plating_rec.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var tm: TileMapLayer = await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1500, 540))
	for lx in [1300, 1500]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 440)
		t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1520, 480)
	var chute := MW._chute(t.main, Vector2(1340, 555), Vector2(1400, 568))
	# the box: roof, both sides and under the floor, laid corner to corner
	var box := [
		MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1450, 470), {"end_offset": Vector2(100, 0)}),
		MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1550, 470), {"end_offset": Vector2(0, 122)}),
		MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1550, 592), {"end_offset": Vector2(-100, 0)}),
		MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1450, 592), {"end_offset": Vector2(0, -122)}),
	]
	await t.wait(0.3)
	await t.shot("plating_box")
	var b: Node2D = preload("res://scenes/burrower.tscn").instantiate()
	b.global_position = Vector2(1760, 470)
	t.main.add_child(b)
	var t0 := Time.get_ticks_msec() / 1000.0
	var gave_up := -1.0
	for f in 220:
		await t.wait(0.1)
		if not is_instance_valid(b):
			break
		var now := Time.get_ticks_msec() / 1000.0 - t0
		if f % 10 == 0:
			t.log_line("  box t=%.1f pos %s dug %d target %s route %s" % [now, b.global_position.round(), b.dug, str(b._target.name) if b._target else "-", str(b._round)])
		if gave_up < 0 and b._target == chute:
			gave_up = now
			cam.global_position = Vector2(1400, 480)
		if gave_up > 0 and now > gave_up + 4.0:
			break
	var scraped := 0
	for p in box:
		scraped += p.blocked
	t.log_line("plating: boxed in: the mole gave the wheel up after %.1f s (drill skidded %d times), went for the chute; wheel standing %s; 4 s later it is at %s" % [
		gave_up, scraped, is_instance_valid(wheel) and not wheel.is_queued_for_deletion(), str(b.global_position.round()) if is_instance_valid(b) else "-"])
	await t.shot("plating_box_gave_up")
	if is_instance_valid(b):
		b.take_damage(99)
