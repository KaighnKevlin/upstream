extends CharacterBody2D

enum EnemyType { TITAN, SCUTTLER, SOLDIER, CASTER, ORNITHOPTER }

@export var enemy_type: EnemyType = EnemyType.TITAN
@export var speed: float = 60.0
@export var hp: int = 3
@export var damage: int = 10

var direction: float = -1.0
var _shoot_timer: float = 0.0
var _shoot_cooldown: float = 2.0
var _shoot_range: float = 300.0
var _stopped := false

const GRAVITY := 980.0

const SpriteLoader = preload("res://scripts/sprite_loader.gd")
const SFX = preload("res://scripts/sfx.gd")
const ObjectSprites = preload("res://scripts/object_sprites.gd")
const FX = preload("res://scripts/fx.gd")

# Colour of the burst when each type dies
const DEATH_COLORS := {
	EnemyType.TITAN: Color(0.62, 0.48, 0.32),
	EnemyType.SCUTTLER: Color(0.72, 0.58, 0.35),
	EnemyType.SOLDIER: Color(0.92, 0.9, 0.96),
	EnemyType.CASTER: Color(0.55, 0.85, 0.9),
	EnemyType.ORNITHOPTER: Color(0.72, 0.58, 0.35),
}

var _dying := false
const POUNCE_RANGE := 78.0
const CLIMB_SPEED := {
	EnemyType.TITAN: 16.0, EnemyType.SCUTTLER: 42.0, EnemyType.SOLDIER: 26.0, EnemyType.CASTER: 30.0,
}

# Melee types walk up to the dome (or the player), stop and swing; damage
# lands on the impact frame of the "attack" animation. body_offset: how far
# the body sits left of the frame centre, leaving room in front for the
# weapon (see the generators in tools/art/).
const MELEE := {
	EnemyType.TITAN: {"damage": 12, "cooldown": 1.6, "reach_dome": 105.0, "reach_player": 58.0,
		"impact": 5, "body_offset": 12.0, "knock": Vector2(260, -240), "hit_x": 42.0, "heavy": true,
		# against the player it uses a low rising sweep instead of the chop
		"vs_player": {"anim": "sweep", "impact": 4, "knock": Vector2(380, -150), "damage": 10}},
	EnemyType.SOLDIER: {"damage": 7, "cooldown": 1.3, "reach_dome": 62.0, "reach_player": 42.0,
		"impact": 2, "body_offset": 13.0, "knock": Vector2(170, -140), "hit_x": 36.0, "heavy": false},
}
var _facing := -1.0
var _chop_cooldown := 0.0
var _chop_target: Node2D
var _attack_anim := "attack"
# Titan stomp: an area attack for a player just beyond axe reach. The
# shockwave rolls both ways along the ground; being airborne dodges it.
const STOMP := {"range": 150.0, "min": 40.0, "impact": 4, "damage": 8,
	"knock": Vector2(140, -330), "cooldown": 5.0}
var _stomp_cooldown := 2.0

var _bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# Stats per type: [speed, hp, damage, scale]
const TYPE_STATS := {
	EnemyType.TITAN:    [25.0,  15, 30, 1.0],  # slow, tanky; melee stats in MELEE
	EnemyType.SCUTTLER: [100.0, 2,  5,  1.0],  # small, fast clockwork beetle
	EnemyType.SOLDIER:  [30.0,  8,  20, 1.0],  # shield-and-spear automaton
	EnemyType.CASTER:   [35.0,  4,  0,  1.0],  # hovering tesla sentinel, shoots bolts
	EnemyType.ORNITHOPTER: [55.0, 3, 6, 1.0],  # flier; damage is per bomb
}


func setup(type: EnemyType) -> void:
	enemy_type = type
	var stats: Array = TYPE_STATS[type]
	speed = stats[0]
	hp = stats[1]
	damage = stats[2]


