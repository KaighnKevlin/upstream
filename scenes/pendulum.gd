extends Node2D
## Wrecking pendulum: an iron ball on a chain under an A-frame gantry.
## Placed by its pivot; the chain is sized so the ball skims just above the
## ground at the bottom of its swing, at walker height. It hangs still until
## something pushes it: ore that hits the ball shoves it (the ball is heavy,
## so one piece only nudges it; a stream timed to its swing pumps it up).
## Swinging fast, it smashes enemies it passes through and bats them away,
## harder the faster it goes, and flings the player.
## The swing is simulated directly (angle and angular speed); the ball is a
## kinematic body on the ore-only layer, so ore bounces off it for real.
## Art: tools/art/gen_pendulum.py (ball, hub); chain and frame drawn here.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const G := 980.0
const L_MIN := 40.0
const L_MAX := 170.0
const CLEARANCE := 15.0        # ball centre above the ground at the bottom
const BALL_R := 10.5
const MASS_RATIO := 1.0 / 6.0  # a piece of ore against the ball
const RESTITUTION := 0.3
const DAMPING := 0.06          # 1/s: swings last a good while
const MAX_SPEED := 560.0       # ball speed cap (px/s)
const HIT_SPEED := 110.0       # below this it just shoves; above it smashes
const ORE_ONLY := 64

var length := 90.0
var theta := 0.0               # radians from straight down, positive = swung right
var omega := 0.0
var hits := 0                  # enemies smashed (tests)
var _ball: AnimatableBody2D
var _ball_spr: Sprite2D
var _sense: Area2D
var _legs: Array[Vector2] = []  # A-frame feet, local
var _last := {}                 # body id -> time of its last shove / smash


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_fit_length()
	var hub := Sprite2D.new()
	hub.texture = preload("res://assets/sprites/pendulum_hub.png")
	hub.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hub.z_index = 2
	add_child(hub)
	_ball_spr = Sprite2D.new()
	_ball_spr.texture = preload("res://assets/sprites/wrecking_ball.png")
	_ball_spr.centered = false
	_ball_spr.offset = Vector2(-13, -15)
	_ball_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_spr.z_index = 1
	add_child(_ball_spr)
	if has_meta("ghost"):
		_place_ball()
		return
	_ball = AnimatableBody2D.new()
	_ball.collision_layer = ORE_ONLY
	_ball.collision_mask = 0
	_ball.sync_to_physics = true
	var m := PhysicsMaterial.new()
	m.bounce = 0.3
	_ball.physics_material_override = m
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_R
	cs.shape = c
	_ball.add_child(cs)
	add_child(_ball)
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 2
	var ss := CollisionShape2D.new()
	var sc := CircleShape2D.new()
	sc.radius = BALL_R + 18.0   # wide: catch ore on the way in, before the bounce
	ss.shape = sc
	_sense.add_child(ss)
	add_child(_sense)
	_place_ball()


## Chain length: the ball's lowest point skims the ground under the pivot.
## The A-frame's feet land where rays from the pivot meet the ground.
func _fit_length() -> void:
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, L_MAX + CLEARANCE + 40), 1))
	if not hit.is_empty():
		length = clampf(hit.position.y - global_position.y - CLEARANCE, L_MIN, L_MAX)
	_legs.clear()
	for side in [-1.0, 1.0]:
		var to := global_position + Vector2(side * (length * 0.75 + 12), length + CLEARANCE + 40)
		var h := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, to, 1))
		_legs.append(to_local(h.position if not h.is_empty() else to))


func ball_pos() -> Vector2:
	return Vector2(sin(theta), cos(theta)) * length


func ball_velocity() -> Vector2:
	return Vector2(cos(theta), -sin(theta)) * length * omega


