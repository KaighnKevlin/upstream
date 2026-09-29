extends RefCounted
## Marble Siege: a playable slice. One long cavern to the right of the dome:
## the works (a marble machine) up top, the walker lane along the floor, the
## vault behind the works at the left. Waves walk in from the right wall
## (scripts/siege_director.gd); the machine's marbles are what re-arm and
## refill the defences along the lane.
##
##   works    a dispenser drops copper and iron into a bowl feeder, which
##            walks them up its ledge single file onto a sling; the sling
##            whirls each one and throws it over the vault shaft into a
##            catch funnel, where a balloon lift floats it up to the roof
##   roof     a long run right along the ceiling. A magnet rail lifts the
##            iron off over a gap; the copper drops through it into a field
##            of pop bumpers and rattles down to the lower line
##   coaster  the iron runs on to the far end, where a steep magnet rail
##            hurls it down into a loop-the-loop, then over a jump
##   feed     overflow gates hand each line out in priority order, each
##            one keeping a small stock by its trap and passing the rest on:
##              iron:   spring trap (front) > flak cannon > bombs (lit by
##                      the igniter, rolled left at the walkers)
##              copper: portcullis bucket > wrecking ball (its stock waits
##                      behind a sluice on the ball's own tripwire) > the
##                      gabion > the caltrop spreader
##
## Pieces never collide with each other, so a "pocket" (a V of chutes, or
## chute and floor) holds any number overlapped: that is the stock.
## Built by main.gd start_siege_works().

