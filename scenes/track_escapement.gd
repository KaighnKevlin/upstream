extends Node2D
## Track escapement (TRIAL, track net): the pacer for the track. A short
## gate rail with a pallet pin at its far end: the pin holds the queue and
## lets exactly one marble off each beat, however many are pushing behind
## (a beat nobody uses isn't saved up beyond the one). Set it on the end of
## a rail (it snaps there) and lay the next rail from its end.
## Click it to cycle 0.6 / 1.2 / 2.4 s a beat. Throughput limiter.

const TrackNet = preload("res://scripts/track/track_net.gd")
const SFX = preload("res://scripts/sfx.gd")
const PERIODS := [0.6, 1.2, 2.4]
const LEN := 24.0

@export var mode := 1
@export var side := 1.0          # which way it runs

var released := 0                # tests
var track = null
var _net: Node = null
var _beat := 0                   # ticks to the next beat
var _swing := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	_net = TrackNet.get_net(self)
	global_position = _net.snap_point(global_position, true, 12.0, self)
	track = _net.add_track(self, PackedVector2Array([global_position, global_position + _end()]), false)
	track.gate = 0
	track.notify = true
	_net.add_ticker(self)


func _exit_tree() -> void:
	if is_instance_valid(_net):
		_net.remove_ticker(self)
		if track != null:
			_net.remove_track(track)
	track = null


func _end() -> Vector2:
	return Vector2(LEN * side, 4)


## The net's tick: on the beat the pin lifts for one.
func track_tick(_net_: Node, _tick: int) -> void:
	_beat -= 1
	if _beat <= 0:
		_beat = int(round(PERIODS[mode] * 60.0))
		if track.gate == 0:
			track.gate = 1


func rider_passed(_tr, _kind: String) -> void:
	released += 1
	_swing = 1.0
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -22.0, 1.5)


func end_point() -> Vector2:
	return global_position + _end()


func _process(delta: float) -> void:
	if _swing > 0 or (track != null and track.gate != 0):
		_swing = maxf(0.0, _swing - delta * 5.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if track == null or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	var m := to_local(Pointer.world(self))
	if Rect2(minf(0, _end().x) - 4, -26, LEN + 8, 34).has_point(m):
		mode = (mode + 1) % PERIODS.size()
		_beat = mini(_beat, int(round(PERIODS[mode] * 60.0)))
		queue_redraw()
		get_viewport().set_input_as_handled()


# ── look: a gate rail, a pin at its end, a clockwork box with beat pips ──

const DARK := Color(0.07, 0.06, 0.08)
const IRON := Color(0.24, 0.23, 0.26)
const SHEEN := Color(0.52, 0.52, 0.56)
const WOOD := Color(0.36, 0.23, 0.13)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	var b := _end()
	var t := b.normalized()
	var n := Vector2(t.y, -t.x)
	if n.y > 0:
		n = -n
	var k := 4.0
	while k < LEN - 1:
		draw_line(t * k - n * 2.0, t * k - n * 6.0, DARK, 3.0)
		draw_line(t * k - n * 2.5, t * k - n * 5.5, WOOD, 1.5)
		k += 7.0
	draw_line(-n * 1.5, b - n * 1.5, DARK, 4.0)
	draw_line(-n * 1.5, b - n * 1.5, IRON, 2.0)
	draw_line(-n * 0.5, b - n * 0.5, SHEEN, 1.0)
	# the clockwork box above the middle, a fork down to the pin
	var mid := b * 0.5 + Vector2(0, -18)
	draw_rect(Rect2(mid - Vector2(7, 6), Vector2(14, 10)), DARK)
	draw_rect(Rect2(mid - Vector2(6, 5), Vector2(12, 8)), IRON)
	for i in PERIODS.size():
		draw_rect(Rect2(mid + Vector2(-4 + i * 3, -1), Vector2(2, 2)), BRASS if i == mode else DARK)
	var shut: bool = track == null or track.gate == 0
	var lift := 0.0 if shut else 8.0
	lift = maxf(lift, _swing * 8.0)
	var pin := b + t * 6.0 + Vector2(0, -lift)
	draw_line(mid + Vector2(0, 4), pin + Vector2(0, -10), DARK, 3.0)
	draw_line(mid + Vector2(0, 4), pin + Vector2(0, -10), BRASS, 1.0)
	draw_line(pin + Vector2(0, -10), pin, DARK, 4.0)
	draw_line(pin + Vector2(0, -9), pin + Vector2(0, -1), BRASS, 2.0)
