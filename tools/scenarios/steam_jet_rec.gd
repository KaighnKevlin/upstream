extends RefCounted
## Steam jet. The rust-mite setup (tools/scenarios/rust_mite_rec.gd): in the
## carved cavern a stand-in wheel (always full power, x 1250) driving an
## escapement (x 1330), with a steam jet set down between them (x 1290),
## belted to the wheel. A second jet off on its own (x 1000, no wheel) shows
## how long steam takes unpowered. A swarm of 6 starts in the rock right of
## the cavern (x 1700) and seeps in. Logs each blast (killed / blown off),
## the lowest the escapement's power fell and where it ends up, against the
## 0.26 six mites leave it with no jet; then a piece of ore fed to the lone
## jet's firebox.

const MW = preload("res://scripts/marble_works.gd")
const Power = preload("res://scripts/power.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
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
	var jet := MW._piece(t.main, "res://scenes/steam_jet.tscn", Vector2(1290, 576))
	var lone := MW._piece(t.main, "res://scenes/steam_jet.tscn", Vector2(1000, 576))
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
	var tree: SceneTree = t.main.get_tree()
	var mites: Array = preload("res://scenes/rust_mite.gd").swarm(t.main, Vector2(1700, 470), 6)
	var t0 := Time.get_ticks_msec() / 1000.0
	var low := 1.0
	var lone_full := -1.0
	var last_blasts := 0
	var shot_blast := false
	var on_peak := 0
	for f in 180:
		await t.wait(0.1)
		var now := Time.get_ticks_msec() / 1000.0 - t0
		low = minf(low, lvl.call())
		on_peak = maxi(on_peak, tree.get_nodes_in_group("rust_mites").filter(func(m): return m.clinging_to != null).size())
		if lone_full < 0 and lone.pressure >= 1.0:
			lone_full = now
		if jet.blasts > last_blasts:
			last_blasts = jet.blasts
			t.log_line("  t=%.1f blast %d: killed %d, blew off %d so far; %d mites left; escapement power %.2f" % [now, jet.blasts, jet.killed, jet.knocked, tree.get_nodes_in_group("rust_mites").size(), lvl.call()])
			if not shot_blast:
				shot_blast = true
				await t.wait(0.05)
				await t.shot("steam_jet_blast")
		if f == 60:
			await t.shot("steam_jet_mites")
		if tree.get_nodes_in_group("rust_mites").is_empty() and now > 4.0:
			break
	var left := tree.get_nodes_in_group("rust_mites").size()
	await t.wait(0.3)
	t.log_line("steam jet: 6 mites came; at most %d clung at once; %d blasts killed %d and blew %d off; %d left; escapement power fell to %.2f at worst and is %.2f now (6 mites, no jet: 0.26); lone unpowered jet full after %.1f s (powered: %.1f s)" % [
		on_peak, jet.blasts, jet.killed, jet.knocked, left, low, lvl.call(), lone_full, jet.CHARGE / Power.rate_at(tree, jet.global_position)])
	# the lone jet's firebox: blow it off, then feed it a piece of ore
	lone.pressure = 0.0
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = "copper"
	o.global_position = lone.global_position + Vector2(0, -30)
	t.main.add_child(o)
	await t.wait(0.8)
	t.log_line("steam jet: ore dropped in the lone jet's firebox: burned %d, pressure %.2f" % [lone.burned, lone.pressure])
	cam.global_position = Vector2(1300, 520)
	await t.shot("steam_jet_after")
