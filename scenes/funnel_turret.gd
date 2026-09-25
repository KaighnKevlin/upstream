extends Node2D
## Funnel turret: bounce ore into the funnel; it stacks in the magazine tube
## and the cannon below fires the ore itself at the nearest enemy, on a
## ballistic arc (leading moving targets). The shot is a real ore chunk: it
## hurts what it hits (ore.gd) and lands where it lands.
## Geometry matches tools/art/gen_traps.py (origin = barrel pivot).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const OreStore = preload("res://scripts/ore_store.gd")

const MAG_HALF := 9.0
const MAG_TOP := -60.0
const MAG_BOTTOM := -10.0     # the breech gate
const SPEED := 600.0   # max flat reach = SPEED^2 / g, about 367px
const RANGE := 360.0
const FIRE_EVERY := 0.8
const MUZZLE := 21.0
const LEG_MAX := 160.0

var _store: Area2D
var _barrel: Sprite2D
var _aim := -PI / 2
var _cool := 0.0
var _flash: AnimatedSprite2D
var _agitate := 0.0
var _shake := 14.0          # feeder strength; escalates while nothing drops
var _last_in_tube := 0
const MAG_HOLDS := 3        # ore in the magazine tube below the funnel


func _ready() -> void:
	var back := _sprite("res://assets/sprites/turret_back.png", -1)
	back.offset = Vector2(0, 46 - 80)  # 60x92, origin (30, 80)
	var front := _sprite("res://assets/sprites/turret_front.png", 1)
	front.offset = back.offset
	_barrel = _sprite("res://assets/sprites/turret_barrel.png", 2)
	_barrel.centered = false
	_barrel.offset = Vector2(-5, -6)
	_barrel.rotation = _aim
	if has_meta("ghost"):
		return
	_build_legs()
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	for seg in [[Vector2(-24, -74), Vector2(-MAG_HALF, MAG_TOP)], [Vector2(24, -74), Vector2(MAG_HALF, MAG_TOP)],
			[Vector2(-MAG_HALF, MAG_TOP), Vector2(-MAG_HALF, MAG_BOTTOM)],
			[Vector2(MAG_HALF, MAG_TOP), Vector2(MAG_HALF, MAG_BOTTOM)],
			[Vector2(-MAG_HALF, MAG_BOTTOM), Vector2(MAG_HALF, MAG_BOTTOM)]]:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = seg[0]
		sh.b = seg[1]
		cs.shape = sh
		walls.add_child(cs)
	add_child(walls)
	_store = Area2D.new()
	_store.collision_layer = 0
	_store.collision_mask = 2
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(52, MAG_BOTTOM + 78)             # magazine + funnel, mouth to gate
	s.shape = r
	s.position = Vector2(0, (MAG_BOTTOM - 78) / 2.0)
	_store.add_child(s)
	add_child(_store)
	# deferred: freezing/unfreezing bodies isn't allowed inside the physics
	# callback that reports the overlap
	_store.body_entered.connect(_stack_on, CONNECT_DEFERRED)
	_store.body_exited.connect(_stack_off, CONNECT_DEFERRED)
	_flash = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 24.0)
	sf.set_animation_loop("default", false)
	var ftex := preload("res://assets/sprites/muzzle_flash.png")
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = ftex
		a.region = Rect2(i * 20, 0, 20, 16)
		sf.add_frame("default", a)
	_flash.sprite_frames = sf
	_flash.centered = false
	_flash.offset = Vector2(0, -8)
	_flash.position = Vector2(MUZZLE - 5, 0)
	_flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flash.visible = false
	_flash.animation_finished.connect(func(): _flash.visible = false)
	_barrel.add_child(_flash)


