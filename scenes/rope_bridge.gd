extends Node2D
## Rope bridge: planks on two ropes slung between posts (drag it, like a
## chute). Everything crosses it: walkers, you, rolling pieces. It sags and
## sways under what's on it. A trigger (tripwire, plate, bell, tally) or a
## click on the near post cuts it: the near end lets go and the bridge
## swings down against the far post, dropping whatever was on it into the
## gap. It knits itself back together CUT_FOR seconds later.

const SFX = preload("res://scripts/sfx.gd")
const LEN_MIN := 60.0
const LEN_MAX := 320.0
const SEG := 16.0
const CUT_FOR := 5.0
const SLACK := 1.01

@export var end_offset := Vector2(160, 0)

var cuts := 0                    # tests
var _p: PackedVector2Array = []  # rope points, local
var _q: PackedVector2Array = []  # last frame's (verlet)
var _planks: Array = []          # AnimatableBody2D per segment
var _cut := 0.0                  # seconds left hanging cut
var _knit := 1.0                 # 0..1 pulling back straight after a cut


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	_reset_points()
	queue_redraw()


func _n() -> int:
	return maxi(3, int(ceil(end_offset.length() / SEG)))


func _reset_points() -> void:
	_p.resize(_n() + 1)
	for i in _p.size():
		_p[i] = end_offset * (float(i) / _n())
	_q = _p.duplicate()


func _ready() -> void:
	z_index = 1
	_reset_points()
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var m := PhysicsMaterial.new()
	m.friction = 1.0
	m.bounce = 0.2
	m.absorbent = true
	for i in _n():
		var b := AnimatableBody2D.new()
		b.sync_to_physics = false
		b.collision_layer = 1 | 64
		b.collision_mask = 0
		b.physics_material_override = m
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(SEG + 1.0, 3.0)
		cs.shape = r
		cs.position = Vector2(0, 1.5)
		b.add_child(cs)
		add_child(b)
		_planks.append(b)
	_place_planks()


func trigger() -> void:
	if _cut > 0.0:
		return
	_cut = CUT_FOR
	cuts += 1
	for b in _planks:
		b.get_child(0).set_deferred("disabled", true)
	SFX.play_small(self, SFX.sfx_latch(), -6.0, 0.6)


## What's standing or rolling on a plank weighs it down.
func _loads() -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(_p.size())
	var things: Array = []
	for o in get_tree().get_nodes_in_group("ore"):
		things.append([o, 0.35])
	for e in get_tree().get_nodes_in_group("enemies"):
		things.append([e, 1.6])
	var pl := get_tree().current_scene.get_node_or_null("Player")
	if pl:
		things.append([pl, 1.2])
	var ext := end_offset.length() + 8.0
	for th in things:
		var n2 = th[0]
		if not is_instance_valid(n2):
			continue
		var at: Vector2 = to_local(n2.global_position)
		if at.x < -8 or at.x > ext or absf(at.y) > 40:
			continue
		for i in range(1, _p.size() - 1):
			var d: Vector2 = at - _p[i]
			if absf(d.x) < SEG * 0.6 and d.y < 2 and d.y > -26:
				w[i] += th[1]
	return w


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var n := _p.size()
	var rest := end_offset.length() / _n() * SLACK
	var w := _loads()
	var g := 600.0 * delta * delta
	for i in n:
		var cur := _p[i]
		var v := (cur - _q[i]) * 0.96
		_q[i] = cur
		_p[i] = cur + v + Vector2(0, g * (1.0 + w[i] * 3.0))
	var cut := _cut > 0.0
	if cut:
		_cut -= delta
		if _cut <= 0.0:
			_knit = 0.0
			SFX.play_small(self, SFX.sfx_ratchet(), -10.0, 0.8)
	for it in 8:
		if not cut:
			_p[0] = Vector2.ZERO
		_p[n - 1] = end_offset
		for i in n - 1:
			var d := _p[i + 1] - _p[i]
			var l := d.length()
			if l < 0.001:
				continue
			var k := (l - rest) / l * 0.5
			var pin_a := i == 0 and not cut
			var pin_b := i + 1 == n - 1
			if pin_a:
				_p[i + 1] -= d * k * 2.0
			elif pin_b:
				_p[i] += d * k * 2.0
			else:
				_p[i] += d * k
				_p[i + 1] -= d * k
	# after a cut: hauled back up to the near post, then solid again
	if not cut and _knit < 1.0:
		_knit = minf(1.0, _knit + delta * 1.2)
		for i in n:
			var straight := end_offset * (float(i) / (n - 1))
			_p[i] = _p[i].lerp(straight, _knit * 0.5)
			_q[i] = _p[i]
		if _knit >= 1.0:
			for b in _planks:
				b.get_child(0).set_deferred("disabled", false)
	_place_planks()
	queue_redraw()


func _place_planks() -> void:
	for i in _planks.size():
		var a := _p[i]
		var b := _p[i + 1]
		_planks[i].position = (a + b) * 0.5
		_planks[i].rotation = (b - a).angle()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -14)) < 10:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var wood := Color(0.55, 0.38, 0.22)
	var rope := Color(0.75, 0.65, 0.45)
	# the posts
	for p in [Vector2.ZERO, end_offset]:
		draw_line(p + Vector2(0, 6), p + Vector2(0, -20), dark, 5.0)
		draw_line(p + Vector2(0, 6), p + Vector2(0, -20), wood, 3.0)
		draw_circle(p + Vector2(0, -20), 2.5, rope)
	if _p.size() < 2:
		return
	# planks, then the hand ropes (post tops down to the deck and along)
	for i in _p.size() - 1:
		var a := _p[i]
		var b := _p[i + 1]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		var c := (a + b) * 0.5
		var pts := PackedVector2Array([c - d * 7 - nrm, c + d * 7 - nrm, c + d * 7 + nrm * 3, c - d * 7 + nrm * 3])
		draw_colored_polygon(pts, dark)
		draw_colored_polygon(PackedVector2Array([pts[0] + d * 0.5 + nrm * 0.5, pts[1] - d * 0.5 + nrm * 0.5, pts[2] - d * 0.5 - nrm * 0.5, pts[3] + d * 0.5 - nrm * 0.5]), wood.lerp(Color(0.7, 0.5, 0.3), float(i % 2) * 0.3))
	var hand := PackedVector2Array()
	for i in _p.size():
		hand.append(_p[i] + Vector2(0, -12))
	if _cut <= 0.0:
		hand[0] = Vector2(0, -20)
	hand[hand.size() - 1] = end_offset + Vector2(0, -20)
	draw_polyline(hand, rope, 1.0)
	draw_polyline(_p, rope, 1.0)
	for i in range(1, _p.size() - 1):
		draw_line(_p[i], hand[i], Color(rope, 0.6), 1.0)