func _ready() -> void:
	var stats: Array = TYPE_STATS[enemy_type]
	speed = stats[0]
	hp = stats[1]
	damage = stats[2]
	var sprite_scale: float = stats[3]

	if has_node("AnimatedSprite2D"):
		var anim := $AnimatedSprite2D as AnimatedSprite2D
		anim.scale = Vector2(sprite_scale, sprite_scale)
		match enemy_type:
			EnemyType.TITAN:
				anim.sprite_frames = _create_titan_frames()
				_add_strip_anim(anim.sprite_frames, "stomp", "res://assets/sprites/titan_stomp.png", 120, 120, 8, 10.0)
				anim.offset.y = -49
				anim.frame_changed.connect(_on_melee_frame)
				# Bigger collision box for titan (new shape, don't modify shared one)
				var titan_shape := RectangleShape2D.new()
				titan_shape.size = Vector2(40, 60)
				$CollisionShape2D.shape = titan_shape
				# enemies stand on real ground now (the old invisible platform sat
				# 19px higher); shapes moved down so sprites keep their place
				$CollisionShape2D.position.y = -19
			EnemyType.SCUTTLER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/scuttler_walk.png", 44, 36, 6, 14.0)
				_add_strip_anim(anim.sprite_frames, "pounce", "res://assets/sprites/scuttler_pounce.png", 44, 36, 6, 12.0)
				anim.offset.y = -3
			EnemyType.SOLDIER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/soldier_walk.png", 60, 50, 8, 10.0)
				_add_strip_anim(anim.sprite_frames, "attack", "res://assets/sprites/soldier_attack.png", 60, 50, 6, 12.0)
				_add_strip_anim(anim.sprite_frames, "death", "res://assets/sprites/soldier_death.png", 60, 50, 7, 11.0)
				if ResourceLoader.exists("res://assets/sprites/soldier_idle.png"):
					anim.sprite_frames.remove_animation("idle")
					_add_strip_anim(anim.sprite_frames, "idle", "res://assets/sprites/soldier_idle.png", 60, 50, 6, 6.0, true)
				anim.offset.y = -10
				anim.frame_changed.connect(_on_melee_frame)
			EnemyType.CASTER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/caster_hover.png", 40, 46, 6, 9.0)
				_add_strip_anim(anim.sprite_frames, "attack", "res://assets/sprites/caster_attack.png", 40, 46, 6, 12.0)
				_add_strip_anim(anim.sprite_frames, "death", "res://assets/sprites/caster_death.png", 40, 46, 6, 10.0)
				anim.offset.y = -8
				# its core and coils light it up
				var glow := PointLight2D.new()
				glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
				glow.color = Color(0.5, 0.85, 0.95)
				glow.energy = 0.45
				glow.position = Vector2(0, -20)
				add_child(glow)
			EnemyType.ORNITHOPTER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/ornithopter.png", 48, 32, 6, 12.0)
				anim.offset = Vector2(2, 0)
				$CollisionShape2D.set_deferred("disabled", true)  # flies over everything
				_fly_y = FLY_ALTITUDE + randf_range(-12, 12)
		anim.play("walk")


# Ornithopter: flies at altitude toward the dome, drops a bomb each pass,
# turns round beyond it and comes back.
const FLY_ALTITUDE := -30.0
const BOMB_COOLDOWN := 2.4
var _fly_y := FLY_ALTITUDE
var _fly_t := 0.0
var _bomb_cooldown := 0.0


