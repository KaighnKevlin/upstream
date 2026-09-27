extends RefCounted
## Coaster: a marble example world that's a pure fun run, the showpieces in
## a row. The Beam lifts marbles to a shelf at the top of the
## cavern; they roll off down a long curved drop (steep at the top, level at
## the bottom, so no speed is lost at the joins), round a loop-the-loop,
## over a jump and into a bell, and back along the floor to the Beam.
## Built by main.gd start_coaster_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")

const TOP := Vector2(1062, 180)          # where the drop starts
const DROP := Vector2(150, 240)          # how far across and down it goes
const MARBLES := 10


## A smooth drop from `a`: a quarter ellipse of short chutes, falling
## straight down at first and level at the end.
static func _curve(main: Node, a: Vector2, size: Vector2, n := 14) -> void:
	var prev := a
	for k in range(1, n + 1):
		var t := PI * 0.5 * k / n
		var p := a + Vector2(size.x * (1.0 - cos(t)), size.y * sin(t))
		var ch := MarbleWorks._chute(main, prev, p)
		ch.has_lip = false
		ch._rebuild()
		prev = p


static func build(main: Node) -> void:
	await MarbleWorks.carve(main, false)
	# the lift: the Beam, spilling right onto the shelf at the top
	MarbleWorks._piece(main, "res://scenes/beam.tscn", Vector2(995, 158), {"depth": 408.0, "spill": 1})
	MarbleWorks._chute(main, Vector2(1000, 170), Vector2(TOP.x - 1, TOP.y - 1))
	# the drop, into the loop's rail
	_curve(main, TOP, DROP)
	var foot := TOP + DROP + Vector2(70, 1.5)          # the loop's rail starts where the drop ends
	MarbleWorks._piece(main, "res://scenes/loop.tscn", foot)
	# off the rail's far end over a jump (a gap before the kicker: marbles
	# too slow to make it drop through to the floor rather than stall in a dip)...
	var rail_end := foot + Vector2(80, 12.5)
	MarbleWorks._piece(main, "res://scenes/jump.tscn", rail_end + Vector2(18, 3), {"end_offset": Vector2(46, 26)})
	# ...and into a bell
	MarbleWorks._piece(main, "res://scenes/bell.tscn", rail_end + Vector2(118, 40))
	# the floor back into the Beam's foot
	MarbleWorks._chute(main, Vector2(1600, 500), Vector2(984, 556))
	for k in MARBLES:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9
		o.global_position = Vector2(1016 + k * 4.5, 158 + k * 0.7)
		o.add_to_group("showcase")
		main.add_child(o)
	for x in [1000.0, 1200.0, 1400.0, 1600.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
