extends Node2D
## Sieve rail: a sloped rail of steel rungs with gaps between them, drawn
## like a chute (drag from its high end to its low end). Big pieces (ore,
## scrap, shot, ingots) roll along the rungs; grit drops through the gaps,
## so it sorts by size as they go. Give it a good slope.
## Ore-only layer: walkers pass through.

const ORE_ONLY := 64
const LEN_MIN := 32.0
const LEN_MAX := 260.0
const RUNG := 12.0
const GAP := 6.0                 # grit (r 2.6) falls through; shot, ore, scrap roll over

@export var end_offset := Vector2(120, 30)

var _body: StaticBody2D


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	if _body:
		_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	add_child(_body)
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var l := end_offset.length()
	var d := end_offset / l
	var x := 0.0
	while x < l:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = d * x
		s.b = d * minf(l, x + RUNG)
		cs.shape = s
		_body.add_child(cs)
		x += RUNG + GAP
	queue_redraw()


func _draw() -> void:
	var l := end_offset.length()
	var d := end_offset / maxf(l, 1.0)
	var n := d.orthogonal()
	# side rails, then the rungs
	draw_line(n * 3, end_offset + n * 3, Color(0.1, 0.08, 0.07), 2.0)
	draw_line(n * 3, end_offset + n * 3, Color(0.6, 0.62, 0.66), 1.0)
	var x := 0.0
	while x < l:
		var a := d * x
		var b := d * minf(l, x + RUNG)
		draw_line(a, b, Color(0.1, 0.08, 0.07), 3.0)
		draw_line(a, b, Color(0.72, 0.74, 0.78), 1.0)
		x += RUNG + GAP
