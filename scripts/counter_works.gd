extends RefCounted
## Binary Counter: a marble example world where the machine computes. Six
## flip-flops hang in a diagonal cascade, each one a bit (tipped left = 0,
## right = 1), and each marble adds one:
##
##   a 0   the marble rolls off left (done), rocking the bit to 1
##   a 1   the marble rolls off right (the carry), rocking the bit to 0,
##         down a short chute into the next bit
##
## Under them a long gutter gathers every marble into an Archimedes screw,
## which lifts them back to a queue at the top; an escapement lets them in
## one per beat. A readout over the cascade shows the bits and the count,
## and a bell under the eights bit chimes each time the count reaches 8, 24, 40...
## Built by main.gd start_counter_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Readout = preload("res://scenes/bit_readout.gd")

const BITS := 6
const BIT0 := Vector2(1180, 276)         # the first (ones) bit's pivot
const STEP := Vector2(36, 52)            # to the next bit down the cascade
const MARBLES := 14


static func build(main: Node) -> void:
	await MarbleWorks.carve(main, false)
	# the queue: a chute the screw tips onto, running down to the escapement
	MarbleWorks._chute(main, Vector2(1040, 196), Vector2(1150, 232))
	MarbleWorks._piece(main, "res://scenes/escapement.tscn", Vector2(1152, 232), {"side": 1.0})
	var out := MarbleWorks._chute(main, Vector2(1156, 236), Vector2(1172, 244))
	out.has_lip = false                   # a stop-lip here would be right in the released marble's way
	out._rebuild()
	# the cascade: each bit's carry chute drops into the next one's funnel
	var bits: Array = []
	for k in BITS:
		var at := BIT0 + STEP * k
		bits.append(MarbleWorks._piece(main, "res://scenes/rocker.tscn", at, {"tilt": -1.0}))
		if k < BITS - 1:
			var carry := MarbleWorks._chute(main, at + Vector2(8, 16), at + Vector2(32, 24))
			carry.has_lip = false
			carry._rebuild()
	# a bell under the eights' done drop: it rings each time the count reaches 8, 24, 40...
	MarbleWorks._piece(main, "res://scenes/bell.tscn", BIT0 + STEP * 3 + Vector2(-30, 30))
	# the gutter under it all, into the screw's mouth, and the screw back up to the queue
	MarbleWorks._chute(main, Vector2(1470, 540), Vector2(984, 550))
	MarbleWorks._piece(main, "res://scenes/screw.tscn", Vector2(980, 566), {"end_offset": Vector2(54, -380)})
	# the marbles, already queued up
	for k in MARBLES:
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.lifetime = 1.0e9                # these go round for ever
		o.global_position = Vector2(1060 + (k % 7) * 12, 170 - (k / 7) * 14)
		o.add_to_group("showcase")
		main.add_child(o)
	var r: Node2D = Readout.new()
	r.bits = bits
	MarbleWorks.Showcase._add_node(main, r, Vector2.ZERO)
	for x in [1000.0, 1180.0, 1360.0, 1540.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
