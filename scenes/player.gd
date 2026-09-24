extends CharacterBody2D

@export var move_speed: float = 200.0
@export var jump_force: float = 420.0
@export var mine_damage: int = 1
@export var mine_cooldown: float = 0.25
@export var max_hp: int = 100
@export var contact_damage_cooldown: float = 1.0

const GRAVITY := 980.0
const TILE_SIZE := 16
const ENEMY_DETECT_RADIUS := 28.0
const HALF_HEIGHT := 18.0
const HALF_WIDTH := 12.0

var hp: int
var _mine_timer := 0.0
var _is_mining := false
var _facing_right := true
var _damage_cooldown := 0.0
var _launch_timer := 0.0  # while > 0, player input doesn't override velocity
var in_shaft := false

signal hp_changed(current: int, max_hp: int)
signal player_died

const SpriteLoader = preload("res://scripts/sprite_loader.gd")
const PlayerSprite = preload("res://scripts/player_sprite.gd")
const LightTextures = preload("res://scripts/light_textures.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _pickaxe: Node2D = $Pickaxe
var _pick_sprite: Sprite2D


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	var frames := PlayerSprite.create_prospector_frames()
	if frames:
		_anim.sprite_frames = frames
		_anim.scale = Vector2.ONE  # drawn at game scale; the old miner sheet was 1.25x
	elif PlayerSprite.create_player_frames():
		_anim.sprite_frames = PlayerSprite.create_player_frames()
	else:
		_anim.sprite_frames = SpriteLoader.create_goblin_frames()
	_anim.play("idle")

	# Pickaxe: painted sprite (tools/art/gen_player.py) instead of the polygons.
	# Its pivot is the handle butt, held at the shoulder.
	for c in _pickaxe.get_children():
		c.visible = false
	_pick_sprite = Sprite2D.new()
	_pick_sprite.texture = preload("res://assets/sprites/pickaxe.png")
	_pick_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pick_sprite.centered = false
	_pick_sprite.offset = Vector2(-2, -8)
	_pickaxe.add_child(_pick_sprite)
	_pickaxe.position = Vector2(1, -3)

	# Player light
	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(256)
	light.texture_scale = 3.0
	light.energy = 0.7  # stacks with moonlight on the surface; 1.0 blew out nearby sprites
	light.color = Color(1.0, 0.95, 0.8)
	add_child(light)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var cam := $Camera2D as Camera2D
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			cam.zoom = Vector2(minf(cam.zoom.x + 0.25, 3.0), minf(cam.zoom.y + 0.25, 3.0))
		elif event.keycode == KEY_MINUS:
			cam.zoom = Vector2(maxf(cam.zoom.x - 0.25, 0.5), maxf(cam.zoom.y - 0.25, 0.5))


var _hurt_timer := 0.0
var _dead := false


func _physics_process(delta: float) -> void:
	if _dead:  # just fall and slide to a stop
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.x = move_toward(velocity.x, 0, 1200.0 * delta)
		move_and_slide()
		return
	if _hurt_timer > 0:
		_hurt_timer -= delta

	# Damage cooldown
	if _damage_cooldown > 0:
		_damage_cooldown -= delta

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

	if _launch_timer > 0:
		# During knockback/launch: very little player control
		if input_x != 0:
			velocity.x += input_x * move_speed * 0.1 * delta * 60
		# Ground friction, so a knockback doesn't slide you across the map
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 2500.0 * delta)
	elif is_on_floor():
		# On ground: direct control
		velocity.x = input_x * move_speed
	else:
		# In air: gradual acceleration, preserves launch momentum
		if input_x != 0:
			velocity.x = move_toward(velocity.x, input_x * move_speed, 600.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, 200.0 * delta)

	# Facing direction
	if input_x > 0:
		_facing_right = true
		_anim.flip_h = false
	elif input_x < 0:
		_facing_right = false
		_anim.flip_h = true

	# Jump — W or Space (can jump on floor or inside a shaft)
	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_W)) and (is_on_floor() or in_shaft):
		velocity.y = -jump_force

	move_and_slide()

	# Enemy contact check (after move_and_slide so knockback isn't immediately consumed)
	if _damage_cooldown <= 0:
		_check_enemy_contact()

	# Update animation (only switch when animation changes)
	if not _is_mining:
		var new_anim: String
		if _hurt_timer > 0 and _anim.sprite_frames.has_animation("hurt"):
			new_anim = "hurt"
		elif not is_on_floor():
			new_anim = "jump"
		elif abs(velocity.x) > 10:
			new_anim = "walk"
		else:
			new_anim = "idle"
		if _anim.animation != new_anim:
			_anim.play(new_anim)

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

	# Straight down: the body (24px) is wider than a tile, so clear every tile
	# under the feet (plus a pixel of margin, or a tile corner still catches it).
	if dir.x == 0 and dir.y > 0:
		var feet_y := global_position.y + HALF_HEIGHT + TILE_SIZE / 2.0
		var left := global_position.x - HALF_WIDTH - 1
		var right := global_position.x + HALF_WIDTH + 1
		var x := left
		while x < right + TILE_SIZE:
			_try_mine_at(Vector2(minf(x, right), feet_y), false)
			x += TILE_SIZE
		_mine_timer = mine_cooldown
		return

	# Straight sideways: the body is ~2.3 tiles tall, so clear the whole
	# column beside it or the player can't walk into the tunnel.
	if dir.y == 0:
		var side_x := global_position.x + dir.x * (HALF_WIDTH + TILE_SIZE / 2.0)
		var y := global_position.y - HALF_HEIGHT + 1
		var mined := false
		while y < global_position.y + HALF_HEIGHT:
			mined = _try_mine_at(Vector2(side_x, y), false) or mined
			y += TILE_SIZE
		mined = _try_mine_at(Vector2(side_x, global_position.y + HALF_HEIGHT - 1), false) or mined
		if mined:
			_mine_timer = mine_cooldown
		return

	var target := global_position + dir.normalized() * TILE_SIZE
	_try_mine_at(target)