func _sprite(path: String, z: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.z_index = z
	add_child(sp)
	return sp


func _build_legs() -> void:
	var space := get_world_2d().direct_space_state
	for side in [-1.0, 1.0]:
		var top := global_position + Vector2(side * 6, 8)
		var q := PhysicsRayQueryParameters2D.create(top, top + Vector2(side * 16, LEG_MAX), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var leg := Line2D.new()
		leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
		# riveted lattice girder (tools/art/gen_traps.py strut), tiled along the leg
		leg.texture = preload("res://assets/sprites/strut.png")
		leg.texture_mode = Line2D.LINE_TEXTURE_TILE
		leg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		leg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		leg.width = 7.0
		leg.z_index = -2
		add_child(leg)


## Ore resting in the magazine, lowest first (the next shot).
func _loaded() -> Array:
	var ores := []
	for b in _store.get_overlapping_bodies():
		if b is RigidBody2D and b.is_in_group("ore") and to_local(b.global_position).y > MAG_TOP - 16:
			ores.append(b)
	ores.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
	return ores


func _physics_process(delta: float) -> void:
	if _store == null:
		return
	_cool -= delta
	OreStore.settle(_store, delta)
	_feed(delta)
	var target := _nearest_enemy()
	if target:
		var sol = _solve(target)
		if sol != null:
			_aim = sol.angle()
			if _cool <= 0 and absf(angle_difference(_barrel.rotation, _aim)) < 0.12:
				var ammo := _loaded()
				if not ammo.is_empty():
					_fire(ammo[0], sol)
	_barrel.rotation = lerp_angle(_barrel.rotation, _aim, 0.2)


## Vibratory feeder: if pieces are sitting up in the funnel while the tube
## below has room, give the pile a light shake so they drop in instead of
## wedging across the neck (the way grain arches in a real hopper).
func _feed(delta: float) -> void:
	_agitate -= delta
	if _agitate > 0:
		return
	_agitate = 0.35
	var in_tube := 0
	var in_funnel := 0
	for b in _store.get_overlapping_bodies():
		if b is RigidBody2D:
			if to_local(b.global_position).y > MAG_TOP:
				in_tube += 1
			else:
				in_funnel += 1
	if in_funnel > 0 and in_tube < MAG_HOLDS:
		# escalate while the arch holds (no new piece reached the tube)
		_shake = 14.0 if in_tube > _last_in_tube else minf(_shake * 1.6, 90.0)
		OreStore.rattle(_store, _shake)
	else:
		_shake = 14.0
	_last_in_tube = in_tube


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Launch velocity for a low arc onto the target (with one step of lead),
## or null if it's out of reach at SPEED.
func _solve(target: Node2D):
	var g := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var muzzle := global_position
	var aim_at := target.global_position + Vector2(0, -12)
	for pass_i in 2:
		var d := aim_at - muzzle
		var x := absf(d.x)
		var y := -d.y  # up is positive here
		var v2 := SPEED * SPEED
		var disc := v2 * v2 - g * (g * x * x + 2.0 * y * v2)
		if disc < 0 or x < 1.0:
			return null
		var theta := atan((v2 - sqrt(disc)) / (g * x))
		var vel := Vector2(signf(d.x) * cos(theta), -sin(theta)) * SPEED
		if pass_i == 0 and "velocity" in target:
			var t := x / maxf(1.0, SPEED * cos(theta))
			aim_at += Vector2(target.velocity.x, 0) * t
			continue
		return vel
	return null


func _fire(ore: RigidBody2D, vel: Vector2) -> void:
	_cool = FIRE_EVERY
	var dir := vel.normalized()
	OreStore.release(ore)
	ore.global_position = global_position + dir * (MUZZLE + 2)
	ore.linear_velocity = vel
	ore.angular_velocity = randf_range(-12, 12)
	_flash.visible = true
	_flash.frame = 0
	_flash.play()
	FX.burst(get_parent(), global_position + dir * MUZZLE, Color(0.8, 0.8, 0.78, 0.6), 4, 20.0, 0.8, 2.5, -40.0)
	SFX.play(self, SFX.sfx_turret_fire())
	OreStore.rattle(_store, 25.0)  # the recoil shakes the magazine: the column drops, jams clear
	var kick := create_tween()
	kick.tween_property(_barrel, "offset", Vector2(-9, -6), 0.04)
	kick.tween_property(_barrel, "offset", Vector2(-5, -6), 0.18)


## Stacking, settling and freezing of stored ore: scripts/ore_store.gd.
func _stack_on(body: Node2D) -> void:
	if is_instance_valid(body):
		OreStore.on(body, _store)


func _stack_off(body: Node2D) -> void:
	if is_instance_valid(body):
		OreStore.off(body, _store)
