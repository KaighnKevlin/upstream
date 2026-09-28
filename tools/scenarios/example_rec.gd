extends RefCounted
## A scenario in its own file: tools/playtest.gd runs `run(t)` when asked
## for a scenario it doesn't have itself (`-- example_rec <outdir>`). t is
## the harness: t.main, t.wait(s), t.shot(label), t.log_line(s),
## t._spawn(type, pos), t.get_nodes_in_group(g).


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await preload("res://scripts/marble_works.gd").carve(t.main, false)
	await t.wait(0.5)
	await t.shot("example")
	t.log_line("example scenario ran from its own file")
