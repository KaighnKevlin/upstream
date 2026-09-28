extends Node2D
## Drawbridge: a hinged span across a gap in a track. Lowered, pieces roll
## over it onto the far bank and on; raised, the span stands up on its
## hinge at the far bank and pieces reaching the edge drop into the gap
## (put a chute, cup or bin under it). A trigger (tally wheel, plate, bell,
## tripwire) swings it the other way, and so does a click: routing by
## signal you can see from across the cavern. Chains from the gatehouse
## post on the far bank work it. The node is the near edge (end the feeding
## chute there); the span runs SPAN px toward `side`, then a short ramp
## leads off the far bank. Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const SPAN := 48.0
const DROP := 3.0                # the hinge sits a little below the near edge: pieces roll across
const RAMP := Vector2(14, 5)     # off the far bank, toward `side`
const TOWER := 40.0
const SPEED := 2.6               # rad/s it swings

@export var side := 1.0          # the way pieces cross
@export var raised := false

var crossed := 0                 # tests
var fell := 0
var toggles := 0
var _a := 0.0                    # 0 lowered .. 1 raised
var _span: SegmentShape2D
var _watch := {}                 # id -> body, on the approach, until it crosses or falls


static var _steel := _make_steel()


static func _make_steel() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.5
	m.absorbent = true
	m.friction = 1.0
	return m


func _ready() -> void:
	z_index = 1
	_a = 1.0 if raised else 0.0
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	body.physics_material_override = _steel
	var cs := CollisionShape2D.new()
	_span = SegmentShape2D.new()
	cs.shape = _span
	body.add_child(cs)
	var rc := CollisionShape2D.new()
	var ramp := SegmentShape2D.new()
	ramp.a = hinge()
	ramp.b = hinge() + Vector2(side * RAMP.x, RAMP.y)
	rc.shape = ramp
	rc.one_way_collision = true
	body.add_child(rc)
	add_child(body)
	_fit()


## The hinge, on the far bank.
func hinge() -> Vector2:
	return Vector2(side * SPAN, DROP)


## The span's free end at the current swing.
func tip() -> Vector2:
	var down := Vector2(-side * SPAN, -DROP).angle()
	var up := Vector2(side * 0.15, -1.0).angle()
	return hinge() + Vector2.from_angle(lerpf(down, up, _ease(_a))) * SPAN


func _ease(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)


func trigger() -> void:
	raised = not raised
	toggles += 1
	SFX.play_small(self, SFX.sfx_clink(), -12.0, 0.7)


func _fit() -> void:
	if _span:
		_span.a = hinge()
		_span.b = tip()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var goal := 1.0 if raised else 0.0
	if _a != goal:
		_a = move_toward(_a, goal, delta * SPEED / 1.45)
		_fit()
		if _a == goal:
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.6)
		queue_redraw()
	# the tally for tests: pieces on the approach, then over or down
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or _watch.has(o.get_instance_id()):
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x + side * 6) < 8 and p.y > -16 and p.y < 2 and o.linear_velocity.x * side > 5:
			_watch[o.get_instance_id()] = o
	for id in _watch.keys():
		var o = _watch[id]
		if not is_instance_valid(o):
			_watch.erase(id)
			continue
		var p: Vector2 = o.global_position - global_position
		if p.x * side > SPAN + 4 and p.y < 14:
			crossed += 1
			_watch.erase(id)
		elif p.y > 26:
			fell += 1
			_watch.erase(id)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_global_mouse_position() - global_position
	var near_span := Geometry2D.get_closest_point_to_segment(m, hinge(), tip()).distance_to(m) < 8
	var near_tower := absf(m.x - side * (SPAN + 4)) < 7 and m.y > -TOWER and m.y < 16
	if near_span or near_tower:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var wood := Color(0.55, 0.4, 0.22)
	var h := hinge()
	var tp := tip()
	var post := Vector2(side * (SPAN + 5), 0)
	var top := post + Vector2(0, -TOWER)
	# the near bank's abutment and the far bank's gatehouse post
	draw_line(Vector2(0, 2), Vector2(0, 16), dark, 5.0)
	draw_line(Vector2(0, 3), Vector2(0, 15), steel.darkened(0.2), 3.0)
	draw_line(post + Vector2(0, 16), top, dark, 6.0)
	draw_line(post + Vector2(0, 15), top + Vector2(0, 1), wood, 4.0)
	draw_line(top + Vector2(-6, 0), top + Vector2(6, 0), dark, 4.0)
	draw_line(top + Vector2(-5, -0.5), top + Vector2(5, -0.5), brass, 2.0)
	# the ramp off the far bank
	var r := h + Vector2(side * RAMP.x, RAMP.y)
	draw_line(h + Vector2(0, 2), r + Vector2(0, 2), dark, 5.0)
	draw_line(h + Vector2(0, 1.5), r + Vector2(0, 1.5), steel, 2.0)
	# the span: planks on a steel frame, a cross-plank every few px
	var d := (tp - h).normalized()
	var under := Vector2(d.y, -d.x) * side   # the span's underside, down when lowered
	draw_line(h + under * 2.5, tp + under * 2.5, dark, 7.0)
	draw_line(h + under * 2.5, tp + under * 2.5, wood, 4.0)
	var k := 6.0
	while k < SPAN - 2:
		var q := h + d * k + under * 2.5
		draw_line(q - under * 2, q + under * 2, wood.darkened(0.35), 1.0)
		k += 7.0
	draw_line(h + under * 0.5, tp + under * 0.5, steel.lightened(0.2), 1.0)
	# the chains, from the top of the post to the span's free end
	var chain := PackedVector2Array()
	var sag := 6.0 * (1.0 - _ease(_a))
	for i in 11:
		var f := i / 10.0
		chain.append(top.lerp(tp, f) + Vector2(0, sin(f * PI) * sag * 0.3))
	draw_polyline(chain, dark, 2.5)
	draw_polyline(chain, Color(0.62, 0.64, 0.7), 1.0)
	draw_circle(h, 3.5, dark)
	draw_circle(h, 2.0, brass)
	draw_circle(tp, 2.0, brass)
	# a signal flag on the post: green lowered, red raised
	var flag := Color(0.3, 0.75, 0.35).lerp(Color(0.85, 0.2, 0.15), _ease(_a))
	var fp := top + Vector2(0, 3)
	draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(-side * 9, 3), fp + Vector2(0, 6)]), flag)
