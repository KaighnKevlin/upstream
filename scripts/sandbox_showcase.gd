extends Node
## The sandbox's starting layout: every element already built and running,
## so a new session starts with working chains to watch and tweak.
##
##   Far west (a small factory)
##     iron tapper -> through a laser mid-flight -> the ingot drops into an
##       assembler, which makes iron shot -> a belt carries it into the lift
##     copper tapper -> gravity wheel, which powers the assembler and belt
##   West of the dome (production)
##     tapper -> laser beam -> ingot lands in the dome's intake
##     tapper -> lobs ore into an upstream shaft, which floats it up and stacks it
##   East of the dome (defence; enemies come from the right)
##     drop hopper (pre-filled) by the dome, plate underneath, where melee
##       enemies stop to attack
##     tapper -> tilted trampoline -> funnel turret (keeps it loaded)
##     spiked pit further out: enemies climbing out are easy turret targets,
##       and a bumper on the near lip bats them back in
##     tapper -> catapult -> back over into the hopper, so the trap rearms
##     iron tapper -> splitter -> a chute each way -> two funnel turrets
##   Guards and lights
##     two brass sentries walking their beats east of the dome, and
##       lanterns on poles along the works for the night
##   Far east (the first things a wave meets)
##     the gate: a tripwire across the path wired to two powder kegs, an
##       ambush that greets the first wave (one-shot: they're gone after)
##     the grinder: a trapdoor over a pit with a crusher at the bottom
##     a tesla coil and a flame turret, charged and fuelled, covering it,
##       and two snares just past the grinder that pin walkers in the
##       coil's reach
##   Underground, under the dome's east approach (the marble yard)
##     a chamber carved beside the dome's shaft (tiles 80..105, rows 13..42,
##       x 1280..1696, y 208..688), sealed in stone below the surface
##       works and the sappers' tunnel row, lit by lanterns
##     copper and iron tappers on an ore ledge on its west wall lob into a
##       catch net, which drops the mixed stream through a paddle wheel
##       (powering a flywheel, which keeps the furnace and the pipe driven)
##     a chute to a magnet drum: iron rides round it and drops behind,
##       copper flies on
##     copper: a tally wheel over its chute throws a points switch every
##       third piece, so they go three into a silo (let out one a second),
##       three straight down to the bottom line
##     iron: a switchback of two banked turns down to the bottom line
##     the bottom line: a brake rail holds it all to a crawl onto a furnace
##       rail, which smelts it, and a pneumatic pipe carries the ingots up
##       the dome's shaft and shoots them into its intake: ammo for the
##       dome's cannon and its repair stock (tools/scenarios/showcase_marble_rec.gd)
##
## Aims were solved with a small simulation of the same physics (gravity
## 980, 60 Hz, the trampoline's reflect + kick, the laser's 0.6 slowdown)
## and checked in game; see tools/playtest.gd `showcase`.
## The world is random each run, so the builder forces the ground it needs.

const WorldGen = preload("res://scripts/world_gen.gd")

const EAST_TAPPER := Vector2i(84, 7)        # ore cell; the rig sits on its top face
const EAST_TAPPER_AIM := Vector2(14, 420)   # degrees from vertical, launch speed
const EAST_TRAMP := Vector2(1440, 12)
const EAST_TRAMP_SET := Vector2(15, 800)    # plate angle, bounce force
const TURRET_AT := Vector2(1580, 40)
const HOPPER_AT := Vector2(1300, 22)
const PIT := Rect2i(117, 6, 4, 3)           # tiles: x, y, w, h
const PIT_BUMPER := Vector2(1860, 90)       # on the pit's near lip: bats climbers back in
const FEED_TAPPER := Vector2i(97, 7)
const FEED_TAPPER_AIM := Vector2(-46, 330)  # lobs left into the catapult's bucket
const CATAPULT_AT := Vector2(1408, 80)
const CATAPULT_AIM := Vector2(-14, 515)     # high lob back up-left, down into the hopper

