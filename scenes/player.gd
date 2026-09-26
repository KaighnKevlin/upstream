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
const WorldGen = preload("res://scripts/world_gen.gd")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _pickaxe: Node2D = $Pickaxe
var _pick_sprite: Sprite2D


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	add_child(preload("res://scenes/grapple.gd").new())   # Shift: the grappling hook
	_gauge = Node2D.new()
	_gauge.z_index = 6
	_gauge.visible = false
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)
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
	light.energy = LAMP_DEEP
	light.color = Color(1.0, 0.95, 0.8)
	add_child(light)
	_lamp = light


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not _dead:
		if _carried and is_instance_valid(_carried):
			_throw_carried()
		else:
			_pick_up()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var cam := $Camera2D as Camera2D
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			cam.zoom = Vector2(minf(cam.zoom.x + 0.25, 3.0), minf(cam.zoom.y + 0.25, 3.0))
		elif event.keycode == KEY_MINUS:
			cam.zoom = Vector2(maxf(cam.zoom.x - 0.25, 0.5), maxf(cam.zoom.y - 0.25, 0.5))


# Headlamp: full strength underground, dimmed on the moonlit surface where
# it would stack with the moon and dome lights and bleach sprites
const LAMP_DEEP := 0.7
const LAMP_SURFACE := 0.2
const SURFACE_Y := 96.0
var _lamp: PointLight2D
# Carrying: E picks up a loose ore/ingot within reach and holds it overhead;
# E again throws it toward the mouse (distance = strength), with a dotted arc
# previewing the throw while it's held.
const CARRY_REACH := 28.0
const HOLD_OFFSET := Vector2(0, -28)
const THROW_MIN := 120.0
const THROW_MAX := 720.0
var _carried: RigidBody2D
var _throw_arc: Node2D
var _hurt_timer := 0.0
var _land_timer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _dead := false
const STEAM_COST := 0.5
var steam := 1.0                 # boiler pressure for steam jumps (tests read it)
var steam_jumps := 0
var _w_was := false
var _gauge: Node2D


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
	if _lamp:
		var depth := clampf((global_position.y - SURFACE_Y) / 48.0, 0.0, 1.0)
		_lamp.energy = lerpf(LAMP_SURFACE, LAMP_DEEP, depth)

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
	# Steam jump: in mid-air the backpack boiler kicks you up again (two
	# bursts' worth of pressure, refilled on the ground)
	var w_now := Input.is_physical_key_pressed(KEY_W)
	var jump_edge := Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept") or (w_now and not _w_was)
	_w_was = w_now
	if is_on_floor() or in_shaft:
		steam = minf(1.0, steam + delta * 1.6)
	elif jump_edge and steam >= STEAM_COST and _launch_timer <= 0:
		steam_jump()
	if _gauge:
		_gauge.visible = steam < 0.999
		_gauge.queue_redraw()

	var vy_before := velocity.y
	move_and_slide()
	_track_landing(vy_before, delta)
	_update_carry()

	# Enemy contact check (after move_and_slide so knockback isn't immediately consumed)
	if _damage_cooldown <= 0:
		_check_enemy_contact()

	# Update animation (only switch when animation changes)
	if not _is_mining:
		var new_anim: String
		var frames := _anim.sprite_frames
		if _hurt_timer > 0 and frames.has_animation("hurt"):
			new_anim = "hurt"
		elif not is_on_floor():
			if not frames.has_animation("rise"):
				new_anim = "jump"
			elif velocity.y < -60:
				new_anim = "rise"
			elif velocity.y > 60:
				new_anim = "fall"
			else:
				new_anim = "jump"  # apex
		elif _land_timer > 0 and frames.has_animation("land"):
			new_anim = "land"
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
	if tilemap.get_cell_atlas_coords(tile_pos).x in WorldGen.PICK_PROOF:
		_clink(tilemap, tile_pos, start_cooldown)
		return false

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
	get_tree().call_group("cave_decor", "tile_cleared", tile_pos)
	# one pick sound per swing, even when a swing clears a whole column
	var now := Time.get_ticks_msec()
	if now - _last_dig_sound > 60:
		_last_dig_sound = now
		SFX.play(self, SFX.sfx_mine_hit())
		SFX.play(self, SFX.sfx_mine_break(atlas_coords.x))
	return true

## The pick glances off ironstone / an ore vein: sparks, a clink, no dig.
var _clink_cooldown := 0.0
var _last_dig_sound := 0

func _clink(tilemap: TileMapLayer, tile_pos: Vector2i, start_cooldown: bool) -> void:
	var at := tilemap.to_global(tilemap.map_to_local(tile_pos))
	if global_position.distance_to(at) > TILE_SIZE * 3:
		return
	if start_cooldown:
		_mine_timer = mine_cooldown
	if Time.get_ticks_msec() / 1000.0 < _clink_cooldown:
		return
	_clink_cooldown = Time.get_ticks_msec() / 1000.0 + mine_cooldown * 0.9
	_play_pickaxe_swing(at)
	var toward := (global_position - at).normalized()
	FX.burst(get_parent(), at + toward * 7, Color(1.0, 0.85, 0.5), 6, 110.0, 0.18, 1.2, 150.0)
	SFX.play(self, SFX.sfx_clink())


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


