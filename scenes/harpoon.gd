extends Node2D
## Harpoon ballista: anti-air. A heavy crossbow on a turntable that fires a
## barbed harpoon on a rope at the nearest thing flying overhead (airships,
## ornithopters, magpies), then winches it down toward the ground. An
## airship dragged down low enough crashes; smaller fliers are slammed into
## the ground. Ammo: scrap or iron ingots dropped in its side hopper (one
## harpoon each). Winches faster when a gravity wheel drives it.
## Art: tools/art/gen_harpoon.py.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const Tech = preload("res://scripts/tech.gd")

const PIVOT := Vector2(0, -24)
const RANGE := 430.0
const SHOT_SPEED := 760.0
const RELOAD := 2.5
const WINCH := 70.0              # px/s down toward the ballista, unpowered; x2.2 driven
const TETHER_TIME := 7.0
const MAX_AMMO := 8

var ammo := 0
var fired := 0                   # tests
var downed := 0
var _bow: Sprite2D
var _intake: Area2D
var _aim := -PI / 2
var _reload := 0.0
var _shot_pos := Vector2.ZERO    # the harpoon in flight
var _shot_vel := Vector2.ZERO
var _flying := false
var _target: Node2D = null       # tethered
var _tether_t := 0.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	var b := Sprite2D.new()
	b.texture = preload("res://assets/sprites/harpoon_base.png")
	b.centered = false
	b.offset = Vector2(-24, -39)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(b)
	_bow = Sprite2D.new()
	_bow.texture = preload("res://assets/sprites/harpoon_bow.png")
	_bow.centered = false
	_bow.offset = Vector2(-10, -12)
	_bow.position = PIVOT
	_bow.rotation = _aim
	_bow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bow.z_index = 1
	add_child(_bow)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for seg in [[Vector2(-22, -30), Vector2(-20, -20)], [Vector2(-12, -30), Vector2(-14, -20)]]:
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
	ic.position = Vector2(-17, -25)
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
	var ok: bool = (b.is_in_group("ore") and b.get("kind") == "scrap") or (b.is_in_group("ingots") and b.get("kind") == "iron")
	if ok and ammo < MAX_AMMO:
		ammo += 1
		b.queue_free()
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -8.0, 0.8)
	else:
		(b as RigidBody2D).linear_velocity = Vector2(-130.0, -210.0)


func _is_flier(e) -> bool:
	if e.get("enemy_type") == 4:     # ornithopter
		return true
	var s = e.get_script()
	return s != null and s.resource_path.get_file() in ["airship.gd", "magpie.gd"]


func _center(e) -> Vector2:
	return e.hit_center() if e.has_method("hit_center") else e.global_position


func _pick() -> Node2D:
	var best: Node2D = null
	var best_d := RANGE
	var from := to_global(PIVOT)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not _is_flier(e):
			continue
		var c := _center(e)
		if c.y > from.y - 20:
			continue
		var d := from.distance_to(c)
		if d < best_d:
			best_d = d
			best = e
	return best


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var from := to_global(PIVOT)
	if _flying:
		_fly(delta)
	elif _target:
		_winch(delta)
	else:
		_reload -= delta * (0.5 + _rate)
		var t := _pick()
		if t:
			var c := _center(t)
			var lead: Vector2 = t.get("velocity") if t.get("velocity") != null else Vector2.ZERO
			c += lead * clampf(from.distance_to(c) / SHOT_SPEED, 0.0, 0.8)
			_aim = (c - from).angle()
			if _reload <= 0 and ammo > 0 and absf(angle_difference(_bow.rotation, _aim)) < 0.1:
				_fire(from)
	var want := _aim if not _target else (_center(_target) - from).angle()
	_bow.rotation = lerp_angle(_bow.rotation, want, 0.15)
	_bow.flip_v = cos(_bow.rotation) < 0
	queue_redraw()


func _fire(from: Vector2) -> void:
	ammo -= 1
	fired += 1
	_reload = RELOAD
	_flying = true
	_shot_pos = from + Vector2.from_angle(_aim) * 18.0
	_shot_vel = Vector2.from_angle(_aim) * SHOT_SPEED
	SFX.play(self, SFX.sfx_turret_fire(), -4.0, 1.3)


func _fly(delta: float) -> void:
	_shot_vel.y += 200.0 * delta
	_shot_pos += _shot_vel * delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not _is_flier(e):
			continue
		if _shot_pos.distance_to(_center(e)) < (e.hit_radius() if e.has_method("hit_radius") else 12.0) + 4.0:
			_flying = false
			_target = e
			_tether_t = TETHER_TIME
			e.take_damage(4)
			FX.burst(get_parent(), _shot_pos, Color(0.9, 0.85, 0.7), 6, 80.0, 0.3, 1.4)
			SFX.play(self, SFX.sfx_ore_knock("metal"), -2.0, 0.7)
			if not is_instance_valid(e) or ("_dying" in e and e._dying):
				_target = null
			return
	if _shot_pos.distance_to(to_global(PIVOT)) > RANGE * 1.3 or _shot_pos.y > global_position.y + 40:
		_flying = false     # a miss: the rope reels the harpoon back


func _winch(delta: float) -> void:
	if not is_instance_valid(_target) or ("_dying" in _target and _target._dying):
		_target = null
		return
	_tether_t -= delta
	if _tether_t <= 0:
		_target = null      # the rope parts
		SFX.play_small(self, SFX.sfx_clink(), -6.0, 0.6)
		return
	var from := to_global(PIVOT)
	var c := _center(_target)
	var pull := (from - c).normalized() * WINCH * (0.55 + 1.65 * _rate) * Tech.mult("harpoons") * delta
	_target.global_position += pull
	# dragged down to the ground: it smashes into it
	var ground := global_position.y
	if c.y > ground - 46.0:
		_target.take_damage(99)
		downed += 1
		FX.shake(self, 4.0, 0.25)
		_target = null


func _draw() -> void:
	var a := PIVOT
	if _flying:
		var b := to_local(_shot_pos)
		draw_line(a, b, Color(0.72, 0.62, 0.45), 1.0)
		var d := _shot_vel.normalized()
		draw_line(b - d * 10.0, b, Color(0.62, 0.68, 0.7), 2.0)
		draw_line(b, b - d.rotated(0.5) * 4.0, Color(0.62, 0.68, 0.7), 1.5)
		draw_line(b, b - d.rotated(-0.5) * 4.0, Color(0.62, 0.68, 0.7), 1.5)
	elif _target and is_instance_valid(_target):
		var b := to_local(_center(_target))
		draw_line(a, b, Color(0.16, 0.15, 0.12), 2.5)
		draw_line(a, b, Color(0.72, 0.62, 0.45), 1.2)
	# ammo pips
	for k in mini(ammo, 8):
		draw_rect(Rect2(-8 + k * 2, -2, 1, 1), Color(0.85, 0.72, 0.45))
