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
var _art: Node2D                 # the rungs, pixel art tiled along the rail
const RAIL_TEX := preload("res://assets/sprites/sieve_rail.png")


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	if _body:
		_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
	# art first, so ghosts and build-bar icons have it
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
	_art.queue_redraw()          # the rail is all sprite now


## The rail tile (a rung and a gap, RUNG + GAP long) repeated from the high
## end, turned to the slope, its back rail kept on top of the rungs' side.
func _draw_art() -> void:
	var l := end_offset.length()
	var d := end_offset / maxf(l, 1.0)
	var flip := 1.0 if d.x >= 0 else -1.0
	_art.draw_set_transform(Vector2.ZERO, d.angle(), Vector2(1, flip))
	_art.draw_texture_rect(RAIL_TEX, Rect2(0, -7, l, 10), true)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