func _flyer_process(delta: float) -> void:
	_fly_t += delta
	_bomb_cooldown -= delta
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	if dome:
		var dx := global_position.x - dome.global_position.x
		if dx * direction > 110:  # overshot the dome: come about
			direction = -direction
		if absf(dx) < 26 and _bomb_cooldown <= 0:
			_bomb_cooldown = BOMB_COOLDOWN
			var b: Node2D = preload("res://scenes/bomb.gd").new()
			b.global_position = global_position + Vector2(0, 9)
			b.velocity = Vector2(direction * speed * 0.6, 0)
			b.damage = damage
			get_parent().add_child(b)
	global_position.x += direction * speed * delta
	global_position.y = lerpf(global_position.y, _fly_y + sin(_fly_t * 2.2) * 5.0, 0.05)
	$AnimatedSprite2D.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	if enemy_type == EnemyType.ORNITHOPTER:
		_flyer_process(delta)
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	# Walked into a wall (a pit side, a ledge): claw up it, slowly. Pits and
	# spikes slow enemies down; they don't hold them forever.
	if is_on_wall() and not _dying:
		velocity.y = -CLIMB_SPEED.get(enemy_type, 25.0)

	# Melee types walk until something is in reach, then attack
	if MELEE.has(enemy_type):
		_melee_process(delta)
		move_and_slide()
		return

	# Scuttlers leap onto the dome and blow themselves up against it
	if enemy_type == EnemyType.SCUTTLER and is_on_floor():
		var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
		if dome and absf(dome.global_position.x - global_position.x) < POUNCE_RANGE:
			_pounce(dome)
			return

	# Wizard stops at range and shoots
	if enemy_type == EnemyType.CASTER:
		var target := _find_nearest_target()
		if target and global_position.distance_to(target.global_position) < _shoot_range:
			_stopped = true
			velocity.x = 0
			_shoot_timer += delta
			if _shoot_timer >= _shoot_cooldown:
				_shoot_timer = 0.0
				_shoot_at(target)
		else:
			_stopped = false
			velocity.x = speed * direction
	else:
		velocity.x = speed * direction

	move_and_slide()

	if has_node("AnimatedSprite2D"):
		# the new clockwork sprites face right; the old sheets face left
		var faces_right := enemy_type == EnemyType.SCUTTLER or enemy_type == EnemyType.CASTER
		$AnimatedSprite2D.flip_h = (direction < 0) if faces_right else (direction > 0)
		if enemy_type == EnemyType.CASTER:
			# hovers: keep the hover loop going unless mid-discharge
			var a := $AnimatedSprite2D as AnimatedSprite2D
			if not (a.animation == "attack" and a.is_playing()):
				a.play("walk")
		elif is_on_floor() and abs(velocity.x) > 5:
			$AnimatedSprite2D.play("walk")


# where hits land on each body (sparks, chips), relative to the origin
const HIT_Y := {
	EnemyType.TITAN: -45.0, EnemyType.SCUTTLER: -10.0, EnemyType.SOLDIER: -16.0,
	EnemyType.CASTER: -18.0, EnemyType.ORNITHOPTER: 0.0,
}


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	var at := global_position + Vector2(0, HIT_Y.get(enemy_type, -10.0))
	FX.burst(get_parent(), at, Color(1, 0.9, 0.5), 4, 70.0, 0.25, 1.5)
	if has_node("AnimatedSprite2D"):
		_hit_react(amount, at)
	if hp <= 0:
		SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
		_die()
	else:
		SFX.play(self, SFX.sfx_enemy_hit())


## Hit feedback: a white flash (a red tint just muddied the bronze), a jolt
## away from the side it's facing, brass chips on heavier hits, and the
## titan rocks back a little when it isn't mid-swing.
func _hit_react(amount: int, at: Vector2) -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	FX.flash(sprite, Color(2.4, 2.3, 2.1), 0.14)
	var facing := _facing if MELEE.has(enemy_type) else direction
	var push := -signf(facing) if facing != 0 else 1.0
	var jolt := create_tween()
	jolt.tween_property(sprite, "position:x", push * (1.0 if enemy_type == EnemyType.TITAN else 2.0), 0.04)
	jolt.tween_property(sprite, "position:x", 0.0, 0.1)
	if amount >= 2 or randf() < 0.25:
		FX.debris(get_parent(), at, 1, 120.0, false)
	if enemy_type == EnemyType.TITAN:
		var swinging := sprite.animation in ["attack", "sweep", "stomp"] and sprite.is_playing()
		if not swinging:
			var rock := create_tween()
			rock.tween_property(sprite, "rotation", -0.05 * signf(facing), 0.06)
			rock.tween_property(sprite, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)


