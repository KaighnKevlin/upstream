extends RefCounted
## Marble Works: a demo world for the marble-machine direction. A big
## cavern is carved under the dome with the Beam running up its middle,
## and one continuous Rube Goldberg machine built around it:
##
##   feed    copper and iron tappers on the cavern floor fling ore across
##           the Beam, which catches it and carries it up
##   tap     an iron tap part way up pulls the iron out to the right, down
##           a long chute into a tipping bucket, whose batches pour onto a
##           gravity wheel (heavy iron, big shoves)
##   crown   the copper rises to the crown and spills both ways
##   left    down a chute onto a flip-flop: every other marble goes left
##           over a sieve rail (grit drops through) or right down a chute
##           through an escapement (one per beat) onto a second wheel
##   right   down a chute onto a shelf, where a robotic arm lifts each
##           piece off and drops it past the shelf
##   stairs  what the arm lets go of lands on a stair lift and climbs it
##           one hop at a time, tipping off the top
##   screw   what rolls off the sieve drops into an Archimedes screw that
##           lifts it back up and tips it out in mid-air
##   return  everything lands on two long floor chutes that run back down
##           into the Beam's foot: it goes round and round
##
## Lanterns on the ceiling light it. Built by main.gd start_marble_works().

const WorldGen = preload("res://scripts/world_gen.gd")
const Showcase = preload("res://scripts/sandbox_showcase.gd")

const CAVE := Rect2i(58, 9, 45, 27)      # tiles: x, y, w, h (rows 9..35; floor row 36)
const BEAM_X := 1200.0
const CROWN_Y := 172.0
const FLOOR_Y := 576.0


static func _chute(main: Node, a: Vector2, b: Vector2) -> Node2D:
	var ch: Node2D = preload("res://scenes/chute.tscn").instantiate()
	ch.end_offset = b - a
	return Showcase._add_node(main, ch, a)


static func _piece(main: Node, path: String, at: Vector2, props := {}) -> Node2D:
	var n: Node2D = load(path).instantiate()
	for k in props:
		n.set(k, props[k])
	return Showcase._add_node(main, n, at)


static func build(main: Node) -> void:
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var shading := main.get_node_or_null("TileShading")
	var decor := main.get_node_or_null("CaveDecor")
	# the cavern: cleared, with a solid floor and walls whatever was there
	for y in range(CAVE.position.y, CAVE.end.y):
		for x in range(CAVE.position.x, CAVE.end.x):
			Showcase._clear(tm, Vector2i(x, y), shading, decor)
	for x in range(CAVE.position.x - 1, CAVE.end.x + 1):
		WorldGen.set_tile(tm, Vector2i(x, CAVE.end.y), WorldGen.TILE_STONE)
	for y in range(CAVE.position.y, CAVE.end.y):
		for x in [CAVE.position.x - 1, CAVE.end.x]:
			WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	# feed: a copper vein on the left of the floor, iron on the right
	Showcase._vein(tm, Vector2i(61, CAVE.end.y), shading, decor)
	Showcase._vein(tm, Vector2i(97, CAVE.end.y), shading, decor, WorldGen.TILE_IRON)
	WorldGen.reframe_all(tm)
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	# pieces go in once the new ground has collision
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	Showcase._tapper(main, tm, Vector2i(61, CAVE.end.y), Vector2(38, 560))
	Showcase._tapper(main, tm, Vector2i(97, CAVE.end.y), Vector2(-38, 560))
	# the Beam
	_piece(main, "res://scenes/beam.tscn", Vector2(BEAM_X, CROWN_Y), {"depth": FLOOR_Y - CROWN_Y - 4.0})
	# the iron tap and its line: chute -> tipping bucket -> wheel
	_piece(main, "res://scenes/beam_tap.tscn", Vector2(BEAM_X + 6, 330), {"mode": 1})
	_chute(main, Vector2(1215, 342), Vector2(1506, 454))   # starts under the spout: its stop-lip behind the iron, not in its way
	_piece(main, "res://scenes/tipping_bucket.tscn", Vector2(1512, 490), {"side": 1.0})   # right under where iron drops off
	_piece(main, "res://scenes/gravity_wheel.tscn", Vector2(1532, 520))
	# crown left: chute -> flip-flop
	_chute(main, Vector2(1160, 196), Vector2(1062, 234))
	_piece(main, "res://scenes/rocker.tscn", Vector2(1046, 262))
	#   left of the flip-flop: a sieve rail to the floor
	_piece(main, "res://scenes/sieve.tscn", Vector2(1024, 284), {"end_offset": Vector2(-84, 40)})
	#   right of it: a chute through an escapement onto a wheel
	_chute(main, Vector2(1066, 288), Vector2(1122, 316))
	_piece(main, "res://scenes/escapement.tscn", Vector2(1124, 316), {"side": 1.0})
	_piece(main, "res://scenes/gravity_wheel.tscn", Vector2(1148, 520))
	# crown right: chute -> a shelf -> the robotic arm
	_chute(main, Vector2(1240, 196), Vector2(1330, 232))
	# a V pocket the pieces settle into for the arm
	_chute(main, Vector2(1336, 284), Vector2(1368, 298))
	_chute(main, Vector2(1400, 280), Vector2(1370, 298))
	var arm := _piece(main, "res://scenes/arm.tscn", Vector2(1412, 326), {"mode": 0})
	arm.pick = Vector2(1369, 290) - arm.global_position
	arm.drop = Vector2(1446, 300) - arm.global_position
	# what the arm drops lands on a stair lift and climbs it, hop by hop
	_piece(main, "res://scenes/stair_lift.tscn", Vector2(1446, 540), {"steps": 6, "side": -1.0})
	# an Archimedes screw lifts what comes off the sieve back up into the air
	_piece(main, "res://scenes/screw.tscn", Vector2(944, 528), {"end_offset": Vector2(70, -120)})
	# the return: two long floor chutes into the Beam's foot
	_chute(main, Vector2(936, 556), Vector2(1186, 568))
	_chute(main, Vector2(1640, 556), Vector2(1214, 568))
	# light
	for x in [960.0, 1090.0, 1320.0, 1450.0, 1600.0]:
		_piece(main, "res://scenes/lantern.tscn", Vector2(x, 160))