func steam_jump() -> void:
	steam -= STEAM_COST
	steam_jumps += 1
	velocity.y = -jump_force * 0.8
	var at := global_position + Vector2(0, 14)
	FX.burst(get_parent(), at, Color(0.92, 0.92, 0.95, 0.8), 10, 90.0, 0.45, 2.4, 160.0)
	FX.burst(get_parent(), global_position + Vector2(-5 if _facing_right else 5, -12), Color(0.85, 0.85, 0.9, 0.7), 4, 40.0, 0.5, 2.0, -40.0)
	SFX.play_small(self, SFX.sfx_ore_knock("ore"), -10.0, 0.45)


## The pressure gauge over the prospector's head while the boiler refills:
## two pips, one per steam burst.
func _draw_gauge() -> void:
	for k in 2:
		var full := clampf((steam - k * STEAM_COST) / STEAM_COST, 0.0, 1.0)
		var r := Rect2(Vector2(-7 + k * 8, -40), Vector2(6, 3))
		_gauge.draw_rect(r.grow(1), Color(0.1, 0.08, 0.07, 0.8))
		_gauge.draw_rect(Rect2(r.position, Vector2(r.size.x * full, r.size.y)), Color(0.85, 0.9, 0.95) if full >= 1.0 else Color(0.6, 0.65, 0.7))


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
	_drop_carried()
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


## A hard landing: brief crouch and a puff of dust at the feet.
func _track_landing(vy_before: float, delta: float) -> void:
	_land_timer -= delta
	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, vy_before)
	elif not _was_on_floor:
		if _fall_speed > 260.0:
			_land_timer = 0.12
			var feet := global_position + Vector2(0, HALF_HEIGHT)
			FX.burst(get_parent(), feet, Color(0.55, 0.45, 0.35, 0.8), 6, 60.0, 0.35, 1.5)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()


func _pick_up() -> void:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CARRY_REACH
	q.shape = circle
	q.transform = Transform2D(0, global_position)
	q.collision_mask = 2  # ore and ingots
	var best: RigidBody2D = null
	var best_d := INF
	for hit in space.intersect_shape(q, 16):
		var b = hit.collider
		if b is RigidBody2D and not b.has_meta("caught_by"):
			var d: float = b.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = b
	if best == null:
		return
	_carried = best
	_carried.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	_carried.set_deferred("freeze", true)
	_carried.set_meta("caught_by", self)
	SFX.play(self, SFX.sfx_mine_hit())
	if _throw_arc == null:
		_throw_arc = preload("res://scripts/trajectory_preview.gd").new()
		_throw_arc.tilemap = _get_tilemap()
		add_child(_throw_arc)
	_throw_arc.visible = true


func _throw_velocity() -> Vector2:
	var hand := global_position + HOLD_OFFSET
	var v := get_global_mouse_position() - hand
	var speed := clampf(v.length() * 3.2, THROW_MIN, THROW_MAX)
	return v.normalized() * speed if v.length() > 1 else Vector2(0, -THROW_MIN)


func _throw_carried() -> void:
	var b := _carried
	_carried = null
	if _throw_arc:
		_throw_arc.visible = false
	if not is_instance_valid(b):
		return
	b.remove_meta("caught_by")
	b.freeze = false
	b.sleeping = false
	var v := _throw_velocity()
	b.linear_velocity = v + Vector2(velocity.x * 0.5, 0)  # a running throw carries some of your speed
	b.angular_velocity = randf_range(-10, 10)
	_facing_right = v.x >= 0
	_anim.flip_h = not _facing_right
	SFX.play(self, SFX.sfx_bounce())


func _drop_carried() -> void:
	if _carried and is_instance_valid(_carried):
		_carried.remove_meta("caught_by")
		_carried.freeze = false
	_carried = null
	if _throw_arc:
		_throw_arc.visible = false


func _update_carry() -> void:
	if not _carried:
		return
	if not is_instance_valid(_carried):
		_carried = null
		if _throw_arc:
			_throw_arc.visible = false
		return
	_carried.global_position = global_position + HOLD_OFFSET
	if "_timer" in _carried:
		_carried._timer = 0.0  # held ore doesn't despawn
	_throw_arc.origin = global_position + HOLD_OFFSET
	_throw_arc.velocity = _throw_velocity() + Vector2(velocity.x * 0.5, 0)
	_throw_arc.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _get_tilemap() -> TileMapLayer:
	var parent := get_parent()
	if parent and parent.has_node("TileMapLayer"):
		return parent.get_node("TileMapLayer") as TileMapLayer
	return null
