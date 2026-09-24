extends Node2D

const ObjectSprites = preload("res://scripts/object_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

@export var fire_rate: float = 1.5  # shots per second
@export var fire_range: float = 500.0
@export var bullet_speed: float = 300.0
@export var damage_per_shot: int = 2

var _ammo_port: Node = null
var _timer: float = 0.0
var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var _turret_sprite: Sprite2D
var _barrel_sprite: Sprite2D
var _flash: AnimatedSprite2D
var _empty_lamp: Sprite2D
const BARREL_OFFSET := Vector2(-3, -5)  # cannon_barrel.png breech at (3, 5)
const MUZZLE := 24.0                    # breech to the muzzle brake's mouth
var _aim := -PI / 2

@onready var _barrel: Polygon2D = $Barrel


func setup(ammo_port: Node) -> void:
	_ammo_port = ammo_port

	# Replace polygon art
	$Base.visible = false
	_barrel.visible = false
	# brass cannon on the dome's crown (tools/art/gen_dome.py): a pedestal
	# and a barrel that swivels toward whatever it's shooting
	_turret_sprite = Sprite2D.new()
	_turret_sprite.texture = preload("res://assets/sprites/cannon_base.png")
	_turret_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_turret_sprite)
	_barrel_sprite = Sprite2D.new()
	_barrel_sprite.texture = preload("res://assets/sprites/cannon_barrel.png")
	_barrel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barrel_sprite.centered = false
	_barrel_sprite.offset = BARREL_OFFSET  # pivot at the breech
	_barrel_sprite.position = Vector2(0, -4)
	_barrel_sprite.rotation = -PI / 2
	add_child(_barrel_sprite)
	# muzzle flash at the brake (reuses the blunderbuss flash)
	_flash = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 24.0)
	sf.set_animation_loop("default", false)
	var ftex := preload("res://assets/sprites/muzzle_flash.png")
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = ftex
		a.region = Rect2(i * 20, 0, 20, 16)
		sf.add_frame("default", a)
	_flash.sprite_frames = sf
	_flash.centered = false
	_flash.offset = Vector2(0, -8)
	_flash.position = Vector2(MUZZLE, 0)
	_flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flash.visible = false
	_flash.animation_finished.connect(func(): _flash.visible = false)
	_barrel_sprite.add_child(_flash)
	# a red lamp over the breech core, shown when it tries to fire empty
	_empty_lamp = Sprite2D.new()
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.35, 0.2))
	img.set_pixel(0, 0, Color.TRANSPARENT); img.set_pixel(2, 0, Color.TRANSPARENT)
	img.set_pixel(0, 2, Color.TRANSPARENT); img.set_pixel(2, 2, Color.TRANSPARENT)
	_empty_lamp.texture = ImageTexture.create_from_image(img)
	_empty_lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_empty_lamp.position = Vector2(1, 0)  # the core, 1px ahead of the pivot
	_empty_lamp.modulate.a = 0.0
	_barrel_sprite.add_child(_empty_lamp)


func _physics_process(delta: float) -> void:
	if _barrel_sprite:
		_barrel_sprite.rotation = lerp_angle(_barrel_sprite.rotation, _aim, 0.25)
	_timer += delta
	if _timer < 1.0 / fire_rate:
		return
	_timer = 0.0

	# Find nearest enemy
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := fire_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest == null:
		return

	# Try to consume ammo
	if _ammo_port == null or not _ammo_port.consume_ammo():
		_dry_fire()
		return

	# Aim the barrel at the target
	var dir := (nearest.global_position + Vector2(0, -12) - global_position).normalized()
	_aim = dir.angle()

	SFX.play(self, SFX.sfx_turret_fire())

	# Spawn bullet
	var bullet := _bullet_scene.instantiate()
	bullet.global_position = global_position + Vector2(0, -4) + dir * MUZZLE
	bullet.velocity = dir * bullet_speed
	bullet.damage = damage_per_shot
	get_tree().current_scene.add_child(bullet)

	# Muzzle flash (on the visible pixel sprite; the polygon barrel is hidden)
	# snap onto the shot so the flash and recoil line up with the bullet
	_barrel_sprite.rotation = _aim
	FX.flash(_barrel_sprite, Color(1.6, 1.5, 1.1), 0.08)
	_flash.visible = true
	_flash.frame = 0
	_flash.play()
	# recoil: the barrel kicks back along its axis and runs out again
	var kick := create_tween()
	kick.tween_property(_barrel_sprite, "offset", BARREL_OFFSET - Vector2(4, 0), 0.04)
	kick.tween_property(_barrel_sprite, "offset", BARREL_OFFSET, 0.18).set_ease(Tween.EASE_OUT)
	var tip := global_position + Vector2(0, -4) + dir * MUZZLE
	FX.burst(get_parent(), tip, Color(1, 0.9, 0.5), 5, 90.0, 0.15, 1.5, 0.0)
	FX.burst(get_parent(), tip, Color(0.75, 0.75, 0.72, 0.6), 4, 20.0, 0.8, 2.5, -40.0)  # smoke


## Out of ammo: the core flickers red twice and a wisp of steam escapes,
## instead of tinting the whole cannon.
func _dry_fire() -> void:
	if _empty_lamp == null:
		return
	var t := create_tween()
	for k in 2:
		t.tween_property(_empty_lamp, "modulate:a", 1.0, 0.06)
		t.tween_property(_empty_lamp, "modulate:a", 0.15, 0.12)
	t.tween_property(_empty_lamp, "modulate:a", 0.0, 0.2)
	var tip := global_position + Vector2(0, -4) + Vector2.from_angle(_barrel_sprite.rotation) * MUZZLE
	FX.burst(get_parent(), tip, Color(0.8, 0.8, 0.78, 0.5), 2, 12.0, 0.6, 2.0, -30.0)

