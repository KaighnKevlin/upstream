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

@export var end_offset := Vector2(0, 96)

var blocked := 0                  # tests: times a drill was turned by it
var _body: StaticBody2D
var _scrape := 0.0


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(0, LEN_MIN)
	_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
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
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var l := end_offset.length()
	if l < 0.1:
		return
	draw_set_transform(Vector2.ZERO, end_offset.angle(), Vector2.ONE)
	var h := THICK * 0.5
	draw_rect(Rect2(-h, -h, l + THICK, THICK), dark)
	draw_rect(Rect2(-h + 1, -h + 1, l + THICK - 2, THICK - 2), steel)
	draw_line(Vector2(-h + 1, -h + 1.5), Vector2(l + h - 1, -h + 1.5), steel.lightened(0.3), 1.0)
	# seams between the plates, and a rivet either side of each
	var n := maxi(1, int(round(l / 24.0)))
	for i in n + 1:
		var x := l * i / n
		if i > 0 and i < n:
			draw_line(Vector2(x, -h + 1), Vector2(x, h - 1), dark, 1.0)
		for dx in [-3.0, 3.0]:
			if x + dx > -h + 1 and x + dx < l + h - 1:
				draw_circle(Vector2(x + dx, 0), 1.0, steel.lightened(0.45))
	# brass bolts through into the rock at each end
	for x in [0.0, l]:
		draw_circle(Vector2(x, 0), 2.2, dark)
		draw_circle(Vector2(x, 0), 1.4, brass)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
