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

var rings := 0                   # tests
var _swing := 0.0
var _swing_v := 0.0
var _flash := 0.0
var _cool := 0.0


func _ready() -> void:
	z_index = 1
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
	SFX.play(self, SFX.sfx_bell(), -8.0, 1.0)
	for n in Tripwire.linked_to(get_tree(), [global_position]):
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
	var dark := Color(0.1, 0.08, 0.07)
	# bracket
	draw_line(Vector2(-10, -4), Vector2(10, -4), dark, 4.0)
	draw_line(Vector2(-10, -4), Vector2(10, -4), Color(0.4, 0.3, 0.2), 2.0)
	draw_set_transform(Vector2(0, -2), _swing, Vector2.ONE)
	var body := PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(6, 6), Vector2(8, 14),
		Vector2(R + 1, 20), Vector2(-R - 1, 20), Vector2(-8, 14), Vector2(-6, 6)])
	draw_colored_polygon(body, dark)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.85 + Vector2(0, 1.5))
	var brass := Color(0.85, 0.65, 0.3).lerp(Color(1.0, 0.95, 0.7), _flash)
	draw_colored_polygon(inner, brass)
	draw_line(Vector2(-4, 5), Vector2(-6, 15), Color(1.0, 0.9, 0.6, 0.7), 1.0)
	draw_circle(Vector2(0, 21), 2.5, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0:
		draw_arc(Vector2(0, 10), 16 + (1.0 - _flash) * 14, 0, TAU, 24, Color(1.0, 0.85, 0.5, _flash * 0.6), 1.5)
