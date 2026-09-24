extends CharacterBody2D

enum EnemyType { TITAN, GOBLIN, SKELETON, WIZARD }

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
	EnemyType.GOBLIN: Color(0.4, 0.72, 0.28),
	EnemyType.SKELETON: Color(0.92, 0.9, 0.96),
	EnemyType.WIZARD: Color(0.62, 0.32, 0.92),
}

var _dying := false

# Titan: walks up to the dome (or the player) and chops with its axe; damage
# lands on the impact frame of the attack animation.
const TITAN_CHOP_DAMAGE := 12
const TITAN_CHOP_COOLDOWN := 1.6
const TITAN_REACH_DOME := 105.0
const TITAN_REACH_PLAYER := 58.0
const TITAN_IMPACT_FRAME := 5
# Frames are 120px wide with the body 12px left of centre, leaving room for
# the axe in front (tools/art/gen_titan.py).
const TITAN_BODY_OFFSET := 12.0
var _facing := -1.0
var _chop_cooldown := 0.0
var _chop_target: Node2D

var _bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# Stats per type: [speed, hp, damage, scale]
const TYPE_STATS := {
	EnemyType.TITAN:    [25.0,  15, 30, 1.0],  # slow, tanky; chops for TITAN_CHOP_DAMAGE
	EnemyType.GOBLIN:   [100.0, 2,  5,  1.8],
	EnemyType.SKELETON: [30.0,  8,  20, 2.2],
	EnemyType.WIZARD:   [35.0,  4,  0,  2.0],
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
				anim.frame_changed.connect(_on_titan_frame)
				# Bigger collision box for titan (new shape, don't modify shared one)
				var titan_shape := RectangleShape2D.new()
				titan_shape.size = Vector2(40, 60)
				$CollisionShape2D.shape = titan_shape
				$CollisionShape2D.position.y = -38
			EnemyType.GOBLIN:
				anim.sprite_frames = SpriteLoader.create_goblin_frames()
				anim.modulate = Color(0.9, 0.6, 0.3)
			EnemyType.SKELETON:
				anim.sprite_frames = _create_skeleton_frames()
			EnemyType.WIZARD:
				anim.sprite_frames = _create_skeleton_frames()
				anim.modulate = Color(0.6, 0.3, 0.9)  # purple tint
		anim.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Titan walks until something is in axe reach, then chops
	if enemy_type == EnemyType.TITAN:
		_titan_process(delta)
		move_and_slide()
		return

	# Wizard stops at range and shoots
	if enemy_type == EnemyType.WIZARD:
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
		$AnimatedSprite2D.flip_h = direction > 0
		if enemy_type == EnemyType.WIZARD and _stopped:
			$AnimatedSprite2D.play("idle")
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
		if enemy_type == EnemyType.GOBLIN:
			restore_color = Color(0.9, 0.6, 0.3)
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
	var body_y := -10.0 if enemy_type != EnemyType.TITAN else -40.0
	FX.burst(get_parent(), global_position + Vector2(0, body_y), DEATH_COLORS[enemy_type],
		18 if enemy_type != EnemyType.TITAN else 40, 140.0, 0.7, 2.5)
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	sprite.pause()
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3, 0), 0.25)
	tween.tween_property(sprite, "scale", sprite.scale * Vector2(1.3, 0.6), 0.25)
	tween.chain().tween_callback(queue_free)


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

	var dir: Vector2 = (target.global_position - global_position).normalized()
	var bullet := _bullet_scene.instantiate()
	bullet.global_position = global_position + dir * 10
	bullet.velocity = dir * 200.0
	bullet.damage = 8
	get_tree().current_scene.add_child(bullet)

	# Attack animation
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("attack")


func _titan_process(delta: float) -> void:
	var anim := $AnimatedSprite2D as AnimatedSprite2D
	_chop_cooldown -= delta
	var swinging := anim.animation == "attack" and anim.is_playing()
	var target := _titan_target()
	if swinging:
		velocity.x = 0
	elif target:
		velocity.x = 0
		_facing = signf(target.global_position.x - global_position.x)
		if _chop_cooldown <= 0:
			_chop_target = target
			_chop_cooldown = TITAN_CHOP_COOLDOWN
			anim.play("attack")
		else:
			anim.play("idle")
	else:
		velocity.x = speed * direction
		_facing = signf(direction)
		anim.play("walk")
	# sprite faces right; keep the body (not the frame centre) on the origin
	anim.flip_h = _facing < 0
	anim.offset.x = TITAN_BODY_OFFSET if _facing > 0 else -TITAN_BODY_OFFSET


func _titan_target() -> Node2D:
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Player") as Node2D
	if player and absf(player.global_position.x - global_position.x) < TITAN_REACH_PLAYER \
			and absf(player.global_position.y - global_position.y) < 60:
		return player
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	if dome and absf(dome.global_position.x - global_position.x) < TITAN_REACH_DOME:
		return dome
	return null


func _on_titan_frame() -> void:
	var anim := $AnimatedSprite2D as AnimatedSprite2D
	if _dying or anim.animation != "attack" or anim.frame != TITAN_IMPACT_FRAME:
		return
	# the blade hits the ground ~40px in front of the body
	var hit := global_position + Vector2(_facing * 42, 10)
	FX.burst(get_parent(), hit, Color(0.55, 0.45, 0.35), 16, 120.0, 0.5, 2.5)
	FX.burst(get_parent(), hit + Vector2(0, -6), Color(0.85, 0.95, 1.0), 6, 160.0, 0.2, 1.5, 0.0)
	FX.shake(self, 5.0, 0.25)
	SFX.play(self, SFX.sfx_mine_break())
	if not is_instance_valid(_chop_target):
		return
	if _chop_target.has_method("take_damage"):
		_chop_target.take_damage(TITAN_CHOP_DAMAGE)
		if _chop_target.has_method("launch"):
			_chop_target.launch(Vector2(_facing * 260, -240))
	elif get_tree().current_scene.has_method("damage_dome"):
		get_tree().current_scene.damage_dome(TITAN_CHOP_DAMAGE)


func _create_titan_frames() -> SpriteFrames:
	var walk := load("res://assets/sprites/titan_walk.png") as Texture2D
	var attack := load("res://assets/sprites/titan_attack.png") as Texture2D
	if walk == null or attack == null:
		return _create_titan_frames_old()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fw := 120
	var fh := 120
	for spec in [["walk", walk, 8, 8.0, true], ["idle", walk, 1, 4.0, true],
			["attack", attack, 8, 11.0, false]]:
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


func _create_skeleton_frames() -> SpriteFrames:
	var tex := load("res://assets/sprites/skeleton.png") as Texture2D
	return SpriteLoader.create_frames_from_sheet(tex, {
		"idle": {"row": 0, "frames": 4, "speed": 6.0},
		"walk": {"row": 5, "frames": 4, "speed": 6.0},
		"attack": {"row": 1, "frames": 4, "speed": 8.0},
		"jump": {"row": 2, "frames": 3, "speed": 6.0},
		"damage": {"row": 3, "frames": 2, "speed": 8.0, "loop": false},
		"death": {"row": 4, "frames": 4, "speed": 8.0, "loop": false},
	})
