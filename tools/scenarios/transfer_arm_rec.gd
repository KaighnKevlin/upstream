extends RefCounted
## Transfer arm: pieces rolled down a chute into the arm's cradle should be
## caught, swung up and over the pivot and tipped onto a chute a level
## higher on the far side (right). First unpowered (slow), then with a
## stand-in power wheel in reach (full rate). Logs lift, cycle time and
## where they all ended up.


static func _ore(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	o.lifetime = 1.0e9
	o.global_position = at
	t.main.add_child(o)
	return o


static func _batch(t, arm: Node2D, kinds: Array, label: String, shoot: bool) -> String:
	var n0: int = arm.lifted
	var t0 := Time.get_ticks_msec() / 1000.0
	var mine := []
	for k in kinds:
		mine.append(_ore(t, k, Vector2(1160, 460)))
		await t.wait(0.35)
	var done := -1.0
	var lifts := []
	var shot := false
	for w in 200:
		await t.wait(0.05)
		if arm.lifted > n0 + lifts.size():
			lifts.append(int(arm.last_lift))
		if shoot and not shot and arm._state == 1 and arm._phi > PI - 0.3:
			shot = true
			await t.shot("transfer_arm_over")
		if arm.lifted - n0 >= kinds.size():
			done = Time.get_ticks_msec() / 1000.0 - t0
			break
	await t.wait(0.6)
	var up := 0
	for o in mine:
		if is_instance_valid(o) and o.global_position.x > 1340:
			up += 1
	return "%s: %d of %d lifted in %.1f s (%.2f s a piece), up %s px, rate %.2f, %d went on right along the upper chute" % [label, arm.lifted - n0, kinds.size(), done, done / kinds.size(), lifts, arm._rate, up]


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var MW = preload("res://scripts/marble_works.gd")
	await MW.carve(t.main, false)
	var at := Vector2(1300, 480)
	var arm: Node2D = MW._piece(t.main, "res://scenes/transfer_arm.tscn", at, {"side": 1.0})
	var c: Vector2 = at + arm.catch_point()
	MW._chute(t.main, Vector2(1150, 470), c + Vector2(-6, 7))
	var dp: Vector2 = at + arm.drop_point()
	var up = MW._chute(t.main, dp + Vector2(2, 12), dp + Vector2(170, 44))
	up.has_lip = false
	up._rebuild()
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.6, 2.6)
	cam.global_position = Vector2(1300, 470)
	await t.wait(0.4)
	var a: String = await _batch(t, arm, ["copper", "iron"], "unpowered", false)
	# a stand-in gravity wheel at full power, in reach
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nfunc power() -> float:\n\treturn 1.0\n"
	gs.reload()
	var wheel := Node2D.new()
	wheel.set_script(gs)
	wheel.add_to_group("power_wheels")
	t.main.add_child(wheel)
	wheel.global_position = at + Vector2(-80, -60)
	await t.wait(0.4)
	var b: String = await _batch(t, arm, ["copper", "iron", "scrap", "copper"], "powered", true)
	await t.shot("transfer_arm_after")
	t.log_line("transfer_arm: catch at %s, drop at %s | %s || %s" % [Vector2i(c), Vector2i(dp), a, b])
