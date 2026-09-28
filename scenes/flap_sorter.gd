extends Node2D
## Flap sorter: a sloped rail with spring-loaded flaps set into it. Each
## flap is held shut by a spring of its own stiffness (the number on it,
## click to change): a piece lighter than that rolls over it; a heavier one
## presses it down and drops through. Softer flaps downstream sort a mixed
## stream by weight: heaviest out first, the lightest roll off the end.
## Drawn from its high end (drag to set the low end, like a chute).
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const LEN_MIN := 80.0
const LEN_MAX := 260.0
const FLAP := 18.0               # the hole under a flap: a marble (13) falls through
const SPRINGS := [0.8, 1.2, 1.8, 2.5]
const RAIL_TEX := preload("res://assets/sprites/flap_rail.png")
const FLAP_TEX := preload("res://assets/sprites/flap_plate.png")
const STOP_TEX := preload("res://assets/sprites/flap_stop.png")

@export var end_offset := Vector2(160, 40)
@export var springs: Array = [2.5, 1.2]   # one per flap, upstream first

var dropped: Array[int] = []     # tests: per flap
var passed := 0                  # rolled off the end
var _body: StaticBody2D
var _flaps: Array = []           # [CollisionShape2D, Area2D, open_timer, angle]
var _end_area: Area2D
var _art: Node2D                 # the rail and flaps, pixel art (nearest, tiled)


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	if _body:
		_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
	# art first, so ghosts and build-bar icons have it; behind our own _draw
	# (springs, numbers)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true           # like a chute: landings stick, then roll
	m.bounce = 0.5
	m.friction = 1.0
	_body.physics_material_override = m
	add_child(_body)
	_rebuild()


## Where along the rail flap k sits (its centre), in px from the high end.
func _flap_at(k: int) -> float:
	var l := end_offset.length()
	return l * (k + 1.0) / (springs.size() + 1.0)


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	for f in _flaps:
		f[1].queue_free()
	_flaps.clear()
	if _end_area:
		_end_area.queue_free()
	var l := end_offset.length()
	var d := end_offset / l
	dropped.resize(springs.size())
	dropped.fill(0)
	# the rail, broken where the flaps are
	var cuts := [0.0]
	for k in springs.size():
		cuts.append(_flap_at(k) - FLAP * 0.5)
		cuts.append(_flap_at(k) + FLAP * 0.5)
	cuts.append(l)
	for i in range(0, cuts.size(), 2):
		_seg(d * cuts[i], d * cuts[i + 1])
	# a stop at the high end
	_seg(Vector2.ZERO, Vector2(0, -7))
	for k in springs.size():
		var c := _flap_at(k)
		var shape := _seg(d * (c - FLAP * 0.5), d * (c + FLAP * 0.5))
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := CircleShape2D.new()
		r.radius = FLAP * 0.5
		cs.shape = r
		cs.position = d * c + Vector2(d.y, -d.x) * 7.0 * (1.0 if d.x >= 0 else -1.0)
		a.add_child(cs)
		add_child(a)
		a.body_entered.connect(_weigh.bind(k))
		_flaps.append([shape, a, 0.0, 0.0])
	_end_area = Area2D.new()
	_end_area.collision_layer = 0
	_end_area.collision_mask = 2
	var ecs := CollisionShape2D.new()
	var er := CircleShape2D.new()
	er.radius = 8.0
	ecs.shape = er
	ecs.position = end_offset + Vector2(d.x, 0).normalized() * 10.0
	_end_area.add_child(ecs)
	add_child(_end_area)
	_end_area.body_entered.connect(func(b): if b is RigidBody2D: passed += 1)
	queue_redraw()


func _seg(a: Vector2, b: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	_body.add_child(cs)
	return cs


func _weigh(b, k: int) -> void:
	if not (b is RigidBody2D) or _flaps[k][2] > 0:
		return
	if b.mass <= springs[k]:
		return               # too light: the spring holds and it rolls over
	var f: Array = _flaps[k]
	f[0].set_deferred("disabled", true)
	f[2] = 0.4
	dropped[k] += 1
	# pressed down into the hole rather than skipping over it
	b.linear_velocity = Vector2(b.linear_velocity.x * 0.25, 90.0)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.7 + k * 0.2)


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var busy := false
	for f in _flaps:
		if f[2] > 0:
			f[2] -= delta
			f[3] = minf(1.0, f[3] + delta * 8.0)
			if f[2] <= 0:
				f[0].set_deferred("disabled", false)   # sprung shut again
			busy = true
		elif f[3] > 0:
			f[3] = maxf(0.0, f[3] - delta * 5.0)
			busy = true
	if busy:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or _body == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := to_local(get_global_mouse_position())
	var d := end_offset.normalized()
	for k in springs.size():
		if p.distance_to(d * _flap_at(k)) < 12:
			var i := SPRINGS.find(springs[k])
			springs[k] = SPRINGS[(i + 1) % SPRINGS.size()]
			queue_redraw()
			get_viewport().set_input_as_handled()
			return


func _draw() -> void:
	if _art:
		_art.queue_redraw()
	var l := end_offset.length()
	var d := end_offset / maxf(l, 1.0)
	var n := Vector2(d.y, -d.x) if d.x >= 0 else Vector2(-d.y, d.x)   # up, off the rail
	var font := ThemeDB.fallback_font
	for k in springs.size():
		var c := d * _flap_at(k)
		var open: float = _flaps[k][3] if k < _flaps.size() else 0.0
		# its spring, under the free end
		var s0 := c + d * FLAP * 0.3 - n * 3
		var s1 := s0 - n * (10 - open * 4)
		var zig := PackedVector2Array()
		for i in 7:
			zig.append(s0.lerp(s1, i / 6.0) + d * (2.5 if i % 2 == 1 else -2.5))
		draw_polyline(zig, Color(0.1, 0.08, 0.07), 2.0)
		draw_polyline(zig, Color(0.7, 0.72, 0.76), 1.0)
		draw_string(font, c + n * 10 - Vector2(6, 0), "%.1f" % springs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))


## The rail (a tiled strip, broken at the flaps), the stop and the flaps,
## each drawn along the rail; flipped on leftward rails so tops face up.
func _draw_art() -> void:
	var l := end_offset.length()
	var d := end_offset / maxf(l, 1.0)
	var flip := 1.0 if d.x >= 0 else -1.0
	var ang := d.angle()
	var cuts := [0.0]
	for k in springs.size():
		cuts.append(_flap_at(k) - FLAP * 0.5)
		cuts.append(_flap_at(k) + FLAP * 0.5)
	cuts.append(l)
	for i in range(0, cuts.size(), 2):
		_art.draw_set_transform(d * cuts[i], ang, Vector2(1, flip))
		_art.draw_texture_rect(RAIL_TEX, Rect2(0, -2, cuts[i + 1] - cuts[i], 8), true)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_art.draw_texture(STOP_TEX, Vector2(-3, -10))
	for k in springs.size():
		var hinge := d * (_flap_at(k) - FLAP * 0.5)
		var open: float = _flaps[k][3] if k < _flaps.size() else 0.0
		# hinged at its upstream edge, swinging down as it opens
		_art.draw_set_transform(hinge, ang + open * 1.2 * flip, Vector2(1, flip))
		_art.draw_texture(FLAP_TEX, Vector2(-3, -3))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
