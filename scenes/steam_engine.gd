extends Node2D
## Steam engine: the second power source (the gravity wheel is the first).
## Drop ore into its funnel and it burns it as fuel (copper, iron, scrap,
## grit, gears, springs: some burn longer than others, up to MAX_FUEL
## seconds banked); while the fire's lit it drives every machine in reach
## at full power over leather belts (scripts/power.gd), where a wheel
## needs a steady stream falling through it. The flywheel spins up when it
## lights and runs down when the fuel's gone. Smoke from the chimney,
## firelight from the grate.
## Art: tools/art/gen_engine.py (4 frames of 56x48).

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const FUEL := {"copper": 8.0, "iron": 14.0, "scrap": 6.0, "grit": 3.0, "gear": 5.0, "spring": 5.0, "shot": 6.0}
const MAX_FUEL := 90.0
const SPIN_UP := 0.8             # power per second while lit
const FUNNEL := Vector2(-4, -40)
const CHIMNEY := Vector2(9, -47)
const GRATE := Vector2(-20, -12)

var fuel := 0.0
var _power := 0.0
var _users: Array = []
var _scan := 0.0
var _smoke := 0.0
var _belt_phase := 0.0
var _spr: AnimatedSprite2D
var _fire: PointLight2D
var _glow: Node2D


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 10.0)
	var tex := preload("res://assets/sprites/engine.png")
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 56, 0, 56, 48)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-28, -47)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")
	var intake := Area2D.new()
	intake.collision_layer = 0
	intake.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 10)
	cs.shape = r
	cs.position = FUNNEL + Vector2(0, 4)
	intake.add_child(cs)
	add_child(intake)
	intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)
	_fire = PointLight2D.new()
	_fire.texture = preload("res://scripts/light_textures.gd").create_radial_light(64)
	_fire.color = Color(1.0, 0.55, 0.2)
	_fire.energy = 0.0
	_fire.texture_scale = 1.4
	_fire.position = GRATE
	add_child(_fire)
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = mat
	_glow.z_index = 2
	_glow.draw.connect(func():
		if fuel > 0:
			var f := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.02)
			_glow.draw_rect(Rect2(GRATE + Vector2(-3, -3), Vector2(6, 6)), Color(1.0, 0.55 + 0.2 * f, 0.15, 0.9)))
	add_child(_glow)


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


func power() -> float:
	return _power


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.freeze or b.has_meta("caught_by"):
		return
	var k = b.get("kind")
	if b.is_in_group("ore") and FUEL.has(k) and fuel < MAX_FUEL:
		fuel = minf(MAX_FUEL, fuel + FUEL[k])
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -8.0, 0.8)
		FX.burst(get_parent(), global_position + GRATE, Color(1.0, 0.6, 0.2), 5, 50.0, 0.3, 1.4, -30.0)
	else:
		(b as RigidBody2D).linear_velocity = Vector2(-120.0, -220.0)   # won't burn: tossed back out


func _physics_process(delta: float) -> void:
	if _fire == null:
		return
	if fuel > 0:
		fuel = maxf(0.0, fuel - delta)
		_power = minf(1.0, _power + SPIN_UP * delta)
	else:
		_power = maxf(0.0, _power - 0.5 * delta)
	_fire.energy = lerpf(_fire.energy, 0.9 if fuel > 0 else 0.0, 0.1)
	_spr.speed_scale = _power
	if _power > 0.02:
		if not _spr.is_playing():
			_spr.play()
	elif _spr.is_playing():
		_spr.stop()
	_smoke -= delta
	if fuel > 0 and _smoke <= 0:
		_smoke = 0.35
		FX.burst(get_parent(), global_position + CHIMNEY, Color(0.45, 0.43, 0.42, 0.55), 2, 14.0, 1.6, 3.4, -50.0)
	_scan -= delta
	if _scan <= 0:
		_scan = 0.5
		_users.clear()
		for u in get_tree().get_nodes_in_group("power_users"):
			if is_instance_valid(u) and u != self and u.global_position.distance_to(global_position) <= Power.REACH:
				_users.append(u)
	_belt_phase = fmod(_belt_phase + _power * 30.0 * delta, 8.0)
	_glow.queue_redraw()
	queue_redraw()


const LEATHER := Color(0.36, 0.24, 0.16)
const LEATHER_HI := Color(0.55, 0.38, 0.25)
const DARK := Color(0.09, 0.07, 0.1)
const BRASS := Color(0.85, 0.62, 0.28)


## Drive belts to the machines it powers (as the gravity wheel draws them),
## from the flywheel, and a fuel gauge on the boiler.
func _draw() -> void:
	if _fire == null:
		return
	var hub := Vector2(17, -16)
	for u in _users:
		if not is_instance_valid(u) or _power < 0.02:
			continue
		var to := to_local(u.global_position)
		var d := (to - hub).normalized()
		var n := d.orthogonal() * 2.0
		for side in [-1.0, 1.0]:
			draw_line(hub + n * side, to + n * side, DARK, 2.0)
			draw_line(hub + n * side, to + n * side, LEATHER, 1.0)
		var l := (to - hub).length()
		var k := _belt_phase
		while k < l:
			draw_rect(Rect2((hub + d * k + n).round(), Vector2(1, 1)), LEATHER_HI)
			k += 8.0
		draw_circle(to, 3.0, DARK)
		draw_circle(to, 2.0, BRASS)
	# fuel gauge: a little bar on the boiler's side
	draw_rect(Rect2(Vector2(-14, -4), Vector2(18, 3)), DARK)
	draw_rect(Rect2(Vector2(-13, -3), Vector2(16.0 * fuel / MAX_FUEL, 1)), Color(1.0, 0.6, 0.2))
