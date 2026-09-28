extends Node2D
## Flume: a level wooden trough of running water with a low weir at its far
## end (drag it: the water runs the way you drag). Light pieces dropped in
## (copper, grit) float and are carried along on the current, over the weir
## and out. Heavy ones (iron, shot, gears, scrap) sink, creep along the
## bottom and pile up against the weir, until a trigger or a click on the
## weir drops it for a moment and flushes them out. A conveyor, a sorter and
## an iron store at once. Ore-only: walkers aren't touched.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const LEN_MIN := 60.0
const LEN_MAX := 320.0
const D := 12.0                  # water depth
const WALL := 18.0               # the trough's back wall
const WEIR := 5.0
const CUR := 110.0               # px/s the current carries a floater
const CREEP := 30.0              # a sinker along the bottom
const HEAVY := ["iron", "shot", "gear", "scrap"]
const FLUSH := 1.4

@export var end_offset := Vector2(160, 0)

var floated := 0                 # tests: went over the weir afloat
var flushed := 0                 # and sinkers let out by a flush
var _body: StaticBody2D
var _weir: CollisionShape2D
var _wet := {}                   # ore in the water
var _flush := 0.0
var _t := 0.0


func set_end(offset: Vector2) -> void:
	var l := clampf(absf(offset.x), LEN_MIN, LEN_MAX)
	end_offset = Vector2(l * (1.0 if offset.x >= 0 else -1.0), 0)
	queue_redraw()


func _ready() -> void:
	z_index = 1
	end_offset.y = 0.0
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.friction = 0.2
	m.bounce = 0.0
	m.absorbent = true
	_body.physics_material_override = m
	add_child(_body)
	var l := end_offset.x
	_seg(Vector2(0, 0), Vector2(l, 0))
	_seg(Vector2(0, 0), Vector2(0, -WALL))
	_weir = _seg(Vector2(l, 0), Vector2(l, -WEIR))


func _seg(a: Vector2, b: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	_body.add_child(cs)
	return cs


func trigger() -> void:
	if _flush > 0.0:
		return
	_flush = FLUSH
	_weir.set_deferred("disabled", true)
	SFX.play_small(self, SFX.sfx_latch(), -8.0, 0.7)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t += delta
	if _flush > 0.0:
		_flush -= delta
		if _flush <= 0.0:
			_weir.set_deferred("disabled", false)
	var side := signf(end_offset.x)
	var l := absf(end_offset.x)
	var k := 1.0 - exp(-6.0 * delta)
	var now_wet := {}
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.has_meta("store_material"):
			continue
		var p: Vector2 = to_local(o.global_position)
		var along := p.x * side
		if along < 0 or along > l + 2 or p.y > 2 or p.y < -D - 8:
			continue
		now_wet[o] = true
		var r: float = o.KINDS[o.kind].radius
		var heavy: bool = o.kind in HEAVY
		var v: Vector2 = o.linear_velocity
		if heavy:
			o.gravity_scale = 0.4
			var run := CUR * 1.5 if _flush > 0.0 else CREEP
			v.x = lerpf(v.x, side * run, k)
			v.y = minf(v.y, 80.0)
		else:
			o.gravity_scale = 0.0
			v.x = lerpf(v.x, side * CUR, k)
			v.y = lerpf(v.y, clampf((-D - p.y) * 6.0, -120, 120), k)
			v.y += sin(_t * 5.0 + along * 0.2) * 3.0
		o.linear_velocity = v
		o.angular_velocity = lerpf(o.angular_velocity, side * v.x / r * 0.3, k)
		if "_timer" in o:
			o._timer = 0.0
	# out of the water: back to their own weight (and counted out the far end)
	for o in _wet.keys():
		if not now_wet.has(o) and is_instance_valid(o):
			o.gravity_scale = 1.0
			if (to_local(o.global_position).x * side) > l:
				if o.kind in HEAVY:
					flushed += 1
				else:
					floated += 1
	_wet = now_wet
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + end_offset + Vector2(0, -6)) < 10:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var wood := Color(0.5, 0.34, 0.2)
	var l := end_offset.x
	var side := signf(l)
	var x0 := minf(0.0, l)
	var w := absf(l)
	# the water, rippling, with the current's streaks running along
	draw_rect(Rect2(x0, -D - 1, w, D + 1), Color(0.25, 0.5, 0.8, 0.45))
	var pts := PackedVector2Array()
	for i in int(w / 4.0) + 1:
		var x := x0 + i * 4.0
		pts.append(Vector2(x, -D - 1 + sin(_t * 4.0 - x * 0.15 * side) * 0.8))
	draw_polyline(pts, Color(0.7, 0.85, 1.0, 0.7), 1.0)
	for i in 5:
		var f := fposmod(_t * CUR * 0.5 + i * w / 5.0, w)
		var x := (x0 + f) if side > 0 else (x0 + w - f)
		draw_line(Vector2(x, -D * 0.5), Vector2(x - side * 6, -D * 0.5), Color(0.8, 0.9, 1.0, 0.35), 1.0)
	# the trough: floor, back wall, weir (down while it flushes)
	draw_line(Vector2(x0 - 2, 1), Vector2(x0 + w + 2, 1), dark, 4.0)
	draw_line(Vector2(x0 - 2, 1), Vector2(x0 + w + 2, 1), wood, 2.0)
	draw_line(Vector2(0, 2), Vector2(0, -WALL), dark, 4.0)
	draw_line(Vector2(0, 2), Vector2(0, -WALL), wood, 2.0)
	var weir_h := 1.0 if _flush > 0.0 else WEIR
	draw_line(Vector2(l, 2), Vector2(l, -weir_h), dark, 4.0)
	draw_line(Vector2(l, 2), Vector2(l, -weir_h), Color(0.62, 0.64, 0.7), 2.0)
	draw_circle(Vector2(l, -8), 2.0, Color(0.85, 0.65, 0.35))
	# trestle legs
	var x := x0 + 10.0
	while x < x0 + w:
		draw_line(Vector2(x, 2), Vector2(x - 4, 14), dark, 3.0)
		draw_line(Vector2(x, 2), Vector2(x + 4, 14), dark, 3.0)
		draw_line(Vector2(x, 2), Vector2(x - 4, 14), wood, 1.0)
		draw_line(Vector2(x, 2), Vector2(x + 4, 14), wood, 1.0)
		x += 48.0
