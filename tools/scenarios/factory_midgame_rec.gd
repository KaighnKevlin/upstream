extends RefCounted
## Builds a mid-game Factory and saves it to the real save slot (F9 loads it):
## the tier-0 chain from factory_t0_rec running (tappers, furnace rails, gear
## and flask assemblers, a lab), every tier-1 tech researched, the lab on
## Forging with its red flasks paid and its clockwork ones still to come,
## and the first pieces of a clockwork-flask line set out (grindstone, pellet
## press, a third assembler on Clockwork flask), for the player to finish.
## SAVE_TO env overrides the path (tests); otherwise it's the game's slot,
## so back the old one up first.

const Tech = preload("res://scripts/tech.gd")
const Lab = preload("res://scenes/lab.gd")
const Save = preload("res://scripts/sandbox_save.gd")
const T0 = preload("res://tools/scenarios/factory_t0_rec.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	Tech.levels.clear()
	Lab.tree_progress.clear()
	t.main.start_factory()
	await t.wait(0.3)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	await T0._ground(t)
	var tm: TileMapLayer = t.tilemap()
	var cell_top := func(c: Vector2i) -> Vector2: return tm.to_global(tm.map_to_local(c))
	for spec in [[T0.CU1, T0.CU1_AIM, 2.8], [T0.FE, T0.FE_AIM, 2.8], [T0.CU2, T0.CU2_AIM, 4.5]]:
		T0._place(t, "res://scenes/miner.tscn", cell_top.call(spec[0]), {"eject_angle": spec[1].x, "eject_force": spec[1].y, "eject_interval": spec[2]})
	T0._place(t, "res://scenes/furnace_rail.tscn", T0.FR1[0], {"end_offset": T0.FR1[1] - T0.FR1[0]})
	T0._place(t, "res://scenes/furnace_rail.tscn", T0.FR2[0], {"end_offset": T0.FR2[1] - T0.FR2[0]})
	T0._place(t, "res://scenes/assembler.tscn", T0.G, {"recipe": 1})
	T0._place(t, "res://scenes/assembler.tscn", T0.F, {"recipe": 2})

	# tier 1 done; the lab is on Forging: red paid, clockwork to come
	for tt in Tech.TREE:
		if int(tt.tier) == 1:
			Tech.levels[tt.id] = 1
	Lab.tree_progress["forging"] = {"flask": 5}
	var lab := T0._place(t, "res://scenes/lab.tscn", T0.L, {"tree_id": "forging"})
	t.main.refresh_unlocks()

	# the start of a clockwork-flask line, on the cavern floor to the left:
	# grindstone -> pellet press -> an assembler on Clockwork flask (recipe 6)
	T0._place(t, "res://scenes/grindstone.tscn", Vector2(830, 600))
	T0._place(t, "res://scenes/pellet_press.tscn", Vector2(880, 600))
	T0._place(t, "res://scenes/assembler.tscn", Vector2(935, 588), {"recipe": 6})

	t.main.get_node("Player").global_position = Vector2(1180, 590)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.5, 1.5)
	cam.global_position = Vector2(1200, 480)
	await t.wait(20.0)   # running: ingots and gears in flight
	await t.shot("midgame")
	if OS.has_environment("SAVE_TO"):
		Save.path = OS.get_environment("SAVE_TO")
	var n: int = Save.save(t.main)
	t.log_line("midgame saved %d pieces to %s; lab on '%s' (%s); unlocked %d pieces; tech %s" % [n, Save.path, lab.tree_id, lab._label.text, Tech.unlocked_types().size(), Tech.levels])
	Save.path = Save.PATH
