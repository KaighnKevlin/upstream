extends Node2D
## Porter drone: a little brass rotor-drone from a dock (scenes/dock.gd).
## It keeps the works tidy: it looks for loose pieces lying about within
## its dock's RANGE, flies over, picks one up in its claw and delivers it:
## ingots to the dome's intake (repair stock), ore and shot to the nearest
## funnel turret's magazine (ammo). With nowhere to take a piece, it drops
## it on its dock's pad. Between jobs it hovers over the pad.
## Art: tools/art/gen_drone.py (2 frames of 22x16).

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

enum State { IDLE, FETCH, DELIVER }

const SPEED := 155.0
const CLAW := Vector2(0, 7)
const TURRET_REACH := 560.0
const CARRIES := ["copper", "iron", "shot", "grit", "scrap", "spring", "gear"]

var dock: Node2D = null
var delivered := 0               # tests
var _state := State.IDLE
var _target: RigidBody2D = null
var _carried: RigidBody2D = null
var _dest := Vector2.ZERO
var _look := 0.0
var _bob := 0.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	z_index = 3
	_bob = randf() * TAU
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 20.0)
	var tex := preload("res://assets/sprites/drone.png")
	for i in 2:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 22, 0, 22, 16)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play()
	add_child(_spr)
	var l := PointLight2D.new()
	l.texture = preload("res://scripts/light_textures.gd").create_radial_light(32)
	l.color = Color(0.5, 0.9, 1.0)
	l.energy = 0.45
	add_child(l)


func _home() -> Vector2:
	return dock.global_position + Vector2(0, -34) if is_instance_valid(dock) else global_position


func _valid(o) -> bool:
	return o != null and is_instance_valid(o) and not o.freeze and not o.has_meta("caught_by") \
		and not o.has_meta("store_material") and not o.has_meta("claimed_by") and not o.is_queued_for_deletion()


func _pick() -> RigidBody2D:
	if not is_instance_valid(dock):
		return null
	var best: RigidBody2D = null
	var best_d: float = dock.RANGE
	for group in ["ingots", "ore"]:
		for o in get_tree().get_nodes_in_group(group):
			if not _valid(o) or o.linear_velocity.length() > 30.0:
				continue
			if group == "ore" and not (o.get("kind") in CARRIES):
				continue
			var d: float = o.global_position.distance_to(dock.global_position)
			var on_pad: bool = absf(o.global_position.x - dock.global_position.x) < 20 and o.global_position.y < dock.global_position.y - 6
			if d < best_d and not on_pad:   # (what's on its own pad has nowhere to go)
				best_d = d
				best = o
	return best


## Where a piece goes: ingots to the dome, the rest to a turret's funnel.
func _destination(o: RigidBody2D) -> Vector2:
	var scene := get_tree().current_scene
	if o.is_in_group("ingots"):
		var r := scene.get_node_or_null("Receiver") as Node2D
		if r:
			return r.global_position + Vector2(0, -50)
	var best = null
	var best_d := TURRET_REACH
	var bs := get_node_or_null("/root/BuildSystem")
	if bs:
		for b in bs._placed_buildings:
			if is_instance_valid(b) and b.get_script() and b.get_script().resource_path.get_file() == "funnel_turret.gd":
				var d: float = b.global_position.distance_to(global_position)
				if d < best_d:
					best_d = d
					best = b
	if best:
		return best.global_position + Vector2(0, -90)
	return _home() + Vector2(0, 14)


func _physics_process(delta: float) -> void:
	_bob += delta * 3.0
	match _state:
		State.IDLE:
			_fly(_home() + Vector2(sin(_bob) * 10.0, cos(_bob * 0.7) * 4.0), delta, 0.5)
			_look -= delta
			if _look <= 0:
				_look = 0.6
				var o := _pick()
				if o:
					_target = o
					o.set_meta("claimed_by", self)
					_state = State.FETCH
		State.FETCH:
			if not is_instance_valid(_target) or _target.freeze or _target.has_meta("caught_by"):
				_release_claim()
				_state = State.IDLE
				return
			var at := _target.global_position - CLAW
			_fly(at, delta, 1.0)
			if global_position.distance_to(at) < 6.0:
				_grab()
		State.DELIVER:
			if not is_instance_valid(_carried):
				_carried = null
				_state = State.IDLE
				return
			_fly(_dest, delta, 0.8)
			_carried.global_position = global_position + CLAW + Vector2(0, 3)
			if "_timer" in _carried:
				_carried._timer = 0.0
			if global_position.distance_to(_dest) < 6.0:
				_drop()


func _fly(to: Vector2, delta: float, k: float) -> void:
	var d := to - global_position
	var step := minf(d.length(), SPEED * k * delta)
	if d.length() > 0.01:
		global_position += d.normalized() * step
		_spr.rotation = lerpf(_spr.rotation, clampf(d.x * 0.01, -0.35, 0.35), 0.15)


func _grab() -> void:
	var o := _target
	_target = null
	o.remove_meta("claimed_by")
	o.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	o.set_deferred("freeze", true)
	o.set_meta("caught_by", self)
	_carried = o
	_dest = _destination(o)
	_state = State.DELIVER
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.6)


func _drop() -> void:
	var o := _carried
	_carried = null
	_state = State.IDLE
	if not is_instance_valid(o):
		return
	o.freeze = false
	o.remove_meta("caught_by")
	o.linear_velocity = Vector2(0, 40)
	o.sleeping = false
	delivered += 1
	FX.burst(get_parent(), global_position + CLAW, Color(0.6, 0.9, 1.0), 3, 30.0, 0.2, 1.0)


func _release_claim() -> void:
	if is_instance_valid(_target) and _target.get_meta("claimed_by", null) == self:
		_target.remove_meta("claimed_by")
	_target = null


func _exit_tree() -> void:
	_release_claim()
	if is_instance_valid(_carried):
		_carried.freeze = false
		_carried.remove_meta("caught_by")
