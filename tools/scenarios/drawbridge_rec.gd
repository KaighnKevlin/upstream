extends RefCounted
## Drawbridge: a dispenser feeds a chute onto the bridge; a tally wheel on
## the feed (every 3rd piece) is wired to it, so it toggles every third
## piece. Lowered, pieces should cross to the far chute (right); raised,
## drop into the gap onto a chute below that carries them left. Logs the
## outcome of each piece in order and where they all ended up. Last, a
## click on the gatehouse post toggles it by hand.


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var at := Vector2(1250, 440)
	var db: Node2D = MW._piece(t.main, "res://scenes/drawbridge.tscn", at, {"side": 1.0})
	MW._piece(t.main, "res://scenes/dispenser.tscn", Vector2(1150, 350), {"mode": 0, "limit": 12, "kinds": ["copper", "iron", "copper", "scrap", "copper", "iron"]})
	MW._chute(t.main, Vector2(1135, 385), at)
	var tl: Node2D = MW._piece(t.main, "res://scenes/tally.tscn", Vector2(1172, 396), {"mode": 0, "wire_to": Vector2(60, 20)})
	var far = MW._chute(t.main, Vector2(1316, 452), Vector2(1500, 500))
	far.has_lip = false
	far._rebuild()
	MW._chute(t.main, Vector2(1330, 495), Vector2(1120, 545))
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1290, 450)
	var seq := ""
	var c0 := 0
	var f0 := 0
	var shot_up := false
	var shot_down := false
	var shot_mid := false
	for k in 260:
		await t.wait(0.05)
		while db.crossed > c0:
			c0 += 1
			seq += "C"
		while db.fell > f0:
			f0 += 1
			seq += "F"
		if db._a >= 1.0 and not shot_up and db.fell >= 1:
			shot_up = true
			await t.shot("drawbridge_raised")
		if db._a <= 0.0 and not shot_down and db.crossed >= 1:
			shot_down = true
			await t.shot("drawbridge_lowered")
		if db._a > 0.3 and db._a < 0.7 and k > 100 and not shot_mid:
			shot_mid = true
			await t.shot("drawbridge_swinging")
	var right := 0
	var left := 0
	for o in t.get_nodes_in_group("ore"):
		if o.global_position.x > 1330:
			right += 1
		elif o.global_position.x < 1240 and o.global_position.y > 510:
			left += 1
	var a := "tally fired %d, bridge toggled %d | order %s | crossed %d, fell %d | ended: %d far side (right), %d down the pit chute (left)" % [tl.fired, db.toggles, seq, db.crossed, db.fell, right, left]
	# a click on the gatehouse post
	var was: bool = db.raised
	var world: Vector2 = at + Vector2(db.SPAN + 5, -20)
	var screen: Vector2 = t.main.get_viewport().get_canvas_transform() * world
	Input.warp_mouse(screen)
	await t.wait(0.1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)
	await t.wait(0.05)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await t.wait(0.8)
	t.log_line("drawbridge: %s || click on the post: raised %s -> %s" % [a, was, db.raised])
	await t.shot("drawbridge_after")
