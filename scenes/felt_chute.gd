extends "res://scenes/chute.gd"
## Felt chute: a chute lined with green baize. Marbles landing on it and
## rolling along it make no clatter (the noise meter doesn't hear them), but
## the felt drags at them, so a felt run is quiet and slow where steel is
## loud and quick.

const DRAG := 1.1                # per second, while on the felt
const FELT := Color(0.2, 0.45, 0.28)
const FELT_HI := Color(0.32, 0.6, 0.38)

var _felt: Area2D


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


func _draw_surface(a: Vector2, b: Vector2, _t: Vector2, n: Vector2, _l: float) -> void:
	draw_line(a - n * 0.5, b - n * 0.5, FELT, 3.0)
	draw_line(a + n * 0.5, b + n * 0.5, FELT_HI, 1.0)
