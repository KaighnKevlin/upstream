extends Node2D
## Track rail: the chute's counterpart on the track net (TRIAL, beside the
## physics chute for comparison). A dark iron rail on wooden sleepers, laid
## from where it was placed to its end. Marbles on it aren't physics bodies:
## scripts/track/track_net.gd rolls them along it (downhill faster, uphill
## slower, queueing nose to tail), so a thousand cost next to nothing.
##
## Its end, laid within a few px of another track piece's start, runs onto
## it; over a track bin it feeds the bin. An end that goes nowhere is open:
## marbles fly off it as ordinary physics ore, and ore coming down onto a
## rail rolls on as a rider again. The start has a stop when the rail runs
## down from it; laid uphill (a kick) it's open too.
##
## Placed by its start; click it, then drag the end handle. `drive` > 0
## makes it powered (riders held to that speed: a lift).

const TrackNet = preload("res://scripts/track/track_net.gd")
const ORE_ONLY := 64
const LEN_MIN := 32.0
const LEN_MAX := 220.0
const POST_MAX := 220.0
const LIP := 7.0

## The other end of the rail, relative to where it was placed.
@export var end_offset := Vector2(84, 36)
## Powered: riders are driven along it at this speed (px/s). 0: gravity.
@export var drive := 0.0

var track = null                 # its Track on the net
var _net: Node = null
var _body: StaticBody2D
var _posts: Array[Line2D] = []
var _selected := false
var _dragging := false
var _chain := 0.0
var _lip := true                 # a stop at the start (the net says: nothing feeds it, runs down)
static var _steel := _make_steel()


static func _make_steel() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.5
	m.absorbent = true
	m.friction = 1.0
	return m


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	_net = TrackNet.get_net(self)
	# laid by hand: snap the start onto a track end, the end onto a start or bin
	var start: Vector2 = _net.snap_point(global_position, true, 12.0, self)
	var end_at: Vector2 = _net.snap_point(global_position + end_offset, false, 12.0, self)
	global_position = start
	end_offset = end_at - start
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	_body.physics_material_override = _steel
	add_child(_body)
	track = _net.add_track(self, _path())
	track.drive = drive
	_rebuild()


func _exit_tree() -> void:
	if track != null and is_instance_valid(_net):
		_net.remove_track(track)
		track = null


func _path() -> PackedVector2Array:
	return PackedVector2Array([global_position, global_position + end_offset])


## Physics ore that isn't caught (a bomb, say) still lands and rolls on it,
## one-way from above like a chute.
func _rebuild() -> void:
	queue_redraw()
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var a := Vector2.ZERO if end_offset.x >= 0 else end_offset
	var b := end_offset if end_offset.x >= 0 else Vector2.ZERO
	var rail := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.b = Vector2((b - a).length(), 0)
	rail.shape = seg
	rail.position = a
	rail.rotation = (b - a).angle()
	rail.one_way_collision = true
	rail.one_way_collision_margin = 4.0
	_body.add_child(rail)
	if _lip:
		var lip := CollisionShape2D.new()
		var ls := SegmentShape2D.new()
		ls.b = Vector2(0, -LIP)
		lip.shape = ls
		_body.add_child(lip)
	_build_posts()


func _build_posts() -> void:
	for p in _posts:
		p.queue_free()
	_posts.clear()
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	for end in [Vector2.ZERO, end_offset]:
		var top := to_global(end) + Vector2(0, 3)
		var q := PhysicsRayQueryParameters2D.create(top, top + Vector2(0, POST_MAX), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var leg := Line2D.new()
		leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
		leg.texture = preload("res://assets/sprites/strut.png")
		leg.texture_mode = Line2D.LINE_TEXTURE_TILE
		leg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		leg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		leg.width = 5.0
		leg.z_index = -2
		add_child(leg)
		_posts.append(leg)


func _process(delta: float) -> void:
	if track != null and track.lip != _lip:
		_lip = track.lip
		_rebuild()
	if drive != 0.0 and not has_meta("ghost"):
		_chain = fmod(_chain + drive * delta, 10.0)
		queue_redraw()


# ── look: a dark iron rail on wooden sleepers ──────────────────────────

const DARK := Color(0.07, 0.06, 0.08)
const IRON := Color(0.24, 0.23, 0.26)
const SHEEN := Color(0.52, 0.52, 0.56)
const WOOD := Color(0.36, 0.23, 0.13)
const WOOD_TOP := Color(0.5, 0.34, 0.2)
const CHAIN := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	var a := Vector2.ZERO
	var b := end_offset
	var d := b - a
	var l := d.length()
	if l < 1:
		return
	var t := d / l
	var n := Vector2(t.y, -t.x)
	if n.y > 0 or (n.y == 0 and n.x > 0):
		n = -n
	# sleepers under the rail, every 8 px
	var k := 4.0
	while k < l - 2:
		var p := a + t * k
		draw_line(p - n * 2.0, p - n * 7.0, DARK, 4.0)
		draw_line(p - n * 2.5, p - n * 6.5, WOOD, 2.0)
		draw_line(p - n * 2.5, p - n * 3.5, WOOD_TOP, 2.0)
		k += 8.0
	# the rail: a dark iron bar with a dull sheen on the running edge
	draw_line(a - n * 1.5, b - n * 1.5, DARK, 4.0)
	draw_line(a - n * 1.5, b - n * 1.5, IRON, 2.0)
	draw_line(a - n * 0.5, b - n * 0.5, SHEEN, 1.0)
	# powered: a brass chain crawling along it
	if drive != 0.0:
		k = _chain if drive > 0 else 10.0 - _chain
		while k < l:
			draw_line(a + t * k - n * 4.0, a + t * minf(k + 4.0, l) - n * 4.0, CHAIN, 1.0)
			k += 10.0
	# a faint chevron every 48 px: the way it runs
	k = 24.0
	while k < l - 8:
		var p := a + t * k - n * 4.5
		draw_line(p - t * 2 + n * 1.5, p, SHEEN.darkened(0.3), 1.0)
		draw_line(p - t * 2 - n * 1.5, p, SHEEN.darkened(0.3), 1.0)
		k += 48.0
	# a stop at the start when it runs down from there; iron caps
	if _lip and end_offset.y >= -0.5:
		draw_line(a + Vector2(0, 1), a + Vector2(0, -LIP), DARK, 4.0)
		draw_line(a, a + Vector2(0, -LIP + 1), IRON, 2.0)
	for p in [a, b]:
		draw_rect(Rect2((p - n * 1.5).round() - Vector2(2, 2), Vector2(4, 4)), DARK)
		draw_rect(Rect2((p - n * 1.5).round() - Vector2(1, 1), Vector2(2, 2)), SHEEN)
	if _selected:
		draw_line(Vector2.ZERO, end_offset, Color(1.0, 0.7, 0.2, 0.35), 1.0)
		draw_circle(end_offset, 6.0, DARK)
		draw_circle(end_offset, 4.5, Color(1.0, 0.7, 0.2))


# ── aiming UI: click to select, drag the end handle ────────────────────

func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	if track != null:
		_net.set_track_path(track, _path())
	_rebuild()


func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	modulate = Color(1.2, 1.15, 1.05) if on else Color.WHITE
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _body == null:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			_set_selected(false)
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			_set_selected(false)
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local := to_local(mouse)
			if _selected and mouse.distance_to(to_global(end_offset)) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif Geometry2D.get_closest_point_to_segment(local, Vector2.ZERO, end_offset).distance_to(local) < 8:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		set_end(to_local(mouse).snapped(Vector2(2, 2)))
		get_viewport().set_input_as_handled()