func _place_ball() -> void:
	var p := ball_pos()
	_ball_spr.position = p
	_ball_spr.rotation = -theta
	if _ball:
		_ball.position = p
		_sense.position = p
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _ball == null:
		return
	# swing: semi-implicit Euler, light damping
	omega += (-G / length * sin(theta) - DAMPING * omega) * delta
	omega = clampf(omega, -MAX_SPEED / length, MAX_SPEED / length)
	theta = wrapf(theta + omega * delta, -PI, PI)
	_place_ball()
	var now := Time.get_ticks_msec() / 1000.0
	var bp := global_position + ball_pos()
	var bv := ball_velocity()
	# ore striking the ball pushes it (it also bounces off it physically)
	for body in _sense.get_overlapping_bodies():
		var o := body as RigidBody2D
		if o == null or o.freeze:
			continue
		var n := (o.global_position - bp).normalized()
		var vn := (o.linear_velocity - bv).dot(n)
		var id := o.get_instance_id()
		# approaching and about to touch within a frame or two
		var gap := o.global_position.distance_to(bp) - BALL_R - 6.5
		if vn < -30.0 and gap < -vn * 0.035 and now - float(_last.get(id, -9.0)) > 0.25:
			_last[id] = now
			var dv := -n * absf(vn) * (1.0 + RESTITUTION) * MASS_RATIO
			omega += dv.dot(Vector2(cos(theta), -sin(theta))) / length
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 0.7)
	# smash what it swings through
	var speed := bv.length()
	if speed > HIT_SPEED:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.has_method("hit_center") or ("_dying" in e and e._dying):
				continue
			var d: float = e.hit_center().distance_to(bp)
			if d < BALL_R + e.hit_radius():
				var id: int = e.get_instance_id()
				if now - float(_last.get(id, -9.0)) < 0.5:
					continue
				_last[id] = now
				_smash(e, bv)
		var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
		if p and p.has_method("launch") and p.global_position.distance_to(bp) < BALL_R + 12 \
				and now - float(_last.get(p.get_instance_id(), -9.0)) > 0.5:
			_last[p.get_instance_id()] = now
			p.launch(bv.normalized() * minf(speed * 1.3, 520) + Vector2(0, -180))


func _smash(e: Node2D, bv: Vector2) -> void:
	var speed := bv.length()
	var dmg := clampi(int(speed / 70.0), 1, 8)
	hits += 1
	if e.has_method("knock"):
		e.knock(Vector2(signf(bv.x) * minf(speed * 1.2, 520.0), -minf(speed * 0.6, 300.0)))
	e.take_damage(dmg)
	omega *= 0.75   # it gives up some swing to the blow
	var at: Vector2 = e.hit_center()
	FX.burst(get_parent(), at, Color(1.0, 0.85, 0.5), 8, 140.0, 0.25, 1.5)
	FX.shake(self, 2.0 + dmg * 0.4, 0.15)
	SFX.play(self, SFX.sfx_bumper())


# ── the A-frame and the chain ──────────────────────────────────────────

const DARK := Color(0.09, 0.07, 0.1)
const STEEL := Color(0.42, 0.44, 0.5)
const SHINE := Color(0.7, 0.74, 0.78)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	# A-frame legs behind everything (drawn here, under the sprites)
	for f in _legs:
		draw_line(Vector2.ZERO, f, DARK, 5.0)
		draw_line(Vector2.ZERO, f, STEEL.darkened(0.25), 3.0)
		draw_line(Vector2(0, 0), f, STEEL.darkened(0.05), 1.0)
		draw_rect(Rect2(f + Vector2(-4, -2), Vector2(8, 3)), DARK)
		draw_rect(Rect2(f + Vector2(-3, -2), Vector2(6, 2)), BRASS.darkened(0.3))
	if _legs.size() == 2:  # cross brace
		var a: Vector2 = _legs[0] * 0.55
		var b: Vector2 = _legs[1] * 0.55
		draw_line(a, b, DARK, 3.0)
		draw_line(a, b, STEEL.darkened(0.3), 1.0)
	# chain: links alternating face-on and edge-on down to the shackle
	var end := ball_pos() - Vector2(sin(theta), cos(theta)) * 12.0
	var d := end
	var l := d.length()
	if l < 1:
		return
	var t := d / l
	var n := t.orthogonal()
	var k := 3.0
	var i := 0
	while k < l:
		var p := t * k
		if i % 2 == 0:
			draw_line(p - t * 2.5 + n * 1.5, p + t * 2.5 + n * 1.5, DARK, 1.0)
			draw_line(p - t * 2.5 - n * 1.5, p + t * 2.5 - n * 1.5, DARK, 1.0)
			draw_line(p - t * 2.5 + n * 1.0, p + t * 2.5 + n * 1.0, SHINE, 1.0)
		else:
			draw_line(p - t * 2.5, p + t * 2.5, DARK, 3.0)
			draw_line(p - t * 2.0, p + t * 2.0, STEEL, 1.0)
		k += 4.0
		i += 1
