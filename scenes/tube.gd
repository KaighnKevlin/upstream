extends Node2D
## Pneumatic tube: a brass pipe with glass windows from an intake funnel to
## an outlet nozzle, dragged out like a chute (press at the intake, release
## at the outlet: any direction, uphill included; it bows up in a gentle
## arc). Anything dropped into the funnel is sucked in, whooshes along the
## pipe (you can watch it through the glass) and is shot out of the nozzle
## along the pipe's last stretch. Faster when a gravity wheel drives it.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const LEN_MIN := 40.0
const LEN_MAX := 420.0
const SPEED := 260.0          # px/s through the pipe at full power
const EJECT := 240.0
const SEGS := 24

@export var end_offset := Vector2(160, -40)

var sent := 0                 # tests
var _travel := []             # [body, t]
var _intake: Area2D
var _pts := PackedVector2Array()
var _len := 1.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 3
	_rebuild()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 10)
	cs.shape = r
	cs.position = Vector2(0, -8)
	_intake.add_child(cs)
	add_child(_intake)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	_rebuild()


## The pipe's path: a quadratic arc from the intake to the outlet, bowed up.
func _point(t: float) -> Vector2:
	var ctrl := end_offset * 0.5 + Vector2(0, -minf(60.0, end_offset.length() * 0.25))
	return (1.0 - t) * (1.0 - t) * Vector2.ZERO + 2.0 * (1.0 - t) * t * ctrl + t * t * end_offset


func _rebuild() -> void:
	_pts.clear()
	_len = 0.0
	for k in SEGS + 1:
		var p := _point(float(k) / SEGS)
		if k > 0:
			_len += p.distance_to(_pts[k - 1])
		_pts.append(p)
	queue_redraw()


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.has_meta("caught_by") or b.freeze:
		return
	b.set_meta("caught_by", self)
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	b.set_physics_process(false)     # no despawning in transit
	b.set_meta("tube_z", b.z_index)
	b.z_index = z_index + 1          # drawn over the pipe: seen through the glass
	_travel.append([b, 0.0])
	SFX.play_small(self, SFX.sfx_bounce(), -12.0, 1.8)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var step := SPEED * (0.45 + 0.55 * _rate) * delta / _len
	var done := []
	for it in _travel:
		var b: RigidBody2D = it[0]
		if not is_instance_valid(b):
			done.append(it)
			continue
		it[1] += step
		if it[1] >= 1.0:
			done.append(it)
			_eject(b)
		else:
			b.global_position = to_global(_point(it[1]))
	for it in done:
		_travel.erase(it)


func _eject(b: RigidBody2D) -> void:
	var dir := (_point(1.0) - _point(0.94)).normalized()
	b.global_position = to_global(end_offset + dir * 8.0)
	b.freeze = false
	b.remove_meta("caught_by")
	b.z_index = b.get_meta("tube_z", 0)
	b.remove_meta("tube_z")
	b.set_physics_process(true)
	b.sleeping = false
	b.linear_velocity = dir * EJECT
	sent += 1
	FX.burst(get_parent(), b.global_position, Color(0.85, 0.85, 0.8, 0.7), 4, 50.0, 0.3, 1.4)
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.4)


func _draw() -> void:
	if _pts.size() < 2:
		return
	# the pipe: dark rim, brass wall, glass windows between brass bands
	draw_polyline(_pts, Color(0.16, 0.15, 0.12), 9.0)
	draw_polyline(_pts, Color(0.66, 0.53, 0.31), 7.0)
	draw_polyline(_pts, Color(0.55, 0.78, 0.82, 0.45), 4.0)
	for k in range(2, SEGS - 1, 3):
		var p := _pts[k]
		var d := (_pts[k + 1] - _pts[k - 1]).normalized()
		var n := Vector2(-d.y, d.x)
		draw_line(p - n * 4.5, p + n * 4.5, Color(0.85, 0.72, 0.45), 2.0)
	# a highlight along the glass
	var hi := PackedVector2Array()
	for p in _pts:
		hi.append(p + Vector2(0, -1.5))
	draw_polyline(hi, Color(0.9, 0.97, 1.0, 0.25), 1.0)
	# intake funnel
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(5, 0), Vector2(-5, 0)]), Color(0.16, 0.15, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-9.5, -13), Vector2(9.5, -13), Vector2(4, -1), Vector2(-4, -1)]), Color(0.57, 0.6, 0.62))
	draw_line(Vector2(-11, -14), Vector2(11, -14), Color(0.85, 0.72, 0.45), 2.0)
	# outlet nozzle
	var e := end_offset
	var dir := (_point(1.0) - _point(0.94)).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([e - nrm * 5.5, e + dir * 8.0 - nrm * 4.0, e + dir * 8.0 + nrm * 4.0, e + nrm * 5.5]), Color(0.16, 0.15, 0.12))
	draw_colored_polygon(PackedVector2Array([e - nrm * 4.0, e + dir * 7.0 - nrm * 3.0, e + dir * 7.0 + nrm * 3.0, e + nrm * 4.0]), Color(0.85, 0.72, 0.45))
