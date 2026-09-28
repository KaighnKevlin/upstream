extends RefCounted
## Pachinko: a marble example world you play rather than watch. Click and
## hold the plunger at the bottom right to draw its spring, let go to fire
## a marble up the lane; the plate at the top turns it out over a field of
## pegs, and it bounces down into one of five scoring pockets (the middle
## one's worth most). Marbles that score come back to the plunger.
## Built by main.gd start_pachinko_works() in the Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Board = preload("res://scenes/pachinko.gd")

const PLUNGER := Vector2(1606, 560)


static func build(main: Node) -> Node2D:
	await MarbleWorks.carve(main, false)
	var pl := MarbleWorks._piece(main, "res://scenes/plunger.tscn", PLUNGER, {"ammo": 20})
	var b: Node2D = Board.new()
	b.plunger = pl
	MarbleWorks.Showcase._add_node(main, b, Vector2.ZERO)
	for x in [1050.0, 1300.0, 1550.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
	return b
