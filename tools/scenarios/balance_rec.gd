extends RefCounted
## Balance (>2 copper-weights) standing on the cavern floor at x 1400.
## Round 1: 3 copper left and 1 iron right land together: level, nothing
## fires; 2 more copper left tips it and the LEFT side fires, both pans
## empty. Round 2: 2 iron right vs 1 copper left: the RIGHT side fires.
## Then trigger() empties a loaded pan without firing.


static func _drop(t, kind: String, at: Vector2) -> RigidBody2D:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.kind = kind
	o.global_position = at
	t.main.add_child(o)
	return o


static func _state(b: Node2D) -> String:
	return "tilt %.2f, pans %d/%d (w %.0f/%.0f), fired L%d R%d" % [b.angle, b._pans[0].size(), b._pans[1].size(), b._weight(0), b._weight(1), b.fired_l, b.fired_r]


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(1100, 540)
	var b: Node2D = preload("res://scenes/balance.tscn").instantiate()
	b.mode = 1
	b.global_position = Vector2(1400, 576)
	t.main.add_child(b)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(3.0, 3.0)
	cam.global_position = Vector2(1400, 530)
	await t.wait(0.5)
	var lx := 1400.0 - 32.0
	var rx := 1400.0 + 32.0
	# round 1: 3 copper vs 1 iron, together
	var ores := []
	for k in 3:
		ores.append(_drop(t, "copper", Vector2(lx - 7 + k * 7, 470 - k * 14)))
	ores.append(_drop(t, "iron", Vector2(rx, 470)))
	await t.wait(1.5)
	t.log_line("round 1 (3cu vs 1fe): %s" % _state(b))
	# two more copper on the left
	for k in 2:
		ores.append(_drop(t, "copper", Vector2(lx - 4 + k * 8, 440 - k * 14)))
	var peak := 0.0
	var shot := false
	for f in 60:
		await t.wait(0.025)
		if absf(b.angle) > absf(peak):
			peak = b.angle
		if not shot and absf(b.angle) > 0.12:
			shot = true
			await t.shot("balance_tilt")
	await t.wait(1.0)
	t.log_line("round 1 (+2cu left): peak tilt %.2f | %s | dumped %d" % [peak, _state(b), b.dumped])
	var ys: Array = ores.map(func(o): return int(o.global_position.y))
	t.log_line("round 1 pieces now at y %s (floor 576)" % [ys])
	# round 2: 2 iron right vs 1 copper left
	_drop(t, "copper", Vector2(lx, 470))
	await t.wait(0.4)
	var mid := _state(b)
	_drop(t, "iron", Vector2(rx - 6, 470))
	_drop(t, "iron", Vector2(rx + 6, 456))
	peak = 0.0
	for f in 60:
		await t.wait(0.025)
		if absf(b.angle) > absf(peak):
			peak = b.angle
		if f == 8:
			await t.shot("balance_tilt_r")
	await t.wait(1.0)
	t.log_line("round 2 (1cu then 2fe): before iron %s | peak tilt %.2f | %s | dumped %d" % [mid, peak, _state(b), b.dumped])
	# trigger empties without firing
	_drop(t, "copper", Vector2(lx, 470))
	await t.wait(0.8)
	var before := _state(b)
	b.trigger()
	await t.wait(1.0)
	t.log_line("trigger: before %s | after %s" % [before, _state(b)])
	await t.shot("balance_end")
