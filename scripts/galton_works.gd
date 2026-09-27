extends RefCounted
## Galton Board: a marble example world about chance. A hopper lets 80
## marbles go one at a time over ten rows of pegs; each peg is a coin toss,
## and the bins below fill into a bell curve, drawn against the ideal
## binomial as it builds. Built by main.gd start_galton_works() in the
## Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")


static func build(main: Node) -> void:
	await MarbleWorks.carve(main, false)
	MarbleWorks._piece(main, "res://scenes/galton.tscn", Vector2(1290, 165))
	for x in [1150.0, 1430.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
