extends CharacterBody2D
## Cave crawler: a small clockwork spider that lives in the caves. It hangs
## from a cave ceiling, curled up, until someone walks beneath it; then it
## drops, lands on its feet and scuttles after the prospector, biting on
## contact (the player's contact damage from `damage`). Loses interest when
## you get far away and wanders. A few are placed in each world's caverns.
## Art: tools/art/gen_crawler.py (5 frames of 26x18: 4 scuttle, 1 curled).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

enum State { HANGING, FALLING, HUNT }

const SPEED := 70.0
const GRAVITY := 980.0
const MAX_HP := 5
const TRIGGER := Vector2(40, 220)   # drops when the player is this close below it (x span, depth)
const SIGHT := 260.0

var hp := MAX_HP
var buried := true                  # (while hanging: turrets that aim leave it be)
var damage := 6                     # a bite (player contact damage)
var direction := -1.0
var _dying := false
var _knock_t := 0.0
var _state := State.HANGING
var _wander := 0.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("crawlers")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 10)
	cs.shape = r
	cs.position = Vector2(0, -5)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/crawler.png")
	for spec in [["walk", [0, 1, 2, 3], 14.0], ["curl", [4], 1.0]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 26, 0, 26, 18)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-13, -17)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_spr.play("curl")
	_spr.flip_v = true                 # upside down on the ceiling
	_spr.position = Vector2(0, -16)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -6 if _state != State.HANGING else -14)


func hit_radius() -> float:
	return 9.0


func knock(v: Vector2) -> void:
	if not _dying:
		_drop()
		velocity = v
		_knock_t = 0.4


func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") as Node2D


func _drop() -> void:
	if _state != State.HANGING:
		return
	_state = State.FALLING
	buried = false
	_spr.flip_v = false
	_spr.position = Vector2.ZERO
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 1.6)
	FX.burst(get_parent(), global_position + Vector2(0, -18), Color(0.55, 0.48, 0.42, 0.7), 5, 30.0, 0.5, 1.8)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	var p := _player()
	match _state:
		State.HANGING:
			if p:
				var d := p.global_position - global_position
				if absf(d.x) < TRIGGER.x and d.y > 0 and d.y < TRIGGER.y:
					_drop()
			return
		State.FALLING:
			velocity.y += GRAVITY * delta
			move_and_slide()
			if is_on_floor():
				_state = State.HUNT
				_spr.play("walk")
				FX.burst(get_parent(), global_position, Color(0.55, 0.48, 0.42, 0.7), 4, 40.0, 0.3, 1.5)
			return
	# hunting
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if _knock_t > 0:
		_knock_t -= delta
		move_and_slide()
		return
	if p and p.global_position.distance_to(global_position) < SIGHT:
		direction = signf(p.global_position.x - global_position.x) if absf(p.global_position.x - global_position.x) > 4 else direction
		velocity.x = SPEED * direction
		# a hop at a ledge or when the prospector is just above
		if is_on_floor() and (is_on_wall() or p.global_position.y < global_position.y - 30.0 and absf(p.global_position.x - global_position.x) < 50):
			velocity.y = -300.0
	else:
		_wander -= delta
		if _wander <= 0:
			_wander = randf_range(1.0, 3.0)
			direction = -direction if randf() < 0.5 else direction
		velocity.x = SPEED * 0.4 * direction
		if is_on_wall():
			direction = -direction
	move_and_slide()
	_spr.flip_h = direction < 0


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center(), amount, self)
	_drop()
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -6.0, 1.4)
		return
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 1)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), -4.0, 1.4)
	FX.burst(get_parent(), hit_center(), Color(0.9, 0.3, 0.2), 8, 100.0, 0.3, 1.4)
	FX.debris(get_parent(), hit_center(), 4, 140.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


## Crawlers on cave ceilings across the world: rock above, a few tiles of
## air below, well below the surface and away from the dome.
static func scatter(main: Node, tm: TileMapLayer, count := 10) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Vector2] = []
	for attempt in 5000:
		if spots.size() >= count:
			break
		var c := Vector2i(rng.randi_range(4, WorldGen.WORLD_WIDTH - 5), rng.randi_range(WorldGen.SURFACE_ROWS + 12, WorldGen.WORLD_HEIGHT - 4))
		if tm.get_cell_source_id(c) != -1 or tm.get_cell_source_id(c + Vector2i.UP) == -1:
			continue
		var clear := true
		for dy in range(1, 4):
			clear = clear and tm.get_cell_source_id(c + Vector2i(0, dy)) == -1
		if not clear:
			continue
		var at := tm.to_global(tm.map_to_local(c)) + Vector2(0, 8)
		if absf(at.x - 1200.0) < 180.0:
			continue
		for s in spots:
			clear = clear and s.distance_to(at) > 150.0
		if clear:
			spots.append(at)
	for at in spots:
		var cr: Node2D = load("res://scenes/crawler.tscn").instantiate()
		cr.global_position = at
		main.add_child(cr)
