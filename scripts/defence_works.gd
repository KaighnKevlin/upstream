extends RefCounted
## Marble Defence: a marble example world where the machine is the defence.
## A dispenser of copper and iron feeds a flip-flop that splits the marbles
## between two funnel turrets, which fire them at a wave coming in from the
## right wall for the vault at the left. More than three leaks and it's
## lost. Shieldbearers are in the wave: copper glances off their shields
## and only iron gets through, so sorting the iron to where it counts
## (a weigh scale for the flip-flop) matters.
## Built by main.gd start_defence_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Director = preload("res://scenes/defence_director.gd")


## `sorted`: a weigh scale in place of the flip-flop, sending all the iron
## to the right-hand turret (the one the wave meets first).
static func build(main: Node, sorted := false) -> Node2D:
	await MarbleWorks.carve(main, false)
	# the feed: a dispenser of copper and iron in turn, a flip-flop, a chute to each turret
	MarbleWorks._piece(main, "res://scenes/dispenser.tscn", Vector2(1260, 190), {"mode": 1, "kinds": ["copper", "iron"]})
	if sorted:
		MarbleWorks._piece(main, "res://scenes/weigh_scale.tscn", Vector2(1260, 240), {"heavy_side": 1.0})
	else:
		MarbleWorks._piece(main, "res://scenes/rocker.tscn", Vector2(1260, 240))
	MarbleWorks._chute(main, Vector2(1240, 262), Vector2(1160, 330))
	MarbleWorks._chute(main, Vector2(1280, 262), Vector2(1360, 330))
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1150, 400))
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1370, 400))
	var d: Node2D = Director.new()
	# shieldbearers: copper glances off their tower shields, iron punches through
	d.types = ["SCUTTLER", "SHIELDBEARER", "SCUTTLER", "SHIELDBEARER", "SOLDIER"]
	d.wave = 16
	d.every = 1.4
	MarbleWorks.Showcase._add_node(main, d, Vector2.ZERO)
	for x in [1000.0, 1260.0, 1520.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	return d
