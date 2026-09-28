extends Node2D
## Bowling ramp: a tall, steep brass slide that curls down to the floor and
## ends facing the walkers' path. Ore fed into the mouth at its top runs
## down it and comes off rolling fast along the floor toward `side`, and
## bowls into whatever is walking there. What it does to a walker is the
## piece's momentum: heavy iron bowls it over (knocked back hard, a good
## bite of damage) and ploughs on into the next one; light copper just
## bumps it and bounces off. Copper glances off a tower shield, iron
## doesn't. Walkers pass through the ramp itself.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const G := 980.0
const TOP := Vector2(0, -120)      # the mouth (x flips with side)
const BEND := Vector2(2, -7)       # where the slide curls flat
const EXIT := Vector2(46, -7)      # it leaves here, a ball's radius over the floor
const MOUTH := 14.0
const DRAG := 0.92                 # the slide keeps this much of the free-fall speed
const ROLL_FOR := 4.0              # s a bowled piece is followed along the floor
const MIN_SPEED := 70.0            # slower than this it's just lying there
const PER_DAMAGE := 280.0          # momentum (mass x px/s) per point of damage
const KNOCK_PER := 0.22            # knock-back px/s per unit of momentum
const KNOCK_MAX := 320.0

@export var side := 1.0

var bowled := 0                    # tests
var hits := 0
var damage_done := 0
var last_speed := 0.0
var last_hit := {}                 # kind, momentum, damage, knock
var _riding: Array = []            # [ore, s (0..1 along the slide), speed]
var _rolling: Array = []           # [ore, time left, {enemy id: true}]
var _cool := {}
var _path := PackedVector2Array()
var _len := PackedFloat32Array()
var _built_side := 0.0
var _art: Node2D                   # the slide and trestle, drawn sending to +x; mirrored for side -1


func _p(v: Vector2) -> Vector2:
	return Vector2(v.x * side, v.y)


func _ready() -> void:
	z_index = 1
	# art first, so ghosts and build-bar icons get it too; behind our _draw
	_art = Node2D.new()
	_art.scale = Vector2(side, 1)
	_art.show_behind_parent = true
	add_child(_art)
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/bowling_ramp.png")
	spr.centered = false
	spr.offset = Vector2(-26, -146)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.add_child(spr)
	_build_path()
	if has_meta("ghost"):
		return
	add_to_group("bowling_ramps")


## The slide: straight down from the mouth, curling out flat to the exit.
func _build_path() -> void:
	_path.clear()
	_len.clear()
	_built_side = side
	var a := _p(TOP)
	var b := _p(BEND)
	var c := _p(EXIT)
	var n := 24
	var total := 0.0
	for i in n + 1:
		var t := float(i) / n
		var q := a.lerp(b, t).lerp(b.lerp(c, t), t)
		if i > 0:
			total += q.distance_to(_path[i - 1])
		_path.append(q)
		_len.append(total)


func _at(d: float) -> Vector2:
	for i in range(1, _path.size()):
		if _len[i] >= d:
			var f := inverse_lerp(_len[i - 1], _len[i], d)
			return _path[i - 1].lerp(_path[i], f)
	return _path[_path.size() - 1]


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	if _built_side != side:
		_build_path()
	var now := Time.get_ticks_msec() / 1000.0
	var mouth := global_position + _p(TOP)
	# feed: anything loose dropping into the mouth
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion() or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var d: Vector2 = o.global_position - mouth
		if absf(d.x) < MOUTH and d.y > -22 and d.y < 6:
			_cool[o.get_instance_id()] = now + 999.0
			o.gravity_scale = 0.0
			_riding.append([o, 0.0, maxf(0.0, o.linear_velocity.y) * 0.5])
			SFX.play_small(self, SFX.sfx_roll(), -16.0, 0.9)
	# down the slide: gravity along its fall, held to the rail
	var total: float = _len[_len.size() - 1]
	for r in _riding.duplicate():
		var o = r[0]
		if not is_instance_valid(o):
			_riding.erase(r)
			continue
		var p0 := _at(r[1])
		var s: float = r[1] + r[2] * delta
		var p1 := _at(minf(s, total))
		# energy: speed from the height dropped so far
		r[2] = sqrt(maxf(0.0, r[2] * r[2] + 2.0 * G * (p1.y - p0.y))) * pow(DRAG, delta)
		r[2] = maxf(r[2], 40.0)
		r[1] = s
		if "_timer" in o:
			o._timer = 0.0
		if s >= total:
			_release(o, r[2])
			_riding.erase(r)
		else:
			o.linear_velocity = (global_position + p1 - o.global_position) / delta
	# along the floor: the bowling
	for r in _rolling.duplicate():
		var o = r[0]
		r[1] -= delta
		if not is_instance_valid(o) or r[1] <= 0.0 or o.linear_velocity.length() < MIN_SPEED:
			if is_instance_valid(o):
				o.angular_damp = 1.5
			_rolling.erase(r)
			continue
		if "_hurt_cooldown" in o:
			o._hurt_cooldown = 0.1     # it's the ramp's ball now: it scores the hit
		_bowl(o, r[2])
	queue_redraw()


