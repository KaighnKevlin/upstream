extends Node2D
## Flame turret: a furnace that burns raw ore. Drop ore in its funnel and it
## stokes the firebox (each piece is a few seconds of flame, iron longer).
## Fuelled, it swivels its nozzle at the nearest enemy in close range and
## sprays a cone of fire; anything caught in it keeps burning for a while
## after (so it's good against packs of scuttlers). Ore that lingers in the
## flame is smelted where it flies, so a flamer beside an ore stream is a
## crude smelter too. The third defence choice: cannon (ore as shot), tesla
## (ingots), flamer (ore as fuel).
## Art: tools/art/gen_flamer.py.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const Tech = preload("res://scripts/tech.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const RANGE := 125.0
const CONE := deg_to_rad(20.0)     # half-angle of the flame
const PIVOT := Vector2(6, -20)
const FUEL_PER := {"copper": 3.0, "iron": 5.0}
const MAX_FUEL := 30.0
const BURN_TIME := 2.0              # keeps burning this long after leaving the flame
const BURN_TICK := 0.4
const SMELT_AFTER := 0.15           # seconds in the flame (accumulated) to melt a piece of ore

var fuel := 0.0
var burned := 0                     # damage ticks dealt (tests)
var smelted := 0
var _spr: AnimatedSprite2D
var _nozzle: Sprite2D
var _flames: CPUParticles2D
var _light: PointLight2D
var _intake: Area2D
var _aim := 0.0
var _firing := false
var _burning := {}                  # enemy -> [time left, tick timer]
var _heat := {}                     # ore -> seconds in the flame


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/flamer.png")
	sf.set_animation_speed("default", 9.0)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 44, 0, 44, 48)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-22, -47)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_nozzle = Sprite2D.new()
	_nozzle.texture = preload("res://assets/sprites/flamer_nozzle.png")
	_nozzle.centered = false
	_nozzle.offset = Vector2(-4, -5)
	_nozzle.position = PIVOT
	_nozzle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_nozzle.z_index = 1
	add_child(_nozzle)
	if has_meta("ghost"):
		return
	_flames = CPUParticles2D.new()
	_flames.amount = 70
	_flames.lifetime = 0.42
	_flames.local_coords = false
	_flames.emitting = false
	_flames.direction = Vector2.RIGHT
	_flames.spread = rad_to_deg(CONE) * 0.8
	_flames.gravity = Vector2(0, -160)
	_flames.initial_velocity_min = 230.0
	_flames.initial_velocity_max = 300.0
	_flames.damping_min = 120.0
	_flames.damping_max = 200.0
	_flames.scale_amount_min = 2.0
	_flames.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.25, Color(1.0, 0.62, 0.2, 0.95))
	ramp.add_point(0.6, Color(0.85, 0.25, 0.08, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.25, 0.22, 0.22, 0.0))
	_flames.color_ramp = ramp
	_flames.position = Vector2(16, 0)
	_nozzle.add_child(_flames)
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(128)
	_light.color = Color(1.0, 0.6, 0.25)
	_light.energy = 0.0
	_light.texture_scale = 1.6
	_light.position = PIVOT
	add_child(_light)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for seg in [[Vector2(-9, -46), Vector2(-5, -35)], [Vector2(5, -46), Vector2(1, -35)]]:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = seg[0]
		sh.b = seg[1]
		cs.shape = sh
		body.add_child(cs)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(8, 6)
	ic.shape = ir
	ic.position = Vector2(-2, -38)
	_intake.add_child(ic)
	add_child(_intake)
	_intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.has_meta("caught_by"):
		return
	var k = b.get("kind")
	if b.is_in_group("ore") and FUEL_PER.has(k) and fuel < MAX_FUEL:
		fuel = minf(MAX_FUEL, fuel + FUEL_PER[k])
		b.queue_free()
		FX.burst(get_parent(), global_position + Vector2(-2, -44), Color(1.0, 0.6, 0.2, 0.9), 5, 50.0, 0.4, 1.5, -60.0)
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -10.0, 0.7)
	else:
		(b as RigidBody2D).linear_velocity = Vector2(-120.0, -200.0)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	var reach := RANGE * Tech.mult("barrels")
	var target = _nearest(reach) if fuel > 0 else null
	if target:
		_aim = (target.hit_center() - to_global(PIVOT)).angle() if target.has_method("hit_center") else (target.global_position - to_global(PIVOT)).angle()
	_nozzle.rotation = lerp_angle(_nozzle.rotation, _aim, 0.25)
	_nozzle.flip_v = cos(_nozzle.rotation) < 0
	var firing := target != null and absf(angle_difference(_nozzle.rotation, _aim)) < 0.35
	if firing != _firing:
		_firing = firing
		_flames.emitting = firing
		if firing:
			SFX.play(self, SFX.sfx_laser())
	_spr.speed_scale = 2.0 if firing else 1.0
	if fuel > 0 and not _spr.is_playing():
		_spr.play()
	elif fuel <= 0 and _spr.is_playing():
		_spr.stop()
	_light.energy = lerpf(_light.energy, (1.1 + randf() * 0.4) if firing else (0.25 if fuel > 0 else 0.0), 0.2)
	if firing:
		fuel = maxf(0.0, fuel - delta)
		_scorch(reach, delta)
	_tick_burns(delta)


func _in_cone(p: Vector2, reach: float) -> bool:
	var rel := p - to_global(PIVOT)
	return rel.length() < reach and absf(angle_difference(rel.angle(), _nozzle.rotation)) < CONE


func _scorch(reach: float, delta: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var at: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if _in_cone(at, reach):
			var b: Array = _burning.get(e, [0.0, 0.0])
			b[0] = BURN_TIME
			_burning[e] = b
	# ore in the flame heats up and melts into an ingot where it flies
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or not FUEL_PER.has(o.get("kind")):
			continue
		if _in_cone(o.global_position, reach):
			var t: float = _heat.get(o, 0.0) + delta
			_heat[o] = t
			if t >= SMELT_AFTER:
				_heat.erase(o)
				_smelt(o)


func _smelt(o: RigidBody2D) -> void:
	var ingot: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
	ingot.kind = "iron" if o.get("kind") == "iron" else "copper"
	ingot.global_position = o.global_position
	ingot.linear_velocity = o.linear_velocity * 0.6
	o.queue_free()
	get_tree().current_scene.add_child.call_deferred(ingot)
	smelted += 1


func _tick_burns(delta: float) -> void:
	for e in _burning.keys():
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			_burning.erase(e)
			continue
		var b: Array = _burning[e]
		b[0] -= delta
		b[1] -= delta
		if b[1] <= 0:
			b[1] = BURN_TICK
			e.take_damage(1)
			burned += 1
			var at: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
			FX.burst(get_parent(), at + Vector2(randf_range(-6, 6), 0), Color(1.0, 0.55, 0.15, 0.9), 3, 30.0, 0.5, 1.8, -90.0)
		if b[0] <= 0:
			_burning.erase(e)
	for o in _heat.keys():
		if not is_instance_valid(o):
			_heat.erase(o)


func _nearest(reach: float):
	var best = null
	var best_d := reach
	var from := to_global(PIVOT)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var at: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var d := from.distance_to(at)
		if d < best_d:
			best_d = d
			best = e
	return best
