extends Node2D
## Archimedes screw: a brass tube with a turning helix inside, laid from its
## low end (where it's placed) up to its high end (drag). Pieces that roll
## into the mouth are carried up the tube at SPEED (faster when a gravity
## wheel or engine drives it) and tipped out of the top. A local lift for
## the marble machine: steady and slow where the Beam is magic and fast.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")

const LEN_MIN := 40.0
const LEN_MAX := 260.0
const SPEED := 110.0             # px/s along the tube at full power
const RADIUS := 9.0

@export var end_offset := Vector2(60, -120)

var lifted := 0                  # tests
var _area: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _phase := 0.0


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(0, -LEN_MIN)
	if end_offset.y > -10:
		end_offset.y = -10.0      # it only lifts
	if _area:
		_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	add_child(_area)
	_rebuild()


func _rebuild() -> void:
	for c in _area.get_children():
		c.queue_free()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(end_offset.length(), RADIUS * 2)
	cs.shape = r
	cs.position = end_offset * 0.5
	cs.rotation = end_offset.angle()
	_area.add_child(cs)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_phase += delta * _rate * 3.0
	var l := end_offset.length()
	var dir := end_offset / l
	var n := dir.orthogonal()
	for b in _area.get_overlapping_bodies():
		if not (b is RigidBody2D) or b.freeze or b.has_meta("caught_by") or b.has_meta("in_beam"):
			continue
		var o := b as RigidBody2D
		var rel := o.global_position - global_position
		var along := rel.dot(dir)
		var off := rel.dot(n)
		if along > l - 6.0:
			# out of the top: tipped over the lip
			o.gravity_scale = 1.0
			o.remove_meta("in_screw")
			o.linear_velocity = dir * 60.0 + Vector2(signf(dir.x) * 60.0 if dir.x != 0 else 60.0, -40.0)
			lifted += 1
			continue
		if not o.has_meta("in_screw"):
			o.set_meta("in_screw", true)
		o.gravity_scale = 0.0
		o.linear_velocity = dir * SPEED * _rate - n * off * 8.0
		o.angular_velocity = 6.0
		if "_timer" in o:
			o._timer = 0.0
	queue_redraw()


func _draw() -> void:
	var l := end_offset.length()
	var dir := end_offset / maxf(l, 1.0)
	var n := dir.orthogonal()
	# the tube's walls
	for s in [-1.0, 1.0]:
		draw_line(n * RADIUS * s, end_offset + n * RADIUS * s, Color(0.1, 0.08, 0.07), 3.0)
		draw_line(n * RADIUS * s, end_offset + n * RADIUS * s, Color(0.72, 0.55, 0.3), 1.0)
	# the helix flights, sliding up as it turns
	var k := fmod(_phase * 6.0, 10.0)
	while k < l:
		var c := dir * k
		draw_line(c - n * (RADIUS - 1), c + dir * 4.0 + n * (RADIUS - 1), Color(0.62, 0.64, 0.68, 0.8), 1.0)
		k += 10.0
	# mouth and lip rings
	for p in [Vector2.ZERO, end_offset]:
		draw_line(p - n * (RADIUS + 2), p + n * (RADIUS + 2), Color(0.1, 0.08, 0.07), 4.0)
		draw_line(p - n * (RADIUS + 2), p + n * (RADIUS + 2), Color(0.85, 0.65, 0.35), 2.0)
