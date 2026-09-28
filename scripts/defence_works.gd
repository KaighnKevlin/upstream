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
const CANNON_AT := Vector2(1412, 574)


## `sorted`: a weigh scale in place of the flip-flop, sending all the iron
## to the cannon (its flat shots meet the shields head on) and the copper
## to the turret (its lobbed shots come down over them).
static func build(main: Node, sorted := false) -> Node2D:
	await MarbleWorks.carve(main, false)
	# the feed: a dispenser of copper and iron in turn, a flip-flop, a chute to each turret
	MarbleWorks._piece(main, "res://scenes/dispenser.tscn", Vector2(1260, 190), {"mode": 1, "kinds": ["copper", "iron"]})
	if sorted:
		MarbleWorks._piece(main, "res://scenes/weigh_scale.tscn", Vector2(1260, 240), {"heavy_side": 1.0})
	else:
		MarbleWorks._piece(main, "res://scenes/rocker.tscn", Vector2(1260, 240))
	# (no stop-lips: they'd sit right under the rocker's ends and snag what it drops)
	for ends in [[Vector2(1240, 262), Vector2(1160, 330)], [Vector2(1280, 262), Vector2(1412, 520)]]:
		var ch := MarbleWorks._chute(main, ends[0], ends[1])
		ch.has_lip = false
		ch._rebuild()
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1150, 400))
	# on the right, on the floor, a marble cannon firing flat into the wave
	MarbleWorks._piece(main, "res://scenes/cannon.tscn", CANNON_AT, {"side": 1.0})
	var d: Node2D = Director.new()
	# shieldbearers: copper glances off their tower shields, iron punches through
	d.types = ["SCUTTLER", "SHIELDBEARER", "SCUTTLER", "SHIELDBEARER", "SOLDIER"]
	d.wave = 16
	d.every = 1.4
	MarbleWorks.Showcase._add_node(main, d, Vector2.ZERO)
	for x in [1000.0, 1260.0, 1520.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	return d
