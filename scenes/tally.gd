extends Node2D
## Tally wheel: a brass star-wheel riding on a chute. Each piece rolling
## under it turns it a notch; every `every`th piece (click: 3 / 5 / 10)
## it fires everything triggerable in reach, and at the end of its pull-
## wire if it has one (drag the wire's end), like a tripwire. Counting for
## the marble machine: every tenth ore opens the sluice, every fifth trips
## the barricade. Put its node just over the chute.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const EVERY := [3, 5, 10]

@export var mode := 0
@export var wire_to := Vector2(50, 30)   # drag its end to what it should fire

var count := 0
var fired := 0                   # tests
var _turn := 0.0
var _flash := 0.0
var _last := {}
var _dragging := false
var _wheel: Sprite2D             # turns a notch per piece


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw (the wire and the count)
	var br := Sprite2D.new()
	br.texture = preload("res://assets/sprites/tally_bracket.png")
	br.centered = false
	br.offset = Vector2(-8, -13)
	br.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	br.show_behind_parent = true
	add_child(br)
	_wheel = Sprite2D.new()
	_wheel.texture = preload("res://assets/sprites/tally_wheel.png")   # centred on the axle
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wheel.show_behind_parent = true
	add_child(_wheel)
	if has_meta("ghost"):
		return
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	cs.position = Vector2(0, 8)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_notch)


func _notch(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _last.get(b.get_instance_id(), 0.0) > now:
		return
	_last[b.get_instance_id()] = now + 1.0
	count += 1
	_turn += TAU / 8.0
	SFX.play_small(self, SFX.sfx_ore_knock("wood"), -20.0, 1.5)
	if count % EVERY[mode] == 0:
		fire()
	queue_redraw()


func fire() -> void:
	fired += 1
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 1.2)
	var points := [global_position]
	if wire_to != Vector2.ZERO:
		points.append(global_position + wire_to)
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if event.pressed and wire_to != Vector2.ZERO and m.distance_to(global_position + wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and m.distance_to(global_position) < 12:
			mode = (mode + 1) % EVERY.size()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position
		queue_redraw()


func _draw() -> void:
	# bracket and star-wheel are sprites (see _ready); it glows as it fires
	_wheel.rotation = _turn
	_wheel.self_modulate = Color.WHITE.lerp(Color(1.45, 1.35, 1.1), _flash)
	var dark := Color(0.1, 0.08, 0.07)
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(6, -6), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	# the count toward the next firing
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-10, -14), "%d/%d" % [count % EVERY[mode], EVERY[mode]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
