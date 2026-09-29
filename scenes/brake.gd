extends "res://scenes/chute.gd"
## Brake rail: a chute with stiff brushes along it. Anything going faster
## than its limit (80 / 150 / 250 px/s) is held to it while it's on
## the rail, so a stream arrives at a known speed: into a cup or a net
## without overshooting, onto a flap sorter slowly enough to drop. Click
## its number to change the limit. On the track net: riders are capped
## there (Track.vcap); its brush still holds any physics body on it.

const LIMITS := [80.0, 150.0, 250.0]
const BRISTLE := Color(0.55, 0.4, 0.22)
const RAIL_TEX := preload("res://assets/sprites/brake_rail.png")
const TUFT_TEX := preload("res://assets/sprites/brake_tuft.png")
const CAP_TEX := preload("res://assets/sprites/brake_cap.png")
const STOP_TEX := preload("res://assets/sprites/flap_stop.png")

@export var mode := 1

var braked := 0                  # tests
var _brush: Area2D
var _art: Node2D                 # the rail and bristles, pixel art tiled along it


func _ready() -> void:
	# art first, so ghosts and build-bar icons have it; behind our own _draw
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	super._ready()


func _track_ready() -> void:
	track.vcap = LIMITS[mode]


func _rebuilt() -> void:
	if _brush:
		_brush.queue_free()
	_brush = Area2D.new()
	_brush.collision_layer = 0
	_brush.collision_mask = 2
	var a := Vector2.ZERO
	var b := end_offset
	var t := (b - a).normalized()
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2((b - a).length(), 14)
	cs.shape = r
	cs.position = (a + b) * 0.5 + up * 6.0
	cs.rotation = (b - a).angle()
	_brush.add_child(cs)
	add_child(_brush)


func _physics_process(_delta: float) -> void:
	if _brush == null:
		return
	var cap: float = LIMITS[mode]
	if track != null:
		track.vcap = cap
		# riders held to the cap: count each piece once, as the brush does
		for i in track.count():
			if absf(track.rv[i]) >= cap - 0.5 and _net.rider_get_meta(track, i, "braked_by") == null:
				_net.rider_set_meta(track, i, "braked_by", get_instance_id())
				braked += 1
	for o in _brush.get_overlapping_bodies():
		if o is RigidBody2D and o.linear_velocity.length() > cap:
			o.linear_velocity = o.linear_velocity.limit_length(cap)
			if not o.has_meta("braked_by"):
				o.set_meta("braked_by", get_instance_id())
				braked += 1


func _label_at() -> Vector2:
	var e := _ends()
	var t: Vector2 = (e[1] - e[0]).normalized()
	return (e[0] + e[1]) * 0.5 + Vector2(t.y, -t.x) * 16.0


## Clicking its number changes the limit; anywhere else on it, the chute's
## own click-to-select-and-drag.
func _input(event: InputEvent) -> void:
	if _brush != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and to_local(get_global_mouse_position()).distance_to(_label_at()) < 10:
		mode = (mode + 1) % LIMITS.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	super._input(event)


## The chute's own look is replaced by the art; its limit and the selection
## handle are drawn over it.
func _draw() -> void:
	if _art:
		_art.queue_redraw()
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	var t := (b - a) / l
	_draw_surface(a, b, t, Vector2(t.y, -t.x), l)
	_draw_selected()


## The rail (a tiled strip, row 3 on the rail line), bristle tufts along
## it (closer for a lower limit), the stop at the high end and the caps.
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
	_art.draw_texture_rect(RAIL_TEX, Rect2(0, -3, l, 12), true)
	var gap := 3.0 + mode * 2.0
	var k := 3.0
	while k < l - 2:
		_art.draw_texture(TUFT_TEX, Vector2(k - 1, -7))
		k += gap
	_art.draw_texture(CAP_TEX, Vector2(-3, -4))
	_art.draw_texture(CAP_TEX, Vector2(l - 3, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_surface(a: Vector2, b: Vector2, _t: Vector2, n: Vector2, _l: float) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, (a + b) * 0.5 + n * 16.0 - Vector2(8, 0), "%d" % int(LIMITS[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