const WEST_TAPPER := Vector2i(60, 7)
const WEST_TAPPER_AIM := Vector2(44, 760)
const LASER_AT := Vector2(1060, 20)

const LIFT_TAPPER := Vector2i(50, 7)
const LIFT_TAPPER_AIM := Vector2(20, 300)
const LIFT_AT := Vector2(868, 36)           # upstream shaft standing on the ground

# the factory: aims solved like the others (laser slows what it smelts to 60%)
const FACTORY_IRON := Vector2i(24, 7)
const FACTORY_IRON_AIM := Vector2(36, 610)
const FACTORY_LASER := Vector2(526, -30)
const FACTORY_COPPER := Vector2i(20, 7)
const FACTORY_COPPER_AIM := Vector2(60, 655)   # a flat lob, under the laser, into the wheel
const FACTORY_WHEEL := Vector2(520, 40)
const FACTORY_ASSEMBLER := Vector2(600, 80)
const FACTORY_BELT := [Vector2(640, 86), Vector2(855, 86)]   # to the lift
const GROUND_FROM := 18                      # tiles: the flattened strip starts here
const GROUND_TO := 142

# far east: the grinder, a tesla coil and a flame turret
const GRINDER_PIT := Rect2i(128, 6, 3, 4)      # tiles; a trapdoor over it, a crusher at the bottom
const TESLA_AT := Vector2(1960, 80)
const FLAMER_AT := Vector2(2010, 80)
const SNARES := [Vector2(2118, 80), Vector2(2146, 80)]   # past the grinder, in the coil's reach
const GATE_WIRE := [Vector2(2190, 72), Vector2(2250, 72)]   # waist-high across the path
const GATE_KEGS := [Vector2(2210, 80), Vector2(2232, 80)]
const SENTRIES := [Vector2(1520, 60), Vector2(1760, 60)]
const LANTERNS := [Vector2(1135, 60), Vector2(1470, 60), Vector2(1660, 60), Vector2(1990, 40)]

# one tapper, two turrets: splitter on a post, a chute down to each funnel
const SPLIT_TAPPER := Vector2i(104, 7)
const SPLIT_TAPPER_AIM := Vector2(3, 670)   # near-vertical lob, lands on the paddle coming down
const SPLITTER_AT := Vector2(1704, -100)
const TURRET2_AT := Vector2(1820, 40)
const CHUTE_L := [Vector2(1696, -84), Vector2(1596, -44)]
const CHUTE_R := [Vector2(1712, -84), Vector2(1806, -44)]

