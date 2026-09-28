extends RefCounted
## Marble Defence: a marble example world where the machine is the defence.
## A dispenser feeds a flip-flop that splits the marbles between two funnel
## turrets, which fire them at a wave of walkers coming in from the right
## wall for the vault at the left. More than three leaks and it's lost.
## Built by main.gd start_defence_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Director = preload("res://scenes/defence_director.gd")


static func build(main: Node) -> Node2D:
	await MarbleWorks.carve(main, false)
	# the feed: a dispenser, a flip-flop, a chute to each turret
	MarbleWorks._piece(main, "res://scenes/dispenser.tscn", Vector2(1260, 190), {"mode": 0})
	MarbleWorks._piece(main, "res://scenes/rocker.tscn", Vector2(1260, 240))
	MarbleWorks._chute(main, Vector2(1240, 262), Vector2(1160, 330))
	MarbleWorks._chute(main, Vector2(1280, 262), Vector2(1360, 330))
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1150, 400))
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1370, 400))
	var d: Node2D = Director.new()
	MarbleWorks.Showcase._add_node(main, d, Vector2.ZERO)
	for x in [1000.0, 1260.0, 1520.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	return d
