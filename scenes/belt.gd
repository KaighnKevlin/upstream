extends "res://scenes/chute.gd"
## Conveyor belt: a chute with a moving rubber belt on it. Ore resting on
## it is carried along at SPEED in the direction the belt was drawn (from
## where you pressed to where you let go), up gentle slopes too, so ore can
## go sideways or climb where a chute could only let it fall.
## Placed and adjusted exactly like a chute. No stop at the high end: ore
## rides off whichever end the belt runs to.

const SPEED := 110.0
const GRIP := 14.0            # how fast riders are brought up to belt speed (1/s)
const GRAV := Vector2(0, 980)

var _grip: Area2D
var _phase := 0.0


func _init() -> void:
	has_lip = false


## Direction the belt runs: from the placement point to the end.
func run_dir() -> Vector2:
	return end_offset.normalized()


func _rebuilt() -> void:
	if _grip:
		_grip.queue_free()
	_grip = Area2D.new()
	_grip.collision_layer = 0
	_grip.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	var l := end_offset.length()
	r.size = Vector2(l, 16)
	cs.shape = r
	var t := end_offset / l
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	cs.position = end_offset / 2 + up * 8
	cs.rotation = end_offset.angle()
	_grip.add_child(cs)
	add_child(_grip)


func _physics_process(delta: float) -> void:
	if _grip == null:
		return
	var dir := run_dir()
	for body in _grip.get_overlapping_bodies():
		var b := body as RigidBody2D
		if b == null or b.freeze or b.has_meta("caught_by"):
			continue
		var v := b.linear_velocity
		# hold it against gravity along the belt, then pull it to belt speed
		v -= dir * GRAV.dot(dir) * delta
		v += dir * (SPEED - v.dot(dir)) * minf(1.0, GRIP * delta)
		b.linear_velocity = v
		b.angular_velocity *= 0.8   # carried, not rolling
		b.sleeping = false
		if "_timer" in b:
			b._timer = 0.0           # ore on a belt is in use: no despawn


func _process(delta: float) -> void:
	if _grip:
		_phase = fmod(_phase + SPEED * delta, CLEAT_GAP)
		queue_redraw()


# ── look: a dark rubber belt on the rail, cleats moving along it ───────

const RUBBER := Color(0.13, 0.11, 0.12)
const CLEAT := Color(0.62, 0.56, 0.48)
const CLEAT_GAP := 8.0


func _draw_surface(a: Vector2, b: Vector2, t: Vector2, n: Vector2, l: float) -> void:
	draw_line(a - n * 1.0, b - n * 1.0, RUBBER, 4.0)
	# cleats travel with the belt: along run_dir(), which is t or -t
	var s := 1.0 if run_dir().dot(t) >= 0 else -1.0
	var k := _phase if s > 0 else CLEAT_GAP - _phase
	while k < l:
		var p := a + t * k
		draw_line(p - n * 0.5, p + n * 1.5, CLEAT, 1.5)
		k += CLEAT_GAP
	# drums at both ends
	for p in [a, b]:
		draw_circle(p - n * 2, 3.0, DARK)
		draw_circle(p - n * 2, 1.8, STEEL)