func _die() -> void:
	# Leave the group at once so turrets/bullets stop targeting the corpse
	_dying = true
	remove_from_group("enemies")
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if enemy_type == EnemyType.TITAN and $AnimatedSprite2D.sprite_frames.has_animation("death"):
		_titan_die()
		return
	if enemy_type == EnemyType.SOLDIER and $AnimatedSprite2D.sprite_frames.has_animation("death"):
		_soldier_die()
		return
	if enemy_type == EnemyType.CASTER and $AnimatedSprite2D.sprite_frames.has_animation("death"):
		_caster_die()
		return
	if enemy_type == EnemyType.ORNITHOPTER:
		_flier_crash()
		return
	var body_y := -10.0
	# the mechanism comes apart
	var bits := {EnemyType.SCUTTLER: 5, EnemyType.SOLDIER: 7, EnemyType.CASTER: 6}
	FX.debris(get_parent(), global_position + Vector2(0, -14), bits.get(enemy_type, 5), 170.0,
		enemy_type != EnemyType.SOLDIER)
	FX.burst(get_parent(), global_position + Vector2(0, body_y), DEATH_COLORS[enemy_type],
		18 if enemy_type != EnemyType.TITAN else 40, 140.0, 0.7, 2.5)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.pause()
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3, 0), 0.25)
	tween.tween_property(sprite, "scale", sprite.scale * Vector2(1.3, 0.6), 0.25)
	tween.chain().tween_callback(queue_free)


func _titan_die() -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.play("death")
	# the core bursts: steam and cyan sparks, then it keels over
	FX.burst(get_parent(), global_position + Vector2(0, -45), Color(0.55, 0.85, 0.9), 14, 150.0, 0.5, 2.0)
	FX.burst(get_parent(), global_position + Vector2(0, -40), Color(0.85, 0.85, 0.8, 0.8), 10, 50.0, 1.0, 3.0, -60.0)
	FX.shake(self, 3.0, 0.2)
	FX.debris(get_parent(), global_position + Vector2(0, -45), 8, 200.0)  # gears spill from the core
	await sprite.animation_finished
	FX.burst(get_parent(), global_position + Vector2(_facing * 20, 8), Color(0.55, 0.45, 0.35), 18, 110.0, 0.6, 2.5)
	FX.shake(self, 4.0, 0.2)
	await get_tree().create_timer(1.4).timeout
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _soldier_die() -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.play("death")
	# a few gears shake loose; the rest of it keels over
	FX.debris(get_parent(), global_position + Vector2(0, -14), 3, 140.0, false)
	FX.burst(get_parent(), global_position + Vector2(0, -16), Color(0.55, 0.85, 0.9), 8, 110.0, 0.35, 1.5)
	await sprite.animation_finished
	FX.burst(get_parent(), global_position + Vector2(_facing * 14, 8), Color(0.55, 0.45, 0.35), 10, 80.0, 0.5, 2.0)
	FX.burst(get_parent(), global_position + Vector2(_facing * 6, -2), Color(0.85, 0.85, 0.8, 0.7), 5, 30.0, 1.0, 2.5, -50.0)
	await get_tree().create_timer(1.2).timeout
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _caster_die() -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.play("death")
	FX.burst(get_parent(), global_position + Vector2(0, -18), Color(0.7, 0.95, 1.0), 14, 150.0, 0.35, 1.5)
	var light := get_node_or_null("PointLight2D") as PointLight2D
	for c in get_children():
		if c is PointLight2D:
			light = c
	if light:  # the core gutters out
		var lt := create_tween()
		lt.tween_property(light, "energy", 1.6, 0.08)
		lt.tween_property(light, "energy", 0.0, 0.3)
	await sprite.animation_finished
	FX.burst(get_parent(), global_position + Vector2(0, 6), Color(0.55, 0.45, 0.35), 10, 80.0, 0.5, 2.0)
	FX.debris(get_parent(), global_position + Vector2(0, -8), 3, 120.0)
	await get_tree().create_timer(1.0).timeout
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


