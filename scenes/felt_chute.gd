extends "res://scenes/chute.gd"
## Felt chute: a chute lined with green baize. Marbles landing on it and
## rolling along it make no clatter (the noise meter doesn't hear them), but
## the felt drags at them, so a felt run is quiet and slow where steel is
## loud and quick.

const DRAG := 1.1                # per second, while on the felt
const FELT := Color(0.2, 0.45, 0.28)
const FELT_HI := Color(0.32, 0.6, 0.38)
const RAIL_TEX := preload("res://assets/sprites/felt_chute.png")
const CAP_TEX := preload("res://assets/sprites/felt_cap.png")
const STOP_TEX := preload("res://assets/sprites/flap_stop.png")

var _felt: Area2D
var _art: Node2D                 # the baize-lined trough, pixel art tiled along the rail


func _ready() -> void:
	# art first, so ghosts and build-bar icons have it; behind our own _draw
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	super._ready()


func _rebuilt() -> void:
	if _felt:
		_felt.queue_free()
	_felt = Area2D.new()
	_felt.collision_layer = 0
	_felt.collision_mask = 2
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2((b - a).length(), 12)
	cs.shape = r
	# a strip just above the running surface: marbles are muffled as they come in to land
	var t := (b - a).normalized()
	cs.position = (a + b) * 0.5 + Vector2(t.y, -t.x) * 6.0   # (t.y, -t.x): up, off the running surface
	cs.rotation = (b - a).angle()
	_felt.add_child(cs)
	add_child(_felt)


func _physics_process(delta: float) -> void:
	if _felt == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in _felt.get_overlapping_bodies():
		if o is RigidBody2D:
			o.set_meta("muffled_until", now + 0.2)
			o.linear_velocity *= 1.0 - DRAG * delta


## The chute's own look is replaced by the art; only the selection handle
## is drawn over it.
func _draw() -> void:
	if _art:
		_art.queue_redraw()
	_draw_selected()


## The trough (a tiled strip, row 3 on the rail line), the stop at the high
## end and a cap at each end.
func _draw_art() -> void:
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	if has_lip:
		var high := a if a.y < b.y else b
		_art.draw_texture(STOP_TEX, high + Vector2(-3, -10))
	_art.draw_set_transform(a, (b - a).angle())
	_art.draw_texture_rect(RAIL_TEX, Rect2(0, -3, l, 10), true)
	_art.draw_texture(CAP_TEX, Vector2(-3, -4))
	_art.draw_texture(CAP_TEX, Vector2(l - 3, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
