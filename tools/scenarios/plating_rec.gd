extends RefCounted
## Iron plating. In the carved cavern (x 930..1650, floor 576): a gravity
## wheel (x 1500). A burrower starts in the rock right of the cavern
## (1780, 470) and digs for it: first with the wall bare (logs how long it
## takes to reach the wheel and how many tiles it digs), then, the rock put
## back as it was, with the lower half of the right wall plated (two plates
## laid end to end, y 340..592): it has to go over the top of them. Logs the same again, how many times
## the plating turned its drill, and that no plate cell was dug through.

const MW = preload("res://scripts/marble_works.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const REGION := Rect2i(95, 6, 40, 45)    # tiles saved and put back between runs


static func _snapshot(tm: TileMapLayer) -> Dictionary:
	var out := {}
	for y in range(REGION.position.y, REGION.end.y):
		for x in range(REGION.position.x, REGION.end.x):
			var c := Vector2i(x, y)
			out[c] = [tm.get_cell_source_id(c), tm.get_cell_atlas_coords(c)]
	return out


static func _restore(t, tm: TileMapLayer, snap: Dictionary) -> void:
	for c in snap:
		if snap[c][0] == -1:
			tm.set_cell(c, -1)
		else:
			tm.set_cell(c, snap[c][0], snap[c][1])
	WorldGen.reframe_all(tm)
	for c in snap:
		t.main.get_tree().call_group("tile_shading", "mark_dirty", c)
	for o in t.get_nodes_in_group("ore"):
		o.queue_free()


## One mole from `from` at the wheel: [seconds to reach it, tiles dug, detours, mole].
static func _race(t, wheel: Node2D, from: Vector2, label: String) -> Array:
	var b: Node2D = preload("res://scenes/burrower.tscn").instantiate()
	b.global_position = from
	t.main.add_child(b)
	var t0 := Time.get_ticks_msec() / 1000.0
	var reached := -1.0
	var dug := 0
	var det := 0
	for f in 200:
		await t.wait(0.1)
		if not is_instance_valid(b):
			t.log_line("  %s: the mole is gone" % label)
			break
		dug = b.dug
		det = b.detours
		if f % 10 == 0 or f > 100:
			t.log_line("  %s t=%.1f pos %s hp %d dug %d buried %s detours %d route %s" % [label, Time.get_ticks_msec() / 1000.0 - t0, b.global_position.round(), b.hp, b.dug, b.buried, b.detours, str(b._round)])
		if b._state == 1 and b._target == wheel:
			reached = Time.get_ticks_msec() / 1000.0 - t0
			break
	return [reached, dug, det, b]


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	var tm: TileMapLayer = await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1500, 540))
	for lx in [1400, 1600]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 440)
		t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.6, 1.6)
	cam.global_position = Vector2(1640, 430)
	var snap := _snapshot(tm)
	await t.wait(0.3)
	# bare wall
	var a: Array = await _race(t, wheel, Vector2(1780, 470), "bare")
	t.log_line("plating: bare wall: reached the wheel in %.1f s, %d tiles dug" % [a[0], a[1]])
	if is_instance_valid(a[3]):
		a[3].queue_free()
	await t.wait(0.2)
	_restore(t, tm, snap)
	await t.wait(0.2)
	for y in range(10, 37):
		if tm.get_cell_source_id(Vector2i(103, y)) == -1:
			t.log_line("  after the restore: hole in the wall at row %d" % y)
	# the lower wall plated, where it came in: two plates end to end
	var p1 := MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1656, 340), {"end_offset": Vector2(0, 130)})
	var p2 := MW._piece(t.main, "res://scenes/iron_plating.tscn", Vector2(1656, 470), {"end_offset": Vector2(0, 122)})
	await t.wait(0.3)
	await t.shot("plating_wall")
	var b: Array = await _race(t, wheel, Vector2(1780, 470), "plated")
	var mole = b[3]
	# every wall cell behind the plates still there?
	var holes := 0
	for y in range(22, 37):
		if tm.get_cell_source_id(Vector2i(103, y)) == -1:
			holes += 1
			t.log_line("  hole in the wall at row %d" % y)
	t.log_line("plating: plated wall: reached the wheel in %.1f s, %d tiles dug (%+d tiles, %+.1f s); turned %d times (drill skidded %d); wall cells dug through behind the plates: %d; burrowers target plating: %s" % [
		b[0], b[1], b[1] - a[1], b[0] - a[0], b[2], p1.blocked + p2.blocked, holes,
		str(is_instance_valid(mole) and mole._target != null and mole._target.is_in_group("iron_plating"))])
	if is_instance_valid(mole):
		mole.take_damage(99)
	await t.wait(0.4)
	var dark: Color = t.main._canvas_mod.color
	t.main._canvas_mod.color = Color.WHITE
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1640, 470)
	await t.shot("plating_tunnel")
	t.main._canvas_mod.color = dark
