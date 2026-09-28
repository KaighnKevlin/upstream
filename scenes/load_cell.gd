extends Node2D
## Load cell: a weighing pan on a spring with a dial. When the ore resting
## in it weighs as much as its setting (click: 2 / 5 / 10), it fires
## everything triggerable in reach of it and of its pull-wire's end (drag
## it), once; it rearms when the pan is lighter again. The tally wheel
## counts what passes; this measures what's piled up: the bin under a
## turret is full, so throw the points and send the rest elsewhere.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const ORE_ONLY := 64
const SETS := [2.0, 5.0, 10.0]
const W := 26.0

@export var mode := 0
@export var wire_to := Vector2(50, -20)

var fired := 0                   # tests
var weight := 0.0
var _armed := true
var _pan: Area2D
var _flash := 0.0
var _dragging := false
var _art: Sprite2D               # pan, spring and dial face; brightens as it fires


func _ready() -> void:
	z_index = 1
	# the sprite first, so ghosts and build-bar icons get it too; behind our
	# own _draw (the needle, the reading and the wire)
	_art = Sprite2D.new()
	_art.texture = preload("res://assets/sprites/load_cell.png")
	_art.centered = false
	_art.offset = Vector2(-17, -22)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.show_behind_parent = true
	add_child(_art)
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	m.bounce = 1.0
	body.physics_material_override = m
	for seg in [[Vector2(-W * 0.5, -18), Vector2(-W * 0.5, 0)], [Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0)], [Vector2(W * 0.5, 0), Vector2(W * 0.5, -18)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		cs.shape = s
		body.add_child(cs)
	add_child(body)
	_pan = Area2D.new()
	_pan.collision_layer = 0
	_pan.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W - 4, 30)
	ac.shape = r
	ac.position = Vector2(0, -15)
	_pan.add_child(ac)
	add_child(_pan)


func _physics_process(delta: float) -> void:
	if _pan == null:
		return
	var m := 0.0
	for b in _pan.get_overlapping_bodies():
		if b is RigidBody2D:
			m += b.mass
	weight = m
	if _armed and weight >= SETS[mode]:
		_armed = false
		fire()
	elif not _armed and weight < SETS[mode]:
		_armed = true
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


func fire() -> void:
	fired += 1
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.9)
	var points := [global_position]
	if wire_to != Vector2.ZERO:
		points.append(global_position + wire_to)
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		if event.pressed and wire_to != Vector2.ZERO and p.distance_to(global_position + wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and p.distance_to(global_position + Vector2(0, 10)) < 10:
			mode = (mode + 1) % SETS.size()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position


func _draw() -> void:
	# pan, spring and dial face are a sprite (see _ready)
	_art.self_modulate = Color.WHITE.lerp(Color(1.35, 1.3, 1.1), _flash)
	var dark := Color(0.1, 0.08, 0.07)
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(W * 0.5, -6), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	var f := clampf(weight / SETS[mode], 0.0, 1.0)
	var a := -PI * 0.75 + f * PI * 1.5
	draw_line(Vector2(0, 12), Vector2(0, 12) + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * 5.0, Color(0.8, 0.2, 0.15), 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-W * 0.5, -22), "%.0f/%.0f" % [weight, SETS[mode]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
