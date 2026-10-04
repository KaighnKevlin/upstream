extends Node2D
## Track bin (TRIAL, track net): the backpressure demo. An iron bin whose
## mouth takes marbles off the end of a track rail laid over it (the rail's
## end snaps to the mouth). It holds CAP; full, it refuses the next one,
## which stops at the rail's end, and the queue backs up the line behind it,
## all the way to the source, which stops too. Click the bin to empty it:
## the line drains into it and the source starts again.
## Any piece can be a sink like this: can_accept(kind) and accept(kind, v).

const TrackNet = preload("res://scripts/track/track_net.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_KINDS: Dictionary = preload("res://scenes/ore.gd").KINDS
const CAP := 12
const W := 30.0
const H := 34.0

@export var cap := CAP          # how many it holds

var contents: Array = []         # kinds, in the order they came
var accepted := 0                # tests
var emptied := 0
var _net: Node = null
var _flash := 0.0
var _tex := {}


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	_net = TrackNet.get_net(self)
	_net.add_sink(self, global_position)


func _exit_tree() -> void:
	if is_instance_valid(_net):
		_net.remove_sink(self)


func can_accept(_kind: String) -> bool:
	return contents.size() < cap


func accept(kind: String, v: float) -> void:
	contents.append(kind)
	accepted += 1
	_flash = 1.0
	var k := clampf(inverse_lerp(0.0, 400.0, absf(v)), 0.0, 1.0)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), lerpf(-26.0, -14.0, k), lerpf(1.2, 0.95, k) + contents.size() * 0.01)
	queue_redraw()


func empty() -> void:
	emptied += contents.size()
	contents.clear()
	SFX.play_small(self, SFX.sfx_ore_knock("ground"), -14.0, 0.8)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if _net == null or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if Rect2(-W * 0.5 - 2, -2, W + 4, H + 4).has_point(to_local(Pointer.world(self))):
		empty()
		get_viewport().set_input_as_handled()


# ── look: an open iron bin, the marbles in it, a lamp that lights when full ──

const DARK := Color(0.07, 0.06, 0.08)
const IRON := Color(0.3, 0.29, 0.32)
const SHEEN := Color(0.55, 0.55, 0.6)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	var r := Rect2(-W * 0.5, 2, W, H - 2)
	draw_rect(r.grow(2), DARK)
	draw_rect(r, Color(0.12, 0.1, 0.12))
	# the marbles, three abreast from the bottom
	for i in mini(contents.size(), CAP):
		var spec: Dictionary = ORE_KINDS.get(contents[i], ORE_KINDS.copper)
		if not _tex.has(spec.tex):
			_tex[spec.tex] = load(spec.tex)
		var sz: float = spec.size
		var c := Vector2(-9 + (i % 3) * 9, H - 4.5 - (i / 3) * 7.5)
		draw_texture_rect_region(_tex[spec.tex], Rect2(c - Vector2(4.5, 4.5), Vector2(9, 9)), Rect2((i % int(spec.frames)) * sz, 0, sz, spec.get("h", sz)))
	# walls and rim over them
	draw_line(Vector2(-W * 0.5, 0), Vector2(-W * 0.5, H), IRON, 3.0)
	draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, H), IRON, 3.0)
	draw_line(Vector2(-W * 0.5 - 1, H + 1), Vector2(W * 0.5 + 1, H + 1), IRON, 3.0)
	draw_line(Vector2(-W * 0.5 - 3, 0), Vector2(-W * 0.5 + 3, 0), SHEEN.lerp(Color.WHITE, _flash * 0.5), 2.0)
	draw_line(Vector2(W * 0.5 - 3, 0), Vector2(W * 0.5 + 3, 0), SHEEN.lerp(Color.WHITE, _flash * 0.5), 2.0)
	# fill gauge down the right side, and the full lamp
	var f := minf(1.0, float(contents.size()) / cap)
	draw_rect(Rect2(W * 0.5 + 3, 2, 3, H - 2), DARK)
	draw_rect(Rect2(W * 0.5 + 3, 2 + (H - 2) * (1.0 - f), 3, (H - 2) * f), BRASS)
	var full := contents.size() >= cap
	draw_circle(Vector2(W * 0.5 + 4.5, -3), 2.5, DARK)
	draw_circle(Vector2(W * 0.5 + 4.5, -3), 1.5, Color(1.0, 0.3, 0.2) if full else Color(0.25, 0.1, 0.08))
