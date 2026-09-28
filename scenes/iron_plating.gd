extends Node2D
## Iron plating: a riveted armour plate bolted along a cave wall (drawn like
## a chute: press at one end, drag to the other). A burrower's drill skids
## off it: it can't grind through, so it has to dig round the end of the
## plating (plates laid end to end count as one run), which costs it time
## and tiles. Wall a machine's cave in on the sides the moles come from and
## they come in the long way, under the floor or through the roof, where a
## ground listener and a trap can be waiting. A machine walled in all round
## can't be got at: the mole gives up on it. The plate is solid for
## everything else too (ore, walkers, the prospector), so keep it off the
## marble track. Burrowers don't bother chewing plating.

const THICK := 8.0
const LEN_MIN := 16.0
const LEN_MAX := 240.0
const PAD := 2.0                  # a point this close to the plate's face is on it
const GUARD := 9.0                # a drill point this close is stopped: the rock it's bolted to is safe too
const JOIN := 20.0                # plate ends this close count as one run
const TILE_TEX := preload("res://assets/sprites/plating_tile.png")   # one plate, tiled along the run
const END_TEX := preload("res://assets/sprites/plating_end.png")     # the bolted end cap

@export var end_offset := Vector2(0, 96)

var blocked := 0                  # tests: times a drill was turned by it
var _body: StaticBody2D
var _scrape := 0.0
var _art: Node2D                  # the plates, pixel art (nearest, tiled)


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(0, LEN_MIN)
	_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
	# art first, so ghosts and build-bar icons have it
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	add_to_group("iron_plating")
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_rebuild()


func _rebuild() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(end_offset.length() + THICK, THICK)
	cs.shape = r
	cs.position = end_offset * 0.5
	cs.rotation = end_offset.angle()
	_body.add_child(cs)


func ends() -> Array:
	return [global_position, global_position + end_offset]


## The plate whose face covers `p`, or null.
static func at(tree: SceneTree, p: Vector2, pad := PAD) -> Node2D:
	for pl in tree.get_nodes_in_group("iron_plating"):
		if not is_instance_valid(pl):
			continue
		var e: Array = pl.ends()
		if Geometry2D.get_closest_point_to_segment(p, e[0], e[1]).distance_to(p) < THICK * 0.5 + pad:
			return pl
	return null


## Does any plate lie across the straight line from a to b?
static func crosses(tree: SceneTree, a: Vector2, b: Vector2) -> bool:
	for pl in tree.get_nodes_in_group("iron_plating"):
		if not is_instance_valid(pl):
			continue
		var e: Array = pl.ends()
		if Geometry2D.segment_intersects_segment(a, b, e[0], e[1]) != null:
			return true
	return false


## The two far ends of the run this plate is part of (plates laid end to
## end are followed through), and the direction each end points out along.
## A closed ring has no ends: then this plate's own corners.
func run_ends() -> Array:
	var out := []
	var ring := false
	for k in 2:
		var e: Array = ends()
		var at_end: Vector2 = e[k]
		var from: Vector2 = e[1 - k]
		var seen := {self: true}
		var going := true
		while going:
			going = false
			for pl in get_tree().get_nodes_in_group("iron_plating"):
				if seen.has(pl) or not is_instance_valid(pl):
					continue
				var pe: Array = pl.ends()
				for j in 2:
					if pe[j].distance_to(at_end) < JOIN:
						seen[pl] = true
						from = pe[j]
						at_end = pe[1 - j]
						going = true
						break
				if going:
					break
		out.append([at_end, (at_end - from).normalized()])
		if seen.size() > 2 and at_end.distance_to(e[1 - k]) < JOIN:
			ring = true   # followed it all the way round to this plate's other end
	if ring:
		# a closed ring (a machine boxed in): round this plate's own corners
		var e: Array = ends()
		return [[e[0], (e[0] - e[1]).normalized()], [e[1], (e[1] - e[0]).normalized()]]
	return out


## A drill has just skidded off it (the burrower calls this).
func scraped(at: Vector2) -> void:
	blocked += 1
	if _scrape <= 0.0:
		_scrape = 0.2
		preload("res://scripts/fx.gd").burst(get_parent(), at, Color(1.0, 0.85, 0.45), 3, 90.0, 0.2, 1.1)
		preload("res://scripts/sfx.gd").play_small(self, preload("res://scripts/sfx.gd").sfx_clink(), -16.0, 0.6)


func _physics_process(delta: float) -> void:
	if _scrape > 0.0:
		_scrape -= delta


func _draw() -> void:
	if _art:
		_art.queue_redraw()


## The plates, tiled along the run with a bolted cap over each end;
## flipped on leftward runs so the lit edge stays on top.
func _draw_art() -> void:
	var l := end_offset.length()
	if l < 0.1:
		return
	var d := end_offset / l
	var flip := 1.0 if d.x >= 0 else -1.0
	var ang := d.angle()
	_art.draw_set_transform(Vector2.ZERO, ang, Vector2(1, flip))
	_art.draw_texture_rect(TILE_TEX, Rect2(0, -THICK * 0.5, l, THICK), true)
	_art.draw_texture(END_TEX, Vector2(-4, -4))
	_art.draw_set_transform(end_offset, ang, Vector2(-1, flip))
	_art.draw_texture(END_TEX, Vector2(-4, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
