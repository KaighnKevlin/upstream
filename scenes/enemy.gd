extends CharacterBody2D

enum EnemyType { TITAN, SCUTTLER, SOLDIER, CASTER }

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
}

var _dying := false

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

var _bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# Stats per type: [speed, hp, damage, scale]
const TYPE_STATS := {
	EnemyType.TITAN:    [25.0,  15, 30, 1.0],  # slow, tanky; melee stats in MELEE
	EnemyType.SCUTTLER: [100.0, 2,  5,  1.0],  # small, fast clockwork beetle
	EnemyType.SOLDIER:  [30.0,  8,  20, 1.0],  # shield-and-spear automaton
	EnemyType.CASTER:   [35.0,  4,  0,  1.0],  # hovering tesla sentinel, shoots bolts
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
				anim.offset.y = -49
				anim.frame_changed.connect(_on_melee_frame)
				# Bigger collision box for titan (new shape, don't modify shared one)
				var titan_shape := RectangleShape2D.new()
				titan_shape.size = Vector2(40, 60)
				$CollisionShape2D.shape = titan_shape
				$CollisionShape2D.position.y = -38
			EnemyType.SCUTTLER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/scuttler_walk.png", 44, 36, 6, 14.0)
				anim.offset.y = -3
			EnemyType.SOLDIER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/soldier_walk.png", 60, 50, 8, 10.0)
				_add_strip_anim(anim.sprite_frames, "attack", "res://assets/sprites/soldier_attack.png", 60, 50, 6, 12.0)
				anim.offset.y = -10
				anim.frame_changed.connect(_on_melee_frame)
			EnemyType.CASTER:
				anim.sprite_frames = _strip_frames("res://assets/sprites/caster_hover.png", 40, 46, 6, 9.0)
				_add_strip_anim(anim.sprite_frames, "attack", "res://assets/sprites/caster_attack.png", 40, 46, 6, 12.0)
				anim.offset.y = -8
				# its core and coils light it up
				var glow := PointLight2D.new()
				glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
				glow.color = Color(0.5, 0.85, 0.95)
				glow.energy = 0.7
				glow.position = Vector2(0, -20)
				add_child(glow)
		anim.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Melee types walk until something is in reach, then attack
	if MELEE.has(enemy_type):
		_melee_process(delta)
		move_and_slide()
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


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.burst(get_parent(), global_position + Vector2(0, -10), Color(1, 0.9, 0.5), 4, 70.0, 0.25, 1.5)
	if has_node("AnimatedSprite2D"):
		var sprite := $AnimatedSprite2D
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.05)
		var restore_color := Color.WHITE
		tween.tween_property(sprite, "modulate", restore_color, 0.1)
	if hp <= 0:
		SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
		_die()
	else:
		SFX.play(self, SFX.sfx_enemy_hit())


func _die() -> void:
	# Leave the group at once so turrets/bullets stop targeting the corpse
	_dying = true
	remove_from_group("enemies")
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if enemy_type == EnemyType.TITAN and $AnimatedSprite2D.sprite_frames.has_animation("death"):
		_titan_die()
		return
	var body_y := -10.0
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
	await sprite.animation_finished
	FX.burst(get_parent(), global_position + Vector2(_facing * 20, 8), Color(0.55, 0.45, 0.35), 18, 110.0, 0.6, 2.5)
	FX.shake(self, 4.0, 0.2)
	await get_tree().create_timer(1.4).timeout
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


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
	var swinging := anim.animation == _attack_anim and anim.is_playing()
	var m: Dictionary = MELEE[enemy_type]
	var target := _melee_target(m)
	if swinging:
		velocity.x = 0
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