## Shot down: wings stall, it trails smoke, noses over and spirals into the
## ground (or off the map), then bursts into gears.
func _flier_crash() -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.speed_scale = 0.35  # wings sputter
	FX.burst(get_parent(), global_position, Color(1.0, 0.75, 0.35), 10, 110.0, 0.3, 1.5)
	var vel := Vector2(direction * speed * 0.8, -40.0)
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	var smoke_t := 0.0
	var t := 0.0
	while t < 4.0:
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		t += dt
		vel.y += 420.0 * dt
		global_position += vel * dt
		# nose over toward the direction of travel
		sprite.rotation = lerp_angle(sprite.rotation, vel.angle() if direction > 0 else vel.angle() - PI, 0.12)
		smoke_t -= dt
		if smoke_t <= 0:
			smoke_t = 0.05
			FX.burst(get_parent(), global_position, Color(0.35, 0.33, 0.32, 0.7), 1, 10.0, 0.7, 3.0, -30.0)
		var hit_ground := tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position + Vector2(0, 6)))) != -1
		if hit_ground or global_position.y > 1400:
			break
	FX.burst(get_parent(), global_position, Color(1.0, 0.75, 0.35), 16, 150.0, 0.4, 2.0)
	FX.burst(get_parent(), global_position, Color(0.55, 0.45, 0.35), 12, 90.0, 0.6, 2.5)
	FX.debris(get_parent(), global_position + Vector2(0, -6), 6, 180.0, false)
	FX.shake(self, 3.0, 0.15)
	queue_free()


## Crouch, leap in an arc onto the dome's flank, overload and burst.
## Committed once it jumps: it leaves "enemies", so turrets and the dome
## zone ignore it, and the damage comes from the blast instead.
func _pounce(dome: Node2D) -> void:
	_dying = true
	remove_from_group("enemies")
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.play("pounce")
	var side := signf(global_position.x - dome.global_position.x)
	var start := global_position
	var end := Vector2(dome.global_position.x + side * 30.0, dome.global_position.y + 8.0)
	await get_tree().create_timer(0.17).timeout  # crouch
	var tween := create_tween()
	tween.tween_method(func(t: float):
		global_position = start.lerp(end, t) + Vector2(0, -34.0 * 4.0 * t * (1.0 - t)),
		0.0, 1.0, 0.33)
	await tween.finished
	_detonate()


func _detonate() -> void:
	var at := global_position + Vector2(0, -12)
	FX.burst(get_parent(), at, Color(0.7, 0.95, 1.0), 22, 190.0, 0.4, 2.0)
	FX.burst(get_parent(), at, Color(1.0, 0.75, 0.35), 14, 130.0, 0.5, 2.5)
	FX.burst(get_parent(), at, Color(0.8, 0.8, 0.78, 0.7), 8, 40.0, 1.1, 3.0, -50.0)
	FX.debris(get_parent(), at, 5, 200.0, false)
	var flash := PointLight2D.new()
	flash.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
	flash.color = Color(0.6, 0.9, 1.0)
	flash.energy = 2.2
	flash.global_position = at
	get_parent().add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "energy", 0.0, 0.35)
	ft.tween_callback(flash.queue_free)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	if get_tree().current_scene.has_method("damage_dome"):
		get_tree().current_scene.damage_dome(damage)
	queue_free()


func _find_nearest_target() -> Node2D:
	var best: Node2D = null
	var best_dist := 99999.0

	# Check player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		# Fallback: find the player node directly
		var scene := get_tree().current_scene
		if scene and scene.has_node("Player"):
			var p := scene.get_node("Player") as Node2D
			var d := global_position.distance_to(p.global_position)
			if d < best_dist:
				best_dist = d
				best = p

	for p in players:
		var d: float = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p

	# Check dome zone
	var scene := get_tree().current_scene
	if scene and scene.has_node("DomeZone"):
		var dome := scene.get_node("DomeZone") as Node2D
		var d := global_position.distance_to(dome.global_position)
		if d < best_dist:
			best_dist = d
			best = dome

	return best


func _shoot_at(target: Node2D) -> void:
	SFX.play(self, SFX.sfx_enemy_hit())

	var eye := global_position + Vector2(0, -18)
	var dir: Vector2 = (target.global_position - eye).normalized()
	var bullet := _bullet_scene.instantiate()
	bullet.global_position = eye + dir * 10
	bullet.velocity = dir * 200.0
	bullet.damage = 8
	get_tree().current_scene.add_child(bullet)

	# Attack animation
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("attack")