func _try_mine_at(world_pos: Vector2, start_cooldown := true) -> bool:
	var tilemap := _get_tilemap()
	if tilemap == null:
		return false

	var tile_pos := tilemap.local_to_map(tilemap.to_local(world_pos))
	var source_id := tilemap.get_cell_source_id(tile_pos)

	if source_id == -1:
		return false  # empty tile

	# Check range (3 tiles)
	var tile_center := tilemap.to_global(tilemap.map_to_local(tile_pos))
	if global_position.distance_to(tile_center) > TILE_SIZE * 3:
		return false

	if start_cooldown:
		_mine_timer = mine_cooldown
	_play_pickaxe_swing(tile_center)
	var atlas_coords := tilemap.get_cell_atlas_coords(tile_pos)
	var debris: Color = FX.TILE_COLORS.get(atlas_coords.x, Color.GRAY)
	FX.burst(get_parent(), tile_center, debris, 5, 80.0, 0.4)
	tilemap.set_cell(tile_pos, -1)
	FX.tile_break(get_parent(), tilemap, tile_pos, source_id, atlas_coords,
		(global_position - tile_center).normalized())
	get_tree().call_group("tile_shading", "mark_dirty", tile_pos)
	SFX.play(self, SFX.sfx_mine_break())
	return true

func _play_pickaxe_swing(target_world: Vector2) -> void:
	_is_mining = true
	_pickaxe.visible = true

	var dir := (target_world - _pickaxe.global_position).normalized()
	# Chop downward whichever way we face: clockwise facing right,
	# counter-clockwise facing left (and mirror the head so the point leads).
	var facing := signf(dir.x) if absf(dir.x) > 0.1 else (1.0 if _facing_right else -1.0)
	var start_angle := dir.angle() - 1.2 * facing
	var end_angle := dir.angle() + 1.2 * facing
	_pick_sprite.flip_v = facing < 0

	_pickaxe.rotation = start_angle
	_pickaxe.scale = Vector2(1.2, 1.2)

	if _anim.sprite_frames.has_animation("mine"):
		_anim.flip_h = facing < 0
		_anim.speed_scale = 1.0
		_anim.play("mine")
		_anim.frame = 0

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
			# Knockback: push player away from enemy + upward pop
			var push_x: float = signf(global_position.x - enemy.global_position.x)
			if push_x == 0:
				push_x = 1.0
			var knockback := Vector2(push_x * 320, -260)
			velocity = knockback
			_launch_timer = 1.0
			break


func launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	_launch_timer = 0.1  # brief override, player regains control quickly


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = max(0, hp - amount)
	_hurt_timer = 0.3
	FX.shake(self, 3.0, 0.15)
	_damage_cooldown = contact_damage_cooldown
	hp_changed.emit(hp, max_hp)

	# Flash red
	var tween := create_tween()
	tween.tween_property(_anim, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(_anim, "modulate", Color.WHITE, 0.15)

	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	_is_mining = false
	_pickaxe.visible = false
	if _anim.sprite_frames.has_animation("death"):
		_anim.play("death")
		FX.burst(get_parent(), global_position + Vector2(0, 8), Color(0.55, 0.45, 0.35), 10, 70.0, 0.5, 2.0)
		# the headlamp gutters out with the last frame
		for c in get_children():
			if c is PointLight2D:
				var t := create_tween()
				t.tween_interval(0.5)
				t.tween_property(c, "energy", 0.15, 0.3)
		await _anim.animation_finished
		await get_tree().create_timer(0.6).timeout
	player_died.emit()


func _get_tilemap() -> TileMapLayer:
	var parent := get_parent()
	if parent and parent.has_node("TileMapLayer"):
		return parent.get_node("TileMapLayer") as TileMapLayer
	return null
