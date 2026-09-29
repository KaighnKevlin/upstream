extends Node2D
## Track source (TRIAL, track net): a hopper that sets a fresh marble on its
## little spout rail every beat (click: 0.25 / 0.5 / 1 s), copper and iron
## in turn, but only when the spout's first place is free. When the line it
## feeds backs up, the spout fills and it stops (its lamp goes red); as soon
## as the line moves it starts again. Lay a rail on from the spout's end.

const TrackNet = preload("res://scripts/track/track_net.gd")
const SFX = preload("res://scripts/sfx.gd")
const PERIODS := [0.25, 0.5, 1.0]
const SPOUT := Vector2(28, 7)

@export var mode := 1
@export var side := 1.0
@export var kinds: Array = ["copper", "iron"]
@export var limit := 0           # 0: for ever

var emitted := 0                 # tests
var blocked := false             # the spout is full: waiting on the line
var track = null
var _net: Node = null
var _t := 1
var _flash := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	_net = TrackNet.get_net(self)
	track = _net.add_track(self, PackedVector2Array([global_position, spout_end()]), false)
	_net.add_ticker(self)


func _exit_tree() -> void:
	if is_instance_valid(_net):
		_net.remove_ticker(self)
		if track != null:
			_net.remove_track(track)
	track = null


func spout_end() -> Vector2:
	return global_position + Vector2(SPOUT.x * side, SPOUT.y)


## The net's tick: a marble on the beat, if its place is free.
func track_tick(net: Node, _tick: int) -> void:
	if limit > 0 and emitted >= limit:
		return
	_t -= 1
	if _t > 0:
		return
	var kind: String = kinds[emitted % kinds.size()]
	var r: float = net.KR[net.KID[kind]]
	blocked = track.room_at_start(r, net.KR) < r
	if blocked:
		return                   # try again next tick
	net.add_rider(track, r, 30.0, kind)
	emitted += 1
	_t = int(round(PERIODS[mode] * 60.0))
	_flash = 1.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if track == null or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if Rect2(-12, -34, 24, 30).has_point(to_local(get_global_mouse_position())):
		mode = (mode + 1) % PERIODS.size()
		get_viewport().set_input_as_handled()


# ── look: a riveted hopper over a short spout rail, pips, a lamp ──────

const DARK := Color(0.07, 0.06, 0.08)
const IRON := Color(0.3, 0.29, 0.32)
const SHEEN := Color(0.55, 0.55, 0.6)
const WOOD := Color(0.36, 0.23, 0.13)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	var b := Vector2(SPOUT.x * side, SPOUT.y)
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
	# the hopper: a trapezoid over the spout's start
	var hop := PackedVector2Array([Vector2(-11, -34), Vector2(11, -34), Vector2(6, -8), Vector2(-6, -8)])
	draw_colored_polygon(hop, DARK)
	var inner := PackedVector2Array([Vector2(-9, -32), Vector2(9, -32), Vector2(5, -10), Vector2(-5, -10)])
	draw_colored_polygon(inner, IRON.lerp(Color(0.6, 0.55, 0.5), _flash * 0.6))
	draw_line(Vector2(-11, -34), Vector2(11, -34), SHEEN, 1.0)
	for i in PERIODS.size():
		draw_rect(Rect2(Vector2(-4 + i * 3, -28), Vector2(2, 2)), BRASS if i == mode else DARK)
	# the throat down onto the spout, and the lamp: red while the line is backed up
	draw_rect(Rect2(-3, -9, 6, 4), DARK)
	draw_circle(Vector2(0, -20), 2.5, DARK)
	draw_circle(Vector2(0, -20), 1.5, Color(1.0, 0.3, 0.2) if blocked else Color(0.4, 0.85, 0.35))
