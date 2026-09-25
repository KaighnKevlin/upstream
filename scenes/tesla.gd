extends Node2D
## Tesla coil: a turret that runs on ingots. Drop ingots into its side
## hopper; each one charges it (iron more than copper). Charged, it arcs
## lightning from its electrode into the nearest enemy in range, and the
## bolt jumps on to others close by, weaker each jump. No aiming, no arc to
## miss with: it's the answer to fliers (magpies, ornithopters) that the
## funnel cannon struggles to hit. Recharges faster when a gravity wheel
## drives it. Anything that isn't an ingot bounces off the hopper.
## Art: tools/art/gen_tesla.py (4 frames of 40x70, feet at the bottom).

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const RANGE := 230.0
const CHAIN := 95.0            # how far a bolt can jump on to the next enemy
const JUMPS := 2
const DAMAGE := [4, 2, 1]      # first target, then each jump
const COOLDOWN := 1.0          # seconds between zaps at full power
const CHARGE_PER := {"copper": 4, "iron": 6}
const MAX_CHARGE := 30
const ELECTRODE := Vector2(0, -58)

var charge := 0
var zaps := 0                  # tests
var _cool := 0.0
var _spr: AnimatedSprite2D
var _intake: Area2D
var _light: PointLight2D
var _bolts := []               # [points, life]
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	var tex := preload("res://assets/sprites/tesla.png")
	sf.set_animation_speed("default", 8.0)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 40, 0, 40, 70)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-20, -69)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(96)
	_light.color = Color(0.55, 0.85, 1.0)
	_light.energy = 0.0
	_light.position = ELECTRODE
	add_child(_light)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for seg in [[Vector2(-19, -30), Vector2(-17, -22)], [Vector2(-9, -30), Vector2(-11, -22)]]:
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
	ic.position = Vector2(-14, -25)
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
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.is_in_group("ingots") and charge < MAX_CHARGE:
		charge = mini(MAX_CHARGE, charge + int(CHARGE_PER.get(b.get("kind"), 4)))
		b.queue_free()
		SFX.play(self, SFX.sfx_ammo_received())
		FX.burst(get_parent(), to_global(ELECTRODE), Color(0.6, 0.9, 1.0), 6, 60.0, 0.3, 1.2)
	else:
		(b as RigidBody2D).linear_velocity = Vector2(-140.0, -200.0)


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_cool -= delta * _rate * Tech.mult("barrels")
	# the electrode glows with the charge; it idles when empty
	_light.energy = lerpf(_light.energy, 0.15 + 0.5 * float(charge) / MAX_CHARGE if charge > 0 else 0.0, 0.1)
	if charge > 0:
		if not _spr.is_playing():
			_spr.play()
	elif _spr.is_playing():
		_spr.stop()
	if charge > 0 and _cool <= 0:
		var first = _nearest(to_global(ELECTRODE), RANGE * Tech.mult("barrels"), [])
		if first:
			_zap(first)
	for b in _bolts:
		b[1] -= delta
	_bolts = _bolts.filter(func(b): return b[1] > 0)
	queue_redraw()


func _valid(e) -> bool:
	return is_instance_valid(e) and e.has_method("take_damage") and not ("_dying" in e and e._dying)


func _center(e) -> Vector2:
	return e.hit_center() if e.has_method("hit_center") else e.global_position


func _nearest(from: Vector2, reach: float, skip: Array):
	var best = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _valid(e) or e in skip:
			continue
		var d := from.distance_to(_center(e))
		if d < best_d:
			best_d = d
			best = e
	return best


func _zap(first) -> void:
	charge -= 1
	zaps += 1
	_cool = COOLDOWN
	var from := to_global(ELECTRODE)
	var hit := []
	var target = first
	for k in JUMPS + 1:
		if target == null:
			break
		var to := _center(target)
		_bolts.append([_jagged(to_local(from), to_local(to)), 0.16])
		hit.append(target)
		target.take_damage(DAMAGE[k])
		FX.burst(get_parent(), to, Color(0.75, 0.95, 1.0), 6, 90.0, 0.2, 1.2)
		from = to
		target = _nearest(from, CHAIN, hit)
	SFX.play(self, SFX.sfx_laser())
	_light.energy = 1.4


func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := (b - a).orthogonal().normalized()
	var segs := maxi(3, int(a.distance_to(b) / 14.0))
	for k in range(1, segs):
		pts.append(a.lerp(b, float(k) / segs) + n * randf_range(-6, 6))
	pts.append(b)
	return pts


func _draw() -> void:
	for b in _bolts:
		var pts: PackedVector2Array = b[0]
		var a: float = clampf(b[1] / 0.16, 0.0, 1.0)
		draw_polyline(pts, Color(0.45, 0.8, 1.0, 0.35 * a), 5.0)
		draw_polyline(pts, Color(0.85, 0.97, 1.0, a), 1.5)
	# charge pips on the plinth
	for k in mini(charge, 10):
		draw_rect(Rect2(-9 + k * 2, -4, 1, 1), Color(0.55, 0.9, 1.0))
