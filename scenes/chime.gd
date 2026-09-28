extends Node2D
## Chime bar: a tuned brass bar, like a xylophone key, laid as a sloped
## rail. A marble landing on it rings its note (click: up a step) and rolls
## on. Lay a switchback of them and every marble plays the tune on the way
## down: a music box. Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const LEN_MIN := 30.0
const LEN_MAX := 160.0
const NAMES := ["C", "D", "E", "F", "G", "A", "B", "C'", "D'", "E'"]
const FREQS := [523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77, 1046.5, 1174.66, 1318.51]
const HUES := [0.0, 0.08, 0.15, 0.3, 0.5, 0.6, 0.75, 0.0, 0.08, 0.15]
const BAR_TEX := preload("res://assets/sprites/chime_bar.png")     # grey: tinted by the note
const CAPS_TEX := preload("res://assets/sprites/chime_caps.png")
const POST_TEX := preload("res://assets/sprites/chime_post.png")
const STOP_TEX := preload("res://assets/sprites/chime_stop.png")

@export var note := 0
@export var end_offset := Vector2(70, 18)   # the other end of the bar

var rung := 0                    # tests
var _flash := 0.0
var _last := {}
var _art: Node2D                 # the bar, posts and stop, pixel art (nearest, tiled)


func set_end(offset: Vector2) -> void:
	end_offset = offset.normalized() * clampf(offset.length(), LEN_MIN, LEN_MAX) if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	queue_redraw()


func _ready() -> void:
	z_index = 1
	# art first, so ghosts and build-bar icons have it; behind our own _draw
	# (the note's name and the ring's flash)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true           # a landing sticks and rolls, like a chute
	m.bounce = 0.5
	m.friction = 1.0
	body.physics_material_override = m
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = Vector2.ZERO
	s.b = end_offset
	cs.shape = s
	body.add_child(cs)
	# a stop at the high end catches a marble coming off the bar above
	var high := Vector2.ZERO if end_offset.y > 0 else end_offset
	var lip := CollisionShape2D.new()
	var ls := SegmentShape2D.new()
	ls.a = high
	ls.b = high + Vector2(0, -14)
	lip.shape = ls
	body.add_child(lip)
	add_child(body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(end_offset.length(), 10)
	ac.shape = r
	var t := end_offset.normalized()
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	ac.position = end_offset * 0.5 + up * 5.0   # a strip just over the bar
	ac.rotation = end_offset.angle()
	a.add_child(ac)
	add_child(a)
	a.body_entered.connect(_strike)


func _strike(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _last.get(b.get_instance_id(), 0.0) > now:
		return
	_last[b.get_instance_id()] = now + 0.6
	ring()


func ring() -> void:
	rung += 1
	_flash = 1.0
	SFX.play(self, SFX.sfx_chime(FREQS[note]), -6.0, 1.0)
	preload("res://scenes/noise_meter.gd").add(get_tree(), 2.0)


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := to_local(get_global_mouse_position())
	var t := end_offset.normalized()
	var along := p.dot(t)
	if along > 0 and along < end_offset.length() and absf(p.dot(Vector2(t.y, -t.x))) < 8:
		note = (note + 1) % FREQS.size()
		ring()


func _colour() -> Color:
	var c := Color.from_hsv(HUES[note], 0.55, 0.85)
	return c.lerp(Color(1, 1, 0.9), _flash * 0.6)


func _draw_art() -> void:
	var l := end_offset.length()
	if l < 0.1:
		return
	var t := end_offset / l
	# the posts it rests on, upright under its nodes, and the stop at the high end
	for f in [0.2, 0.8]:
		_art.draw_texture(POST_TEX, end_offset * f + Vector2(-3, 3))
	var high := Vector2.ZERO if end_offset.y > 0 else end_offset
	_art.draw_texture(STOP_TEX, high + Vector2(-2, -15))
	# the bar, tinted with its note; kept right way up whichever way it runs
	var c := _colour() * Color(1.2, 1.2, 1.2)
	_art.draw_set_transform(Vector2.ZERO, end_offset.angle(), Vector2(1, -1) if t.x < 0 else Vector2.ONE)
	_art.draw_texture_rect(BAR_TEX, Rect2(0, -4, l, 8), true, c)
	_art.draw_texture_rect_region(CAPS_TEX, Rect2(-1, -4, 6, 8), Rect2(0, 0, 6, 8), c)
	_art.draw_texture_rect_region(CAPS_TEX, Rect2(l - 4, -4, 6, 8), Rect2(6, 0, 6, 8), c)
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	_art.queue_redraw()          # bar, posts and stop are pixel art (see _draw_art)
	var c := _colour()
	var t := end_offset.normalized()
	var n := Vector2(t.y, -t.x)
	if n.y > 0:
		n = -n                   # the letter goes above the bar, whichever way it was dragged
	var font := ThemeDB.fallback_font
	draw_string(font, end_offset * 0.5 + n * 12 - Vector2(4, 0), NAMES[note], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, c)
	if _flash > 0:
		draw_line(Vector2.ZERO, end_offset, Color(1, 1, 0.8, _flash * 0.5), 10.0)
