extends "res://scenes/chute.gd"
## Booster rail: a chute with driven rollers in it that push whatever rolls
## onto it along the rail, from where it was placed toward its end, at a
## set speed: uphill too, so a run can climb, or a slow stream be sped up
## to make a jump or a loop. Runs slowly on its own and at full speed when
## a gravity wheel or steam engine is in reach. No stop-lip: it drives
## through both ends.

const Power = preload("res://scripts/power.gd")
const SPEED := 420.0             # px/s along the rail at full power

var boosted := 0                 # tests
var _grip: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _phase := 0.0
var _seen := {}


func _ready() -> void:
	has_lip = false
	super._ready()
	if not has_meta("ghost"):
		add_to_group("power_users")


func _rebuilt() -> void:
	if _grip:
		_grip.queue_free()
	_grip = Area2D.new()
	_grip.collision_layer = 0
	_grip.collision_mask = 2
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
	_grip.add_child(cs)
	add_child(_grip)


func _physics_process(delta: float) -> void:
	if _grip == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_phase += delta * _rate * 12.0
	var dir := end_offset.normalized()
	var want := SPEED * _rate
	for o in _grip.get_overlapping_bodies():
		if not (o is RigidBody2D) or o.freeze:
			continue
		var along: float = o.linear_velocity.dot(dir)
		if along < want:
			# the rollers take it up to speed quickly, keeping it on the rail
			o.linear_velocity += dir * minf(want - along, 1400.0 * delta)
		if not _seen.has(o.get_instance_id()):
			_seen[o.get_instance_id()] = true
			boosted += 1
	queue_redraw()


func _draw_surface(a: Vector2, b: Vector2, t: Vector2, n: Vector2, l: float) -> void:
	# rollers along the rail, turning the way they drive
	var dir := 1.0 if end_offset.dot(b - a) > 0 else -1.0
	var k := fmod(_phase * dir, 10.0)
	if k < 0:
		k += 10.0
	while k < l:
		var p := a + t * k + n * 1.5
		draw_circle(p, 2.0, Color(0.2, 0.18, 0.16))
		draw_line(p - t * 1.5, p + t * 1.5, Color(0.9, 0.7, 0.35).lerp(Color(0.5, 0.5, 0.5), 1.0 - _rate), 1.0)
		k += 10.0
	# a chevron showing which way it drives
	var mid := (a + b) * 0.5 + n * 7.0
	var f := t * dir * 4.0
	draw_line(mid - f + n * 3, mid + f, Color(1.0, 0.8, 0.4, 0.7), 1.5)
	draw_line(mid - f - n * 3, mid + f, Color(1.0, 0.8, 0.4, 0.7), 1.5)