# the marble yard: a chamber under the dome's east approach (see the header)
const YARD := Rect2i(80, 13, 26, 30)           # tiles: x 1280..1696, y 208..688; floor row 43
const YARD_SHOULDER := Rect2i(97, 13, 9, 9)   # rock left in its north-east corner, over the right half
const YARD_COPPER := Vector2i(81, 19)          # ore ledges on the chamber's west wall
const YARD_IRON := Vector2i(84, 19)
const YARD_COPPER_AIM := Vector2(46, 335)      # both lob up and over into the net
const YARD_IRON_AIM := Vector2(43, 260)
const YARD_FEED_EVERY := 1.2                   # s between shots, each tapper
const YARD_NET := Vector2(1450, 300)
const YARD_PADDLE := Vector2(1450, 376)        # under the net's ring: the whole stream falls through it
const YARD_FLYWHEEL := Vector2(1370, 520)      # in reach of the paddle wheel, the furnace and the pipe
const YARD_C1 := [Vector2(1424, 430), Vector2(1534, 456)]
const YARD_DRUM := Vector2(1536, 458)          # at C1's end: iron rides round, copper flies on
const YARD_C2 := [Vector2(1552, 486), Vector2(1632, 504)]   # copper, under the tally wheel
const YARD_TALLY := Vector2(1590, 488)
const YARD_POINTS := Vector2(1646, 532)
const YARD_SILO := Vector2(1662, 630)          # stands on the bottom line, under the points' right side
const YARD_CI := [Vector2(1545, 498), Vector2(1455, 516)]   # iron, dropped behind the drum
const YARD_TURN := Vector2(1452, 517)
const YARD_C3 := [Vector2(1448, 570), Vector2(1582, 600)]   # iron, back out of the turn
const YARD_TURN2 := Vector2(1585, 601)         # and round again, down onto the brake
const YARD_LA := [Vector2(1692, 644), Vector2(1602, 652)]   # the bottom line, running west
const YARD_BRAKE := [Vector2(1600, 652), Vector2(1522, 658)]
const YARD_FURNACE := [Vector2(1330, 678), Vector2(1520, 658)]   # node at the low end: the flywheel reaches it
const YARD_PIPE := Vector2(1316, 684)          # its mouth catches what comes off the furnace
const YARD_INTAKE := Vector2(1236, 100)        # just under the dome's intake: it shoots up into it
const YARD_LAMPS := [Vector2(1360, 216), Vector2(1480, 216), Vector2(1568, 360), Vector2(1664, 360), Vector2(1288, 568), Vector2(1688, 488), Vector2(1688, 600)]
const YARD_NUBS := [Vector2i(80, 34), Vector2i(105, 29), Vector2i(105, 36)]   # rock brackets on the walls the lower lamps hang from