const MarbleWorks = preload("res://scripts/marble_works.gd")
const Showcase = preload("res://scripts/sandbox_showcase.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const Director = preload("res://scripts/siege_director.gd")

const CAVE := Rect2i(68, 9, 67, 32)      # tiles: x 1088..2160, rows 9..40 (floor row 41)
const FLOOR_Y := 656.0
const VAULT_X := 1340.0
const SPAWN_X := 2130.0


static func carve(main: Node) -> TileMapLayer:
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var shading := main.get_node_or_null("TileShading")
	var decor := main.get_node_or_null("CaveDecor")
	for y in range(CAVE.position.y, CAVE.end.y):
		for x in range(CAVE.position.x, CAVE.end.x):
			Showcase._clear(tm, Vector2i(x, y), shading, decor)
	for x in range(CAVE.position.x - 1, CAVE.end.x + 1):
		WorldGen.set_tile(tm, Vector2i(x, CAVE.end.y), WorldGen.TILE_STONE)
		WorldGen.set_tile(tm, Vector2i(x, CAVE.end.y + 1), WorldGen.TILE_STONE)
	for y in range(CAVE.position.y - 1, CAVE.end.y):
		for x in [CAVE.position.x - 1, CAVE.end.x]:
			WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	for x in range(CAVE.position.x - 1, CAVE.end.x + 1):
		WorldGen.set_tile(tm, Vector2i(x, CAVE.position.y - 1), WorldGen.TILE_STONE)
	# a rock shelf in the works for the bowl feeder to stand on
	for x in range(68, 73):
		WorldGen.set_tile(tm, Vector2i(x, 19), WorldGen.TILE_STONE)
	WorldGen.reframe_all(tm)
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	# cave dwellers the world put here: not part of this level
	var rect := Rect2(Vector2(CAVE.position) * 16.0 - Vector2(32, 32), Vector2(CAVE.size) * 16.0 + Vector2(64, 64))
	for g in ["crawlers", "cinderbats", "wyrms", "geysers", "caches", "firedamp", "ruins", "magma", "depths"]:
		for n in main.get_tree().get_nodes_in_group(g):
			if is_instance_valid(n) and n is Node2D and rect.has_point(n.global_position):
				n.queue_free()
	var fog := main.get_node_or_null("Fog")
	if fog:
		for y in range(int(rect.position.y), int(rect.end.y), 48):
			for x in range(int(rect.position.x), int(rect.end.x), 48):
				fog.reveal(Vector2(x, y), 4.0)
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	return tm


static func _chute(main: Node, a: Vector2, b: Vector2, lip := true) -> Node2D:
	var ch := MarbleWorks._chute(main, a, b)
	if not lip:
		ch.has_lip = false
		ch._rebuild()
	return ch


static func _piece(main: Node, path: String, at: Vector2, props := {}) -> Node2D:
	return MarbleWorks._piece(main, path, at, props)


## An overflow gate at `at`: everything to `side` until `full` pieces sit
## still at `watch` (global), then the rest the other way.
static func _gate(main: Node, at: Vector2, side: float, watch: Vector2, full: int) -> Node2D:
	return _piece(main, "res://scenes/overflow_gate.tscn", at, {"side": side, "watch": watch - at, "full": full})


## Builds the level; returns the director (it runs the waves).
static func build(main: Node) -> Node2D:
	await carve(main)
	var parts := {}
	# ── the works ──
	parts.dispenser = _piece(main, "res://scenes/dispenser.tscn", Vector2(1118, 196), {"mode": 0, "kinds": ["copper", "iron", "copper", "copper"]})
	parts.bowl = _piece(main, "res://scenes/bowl_feeder.tscn", Vector2(1122, 304), {"side": 1.0})
	_chute(main, Vector2(1157, 250), Vector2(1176, 256), false)
	parts.sling = _piece(main, "res://scenes/sling.tscn", Vector2(1190, 262), {"aim": 7})
	# what the sling can't take (it's still whirling the last) runs under it to the basket
	_chute(main, Vector2(1172, 286), Vector2(1292, 300))
	# the catch funnel over the vault shaft, the balloon's basket at its foot
	_chute(main, Vector2(1256, 256), Vector2(1297, 294))
	_chute(main, Vector2(1344, 256), Vector2(1303, 294))
	parts.balloon = _piece(main, "res://scenes/balloon_lift.tscn", Vector2(1300, 302), {"mode": 1, "side": 1.0})
	# ── the roof run: iron rides the magnet over the gap, copper drops through ──
	_chute(main, Vector2(1284, 178), Vector2(1450, 205))
	_chute(main, Vector2(1450, 205), Vector2(1600, 230), false)
	parts.magrail = _piece(main, "res://scenes/magnet_rail.tscn", Vector2(1540, 200), {"end_offset": Vector2(150, 8)})
	_chute(main, Vector2(1674, 220), Vector2(1900, 256), false)
	_chute(main, Vector2(1900, 256), Vector2(2062, 282), false)
	# ── the coaster (iron): a steep magnet rail hurls it down, round the loop, over the jump ──
	parts.plunge = _piece(main, "res://scenes/magnet_rail.tscn", Vector2(2090, 262), {"end_offset": Vector2(-85, 147)})
	# it leaves the rail's end at full tilt and flies straight into the loop's foot
	var foot := Vector2(1992, 463)
	parts.loop = _piece(main, "res://scenes/loop.tscn", foot, {"side": -1.0})
	var rail_end := foot + Vector2(-80, 12.5)
	parts.jump = _piece(main, "res://scenes/jump.tscn", rail_end + Vector2(-18, 3), {"end_offset": Vector2(-70, 26)})
	# ── the rattle (copper): pop bumpers under the gap, a long funnel left ──
	parts.bumpers = []
	for p in [Vector2(1630, 292), Vector2(1664, 318), Vector2(1622, 342)]:
		parts.bumpers.append(_piece(main, "res://scenes/pop_bumper.tscn", p))
	_chute(main, Vector2(1436, 382), Vector2(1460, 414))
	_chute(main, Vector2(1712, 348), Vector2(1480, 414))
	# ── the iron feed (low): spring trap first, then the flak cannon, the rest bombs ──
	parts.spring = _piece(main, "res://scenes/spring_trap.tscn", Vector2(1990, 640))
	var spring_pocket := Vector2(2012, 649)
	parts.g_spring = _gate(main, Vector2(1760, 552), 1.0, spring_pocket, 1)   # one in stock: it re-cocks on the next delivery
	_chute(main, Vector2(1778, 566), Vector2(1995, 626))
	_chute(main, Vector2(1999, 638), Vector2(2008, 656), false)
	_chute(main, Vector2(2044, 606), Vector2(2019, 656))
	parts.flak = _piece(main, "res://scenes/flak_cannon.tscn", Vector2(1766, 640))
	var flak_mouth := Vector2(1746, 636)
	parts.g_flak = _gate(main, Vector2(1728, 598), 1.0, flak_mouth, 1)
	_chute(main, Vector2(1760, 598), Vector2(1754, 628), false)   # a backstop over the hopper
	#   what's left over is lit as it drops and rolls left at the walkers at the gabion
	parts.igniter = _piece(main, "res://scenes/igniter.tscn", Vector2(1706, 612), {"mode": 2})
	# ── the copper feed (high): portcullis bucket, wrecking ball, gabion, caltrops ──
	parts.portcullis = _piece(main, "res://scenes/portcullis.tscn", Vector2(1440, 640))
	var port_pocket := Vector2(1416, 594)
	parts.g_port = _gate(main, Vector2(1470, 444), -1.0, port_pocket, 4)
	_chute(main, Vector2(1460, 460), Vector2(1420, 600), false)
	_chute(main, Vector2(1400, 582), Vector2(1412, 602))
	_chute(main, Vector2(1424, 430), Vector2(1432, 482), false)   # a backstop: what the gate flings left drops onto the chute
	_chute(main, Vector2(1488, 458), Vector2(1508, 464))
	#   the wrecking ball's reload waits behind a sluice on the ball's own
	#   tripwire: the wire lets the ball go and opens the sluice, and the
	#   stock rolls down through the winch bucket a moment later, after the
	#   swing (stock left at the bucket would wind it straight back up)
	var wreck_at := Vector2(1700, 568)
	parts.wreck = _piece(main, "res://scenes/wrecking_ball.tscn", wreck_at, {"side": 1.0})
	var wreck_stock := Vector2(1628, 540)
	parts.g_wreck = _gate(main, Vector2(1525, 488), 1.0, wreck_stock, 4)
	_chute(main, Vector2(1543, 502), Vector2(1700, 582))   # through the bucket at (1682, 570), on into the iron's flak gate
	parts.sluice = _piece(main, "res://scenes/sluice.tscn", Vector2(1640, 551), {"side": 1.0})
	#   then the gabion: a V over its top keeps a few waiting on a full one (they
	#   drop in as blows knock pieces out); once they're waiting, the rest goes
	#   down into the caltrop spreader
	var gab_at := Vector2(1475, 640)   # snaps down onto the floor (y 656)
	parts.gabion = _piece(main, "res://scenes/gabion.tscn", gab_at)
	parts.gabion.kinds = ["iron", "copper", "iron", "copper", "iron", "copper"]   # half built at the start
	parts.gabion._fit()
	var gab_top := Vector2(gab_at.x, FLOOR_Y - 52)
	_chute(main, gab_top + Vector2(-18, -18), gab_top + Vector2(-6.5, 0))
	_chute(main, gab_top + Vector2(18, -18), gab_top + Vector2(6.5, 0))
	parts.g_gabion = _gate(main, Vector2(1503, 530), -1.0, gab_top + Vector2(0, -3), 2)
	_chute(main, Vector2(1536, 516), Vector2(1526, 604), false)   # a backstop over the spreader
	parts.caltrops = _piece(main, "res://scenes/caltrop_spreader.tscn", Vector2(1521, 640), {"side": 1})
	# ── the wiring: a tripwire in front of the ball, one in front of the gate ──
	parts.wire_wreck = _piece(main, "res://scenes/tripwire.tscn", Vector2(1722, 636), {"end_offset": Vector2(24, 0)})
	parts.wire_port = _piece(main, "res://scenes/tripwire.tscn", Vector2(1446, 636), {"end_offset": Vector2(24, 0)})
	# light: along the roof, and on poles over the lane
	for x in [1150.0, 1400.0, 1640.0, 1880.0, 2100.0]:
		_piece(main, "res://scenes/lantern.tscn", Vector2(x, 150))
	for x in [1370.0, 1545.0, 1650.0, 1880.0, 2110.0]:
		_piece(main, "res://scenes/lantern.tscn", Vector2(x, 570))
	for at in [Vector2(1250, 420), Vector2(1560, 400), Vector2(1800, 330), Vector2(2050, 420), Vector2(1860, 520)]:
		_piece(main, "res://scenes/lantern.tscn", at)
	var d: Node2D = Director.new()
	d.parts = parts
	d.vault_x = VAULT_X
	d.floor_y = FLOOR_Y
	d.spawn_at = Vector2(SPAWN_X, FLOOR_Y - 16)
	d.flier_at = Vector2(SPAWN_X, 260)
	Showcase._add_node(main, d, Vector2.ZERO)
	for k in ["wreck", "spring", "portcullis", "gabion", "caltrops", "flak", "igniter"]:
		d.track(k, parts[k])
	for p in [wreck_stock, spring_pocket, port_pocket]:
		d.keep_point(p)
	return d
