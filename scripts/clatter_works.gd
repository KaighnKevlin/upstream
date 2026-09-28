extends RefCounted
## Clatter: a marble example world about noise drawing enemies, the
## Factorio pollution idea. A dispenser feeds a marble run (a long chute, a
## bell, a flip-flop) whose output is split between a goal cup (the
## production tally) and a turret. Every knock and ring adds clatter; each
## time the clatter climbs past a threshold, walkers are sent from the right
## for the vault. A louder, busier machine makes more but draws more.
## Built by main.gd start_clatter_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Director = preload("res://scenes/defence_director.gd")
const PENDULUM := Vector2(1500, 440)
const NoiseMeter = preload("res://scenes/noise_meter.gd")


## `felt`: every chute felt-lined and the bell muffled (quiet, slower).
static func build(main: Node, felt := false) -> Array:
	await MarbleWorks.carve(main, false)
	var chute := func(a: Vector2, b: Vector2) -> Node2D:
		if not felt:
			return MarbleWorks._chute(main, a, b)
		var ch: Node2D = preload("res://scenes/felt_chute.tscn").instantiate()
		ch.end_offset = b - a
		return MarbleWorks.Showcase._add_node(main, ch, a)
	MarbleWorks._piece(main, "res://scenes/dispenser.tscn", Vector2(1000, 190), {"mode": 0})
	chute.call(Vector2(985, 215), Vector2(1180, 280))
	# the run ends against a bell (a stop that rings), which drops it onto a flip-flop
	# its pull-wire runs down to a wrecking pendulum over the walkers' path: every
	# ring kicks the ball, so the loud machine has a second weapon (a muffled
	# bell fires nothing)
	MarbleWorks._piece(main, "res://scenes/bell.tscn", Vector2(1204, 262), {"muffled": felt, "wire_to": PENDULUM - Vector2(1204, 262)})
	MarbleWorks._piece(main, "res://scenes/pendulum.tscn", PENDULUM)
	var rk := MarbleWorks._piece(main, "res://scenes/rocker.tscn", Vector2(1192, 330))
	# left: into the production cup; right: to the turret
	chute.call(Vector2(1174, 352), Vector2(1080, 420))
	var cup := MarbleWorks._piece(main, "res://scenes/goal_cup.tscn", Vector2(1066, 470), {"target": 999, "backboard": -1.0})
	chute.call(Vector2(1210, 352), Vector2(1330, 420))
	MarbleWorks._piece(main, "res://scenes/funnel_turret.tscn", Vector2(1345, 490))
	var d: Node2D = Director.new()
	d.wave = 0                        # nothing comes until something hears
	d.endless = true
	d.every = 1.2
	d.types = ["SCUTTLER", "SCUTTLER", "SOLDIER"]
	MarbleWorks.Showcase._add_node(main, d, Vector2.ZERO)
	var n: Node2D = NoiseMeter.new()
	MarbleWorks.Showcase._add_node(main, n, Vector2(1280, 180))
	# each time it's heard, a bigger pack comes
	n.attract.connect(func(steps: int): d.wave += steps + 1)
	for x in [1000.0, 1260.0, 1520.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	return [n, d, cup]
