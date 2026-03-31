extends CharacterBody2D

enum EnemyType { SLIME, GOBLIN, SKELETON, WIZARD }

@export var enemy_type: EnemyType = EnemyType.SLIME
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

var _bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

# Stats per type: [speed, hp, damage, scale]
const TYPE_STATS := {
	EnemyType.SLIME:    [50.0,  3,  8,  1.5],
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
			EnemyType.SLIME:
				anim.sprite_frames = SpriteLoader.create_slime_frames()
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
	hp -= amount
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
		queue_free()
	else:
		SFX.play(self, SFX.sfx_enemy_hit())


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
