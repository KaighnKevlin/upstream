extends Node2D
## Bell: a brass bell hung on a bracket. A marble that strikes it rings it
## (and swings it), and a ring fires everything triggerable within reach,
## like a tripwire does: the marble machine's way of setting things off.
## A signal from the machine: the counter's overflow, a batch arriving.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const ORE_ONLY := 64
const R := 11.0                  # the bell's mouth half-width

@export var muffled := false     # wrapped in felt: a thud, barely heard, and it fires nothing
## a pull-wire: the ring also fires what's in reach of this point (an offset),
## so a bell up in the machine can work a trap down on the floor
@export var wire_to := Vector2.ZERO

var rings := 0                   # tests
var _swing := 0.0
var _swing_v := 0.0
var _flash := 0.0
var _cool := 0.0
var _bell: Sprite2D              # swings about the yoke pin, (0, -2)


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw (the pull-wire and the ring)
	var br := Sprite2D.new()
	br.texture = preload("res://assets/sprites/bell_bracket.png")
	br.centered = false
	br.offset = Vector2(-13, -7)
	br.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	br.show_behind_parent = true
	_bell = Sprite2D.new()
	_bell.texture = preload("res://assets/sprites/bell_felt.png") if muffled else preload("res://assets/sprites/bell.png")
	_bell.centered = false
	_bell.offset = Vector2(-14, -2)
	_bell.position = Vector2(0, -2)
	_bell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bell.show_behind_parent = true
	add_child(_bell)
	add_child(br)                # the yoke over the bell's crown
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = R
	cs.shape = c
	cs.position = Vector2(0, 10)
	body.add_child(cs)
	add_child(body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var ar := CircleShape2D.new()
	ar.radius = R + 4
	ac.shape = ar
	ac.position = Vector2(0, 10)
	a.add_child(ac)
	add_child(a)
	a.body_entered.connect(_on_hit)


func _on_hit(b) -> void:
	if not (b is RigidBody2D) or _cool > 0:
		return
	ring(signf(b.linear_velocity.x) if absf(b.linear_velocity.x) > 5 else 1.0)


func ring(dir := 1.0) -> void:
	_cool = 0.25
	rings += 1
	_swing_v += 3.0 * dir
	_flash = 1.0
	if muffled:
		SFX.play_small(self, SFX.sfx_ore_knock("wood"), -18.0, 0.7)
		preload("res://scenes/noise_meter.gd").add(get_tree(), 1.0)
		return
	SFX.play(self, SFX.sfx_bell(), -8.0, 1.0)
	preload("res://scenes/noise_meter.gd").add(get_tree(), 15.0)   # a bell carries: it's heard
	# wired, it fires only at the wire's end (not whatever happens to stand
	# beside it too); unwired, around itself
	var points := [global_position + wire_to] if wire_to != Vector2.ZERO else [global_position]
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_cool -= delta
	# a damped swing back to hanging
	_swing_v += -_swing * 40.0 * delta
	_swing_v *= exp(-2.5 * delta)
	_swing += _swing_v * delta
	_flash = maxf(0.0, _flash - delta * 1.5)
	if absf(_swing) > 0.001 or _flash > 0:
		queue_redraw()


func _draw() -> void:
	# bracket and bell are sprites (see _ready); the bell swings and glows
	_bell.texture = preload("res://assets/sprites/bell_felt.png") if muffled else preload("res://assets/sprites/bell.png")
	_bell.rotation = _swing
	_bell.self_modulate = Color.WHITE.lerp(Color(1.45, 1.35, 1.1), 0.0 if muffled else _flash)
	var dark := Color(0.1, 0.08, 0.07)
	if wire_to != Vector2.ZERO:
		# the pull-wire, sagging, to a little pulley at its far end
		var mid := wire_to * 0.5 + Vector2(0, 18)
		draw_polyline(PackedVector2Array([Vector2(8, -4), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, Color(0.85, 0.65, 0.35))
	if _flash > 0 and not muffled:
		draw_arc(Vector2(0, 10), 16 + (1.0 - _flash) * 14, 0, TAU, 24, Color(1.0, 0.85, 0.5, _flash * 0.6), 1.5)