static func build(main: Node) -> void:
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var decor := main.get_node_or_null("CaveDecor")
	var shading := main.get_node_or_null("TileShading")

	# ground: flat surface over the whole showcase strip, veins, the pit
	for x in range(GROUND_FROM, GROUND_TO):
		for y in range(0, WorldGen.SURFACE_ROWS):
			tm.set_cell(Vector2i(x, y), -1)
	for cell in [EAST_TAPPER, WEST_TAPPER, LIFT_TAPPER, FEED_TAPPER]:
		_vein(tm, cell, shading, decor)
	_vein(tm, SPLIT_TAPPER, shading, decor, WorldGen.TILE_IRON)   # the turrets' feed: iron shot
	_vein(tm, FACTORY_IRON, shading, decor, WorldGen.TILE_IRON)
	_vein(tm, FACTORY_COPPER, shading, decor)
	for x in range(PIT.position.x, PIT.end.x):
		for y in range(PIT.position.y, PIT.end.y):
			_clear(tm, Vector2i(x, y), shading, decor)
	for x in range(GRINDER_PIT.position.x, GRINDER_PIT.end.x):
		for y in range(GRINDER_PIT.position.y, GRINDER_PIT.end.y):
			_clear(tm, Vector2i(x, y), shading, decor)
		# a solid floor and walls, whatever the world put there
		WorldGen.set_tile(tm, Vector2i(x, GRINDER_PIT.end.y), WorldGen.TILE_STONE)
	for y in range(GRINDER_PIT.position.y, GRINDER_PIT.end.y + 1):
		for x in [GRINDER_PIT.position.x - 1, GRINDER_PIT.end.x]:
			if tm.get_cell_source_id(Vector2i(x, y)) == -1:
				WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_DIRT)

	# the marble yard (underground, east): first, so the surface chains'
	# pieces stay the last of their kinds in the showcase group
	_carve_yard(main, tm, shading, decor)
	_marble_yard(main, tm)

	# the factory (far west)
	_tapper(main, tm, FACTORY_COPPER, FACTORY_COPPER_AIM)
	_add(main, preload("res://scenes/gravity_wheel.tscn"), FACTORY_WHEEL)
	_tapper(main, tm, FACTORY_IRON, FACTORY_IRON_AIM)
	_add(main, preload("res://scenes/laser_smelter.tscn"), FACTORY_LASER)
	_add(main, preload("res://scenes/assembler.tscn"), FACTORY_ASSEMBLER)
	var belt: Node2D = preload("res://scenes/belt.tscn").instantiate()
	belt.end_offset = FACTORY_BELT[1] - FACTORY_BELT[0]
	_add_node(main, belt, FACTORY_BELT[0])

	# production (west)
	_tapper(main, tm, WEST_TAPPER, WEST_TAPPER_AIM)
	_add(main, preload("res://scenes/laser_smelter.tscn"), LASER_AT)
	_tapper(main, tm, LIFT_TAPPER, LIFT_TAPPER_AIM)
	_add(main, preload("res://scenes/upstream_shaft.tscn"), LIFT_AT)

	# defence (east)
	_tapper(main, tm, EAST_TAPPER, EAST_TAPPER_AIM)
	var t: Node2D = preload("res://scenes/trampoline.tscn").instantiate()
	t.bounce_angle = EAST_TRAMP_SET.x
	t.bounce_force = EAST_TRAMP_SET.y
	_add_node(main, t, EAST_TRAMP)
	t._update_visuals()
	_add(main, preload("res://scenes/funnel_turret.tscn"), TURRET_AT)
	var hop: Node2D = _add(main, preload("res://scenes/hopper.tscn"), HOPPER_AT)
	_tapper(main, tm, FEED_TAPPER, FEED_TAPPER_AIM)
	var cat: Node2D = preload("res://scenes/catapult.tscn").instantiate()
	cat.aim_angle = CATAPULT_AIM.x
	cat.throw_speed = CATAPULT_AIM.y
	_add_node(main, cat, CATAPULT_AT)
	for k in 4:  # pre-fill the hopper
		var o: Node2D = preload("res://scenes/ore.tscn").instantiate()
		o.global_position = HOPPER_AT + Vector2(0, -60 - k * 18)
		o.add_to_group("showcase")
		main.add_child(o)
	_tapper(main, tm, SPLIT_TAPPER, SPLIT_TAPPER_AIM)
	_add(main, preload("res://scenes/splitter.tscn"), SPLITTER_AT)
	_add(main, preload("res://scenes/funnel_turret.tscn"), TURRET2_AT)
	for ends in [CHUTE_L, CHUTE_R]:
		var ch: Node2D = preload("res://scenes/chute.tscn").instantiate()
		ch.end_offset = ends[1] - ends[0]
		_add_node(main, ch, ends[0])
	_add(main, preload("res://scenes/bumper.tscn"), PIT_BUMPER)

	# the grinder, and a tesla coil and a flame turret covering it
	var mid := tm.to_global(tm.map_to_local(Vector2i(GRINDER_PIT.position.x + GRINDER_PIT.size.x / 2, GRINDER_PIT.position.y)))
	_add(main, preload("res://scenes/crusher.tscn"), Vector2(mid.x, mid.y + (GRINDER_PIT.size.y - 1) * 16))
	_add(main, preload("res://scenes/trapdoor.tscn"), mid)
	var te: Node2D = _add(main, preload("res://scenes/tesla.tscn"), TESLA_AT)
	te.charge = te.MAX_CHARGE
	var fl: Node2D = _add(main, preload("res://scenes/flamer.tscn"), FLAMER_AT)
	fl.fuel = fl.MAX_FUEL
	for at in SNARES:
		_add(main, preload("res://scenes/snare.tscn"), at)
	# the gate: a wire across the path, two kegs under it
	for at in GATE_KEGS:
		_add(main, preload("res://scenes/keg.tscn"), at)
	var wire: Node2D = preload("res://scenes/tripwire.tscn").instantiate()
	wire.end_offset = GATE_WIRE[1] - GATE_WIRE[0]
	_add_node(main, wire, GATE_WIRE[0])
	for at in SENTRIES:
		_add(main, preload("res://scenes/sentry.tscn"), at)
	for at in LANTERNS:
		_add(main, preload("res://scenes/lantern.tscn"), at)
	WorldGen.reframe_all(tm)   # the cleared strip changed the ground's edges
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	for x in [PIT.position.x + 1, PIT.position.x + 2]:
		var sp: Node2D = preload("res://scenes/spikes.tscn").instantiate()
		_add_node(main, sp, tm.to_global(tm.map_to_local(Vector2i(x, PIT.end.y - 1))))