func _release(o: RigidBody2D, v: float) -> void:
	o.gravity_scale = 1.0
	o.global_position = global_position + _p(EXIT)
	o.linear_velocity = Vector2(side * v, 0.0)
	var rad := 6.5
	o.angular_velocity = side * v / rad
	o.angular_damp = 0.05              # rolls true until it's done bowling
	bowled += 1
	last_speed = v
	_rolling.append([o, ROLL_FOR, {}])
	_cool[o.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + 2.0
	FX.burst(get_parent(), o.global_position + Vector2(0, 5), Color(0.6, 0.5, 0.38, 0.8), 4, 50.0, 0.3, 1.4)


func _bowl(o: RigidBody2D, done: Dictionary) -> void:
	var vel := o.linear_velocity
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("hit_center") or e.get("_dying") or done.has(e.get_instance_id()):
			continue
		var c: Vector2 = e.hit_center()
		var rad: float = e.hit_radius()
		# a rolling ball meets the legs: anywhere from its middle down to the feet
		if absf(o.global_position.x - c.x) > rad * 0.7 + 7.0:
			continue
		if o.global_position.y < c.y - rad or o.global_position.y > e.global_position.y + 8.0:
			continue
		if vel.x * (c.x - o.global_position.x) <= 0.0:
			continue                   # rolling away from it
		done[e.get_instance_id()] = true
		var speed := absf(vel.x)
		var mom: float = o.mass * speed
		if e.has_method("shield_blocks") and o.mass < 2.0:
			var n: Vector2 = e.shield_blocks(o.global_position, vel)
			if n != Vector2.ZERO:
				o.linear_velocity = Vector2(-vel.x * 0.35, -60.0)
				e.shield_clang(o.global_position)
				last_hit = {"kind": o.get("kind"), "momentum": int(mom), "damage": 0, "knock": 0}
				continue
		var dmg := clampi(int(mom / PER_DAMAGE), 1, 9)
		var kx := minf(mom * KNOCK_PER, KNOCK_MAX)
		e.take_damage(dmg)
		if e.has_method("knock"):
			e.knock(Vector2(signf(vel.x) * kx, -70.0 - kx * 0.3))
		hits += 1
		damage_done += dmg
		last_hit = {"kind": o.get("kind"), "momentum": int(mom), "damage": dmg, "knock": int(kx)}
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -6.0, 0.8 if o.mass >= 2.0 else 1.3)
		if o.mass >= 2.0:
			o.linear_velocity = vel * 0.8        # heavy: bowls it over and ploughs on
			FX.burst(get_parent(), o.global_position, Color(1.0, 0.85, 0.5), 7, 110.0, 0.3, 1.4)
		else:
			o.linear_velocity = Vector2(-vel.x * 0.3, -50.0)   # light: bumps it and bounces back
			FX.burst(get_parent(), o.global_position, Color(1.0, 0.85, 0.5), 3, 60.0, 0.2, 1.0)
		return


func _draw() -> void:
	# the slide, trestle, mouth and exit lip are a sprite (see _ready)
	if _art.scale.x != side:
		_art.scale = Vector2(side, 1)
	for r in _riding:
		if is_instance_valid(r[0]):
			draw_circle(to_local(r[0].global_position), 1.5, Color(1, 0.9, 0.6, 0.6))