func _melee_process(delta: float) -> void:
	var anim := $AnimatedSprite2D as AnimatedSprite2D
	_chop_cooldown -= delta
	_stomp_cooldown -= delta
	var swinging := anim.animation == _attack_anim and anim.is_playing()
	var m: Dictionary = MELEE[enemy_type]
	var target := _melee_target(m)
	var stomp_at := _stomp_target() if not swinging else null
	if swinging:
		velocity.x = 0
	elif stomp_at and not (target and target.is_in_group("player")):
		velocity.x = 0
		_facing = signf(stomp_at.global_position.x - global_position.x)
		_stomp_cooldown = STOMP.cooldown
		_chop_cooldown = maxf(_chop_cooldown, 0.6)
		_attack_anim = "stomp"
		anim.play("stomp")
	elif target:
		velocity.x = 0
		_facing = signf(target.global_position.x - global_position.x)
		if _chop_cooldown <= 0:
			_chop_target = target
			_chop_cooldown = m.cooldown
			_attack_anim = "attack"
			if target.is_in_group("player") and m.has("vs_player") \
					and anim.sprite_frames.has_animation(m.vs_player.anim):
				_attack_anim = m.vs_player.anim
			anim.play(_attack_anim)
		else:
			anim.play("idle")
	else:
		velocity.x = speed * direction
		_facing = signf(direction)
		anim.play("walk")
	# sprite faces right; keep the body (not the frame centre) on the origin
	anim.flip_h = _facing < 0
	anim.offset.x = m.body_offset if _facing > 0 else -m.body_offset


func _stomp_target() -> Node2D:
	if enemy_type != EnemyType.TITAN or _stomp_cooldown > 0 \
			or not $AnimatedSprite2D.sprite_frames.has_animation("stomp"):
		return null
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if player == null or not player.is_on_floor():
		return null
	var dx := absf(player.global_position.x - global_position.x)
	if dx > STOMP.min and dx < STOMP.range and absf(player.global_position.y - global_position.y) < 40:
		return player
	return null


func _on_stomp() -> void:
	var ground := global_position + Vector2(_facing * 10, 10)
	FX.shake(self, 7.0, 0.35)
	FX.burst(get_parent(), ground, Color(0.55, 0.45, 0.35), 24, 140.0, 0.6, 2.5)
	FX.burst(get_parent(), ground + Vector2(0, -4), Color(0.7, 0.95, 1.0), 8, 180.0, 0.25, 1.5, 0.0)
	SFX.play(self, SFX.sfx_mine_break())
	var tex := preload("res://assets/sprites/shockwave.png")
	for dir in [-1.0, 1.0]:
		var w := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 12.0)
		sf.set_animation_loop("default", false)
		for i in 5:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 48, 0, 48, 24)
			sf.add_frame("default", a)
		w.sprite_frames = sf
		w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		w.flip_h = dir < 0
		w.z_index = 2
		# frame bottom on the ground surface (the titan's feet are ~8px below its origin)
		w.global_position = Vector2(ground.x + dir * 26, global_position.y - 4)
		get_parent().add_child(w)
		w.play()
		var t := w.create_tween()
		t.tween_property(w, "global_position:x", ground.x + dir * STOMP.range, 0.42)
		t.parallel().tween_property(w, "modulate:a", 0.0, 0.42).set_delay(0.18)
		t.tween_callback(w.queue_free)
	# the wave catches anyone standing on the ground in range
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if player and player.is_on_floor() \
			and absf(player.global_position.x - global_position.x) < STOMP.range \
			and absf(player.global_position.y - global_position.y) < 40:
		var away := signf(player.global_position.x - global_position.x)
		player.take_damage(STOMP.damage)
		player.launch(Vector2(away * STOMP.knock.x, STOMP.knock.y))


func _melee_target(m: Dictionary) -> Node2D:
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as Node2D
	if player and absf(player.global_position.x - global_position.x) < m.reach_player \
			and absf(player.global_position.y - global_position.y) < 60:
		return player
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	if dome and absf(dome.global_position.x - global_position.x) < m.reach_dome:
		return dome
	return null


