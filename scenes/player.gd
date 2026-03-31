extends CharacterBody2D

@export var move_speed: float = 200.0
@export var jump_force: float = 420.0
@export var mine_damage: int = 1
@export var mine_cooldown: float = 0.25
@export var max_hp: int = 100
@export var contact_damage_cooldown: float = 0.5

const GRAVITY := 980.0
const TILE_SIZE := 16
const ENEMY_DETECT_RADIUS := 18.0

var hp: int
var _mine_timer := 0.0
var _is_mining := false
var _facing_right := true
var _damage_cooldown := 0.0
var _launch_timer := 0.0  # while > 0, player input doesn't override velocity

signal hp_changed(current: int, max_hp: int)
signal player_died

const SpriteLoader = preload("res://scripts/sprite_loader.gd")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _pickaxe: Node2D = $Pickaxe


func _ready() -> void:
	hp = max_hp
	_anim.sprite_frames = SpriteLoader.create_goblin_frames()
	_anim.play("idle")


func _physics_process(delta: float) -> void:
	# Enemy contact damage
	if _damage_cooldown > 0:
		_damage_cooldown -= delta
	else:
		_check_enemy_contact()

	# Launch timer (trampoline/knockback)
	if _launch_timer > 0:
		_launch_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Horizontal movement — preserve momentum in air
	var input_x := 0.0
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		input_x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		input_x += 1.0

	if is_on_floor():
		# On ground: direct control
		velocity.x = input_x * move_speed
	else:
		# In air: gradual acceleration, preserves launch momentum
		if input_x != 0:
			velocity.x = move_toward(velocity.x, input_x * move_speed, 600.0 * delta)
		else:
			# Slow air drag when no input — don't kill momentum instantly
			velocity.x = move_toward(velocity.x, 0, 200.0 * delta)

	# Facing direction
	if input_x > 0:
		_facing_right = true
		_anim.flip_h = false
	elif input_x < 0:
		_facing_right = false
		_anim.flip_h = true

	# Jump — W or Space
	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_W)) and is_on_floor():
		velocity.y = -jump_force

	move_and_slide()

	# Update animation
	if not _is_mining:
		if not is_on_floor():
			if velocity.y < 0:
				_anim.play("jump")
			else:
				_anim.play("jump")  # fall uses same anim
		elif abs(velocity.x) > 10:
			_anim.play("walk")
		else:
			_anim.play("idle")

	# Mining cooldown
	if _mine_timer > 0:
		_mine_timer -= delta

	# Mining — J key mines in direction based on held movement keys
	# Also keep click-to-mine for trackpad users
	if Input.is_key_pressed(KEY_J) and _mine_timer <= 0:
		_try_directional_mine()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mine_timer <= 0:
		if not has_node("/root/BuildSystem") or get_node("/root/BuildSystem").current_build == 0:
			_try_mine_at(get_global_mouse_position())


func _try_directional_mine() -> void:
	# Determine direction from held keys: A=left, D=right, S=down
	# No direction held = mine in facing direction
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1

	if dir == Vector2.ZERO:
		# No direction held — mine in facing direction
		dir.x = 1 if _facing_right else -1

	# Target the adjacent tile in that direction
	var target := global_position + dir.normalized() * TILE_SIZE
	_try_mine_at(target)


func _try_mine_at(world_pos: Vector2) -> void:
	var tilemap := _get_tilemap()
	if tilemap == null:
		return

	var tile_pos := tilemap.local_to_map(tilemap.to_local(world_pos))
	var source_id := tilemap.get_cell_source_id(tile_pos)

	if source_id == -1:
		return  # empty tile

	# Check range (3 tiles)
	var tile_center := tilemap.to_global(tilemap.map_to_local(tile_pos))
	if global_position.distance_to(tile_center) > TILE_SIZE * 3:
		return

	_mine_timer = mine_cooldown
	_play_pickaxe_swing(tile_center)
	tilemap.set_cell(tile_pos, -1)


func _play_pickaxe_swing(target_world: Vector2) -> void:
	_is_mining = true
	_pickaxe.visible = true

	var dir := (target_world - global_position).normalized()
	var start_angle := dir.angle() - 1.2
	var end_angle := dir.angle() + 1.2

	_pickaxe.rotation = start_angle
	_pickaxe.scale = Vector2(1.2, 1.2)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_pickaxe, "rotation", end_angle, mine_cooldown * 0.7)
	tween.parallel().tween_property(_pickaxe, "scale", Vector2(1, 1), mine_cooldown * 0.7)
	tween.tween_callback(func(): _pickaxe.visible = false; _is_mining = false)


func _check_enemy_contact() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < ENEMY_DETECT_RADIUS:
			var dmg: int = enemy.damage if "damage" in enemy else 10
			take_damage(dmg)
			# Knockback away from enemy
			var knockback: Vector2 = (global_position - enemy.global_position).normalized()
			velocity = knockback * 300
			break


func launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	_launch_timer = 0.1  # brief override, player regains control quickly


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_damage_cooldown = contact_damage_cooldown
	hp_changed.emit(hp, max_hp)

	# Flash red
	var tween := create_tween()
	tween.tween_property(_anim, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(_anim, "modulate", Color(0.5, 0.7, 1.0), 0.15)  # back to blue tint

	if hp <= 0:
		player_died.emit()


func _get_tilemap() -> TileMapLayer:
	var parent := get_parent()
	if parent and parent.has_node("TileMapLayer"):
		return parent.get_node("TileMapLayer") as TileMapLayer
	return null
