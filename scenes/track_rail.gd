extends "res://scenes/chute.gd"
## Track rail: the trial's rail, now a thin variant of the chute (which is
## itself track since the migration: scenes/chute.gd). What it keeps of its
## own: a dark iron rail on wooden sleepers; it runs from where it was
## placed to its end, uphill too (the stop at its start comes and goes by
## itself: there when it runs down from there and nothing feeds it); its
## ends snap onto another track's end / start or a track bin's mouth when
## laid; `drive` > 0 makes it powered (riders held to that speed: a lift).

## Powered: riders are driven along it at this speed (px/s). 0: gravity.
@export var drive := 0.0

var _lip := true                 # a stop at the start (the net says: nothing feeds it, runs down)
var _chain := 0.0


func _ready() -> void:
	if not has_meta("ghost"):
		var net: Node = TrackNet.get_net(self)
		if net != null:
			# laid by hand: snap the start onto a track end, the end onto a start or bin
			var start: Vector2 = net.snap_point(global_position, true, 12.0, self)
			var end_at: Vector2 = net.snap_point(global_position + end_offset, false, 12.0, self)
			global_position = start
			end_offset = end_at - start
	super._ready()


func _track_path() -> PackedVector2Array:
	return PackedVector2Array([global_position, global_position + end_offset])


func _track_ready() -> void:
	track.lip_mode = -1
	track.drive = drive


## Physics ore that isn't caught (a bomb, say) still lands and rolls on it,
## one-way from above like a chute; the stop is at its start.
func _rebuild() -> void:
	queue_redraw()
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
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


func _process(delta: float) -> void:
	if track != null and track.lip != _lip:
		_lip = track.lip
		_rebuild()
	if drive != 0.0 and not has_meta("ghost"):
		_chain = fmod(_chain + drive * delta, 10.0)
		queue_redraw()


# ── look: a dark iron rail on wooden sleepers ──────────────────────────

const R_DARK := Color(0.07, 0.06, 0.08)
const R_IRON := Color(0.24, 0.23, 0.26)
const R_SHEEN := Color(0.52, 0.52, 0.56)
const R_WOOD := Color(0.36, 0.23, 0.13)
const R_WOOD_TOP := Color(0.5, 0.34, 0.2)
const R_CHAIN := Color(0.85, 0.62, 0.28)


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
		draw_line(p - n * 2.0, p - n * 7.0, R_DARK, 4.0)
		draw_line(p - n * 2.5, p - n * 6.5, R_WOOD, 2.0)
		draw_line(p - n * 2.5, p - n * 3.5, R_WOOD_TOP, 2.0)
		k += 8.0
	# the rail: a dark iron bar with a dull sheen on the running edge
	draw_line(a - n * 1.5, b - n * 1.5, R_DARK, 4.0)
	draw_line(a - n * 1.5, b - n * 1.5, R_IRON, 2.0)
	draw_line(a - n * 0.5, b - n * 0.5, R_SHEEN, 1.0)
	# powered: a brass chain crawling along it
	if drive != 0.0:
		k = _chain if drive > 0 else 10.0 - _chain
		while k < l:
			draw_line(a + t * k - n * 4.0, a + t * minf(k + 4.0, l) - n * 4.0, R_CHAIN, 1.0)
			k += 10.0
	# a faint chevron every 48 px: the way it runs
	k = 24.0
	while k < l - 8:
		var p := a + t * k - n * 4.5
		draw_line(p - t * 2 + n * 1.5, p, R_SHEEN.darkened(0.3), 1.0)
		draw_line(p - t * 2 - n * 1.5, p, R_SHEEN.darkened(0.3), 1.0)
		k += 48.0
	# a stop at the start when it runs down from there; iron caps
	if _lip and end_offset.y >= -0.5:
		draw_line(a + Vector2(0, 1), a + Vector2(0, -LIP), R_DARK, 4.0)
		draw_line(a, a + Vector2(0, -LIP + 1), R_IRON, 2.0)
	for p in [a, b]:
		draw_rect(Rect2((p - n * 1.5).round() - Vector2(2, 2), Vector2(4, 4)), R_DARK)
		draw_rect(Rect2((p - n * 1.5).round() - Vector2(1, 1), Vector2(2, 2)), R_SHEEN)
	if _selected:
		draw_line(Vector2.ZERO, end_offset, Color(1.0, 0.7, 0.2, 0.35), 1.0)
		draw_circle(end_offset, 6.0, R_DARK)
		draw_circle(end_offset, 4.5, Color(1.0, 0.7, 0.2))