func _on_melee_frame() -> void:
	var anim := $AnimatedSprite2D as AnimatedSprite2D
	if _attack_anim == "stomp":
		if not _dying and anim.animation == "stomp" and anim.frame == STOMP.impact:
			_on_stomp()
		return
	var m: Dictionary = MELEE[enemy_type]
	if _attack_anim != "attack":
		m = m.merged(m.vs_player, true)  # the variant's impact frame, knockback, damage
	if _dying or anim.animation != _attack_anim or anim.frame != m.impact:
		return
	var hit := global_position + Vector2(_facing * m.hit_x, 10 if m.heavy else -8)
	if m.heavy:  # axe into the ground: dust, sparks, big shake
		FX.burst(get_parent(), hit, Color(0.55, 0.45, 0.35), 16, 120.0, 0.5, 2.5)
		FX.burst(get_parent(), hit + Vector2(0, -6), Color(0.85, 0.95, 1.0), 6, 160.0, 0.2, 1.5, 0.0)
		FX.shake(self, 5.0, 0.25)
		SFX.play(self, SFX.sfx_mine_break())
	else:  # spear thrust: a glint at the tip
		FX.burst(get_parent(), hit, Color(0.85, 0.95, 1.0), 5, 90.0, 0.15, 1.5, 0.0)
		SFX.play(self, SFX.sfx_enemy_hit())
	if not is_instance_valid(_chop_target):
		return
	if _chop_target.has_method("take_damage"):
		_chop_target.take_damage(m.damage)
		if _chop_target.has_method("launch"):
			var k: Vector2 = m.knock
			_chop_target.launch(Vector2(_facing * k.x, k.y))
	elif get_tree().current_scene.has_method("damage_dome"):
		get_tree().current_scene.damage_dome(m.damage)


func _add_strip_anim(sf: SpriteFrames, anim_name: String, path: String, fw: int, fh: int,
		count: int, fps: float, loop := false) -> void:
	var tex := load(path) as Texture2D
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim_name, atlas)


## SpriteFrames from a horizontal strip: "walk" (all frames) and "idle" (first).
func _strip_frames(path: String, fw: int, fh: int, count: int, fps: float) -> SpriteFrames:
	var tex := load(path) as Texture2D
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in ["walk", "idle"]:
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		for i in (count if anim_name == "walk" else 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame(anim_name, atlas)
	return sf


func _create_titan_frames() -> SpriteFrames:
	var walk := load("res://assets/sprites/titan_walk.png") as Texture2D
	var attack := load("res://assets/sprites/titan_attack.png") as Texture2D
	var idle := load("res://assets/sprites/titan_idle.png") as Texture2D
	var death := load("res://assets/sprites/titan_death.png") as Texture2D
	if walk == null or attack == null:
		return _create_titan_frames_old()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fw := 120
	var fh := 120
	var specs := [["walk", walk, 8, 8.0, true], ["attack", attack, 8, 11.0, false]]
	var sweep := load("res://assets/sprites/titan_sweep.png") as Texture2D
	if sweep:
		specs.append(["sweep", sweep, 8, 12.0, false])
	specs.append(["idle", idle, 6, 6.0, true] if idle else ["idle", walk, 1, 4.0, true])
	if death:
		specs.append(["death", death, 8, 10.0, false])
	for spec in specs:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[3])
		sf.set_animation_loop(spec[0], spec[4])
		for i in spec[2]:
			var atlas := AtlasTexture.new()
			atlas.atlas = spec[1]
			atlas.region = Rect2(i * fw, 0, fw, fh)
			atlas.filter_clip = true
			sf.add_frame(spec[0], atlas)
	return sf


func _create_titan_frames_old() -> SpriteFrames:
	var tex := load("res://assets/sprites/titan-walking-sheet.png") as Texture2D
	if tex == null:
		return SpriteLoader.create_slime_frames()
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var fw := 64
	var fh := 96

	# Walk: 2 frames
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 4.0)
	sf.set_animation_loop("walk", true)
	for i in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * fw, 0, fw, fh)
		atlas.filter_clip = true
		sf.add_frame("walk", atlas)

	# Reuse for other anims
	for anim_name in ["idle", "jump", "attack", "damage", "death"]:
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 4.0)
		sf.set_animation_loop(anim_name, anim_name != "death")
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, 0, fw, fh)
		atlas.filter_clip = true
		sf.add_frame(anim_name, atlas)

	return sf
