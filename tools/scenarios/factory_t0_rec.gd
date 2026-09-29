extends RefCounted
## Is tier 0 self-sufficient? In Factory mode, a minimal chain built only
## from Tech.START pieces, in a carved cavern with a stepped floor:
##
##   copper + iron tappers on the floor lob high onto furnace rail 1 ->
##     copper and iron ingots drop into assembler G (Gear)
##   G's spout drops each gear into assembler F (Science flask), a step down
##   a second copper tapper on the far side lobs onto furnace rail 2, whose
##     copper ingots drop into F from above
##   F's spout drops each flask into the lab, a step further down, which
##     researches the first tree tech it can (Routing)
##
## Nothing in START makes power, so every machine runs at Power.UNPOWERED.
## Logs each stage's count as it goes, the game time (from the first log
## line; the tappers start ~5 s before) of the first gear, the first flask
## and the first tech researched, and "tier 0: SELF-SUFFICIENT" or
## "tier 0: STUCK at <stage>". Takes ~60 s of real time (LIMIT >= 200).

const Tech = preload("res://scripts/tech.gd")
const Lab = preload("res://scenes/lab.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const Showcase = preload("res://scripts/sandbox_showcase.gd")

const G := Vector2(1300, 508)       # gear assembler, on a ledge whose top is y 512
const F := Vector2(1350, 556)       # flask assembler, a step (48 px) down
const L := Vector2(1421, 604)       # lab, a step further down (floor dug to y 608), its funnel under the middle of the flasks' spread
# furnace rails: long, and only steep enough to keep the ingots
# rolling (3 deg), since unpowered (nothing in START powers anything) the grate
# needs 2 s of dwell; ore lands on them from a high lob, with little speed
# along them
const FR1 := [Vector2(1030, 420), Vector2(1280, 433)]
const FR2 := [Vector2(1580, 452), Vector2(1385, 462)]
const CU1 := Vector2i(61, 36)       # floor vein cells: the tappers sit on their tops
const FE := Vector2i(63, 36)
const CU2 := Vector2i(100, 36)
const CU1_AIM := Vector2(5.2, 630)  # degrees from vertical, launch speed (solved for a soft landing)
const FE_AIM := Vector2(3.6, 550)
const CU2_AIM := Vector2(-3.8, 660)
const GAME_TIME := 150.0            # seconds of game time allowed


static func _ground(t) -> void:
	var tm: TileMapLayer = t.tilemap()
	var shading = t.main.get_node_or_null("TileShading")
	var decor = t.main.get_node_or_null("CaveDecor")
	var stone := func(x0: int, x1: int, y0: int, y1: int):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	stone.call(71, 81, 32, 35)      # G's step (top y 512)
	stone.call(82, 85, 35, 35)      # F's step (top y 560)
	for y in [36, 37]:              # the lab's pit (floor y 608)
		for x in range(86, 96):
			Showcase._clear(tm, Vector2i(x, y), shading, decor)
	stone.call(85, 85, 36, 39)
	stone.call(86, 95, 38, 39)
	stone.call(96, 96, 36, 39)
	Showcase._vein(tm, CU1, shading, decor)
	Showcase._vein(tm, FE, shading, decor, WorldGen.TILE_IRON)
	Showcase._vein(tm, CU2, shading, decor)
	WorldGen.reframe_all(tm)
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	await t.main.get_tree().physics_frame
	await t.main.get_tree().physics_frame


static func _place(t, scene: String, at: Vector2, props := {}) -> Node2D:
	var n: Node2D = load(scene).instantiate()
	for k in props:
		n.set(k, props[k])
	n.global_position = at
	t.main.add_child(n)
	t.main.get_node("/root/BuildSystem")._placed_buildings.append(n)
	return n


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	Tech.levels.clear()
	Lab.tree_progress.clear()
	t.main.start_factory()
	await t.wait(0.3)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	await _ground(t)
	var allowed: Array = Tech.unlocked_types()
	var used := {2: "Vein tapper", 75: "Furnace rail", 16: "Assembler", 17: "Research lab"}
	for id in used:
		t.log_line("%s (%d) on the Factory bar: %s" % [used[id], id, allowed.has(id)])
	var tm: TileMapLayer = t.tilemap()
	var cell_top := func(c: Vector2i) -> Vector2: return tm.to_global(tm.map_to_local(c))
	var taps := []
	# the two on rail 1 take turns (each every 2.8 s, half a beat apart), so
	# one lands on the rail's head only once the last has rolled on
	for spec in [[CU1, CU1_AIM, 2.8], [FE, FE_AIM, 2.8], [CU2, CU2_AIM, 4.5]]:
		taps.append(_place(t, "res://scenes/miner.tscn", cell_top.call(spec[0]), {"eject_angle": spec[1].x, "eject_force": spec[1].y, "eject_interval": spec[2]}))
		await t.wait(1.4)
	var r1 := _place(t, "res://scenes/furnace_rail.tscn", FR1[0], {"end_offset": FR1[1] - FR1[0]})
	var r2 := _place(t, "res://scenes/furnace_rail.tscn", FR2[0], {"end_offset": FR2[1] - FR2[0]})
	var g := _place(t, "res://scenes/assembler.tscn", G, {"recipe": 1})
	var f := _place(t, "res://scenes/assembler.tscn", F, {"recipe": 2})
	var lab := _place(t, "res://scenes/lab.tscn", L)
	await t.wait(0.3)
	t.log_line("placed: G at %s, F at %s, lab at %s researching '%s'; tapper veins %s" % [g.global_position, f.global_position, lab.global_position, lab.tree_id, taps.map(func(m): return m._ore_remaining())])
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.9, 1.9)
	cam.global_position = Vector2(1310, 470)
	t.main.get_node("Player").global_position = Vector2(960, 560)
	await t.wait(1.0)
	await t.shot("t0_chain")
	# real time: at x4 each physics step is 4x as long, and ore landing on
	# the rails bounces off / tunnels far more than in play
	var clock := 0.0
	var first := {}
	var next_log := 0.0
	var into_lab := func() -> int:
		return int(Lab.tree_progress.get("routing", {}).get("flask", 0)) + int(lab._held.get("flask", 0)) + (1 if lab._work > 0 else 0)
	while clock < GAME_TIME and not Tech.researched("routing"):
		await t.wait(0.25)
		clock += 0.25
		for k in [["gear", g.made > 0], ["flask", f.made > 0], ["lab", into_lab.call() > 0]]:
			if k[1] and not first.has(k[0]):
				first[k[0]] = clock
		if clock >= next_log:
			next_log += 15.0
			t.log_line("t=%3.0f  smelted %d/%d  G gears %d (holds %s)  F flasks %d (holds %s)  lab '%s', flasks in %d  ingots loose %d" % [clock,
				r1.smelted, r2.smelted, g.made, g._held, f.made, f._held, lab._label.text, into_lab.call(), t.get_nodes_in_group("ingots").size()])
		if clock == 20.0:
			await t.shot("t0_running")
	t.log_line("end t=%.0f: smelted %d/%d, gears %d, flasks %d, lab '%s'; ore left in veins %s" % [clock, r1.smelted, r2.smelted, g.made, f.made, lab._label.text, taps.map(func(m): return m._ore_remaining())])
	t.log_line("first gear at %s s, first flask at %s s, first flask into the lab at %s s, Routing researched: %s at %.0f s" % [
		first.get("gear", "-"), first.get("flask", "-"), first.get("lab", "-"), Tech.researched("routing"), clock])
	await t.wait(0.5)
	await t.shot("t0_end")
	if Tech.researched("routing"):
		t.log_line("tier 0: SELF-SUFFICIENT (START pieces made 5 flasks and researched Routing in %.0f s of game time)" % clock)
	else:
		var stage := "smelting" if r1.smelted + r2.smelted == 0 else ("gears" if g.made == 0 else ("flasks" if f.made == 0 else "the lab"))
		t.log_line("tier 0: STUCK at %s" % stage)
