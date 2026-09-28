extends RefCounted
## Music Box: a marble example world that's an instrument. A dispenser lets
## a marble go every two seconds onto a switchback of chime bars, one note
## each, so every marble plays the tune on its way down (Mary Had a Little
## Lamb's first line), and the marbles behind it play it again as a round.
## Click a bar to retune it. Built by main.gd start_music_works() in the
## Marble Works cavern.

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Chime = preload("res://scenes/chime.gd")

const XL := 1200.0
const XR := 1290.0
const OVER := 24.0               # each bar reaches past the one above's end, to catch the fall
const TOP := 190.0
const STEP := 29.0
const TUNE := ["E", "D", "C", "D", "E", "E", "E", "D", "D", "D", "E", "G", "G"]


static func build(main: Node) -> void:
	await MarbleWorks.carve(main, false)
	MarbleWorks._piece(main, "res://scenes/dispenser.tscn", Vector2(XL, TOP - 36), {"mode": 1})
	for k in TUNE.size():
		var y := TOP + k * STEP
		var from := Vector2(XL - OVER, y) if k % 2 == 0 else Vector2(XR + OVER, y)
		var to := Vector2(XR, y + 20) if k % 2 == 0 else Vector2(XL, y + 20)
		MarbleWorks._piece(main, "res://scenes/chime.tscn", from, {"note": Chime.NAMES.find(TUNE[k]), "end_offset": to - from})
	for x in [1100.0, 1250.0, 1400.0]:
		MarbleWorks._piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
