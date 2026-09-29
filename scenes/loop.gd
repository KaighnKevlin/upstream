extends Node2D
## Loop-the-loop: a steel hoop stood on a rail. A marble rolling along the
## rail into the hoop's foot goes up and round it, slowing as it climbs and
## speeding up coming down, and rolls out along the rail the far side. Only
## if it's fast enough: it needs v^2 >= 5gR at the foot, or somewhere near
## the top it comes off the track and falls. Feed it off a steep drop.
## The node is the foot of the hoop; the rail runs toward `side`.
## Ore-only layer: walkers pass through.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const G := 980.0
const R := 16.0                  # the marble's centre path
const BALL := 6.5
const LOSS := 0.92               # speed kept over one lap (rolling friction)

@export var side := 1.0

var looped := 0                  # tests: marbles that went round
var fell := 0                    # and that came off
var entry_speeds: Array[int] = []   # tests
var _riders := {}                # instance id -> [body, phi, v0sq]
var _spr: Sprite2D


func _centre() -> Vector2:
	return Vector2(0, -R)


func _ready() -> void:
	z_index = 2
	# sprite first (ghosts too): hoop, stand and rail, drawn for side +1
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/loop.png")
	_spr.centered = false
	_spr.offset = Vector2(-72, -42)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.show_behind_parent = true
	_spr.scale = Vector2(side, 1)
	add_child(_spr)
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	m.bounce = 0.5
	m.friction = 1.0
	body.physics_material_override = m
	add_child(body)
	# the rail: in from behind, out the far side, a touch downhill all along
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = Vector2(-side * 70, BALL - 8)
	s.b = Vector2(side * 80, BALL + 6)
	cs.shape = s
	body.add_child(cs)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	# catch marbles rolling into the foot
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or _riders.has(o.get_instance_id()) or o.freeze or not Hold.free_to_take(o, self):
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 6 and absf(p.y) < 10 and o.linear_velocity.x * side > 150 \
				and o.get_meta("looped_until", 0.0) < Time.get_ticks_msec() / 1000.0:
			var v: float = o.linear_velocity.length()
			entry_speeds.append(int(v))
			_riders[o.get_instance_id()] = [o, 0.0, v * v]
			Hold.claim(o, self)
			o.gravity_scale = 0.0
	# carry the riders round
	for id in _riders.keys():
		var r: Array = _riders[id]
		var o = r[0]
		if not is_instance_valid(o):
			_riders.erase(id)
			continue
		var phi: float = r[1]
		var h := R * (1.0 - cos(phi))
		var vsq: float = r[2] * lerpf(1.0, LOSS, phi / TAU) - 2.0 * G * h
		# the track can only push: it needs v^2/R >= the pull of gravity away from it
		if vsq < -G * R * cos(phi) or vsq <= 0.0:
			var v := sqrt(maxf(vsq, 0.0))
			_release(o, Vector2(cos(phi) * side, -sin(phi)) * v)
			fell += 1
			o.set_meta("looped_until", Time.get_ticks_msec() / 1000.0 + 1.0)   # no re-catching it as it lands
			_riders.erase(id)
			continue
		var v := sqrt(vsq)
		phi += v / R * delta
		if phi >= TAU:
			_release(o, Vector2(side * v, 0))
			o.set_meta("looped_until", Time.get_ticks_msec() / 1000.0 + 1.0)
			looped += 1
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 1.3)
			_riders.erase(id)
			continue
		r[1] = phi
		var target := global_position + _centre() + Vector2(sin(phi) * side, cos(phi)) * R
		Hold.claim(o, self)
		o.linear_velocity = (target - o.global_position) / delta
		if "_timer" in o:
			o._timer = 0.0
	queue_redraw()


func _release(o: RigidBody2D, vel: Vector2) -> void:
	Hold.release(o, self)
	o.linear_velocity = vel


func _draw() -> void:
	_spr.scale = Vector2(side, 1)   # the hoop, stand and rail are _spr
	# riders get a speed streak
	for id in _riders:
		var o = _riders[id][0]
		if is_instance_valid(o):
			var p: Vector2 = o.global_position - global_position
			draw_line(p, p - o.linear_velocity * 0.03, Color(1.0, 0.9, 0.6, 0.5), 3.0)
