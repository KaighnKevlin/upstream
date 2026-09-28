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
const TROUGH_TEX := preload("res://assets/sprites/flume_trough.png")

@export var end_offset := Vector2(160, 0)

var floated := 0                 # tests: went over the weir afloat
var flushed := 0                 # and sinkers let out by a flush
var _body: StaticBody2D
var _weir: CollisionShape2D
var _wet := {}                   # ore in the water
var _flush := 0.0
var _t := 0.0
var _art: Node2D                 # art: the trough floor and trestles, tiled along the run
var _wall: Sprite2D              # the head wall and the weir (over the water)
var _weir_art: Sprite2D


func set_end(offset: Vector2) -> void:
	var l := clampf(absf(offset.x), LEN_MIN, LEN_MAX)
	end_offset = Vector2(l * (1.0 if offset.x >= 0 else -1.0), 0)
	queue_redraw()
	_pose()


func _ready() -> void:
	z_index = 1
	end_offset.y = 0.0
	# the art first, so ghosts and build-bar icons have it: the floor behind
	# our own _draw (the water), the wall and weir over it
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	_wall = _spr(preload("res://assets/sprites/flume_wall.png"), Vector2(-4, -20))
	_weir_art = _spr(preload("res://assets/sprites/flume_weir.png"), Vector2(-4, -12))
	_weir_art.hframes = 2
	_pose()
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


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


# the art follows the run's length and direction (and set_end while dragging)
func _pose() -> void:
	if _art == null:
		return
	var side := 1.0 if end_offset.x >= 0 else -1.0
	_wall.scale = Vector2(side, 1)
	_weir_art.scale = Vector2(side, 1)
	_weir_art.position = Vector2(end_offset.x, 0)
	_art.queue_redraw()


func _draw_art() -> void:
	var w := absf(end_offset.x)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 if end_offset.x >= 0 else -1.0, 1))
	_art.draw_texture_rect(TROUGH_TEX, Rect2(0, -2, w, 18), true)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	# the water, rippling, with the current's streaks running along (the
	# trough, wall and weir are sprites; the weir shows lowered while it flushes)
	if _weir_art:
		_weir_art.frame = 1 if _flush > 0.0 else 0
	var l := end_offset.x
	var side := signf(l)
	var x0 := minf(0.0, l)
	var w := absf(l)
	draw_rect(Rect2(x0, -D - 1, w, D + 1), Color(0.25, 0.5, 0.8, 0.42))
	draw_rect(Rect2(x0, -4, w, 4), Color(0.12, 0.28, 0.5, 0.35))
	var pts := PackedVector2Array()
	var lip := PackedVector2Array()
	for i in int(w / 4.0) + 1:
		var x := x0 + i * 4.0
		var y := -D - 1 + sin(_t * 4.0 - x * 0.15 * side) * 0.8
		pts.append(Vector2(x, y))
		lip.append(Vector2(x, y + 1.0))
	draw_polyline(lip, Color(0.45, 0.7, 0.95, 0.4), 1.0)
	draw_polyline(pts, Color(0.8, 0.92, 1.0, 0.8), 1.0)
	for i in 5:
		var f := fposmod(_t * CUR * 0.5 + i * w / 5.0, w)
		var x := (x0 + f) if side > 0 else (x0 + w - f)
		var y := -D * 0.5 + (i % 3 - 1) * 2.0
		draw_line(Vector2(x, y), Vector2(x - side * 6, y), Color(0.8, 0.9, 1.0, 0.35), 1.0)
