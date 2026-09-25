extends Node
## The sandbox's starting layout: every element already built and running,
## so a new session starts with working chains to watch and tweak.
##
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

# one tapper, two turrets: splitter on a post, a chute down to each funnel
const SPLIT_TAPPER := Vector2i(104, 7)
const SPLIT_TAPPER_AIM := Vector2(3, 670)   # near-vertical lob, lands on the paddle coming down
const SPLITTER_AT := Vector2(1704, -100)
const TURRET2_AT := Vector2(1820, 40)
const CHUTE_L := [Vector2(1696, -84), Vector2(1596, -44)]
const CHUTE_R := [Vector2(1712, -84), Vector2(1806, -44)]


static func build(main: Node) -> void:
	var tm: TileMapLayer = main.get_node("TileMapLayer")
	var decor := main.get_node_or_null("CaveDecor")
	var shading := main.get_node_or_null("TileShading")

	# ground: flat surface over the whole showcase strip, veins, the pit
	for x in range(46, 124):
		for y in range(0, WorldGen.SURFACE_ROWS):
			tm.set_cell(Vector2i(x, y), -1)
	for cell in [EAST_TAPPER, WEST_TAPPER, LIFT_TAPPER, FEED_TAPPER]:
		_vein(tm, cell, shading, decor)
	_vein(tm, SPLIT_TAPPER, shading, decor, WorldGen.TILE_IRON)   # the turrets' feed: iron shot
	for x in range(PIT.position.x, PIT.end.x):
		for y in range(PIT.position.y, PIT.end.y):
			_clear(tm, Vector2i(x, y), shading, decor)

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
	WorldGen.reframe_all(tm)   # the cleared strip changed the ground's edges
	if shading:
		for c in shading.get_children():
			c.queue_redraw()
	for x in [PIT.position.x + 1, PIT.position.x + 2]:
		var sp: Node2D = preload("res://scenes/spikes.tscn").instantiate()
		_add_node(main, sp, tm.to_global(tm.map_to_local(Vector2i(x, PIT.end.y - 1))))


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
