extends Node2D
## Vortex funnel: the coin funnel of real marble machines, seen from the
## side. A marble rolling in over the rim is carried round and round the
## bowl, the circle tightening and the marble speeding up as it spirals in
## (angular momentum kept), until it drops out of the spout at the bottom.
## A show, and a delay: a burst in comes out one at a time, seconds later.
## The node is the rim's centre; the spout is DEPTH below.

const SFX = preload("res://scripts/sfx.gd")
const R := 56.0                  # rim radius
const DEPTH := 64.0              # rim to spout
const TILT := 0.28               # how much of the circle's depth shows (perspective)
const SHRINK := 11.0             # px/s the orbit tightens
const V_MIN := 90.0
const V_MAX := 520.0
const SPOUT := 7.0

var swirled := 0                 # tests: marbles that went through
var _riders := {}                # id -> [body, theta, r, v]
var _t := 0.0


func _ready() -> void:
	z_index = 2


func _pos(theta: float, r: float) -> Vector2:
	var sink := DEPTH * (1.0 - r / R)
	return Vector2(cos(theta) * r, sink + sin(theta) * r * TILT)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t += delta
	# catch marbles coming in over the rim
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or _riders.has(o.get_instance_id()) or o.has_meta("in_beam"):
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < R and p.y > -8 and p.y < 10 and o.get_meta("vortex_until", 0.0) < _t:
			var theta := acos(clampf(p.x / R, -1.0, 1.0))
			var v := maxf(V_MIN, absf(o.linear_velocity.x) + 40.0)
			_riders[o.get_instance_id()] = [o, theta, R, v]
			o.gravity_scale = 0.0
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 0.9)
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		var rad: float = r[2] - SHRINK * delta
		if rad < SPOUT:
			o.gravity_scale = 1.0
			o.linear_velocity = Vector2(0, 160)
			o.global_position = global_position + Vector2(0, DEPTH + 6)
			o.set_meta("vortex_until", _t + 1.0)
			swirled += 1
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 1.4)
			_riders.erase(id)
			continue
		# angular momentum: v * r stays put, so it quickens as it tightens
		var v: float = minf(V_MAX, r[3] * r[2] / rad)
		var theta: float = r[1] + v / rad * delta
		r[1] = theta
		r[2] = rad
		r[3] = v
		var target := global_position + _pos(theta, rad)
		o.linear_velocity = (target - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var bowl := Color(0.32, 0.26, 0.2, 0.85)
	# the bowl's side: from the rim down to the spout
	var pts := PackedVector2Array([Vector2(-R, 0), Vector2(-SPOUT, DEPTH), Vector2(SPOUT, DEPTH), Vector2(R, 0)])
	for k in range(8, 0, -1):
		var rr := R * k / 8.0
		var y := DEPTH * (1.0 - rr / R)
		pts.append(Vector2(rr, y))
	draw_colored_polygon(PackedVector2Array([Vector2(-R, 0), Vector2(-SPOUT, DEPTH), Vector2(SPOUT, DEPTH), Vector2(R, 0)]), bowl)
	# the swirl lines (a spiral, turning)
	var prev := _pos(_t * 2.0, R)
	var th := _t * 2.0
	var rr2 := R
	while rr2 > SPOUT:
		th += 0.35
		rr2 -= 2.2
		var p := _pos(th, rr2)
		draw_line(prev, p, Color(0.6, 0.48, 0.3, 0.35), 1.0)
		prev = p
	# rim (an ellipse) and spout
	var rim := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		rim.append(Vector2(cos(a) * R, sin(a) * R * TILT))
	draw_polyline(rim, dark, 4.0)
	draw_polyline(rim, brass, 2.0)
	draw_line(Vector2(-R, 0), Vector2(-SPOUT, DEPTH), dark, 3.0)
	draw_line(Vector2(R, 0), Vector2(SPOUT, DEPTH), dark, 3.0)
	draw_rect(Rect2(-SPOUT - 1, DEPTH, SPOUT * 2 + 2, 8), dark)
	draw_rect(Rect2(-SPOUT, DEPTH, SPOUT * 2, 7), brass)
	# a stand
	draw_line(Vector2(-R * 0.6, DEPTH * 0.45), Vector2(-R * 0.75, DEPTH + 30), Color(0.16, 0.13, 0.1), 2.0)
	draw_line(Vector2(R * 0.6, DEPTH * 0.45), Vector2(R * 0.75, DEPTH + 30), Color(0.16, 0.13, 0.1), 2.0)