## The marble yard's chamber: cleared, with a stone shell whatever the world
## put there, the ore ledges on its west wall, and nothing the world
## scattered in its caves (crawlers, geysers, gas) left inside it.
static func _carve_yard(main: Node, tm: TileMapLayer, shading, decor) -> void:
	for y in range(YARD.position.y, YARD.end.y):
		for x in range(YARD.position.x, YARD.end.x):
			if YARD_SHOULDER.has_point(Vector2i(x, y)):
				WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
			else:
				_clear(tm, Vector2i(x, y), shading, decor)
	for x in range(YARD.position.x - 1, YARD.end.x + 1):
		for y in [YARD.position.y - 1, YARD.end.y]:
			WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	for y in range(YARD.position.y, YARD.end.y):
		for x in [YARD.position.x - 1, YARD.end.x]:
			WorldGen.set_tile(tm, Vector2i(x, y), WorldGen.TILE_STONE)
	for c in YARD_NUBS:
		WorldGen.set_tile(tm, c, WorldGen.TILE_STONE)
	_vein(tm, YARD_COPPER, shading, decor)
	_vein(tm, YARD_IRON, shading, decor, WorldGen.TILE_IRON)
	var box := Rect2(Vector2(YARD.position * WorldGen.TILE_SIZE), Vector2(YARD.size * WorldGen.TILE_SIZE)).grow(8)
	for g in ["caches", "geysers", "crawlers", "ruins", "firedamp", "magma", "depths", "cinderbats", "wyrms"]:
		for n in main.get_tree().get_nodes_in_group(g):
			if is_instance_valid(n) and n is Node2D and box.has_point(n.global_position):
				n.queue_free()


## The marble yard (see the header): built into the chamber _carve_yard made.
static func _marble_yard(main: Node, tm: TileMapLayer) -> void:
	var rails: Array = []
	for cell in [[YARD_COPPER, YARD_COPPER_AIM], [YARD_IRON, YARD_IRON_AIM]]:
		var m := _tapper(main, tm, cell[0], cell[1])
		m.eject_interval = YARD_FEED_EVERY
	_add(main, preload("res://scenes/catch_net.tscn"), YARD_NET)
	_add(main, preload("res://scenes/paddle_wheel.tscn"), YARD_PADDLE)
	_add(main, preload("res://scenes/flywheel.tscn"), YARD_FLYWHEEL)
	rails.append(_rail(main, preload("res://scenes/chute.tscn"), YARD_C1))
	var drum: Node2D = preload("res://scenes/magnet_drum.tscn").instantiate()
	drum.side = 1.0
	_add_node(main, drum, YARD_DRUM)
	# copper: the tally wheel throws the points every third piece, so they go
	# three into the silo, three straight on to the furnace
	rails.append(_rail(main, preload("res://scenes/chute.tscn"), YARD_C2))
	var tally: Node2D = preload("res://scenes/tally.tscn").instantiate()
	tally.mode = 0
	tally.wire_to = Vector2.ZERO    # it fires what's in reach: the points (the silo is just out of it)
	_add_node(main, tally, YARD_TALLY)
	_add(main, preload("res://scenes/points.tscn"), YARD_POINTS)
	var silo: Node2D = preload("res://scenes/silo.tscn").instantiate()
	silo.mode = 1
	_add_node(main, silo, YARD_SILO)
	# iron: behind the drum and down a switchback of banked turns onto the brake
	rails.append(_rail(main, preload("res://scenes/chute.tscn"), YARD_CI))
	var turn: Node2D = preload("res://scenes/banked_turn.tscn").instantiate()
	turn.side = -1.0
	_add_node(main, turn, YARD_TURN)
	rails.append(_rail(main, preload("res://scenes/chute.tscn"), YARD_C3))
	var turn2: Node2D = preload("res://scenes/banked_turn.tscn").instantiate()
	turn2.side = 1.0
	_add_node(main, turn2, YARD_TURN2)
	# the bottom line: brake, furnace, and the pipe up to the dome
	rails.append(_rail(main, preload("res://scenes/chute.tscn"), YARD_LA))
	var brake: Node2D = preload("res://scenes/brake.tscn").instantiate()
	brake.mode = 0
	brake.has_lip = false    # it carries on from the chute before it
	brake.end_offset = YARD_BRAKE[1] - YARD_BRAKE[0]
	rails.append(_add_node(main, brake, YARD_BRAKE[0]))
	rails.append(_rail(main, preload("res://scenes/furnace_rail.tscn"), YARD_FURNACE))
	var pipe: Node2D = preload("res://scenes/tube.tscn").instantiate()
	pipe.end_offset = YARD_INTAKE - YARD_PIPE
	_add_node(main, pipe, YARD_PIPE)
	for at in YARD_LAMPS:
		_add(main, preload("res://scenes/lantern.tscn"), at)
	_repost(main, rails)


