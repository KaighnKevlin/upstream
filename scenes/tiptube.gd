extends Node2D
## Tiptube: a short brass tube on a pivot, set at the end of a chute. A
## piece rolling in (heading toward `side`) runs down to the tube's far end,
## and once its weight is past the pivot the tube tips right over, swinging
## down and under, and pours it out of the far end one level down heading
## back the other way. Then a spring swings the empty tube back up for the
## next. Heavy pieces tip it quicker; while it's over, the next one waits in
## the mouth. The U-turn of a marble run, with a bit of theatre.
## The node is the tube's mouth (end the feeding chute just short of it,
## a touch below); the pour comes out under and behind it.

const SFX = preload("res://scripts/sfx.gd")
const PIVOT := 12.0              # from the mouth, toward `side`
const REACH := 36.0              # pivot to the far end
const BACK := 12.0               # pivot to the mouth end
const REST := 0.06               # rad, far end a little down: pieces roll in
const OVER := 2.3                # rad, tipped over: the far end down and back
const V_OUT := 150.0
const RETURN := 0.45             # s for the spring to bring it back

@export var side := 1.0          # the way pieces arrive (they leave the other way)

var tipped := 0                  # tests
var last_out := Vector2.ZERO     # tests: velocity of the last one poured
var _angle := REST
var _spin := 0.0                 # rad/s while tipping
var _state := 0                  # 0 idle, 1 rolling in, 2 tipping, 3 springing back
var _t := 0.0
var _rider: RigidBody2D = null
var _waiting: Array = []         # arrived while it was busy, held in the mouth
var _cool := {}
var _stand: Sprite2D
var _tube: Sprite2D


func _ready() -> void:
	z_index = 0                  # under the ore: the rider shows riding in it
	# sprites (ghosts too): the stand behind our _draw (the spring), the tube over it
	_stand = _sprite(preload("res://assets/sprites/tiptube_stand.png"), Vector2(-13, -3))
	_stand.show_behind_parent = true
	_tube = _sprite(preload("res://assets/sprites/tiptube_tube.png"), Vector2(-15, -10))
	_place_art()


func _sprite(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


## Drawn for side +1; mirrored for -1 (the tube's angle mirrors with it).
func _place_art() -> void:
	var s := 1.0 if side >= 0 else -1.0
	_stand.position = _pivot()
	_stand.scale = Vector2(s, 1)
	_tube.position = _pivot()
	_tube.scale = Vector2(s, 1)
	_tube.rotation = _angle * s


func _pivot() -> Vector2:
	return Vector2(side * PIVOT, 0)


func _dir(a: float) -> Vector2:
	# along the tube from the pivot to the far end, at tube angle a
	return Vector2(cos(a) * side, sin(a))


## Where the far end is when tipped over (for layouts and tests).
func out_point() -> Vector2:
	return _pivot() + _dir(OVER) * REACH


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or o == _rider or o in _waiting or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 9 and absf(p.y) < 10 and o.linear_velocity.x * side > 10:
			o.gravity_scale = 0.0
			_waiting.append(o)
	_waiting = _waiting.filter(func(o): return is_instance_valid(o))
	match _state:
		0:
			_angle = REST
			if not _waiting.is_empty():
				_rider = _waiting.pop_front()
				_state = 1
				_t = 0.0
		1:
			# rolling down the tube to the far end; the tube dips as it passes the pivot
			_t += delta
			var f := clampf(_t / 0.3, 0.0, 1.0)
			_angle = REST + 0.12 * f
			if f >= 1.0:
				_state = 2
				_spin = 0.0
		2:
			# over it goes: the heavier the piece, the harder it swings
			var m: float = _rider.mass if is_instance_valid(_rider) else 1.0
			_spin += 26.0 * m / (m + 0.8) * delta
			_angle += _spin * delta
			if _angle >= OVER:
				_angle = OVER
				_pour(now)
				_state = 3
				_t = 0.0
		3:
			_t += delta
			var f := clampf(_t / RETURN, 0.0, 1.0)
			# the spring: back past rest, a little bounce, settle
			var e := 1.0 - pow(1.0 - f, 3.0)
			_angle = lerpf(OVER, REST, e) - sin(f * PI * 2.0) * 0.12 * (1.0 - f)
			if f >= 1.0:
				_state = 0
				SFX.play_small(self, SFX.sfx_clink(), -20.0, 1.6)
	# riders: the one in the tube and any waiting in the mouth
	if _state in [1, 2] and not is_instance_valid(_rider):
		_state = 3
		_t = 0.0
	if is_instance_valid(_rider) and _state in [1, 2]:
		var d := REACH - 5.0 if _state == 2 else lerpf(-BACK + 3.0, REACH - 5.0, clampf(_t / 0.3, 0.0, 1.0))
		_hold(_rider, global_position + _pivot() + _dir(_angle) * d, delta)
	for k in _waiting.size():
		_hold(_waiting[k], global_position + Vector2(-side * (2 + k * 3), 0), delta)
	queue_redraw()


func _hold(o: RigidBody2D, at: Vector2, delta: float) -> void:
	o.linear_velocity = (at - o.global_position) / delta
	if "_timer" in o:
		o._timer = 0.0


func _pour(now: float) -> void:
	if not is_instance_valid(_rider):
		return
	_rider.gravity_scale = 1.0
	_rider.global_position = global_position + out_point()
	_rider.linear_velocity = _dir(OVER) * V_OUT
	last_out = _rider.linear_velocity
	_cool[_rider.get_instance_id()] = now + 1.0
	_rider = null
	tipped += 1
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 1.1)


func _draw() -> void:
	_place_art()
	var pv := _pivot()
	# the return spring from the stand's bracket to the tube's mouth end
	var mouth := pv - _dir(_angle) * BACK
	var anchor := pv + Vector2(-side * 8, 14)
	var pts := PackedVector2Array()
	for i in 9:
		var q := anchor.lerp(mouth, i / 8.0)
		var sn := (mouth - anchor).orthogonal().normalized()
		pts.append(q + sn * (2.5 if i % 2 else -2.5) * (0.0 if i == 0 or i == 8 else 1.0))
	draw_polyline(pts, Color(0.1, 0.08, 0.07), 2.0)
	draw_polyline(pts, Color(0.62, 0.64, 0.7), 1.0)
