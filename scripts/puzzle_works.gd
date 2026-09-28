extends RefCounted
## Marble Puzzle: a marble example world with a goal. A dispenser drops a
## marble every second at the top left; a goal cup waits at the bottom
## right, past a rock wall. Build chutes (and anything else) to get five
## marbles into the cup. Level 2 follows at once: the dispenser drops copper
## and iron in turn and the cup takes iron only (a copper in it spoils the
## count), so the route needs a weigh scale in it. Built by main.gd
## start_puzzle_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const DISPENSER := Vector2(1000, 200)
const CUP := Vector2(1520, 574)
const WALL := Rect2i(78, 25, 3, 11)      # tiles: a rock wall up from the floor


static func build(main: Node) -> Node2D:
	var tm: TileMapLayer = await MarbleWorks.carve(main, false)
	for y in range(WALL.position.y, WALL.end.y):
		for x in range(WALL.position.x, WALL.end.x):
			WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	WorldGen.reframe_all(tm)
	await main.get_tree().physics_frame
	var disp := MarbleWorks._piece(main, "res://scenes/dispenser.tscn", DISPENSER, {"mode": 0})
	var cup := MarbleWorks._piece(main, "res://scenes/goal_cup.tscn", CUP, {"target": 5})
	for x in [1000.0, 1270.0, 1520.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	cup.filled.connect(func(): _level_two(main, cup, disp), CONNECT_ONE_SHOT)
	return cup


static func _level_two(main: Node, cup: Node2D, disp: Node2D) -> void:
	await main.get_tree().create_timer(2.0).timeout
	main._show_banner("LEVEL 2", "iron only: a copper in the cup spoils it (weigh scale!)")
	disp.kinds = ["copper", "iron"]
	cup.reset(5, "iron")
