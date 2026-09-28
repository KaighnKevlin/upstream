extends Node2D
## Pop bumper: the pinball kind, a round brass post with a ring that kicks.
## Any piece that touches it is thrown straight away from its centre, faster
## than it came (KICK added), with a flash and a ding. A few of them make a
## rattling mixing field; one beside a stalled line keeps it moving. It's
## triggerable too: a signal fires a kick at whatever's touching it.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const R := 10.0
const KICK := 260.0

var kicks := 0                   # tests
var _flash := 0.0
var _seen := {}
var _area: Area2D


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = R
	cs.shape = c
	body.add_child(cs)
	add_child(body)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var ac := CollisionShape2D.new()
	var ar := CircleShape2D.new()
	ar.radius = R + 8.0
	ac.shape = ar
	_area.add_child(ac)
	add_child(_area)
	_area.body_entered.connect(_kick)


func _kick(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _seen.get(b.get_instance_id(), 0.0) > now:
		return
	_seen[b.get_instance_id()] = now + 0.15
	var away: Vector2 = (b.global_position - global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	var speed: float = b.linear_velocity.length()
	b.sleeping = false
	b.linear_velocity = away * (speed * 0.6 + KICK)
	kicks += 1
	_flash = 1.0
	SFX.play_small(self, SFX.sfx_chime(1046.5 + randf_range(-20, 20)), -16.0, 1.0)


func trigger() -> void:
	if _area == null:
		return
	for b in _area.get_overlapping_bodies():
		_seen.erase(b.get_instance_id())
		_kick(b)


func _process(delta: float) -> void:
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var lit := Color(1.0, 0.9, 0.55)
	# the kicking ring, pushed out while it flashes
	draw_circle(Vector2.ZERO, R + 2 + _flash * 3, dark)
	draw_arc(Vector2.ZERO, R + 1 + _flash * 3, 0, TAU, 24, brass.lerp(lit, _flash), 2.0)
	draw_circle(Vector2.ZERO, R - 2, Color(0.42, 0.44, 0.5))
	draw_circle(Vector2.ZERO, R - 5, brass.lerp(lit, _flash))
	draw_circle(Vector2(-2, -2), 1.5, Color(1, 1, 1, 0.6))
	if _flash > 0:
		draw_arc(Vector2.ZERO, R + 6 + (1.0 - _flash) * 8, 0, TAU, 24, Color(1.0, 0.85, 0.5, _flash * 0.6), 1.5)
