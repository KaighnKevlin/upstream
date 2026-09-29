extends Node2D
## Track splitter (TRIAL, track net): the flip-flop for the track. Set at
## the end of a track rail (it snaps there); two short branch rails lead
## down-left and down-right from it, and a brass rocker sends every other
## marble each way. If the way it wants is backed up it sends the marble the
## other way; with both backed up the marble waits on the feed rail, and the
## queue behind it waits too. Lay rails on from the two branch ends.

const TrackNet = preload("res://scripts/track/track_net.gd")
const SFX = preload("res://scripts/sfx.gd")
const BRANCH := Vector2(20, 12)  # each branch end (the left one mirrored)

var sent := [0, 0]               # tests: left, right
var side := 0                    # the way the next one goes: 0 left, 1 right
var tracks: Array = []           # left branch, right branch
var _net: Node = null
var _tilt := -1.0                # drawn rocker angle, eased toward the side
var _flash := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	_net = TrackNet.get_net(self)
	global_position = _net.snap_point(global_position, true, 12.0, self)
	for sx in [-1.0, 1.0]:
		var p := PackedVector2Array([global_position, global_position + Vector2(BRANCH.x * sx, BRANCH.y)])
		tracks.append(_net.add_track(self, p, false))


func _exit_tree() -> void:
	if is_instance_valid(_net):
		for tr in tracks:
			_net.remove_track(tr)
	tracks.clear()


## Junction router (the net asks): which branch for this marble.
func pick(_kind: String, free: Array) -> int:
	if free[side]:
		return side
	if free[1 - side]:
		return 1 - side
	return -1


func passed(i: int, _kind: String) -> void:
	sent[i] += 1
	side = 1 - i
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -24.0, 1.35)


## Branch ends, world space (tests lay rails on from here).
func branch_end(i: int) -> Vector2:
	return global_position + Vector2(BRANCH.x * (-1.0 if i == 0 else 1.0), BRANCH.y)


func _process(delta: float) -> void:
	var want := -1.0 if side == 0 else 1.0
	if absf(_tilt - want) > 0.01 or _flash > 0:
		_tilt = move_toward(_tilt, want, delta * 8.0)
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


# ── look: two short rails off a brass rocker on a post ────────────────

const DARK := Color(0.07, 0.06, 0.08)
const IRON := Color(0.24, 0.23, 0.26)
const SHEEN := Color(0.52, 0.52, 0.56)
const WOOD := Color(0.36, 0.23, 0.13)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	for sx in [-1.0, 1.0]:
		var b := Vector2(BRANCH.x * sx, BRANCH.y)
		var t := b.normalized()
		var n := Vector2(t.y, -t.x)
		if n.y > 0:
			n = -n
		var k := 4.0
		while k < b.length() - 1:
			draw_line(t * k - n * 2.0, t * k - n * 6.0, DARK, 3.0)
			draw_line(t * k - n * 2.5, t * k - n * 5.5, WOOD, 1.5)
			k += 7.0
		draw_line(-n * 1.5, b - n * 1.5, DARK, 4.0)
		draw_line(-n * 1.5, b - n * 1.5, IRON, 2.0)
		draw_line(-n * 0.5, b - n * 0.5, SHEEN, 1.0)
	# the post and the rocker, tipped toward the way the next one goes
	draw_rect(Rect2(-2, 2, 4, 14), DARK)
	draw_rect(Rect2(-1, 3, 2, 12), IRON)
	var arm := Vector2(10, 0).rotated(_tilt * 0.45)
	var col := BRASS.lerp(Color(1.0, 0.9, 0.6), _flash)
	draw_line(-arm + Vector2(0, -3), arm + Vector2(0, -3), DARK, 4.0)
	draw_line(-arm + Vector2(0, -3), arm + Vector2(0, -3), col, 2.0)
	draw_circle(Vector2(0, -3), 2.5, DARK)
	draw_circle(Vector2(0, -3), 1.5, col)
	# an arrow over the branch the next one takes
	var ax := 12.0 * (-1.0 if side == 0 else 1.0)
	draw_line(Vector2(ax * 0.4, -10), Vector2(ax, -10), col, 1.0)
	draw_line(Vector2(ax, -10), Vector2(ax - signf(ax) * 3, -12), col, 1.0)
	draw_line(Vector2(ax, -10), Vector2(ax - signf(ax) * 3, -8), col, 1.0)