## A chute (or a brake or furnace rail) from its first point to its second.
static func _rail(main: Node, scene: PackedScene, ends: Array) -> Node2D:
	var ch: Node2D = scene.instantiate()
	ch.end_offset = ends[1] - ends[0]
	return _add_node(main, ch, ends[0])


## Rails stand their struts on the ground when they go in, but the yard's
## chamber only gets collision a frame or two later: stand them again then.
static func _repost(main: Node, rails: Array) -> void:
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	for r in rails:
		if is_instance_valid(r) and r.is_inside_tree():
			r._build_posts()


## Remove everything the showcase placed (buildings, pre-fill ore).
static func clear(main: Node) -> void:
	for n in main.get_tree().get_nodes_in_group("showcase"):
		if is_instance_valid(n):
			n.queue_free()
	var bs := main.get_node_or_null("/root/BuildSystem")
	if bs:
		bs._placed_buildings = bs._placed_buildings.filter(func(b): return is_instance_valid(b) and not b.is_in_group("showcase"))


static func _vein(tm: TileMapLayer, cell: Vector2i, shading, decor, tile := WorldGen.TILE_COPPER) -> void:
	# the ore block and a few more below it; the notch above is dug out
	for c in [cell, cell + Vector2i(-1, 1), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]:
		WorldGen.set_tile(tm, c, tile)
	for dx in [-1, 0, 1]:
		_clear(tm, cell + Vector2i(dx, -1), shading, decor)


static func _clear(tm: TileMapLayer, cell: Vector2i, shading, decor) -> void:
	tm.set_cell(cell, -1)
	if shading:
		shading.mark_dirty(cell)
	if decor:
		decor.tile_cleared(cell)


static func _tapper(main: Node, tm: TileMapLayer, cell: Vector2i, aim: Vector2) -> Node2D:
	var m: Node2D = preload("res://scenes/miner.tscn").instantiate()
	m.eject_angle = aim.x
	m.eject_force = aim.y
	return _add_node(main, m, tm.to_global(tm.map_to_local(cell)))


static func _add(main: Node, scene: PackedScene, at: Vector2) -> Node2D:
	return _add_node(main, scene.instantiate(), at)


static func _add_node(main: Node, n: Node2D, at: Vector2) -> Node2D:
	n.global_position = at
	n.add_to_group("showcase")
	main.add_child(n)
	var bs := main.get_node_or_null("/root/BuildSystem")
	if bs:
		bs._placed_buildings.append(n)  # so right-click can remove it like any building
	return n
