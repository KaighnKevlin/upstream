extends CharacterBody2D
## Bridge engine: a clockwork siege cart with a folded truss bridge on its
## bed. It rolls toward the dome; at the lip of a ditch it stops, swings the
## bridge out across the gap (scenes/field_bridge.gd) and waits for the
## deck to lock, then rolls over it. Everyone behind it crosses without
## slowing: your pit traps stop working until you break the bridge (hard
## ore hits, iron best). One bridge per cart; after that it just rolls on
## and rams the dome. Too wide a gap (over MAX_GAP tiles) and it has to
## roll in like everyone else.
## Art: tools/art/gen_bridger.py (8 frames of 60x40: 4 loaded, 4 empty).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const WorldGen = preload("res://scripts/world_gen.gd")

const SPEED := 30.0
const GRAVITY := 980.0
const MAX_GAP := 10          # tiles
const MAX_HP := 16

var hp := MAX_HP
var damage := 14
var direction := -1.0
var loaded := true
var bridges := 0             # tests
var _dying := false
var _deploying: Node = null
var _spr: AnimatedSprite2D
var _knock_t := 0.0
var _check := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(34, 16)
	cs.shape = r
	cs.position = Vector2(0, -8)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/bridger.png")
	for spec in [["loaded", 0], ["empty", 4]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], 8.0)
		for i in 4:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2((spec[1] + i) * 60, 0, 60, 40)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-28, -39)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("loaded")
	add_child(_spr)
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D if scene else null
	if dome:
		direction = signf(dome.global_position.x - global_position.x) if absf(dome.global_position.x - global_position.x) > 1 else -1.0


func hit_center() -> Vector2:
	return global_position + Vector2(0, -16)


func hit_radius() -> float:
	return 18.0


func knock(v: Vector2) -> void:
	if _dying:
		return
	velocity = v * 0.6
	_knock_t = 0.4


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif _knock_t <= 0:
		velocity.y = 0
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
		move_and_slide()
		return
	if _deploying:
		velocity.x = 0
		if not is_instance_valid(_deploying) or _deploying.ready_to_walk:
			_deploying = null
			_spr.play("empty")
		move_and_slide()
		return
	if loaded and is_on_floor():
		_check -= delta
		if _check <= 0:
			_check = 0.1
			if _try_deploy():
				velocity.x = 0
				move_and_slide()
				return
	velocity.x = SPEED * direction
	# a low step (a single tile): the cart bumps up over it
	if is_on_wall() and is_on_floor():
		velocity.y = -170.0
	move_and_slide()
	_spr.flip_h = direction < 0
	_spr.speed_scale = 1.0 if absf(velocity.x) > 1 else 0.0


## At a ditch lip with a far side in reach: lay the bridge.
func _try_deploy() -> bool:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return false
	var nose := global_position + Vector2(direction * 20.0, 4.0)
	var cell := tm.local_to_map(tm.to_local(nose))
	if tm.get_cell_source_id(cell) != -1:
		return false                         # ground ahead
	if preload("res://scenes/trapdoor.gd").covers(get_tree(), nose.x, global_position.y):
		return false                         # looks like ground: it rolls on
	# is it a real drop (not a one-tile dip)?
	if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
		return false
	var dir := int(direction)
	for k in range(1, MAX_GAP + 1):
		var c := Vector2i(cell.x + dir * k, cell.y)
		if tm.get_cell_source_id(c) != -1:
			if tm.get_cell_source_id(c + Vector2i.UP) != -1:
				return false                 # the far side is a higher wall: no bridge for that
			var near_lip := tm.to_global(tm.map_to_local(cell)).x - direction * 8.0
			var far_lip := tm.to_global(tm.map_to_local(c)).x - direction * 8.0
			var surface := tm.to_global(tm.map_to_local(cell)).y - 8.0
			var b: StaticBody2D = preload("res://scenes/field_bridge.gd").new()
			b.span = absf(far_lip - near_lip)
			b.side = direction
			b.position = Vector2(near_lip, surface)
			get_parent().add_child(b)
			_deploying = b
			loaded = false
			bridges += 1
			SFX.play(self, SFX.sfx_clink(), -4.0, 0.8)
			return true
	return false


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount)
	FX.burst(get_parent(), hit_center(), Color(0.66, 0.5, 0.32), 5, 80.0, 0.3, 1.5)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit())
		return
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 3)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.75, 0.35), 14, 150.0, 0.4, 2.0)
	FX.debris(get_parent(), hit_center(), 8, 180.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 0.5, 0.25)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
