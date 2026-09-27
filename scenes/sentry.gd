extends CharacterBody2D
## Brass sentry: your own clockwork guard. Set it down and it walks a short
## beat (PATROL either side of where you put it); when an enemy walker
## comes within SIGHT it goes after it (never further than LEASH from
## home) and hammers it: a heavy blow and a shove. Enemies pressing against
## it wear it down; at 0 it winds down and slumps, its lamp dark. Drop an
## ingot on it to wind it back up to full.
## Art: tools/art/gen_sentry.py (10 frames of 40x40: 6 walk, wind-up,
## strike, recover, wound down).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const SPEED := 40.0
const CHASE := 62.0
const GRAVITY := 980.0
const MAX_HP := 30
const PATROL := 70.0
const SIGHT := 170.0
const LEASH := 190.0
const REACH := 20.0              # plus the target's radius
const HIT := 4
const COOLDOWN := 1.1
const WIND := 0.22
const CRUSH_EVERY := 1.0         # enemies in contact wear it down this often

var hp := MAX_HP
var hits := 0                    # tests
var wound_down := false
var _home := 0.0
var _dir := 1.0
var _cool := 0.0
var _swing := -1.0               # > 0 during a swing
var _victim: Node = null
var _crush := 0.0
var _spr: AnimatedSprite2D
var _lamp: PointLight2D


func _ready() -> void:
	z_index = 2
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/sentry.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 9.0, true], ["idle", [0], 1.0, true], ["windup", [6], 1.0, false],
			["strike", [7, 8], 10.0, false], ["down", [9], 1.0, false]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 40, 0, 40, 40)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-17, -39)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("idle")
	add_child(_spr)
	if has_meta("ghost"):
		return
	collision_layer = 0            # nobody bumps into it
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 30)
	cs.shape = r
	cs.position = Vector2(0, -15)
	add_child(cs)
	# an ingot dropped on it winds it back up
	var intake := Area2D.new()
	intake.collision_layer = 0
	intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var ir := RectangleShape2D.new()
	ir.size = Vector2(22, 36)
	ic.shape = ir
	ic.position = Vector2(0, -18)
	intake.add_child(ic)
	add_child(intake)
	intake.body_entered.connect(_on_intake, CONNECT_DEFERRED)
	_lamp = PointLight2D.new()
	_lamp.texture = preload("res://scripts/light_textures.gd").create_radial_light(64)
	_lamp.color = Color(0.5, 0.9, 1.0)
	_lamp.energy = 0.45
	_lamp.position = Vector2(4, -34)
	add_child(_lamp)
	add_to_group("sentries")
	_home = global_position.x


func _on_intake(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b.is_in_group("ingots") or (hp >= MAX_HP and not wound_down):
		return
	b.queue_free()
	hp = MAX_HP
	if wound_down:
		wound_down = false
		_spr.play("idle")
		_lamp.energy = 0.45
	SFX.play(self, SFX.sfx_ammo_received(), 0.0, 1.1)
	FX.burst(get_parent(), global_position + Vector2(0, -24), Color(0.6, 0.9, 1.0), 10, 80.0, 0.4, 1.5)
	queue_redraw()


func _foe() -> Node2D:
	var best: Node2D = null
	var best_d := SIGHT
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or ("buried" in e and e.buried):
			continue
		if not (e is CharacterBody2D or e is RigidBody2D):
			continue                  # fliers and airships are out of reach
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if absf(c.y - (global_position.y - 16)) > 50 or absf(e.global_position.x - _home) > LEASH:
			continue
		var d := absf(e.global_position.x - global_position.x)
		if d < best_d:
			best_d = d
			best = e
	return best


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	if wound_down or _spr == null or has_meta("ghost"):
		velocity.x = 0
		move_and_slide()
		return
	_cool -= delta
	_wear(delta)
	if _swing >= 0:
		velocity.x = 0
		_swing -= delta
		if _swing < 0:
			_strike()
		move_and_slide()
		return
	var foe := _foe()
	if foe:
		var dx := foe.global_position.x - global_position.x
		_dir = signf(dx) if absf(dx) > 1 else _dir
		var reach: float = REACH + (foe.hit_radius() if foe.has_method("hit_radius") else 10.0)
		if absf(dx) < reach:
			velocity.x = 0
			if _cool <= 0:
				_victim = foe
				_swing = WIND
				_cool = COOLDOWN
				_spr.play("windup")
			elif _spr.animation == "walk":
				_spr.play("idle")
		else:
			velocity.x = CHASE * _dir
			_spr.play("walk")
	else:
		# walk the beat
		if absf(global_position.x - _home) > PATROL:
			_dir = signf(_home - global_position.x)
		velocity.x = SPEED * _dir
		if is_on_wall():
			_dir = -_dir
		_spr.play("walk")
	# never wander off its post
	if absf(global_position.x + velocity.x * delta - _home) > LEASH:
		velocity.x = 0
	_spr.flip_h = _dir < 0
	_spr.offset.x = -17 if _dir > 0 else -23
	move_and_slide()


func _strike() -> void:
	_spr.play("strike")
	if _victim == null or not is_instance_valid(_victim) or ("_dying" in _victim and _victim._dying):
		return
	var c: Vector2 = _victim.hit_center() if _victim.has_method("hit_center") else _victim.global_position
	if absf(c.x - global_position.x) > REACH + 30.0:
		return
	_victim.take_damage(HIT)
	hits += 1
	if is_instance_valid(_victim) and _victim.has_method("knock"):
		_victim.knock(Vector2(_dir * 180.0, -120.0))
	FX.burst(get_parent(), c, Color(1.0, 0.9, 0.6), 6, 100.0, 0.2, 1.4)
	SFX.play(self, SFX.sfx_ore_knock("metal"), -2.0, 0.8)


## Walkers pressing on it grind it down; at 0 it winds down where it stands.
func _wear(delta: float) -> void:
	_crush -= delta
	if _crush > 0:
		return
	_crush = CRUSH_EVERY
	var took := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not (e is CharacterBody2D or e is RigidBody2D):
			continue
		if e.global_position.distance_to(global_position) < 22.0:
			took += maxi(1, int(e.get("damage") if e.get("damage") != null else 5) / 5)
	if took > 0:
		hp -= took
		FX.damage_number(get_parent(), global_position + Vector2(0, -30), took, self)
		_spr.modulate = Color(2.2, 2.2, 2.2)
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
		queue_redraw()
		if hp <= 0:
			hp = 0
			wound_down = true
			_spr.play("down")
			_lamp.energy = 0.0
			SFX.play(self, SFX.sfx_enemy_die(), -6.0, 0.6)
			FX.burst(get_parent(), global_position + Vector2(0, -20), Color(0.8, 0.8, 0.78, 0.7), 8, 30.0, 1.0, 3.0, -40.0)


## A small bar under its feet while it's hurt.
func _draw() -> void:
	if has_meta("ghost") or hp >= MAX_HP:
		return
	draw_rect(Rect2(-10, 3, 20, 3), Color(0.08, 0.07, 0.06, 0.85))
	draw_rect(Rect2(-9, 4, 18.0 * float(hp) / MAX_HP, 1), Color(0.45, 0.85, 1.0))
