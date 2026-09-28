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
	# sprites (ghosts too): the stand and the bowl (a little translucent, so
	# the marbles circling in it show) behind our _draw (the swirl), the rim
	# and spout over it
	_sprite(preload("res://assets/sprites/vortex_stand.png")).show_behind_parent = true
	var bowl := _sprite(preload("res://assets/sprites/vortex_bowl.png"))
	bowl.show_behind_parent = true
	bowl.self_modulate = Color(1, 1, 1, 0.85)
	_sprite(preload("res://assets/sprites/vortex_rim.png"))


func _sprite(tex: Texture2D) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = Vector2(-62, -20)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


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
	# the swirl lines (a spiral, turning) over the bowl
	var prev := _pos(_t * 2.0, R)
	var th := _t * 2.0
	var rr2 := R
	while rr2 > SPOUT:
		th += 0.35
		rr2 -= 2.2
		var p := _pos(th, rr2)
		draw_line(prev, p, Color(0.6, 0.48, 0.3, 0.35), 1.0)
		prev = p
