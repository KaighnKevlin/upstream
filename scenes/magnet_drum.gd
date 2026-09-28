extends Node2D
## Magnet drum: the magnetic head pulley of a real ore line. A turning drum
## that sits where a chute's stream leaves its end: iron things (iron, shot,
## springs, gears, scrap) passing over it cling to its face, ride round its
## underside and drop off behind it; copper and stone don't feel it and fly
## on. Two piles from one stream, by kind. Put the node where the stream
## leaves the chute; `side` is the way the stream is going.

const Magnet = preload("res://scenes/magnet.gd")
const SFX = preload("res://scripts/sfx.gd")
const R := 11.0                  # drum radius
const GRAB := 10.0               # reach beyond its face
const SPIN := 5.0                # rad/s: how fast it carries what clings

@export var side := 1.0

var pulled := 0                  # tests
var _riders := {}                # id -> [body, angle]
var _phase := 0.0
var _time := 0.0


func _ready() -> void:
	z_index = 2


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_phase += delta * SPIN * side
	_time += delta
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()):
			continue
		if not str(o.get("kind")) in Magnet.METAL or o.get_meta("drum_until", 0.0) > _time:
			continue
		var p: Vector2 = o.global_position - global_position
		if p.length() < R + GRAB + 6.5:
			_riders[o.get_instance_id()] = [o, p.angle()]
			o.gravity_scale = 0.0
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 1.3)
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		# carried round the face, over the front and under, the way it turns
		var a: float = r[1] + SPIN * side * delta
		r[1] = a
		var target := global_position + Vector2(cos(a), sin(a)) * (R + 6.5)
		o.linear_velocity = (target - o.global_position) / delta
		# let go once it's round underneath and heading back
		var under := Vector2(cos(a), sin(a))
		if under.y > 0.5 and under.x * side < -0.2:
			o.gravity_scale = 1.0
			o.linear_velocity = Vector2(-side * 40.0, 60.0)
			o.set_meta("drum_until", _time + 1.0)
			pulled += 1
			_riders.erase(id)
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	# bracket
	draw_line(Vector2.ZERO, Vector2(-side * 6, 22), Color(0.16, 0.13, 0.1), 3.0)
	draw_line(Vector2.ZERO, Vector2(side * 6, 22), Color(0.16, 0.13, 0.1), 3.0)
	# the drum, banded red and steel, turning
	draw_circle(Vector2.ZERO, R + 1, dark)
	draw_circle(Vector2.ZERO, R, Color(0.45, 0.47, 0.52))
	for k in 6:
		var a := _phase + k * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		draw_line(d * 3.0, d * R, Color(0.75, 0.2, 0.18) if k % 2 == 0 else Color(0.62, 0.64, 0.68), 3.0)
	draw_circle(Vector2.ZERO, 3.0, dark)
	draw_circle(Vector2.ZERO, 1.5, Color(0.85, 0.65, 0.35))
	# the field, faintly
	draw_arc(Vector2.ZERO, R + GRAB, 0, TAU, 24, Color(0.6, 0.75, 1.0, 0.15), 1.0)
