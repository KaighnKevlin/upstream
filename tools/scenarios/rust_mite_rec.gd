extends RefCounted
## Rust mites. In the carved cavern: a stand-in wheel (always full power,
## x 1250) driving an escapement (x 1330). A swarm of 6 starts in the rock
## right of the cavern (x 1700) and seeps in. Logs how long they took to
## settle, how they split between the two, and the escapement's power
## level before / with them on; then a copper piece dropped fast through
## the ones on the escapement, and the prospector walking into the wheel
## to brush the rest off; the power level after each.

const MW = preload("res://scripts/marble_works.gd")
const Power = preload("res://scripts/power.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	var player: Node2D = t.main.get_node("Player")
	player.global_position = Vector2(300, 60)
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nfunc _ready():\n\tadd_to_group(\"power_wheels\")\nfunc power() -> float:\n\treturn 1.0\nfunc _draw():\n\tdraw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color(0.6, 0.45, 0.25), 3.0)\n"
	gs.reload()
	var wheel := Node2D.new()
	wheel.set_script(gs)
	wheel.name = "Wheel"
	wheel.global_position = Vector2(1250, 540)
	t.main.add_child(wheel)
	var esc := MW._piece(t.main, "res://scenes/escapement.tscn", Vector2(1330, 560))
	esc.name = "Escapement"
	for lx in [1250, 1400]:
		var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
		ln.global_position = Vector2(lx, 470)
		t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.4, 2.4)
	cam.global_position = Vector2(1300, 520)
	await t.wait(0.3)
	var lvl := func() -> float: return Power.level_at(t.main.get_tree(), esc.global_position)
	var before: float = lvl.call()
	var mites: Array = preload("res://scenes/rust_mite.gd").swarm(t.main, Vector2(1700, 470), 6)
	var t0 := Time.get_ticks_msec() / 1000.0
	var settled := -1.0
	for f in 150:
		await t.wait(0.1)
		var on := mites.filter(func(m): return is_instance_valid(m) and m.clinging_to != null).size()
		if on == mites.size():
			settled = Time.get_ticks_msec() / 1000.0 - t0
			break
	var on_w := mites.filter(func(m): return is_instance_valid(m) and m.clinging_to == wheel).size()
	var on_e := mites.filter(func(m): return is_instance_valid(m) and m.clinging_to == esc).size()
	await t.wait(0.3)
	await t.shot("mites_feeding")
	t.log_line("mites: 6 settled after %s: %d on the wheel, %d on the escapement; escapement power %.2f -> %.2f (wheel's own output x%.2f)" % [
		("%.1f s" % settled) if settled >= 0 else "never", on_w, on_e, before, lvl.call(), Power.drain_at(t.main.get_tree(), wheel.global_position)])
	# copper dropped fast through the ones on the escapement
	var alive0 := mites.filter(func(m): return is_instance_valid(m)).size()
	for m in mites:
		if is_instance_valid(m) and m.clinging_to == esc:
			var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
			o.kind = "copper"
			o.global_position = m.global_position + Vector2(0, -40)
			o.linear_velocity = Vector2(0, 450)
			t.main.add_child(o)
			await t.wait(0.12)
	await t.wait(0.3)
	var alive1 := mites.filter(func(m): return is_instance_valid(m)).size()
	t.log_line("mites: copper dropped through the escapement's: %d killed; escapement power now %.2f" % [alive0 - alive1, lvl.call()])
	# the prospector walks into the wheel
	player.global_position = Vector2(wheel.global_position.x, 556)
	await t.wait(0.25)
	var off := 0
	for m in mites:
		if is_instance_valid(m):
			off += m.brushed
	await t.shot("mites_brushed")
	player.global_position = Vector2(300, 60)
	t.log_line("mites: the prospector at the wheel brushed %d off; wheel output x%.2f, escapement power %.2f" % [
		off, Power.drain_at(t.main.get_tree(), wheel.global_position), lvl.call()])
	await t.wait(3.0)
	var back := mites.filter(func(m): return is_instance_valid(m) and m.clinging_to != null).size()
	t.log_line("mites: 3 s later %d are back on; escapement power %.2f" % [back, lvl.call()])
