extends Node2D

const WeaponSprites = preload("res://scripts/weapon_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")

@export var pellet_count: int = 5
@export var spread_angle: float = 30.0  # degrees
@export var pellet_speed: float = 400.0
@export var pellet_damage: int = 2
@export var fire_cooldown: float = 0.6

var _timer := 0.0
var _base_pos := Vector2.ZERO
var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var _muzzle := 30.0
var _flash_anim: AnimatedSprite2D


func _ready() -> void:
	_base_pos = position
	$Flash.visible = false
	var sprite := $GunSprite as Sprite2D
	var tex := load("res://assets/sprites/blunderbuss.png") as Texture2D
	if tex:
		# brass blunderbuss (tools/art/gen_weapons.py): grip at (7, 7) on the pivot
		sprite.texture = tex
		sprite.centered = false
		sprite.offset = Vector2(-7, -7)
		_muzzle = 27.0
		var fl := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 24.0)
		sf.set_animation_loop("default", false)
		var ftex := load("res://assets/sprites/muzzle_flash.png") as Texture2D
		for i in 3:
			var a := AtlasTexture.new()
			a.atlas = ftex
			a.region = Rect2(i * 20, 0, 20, 16)
			sf.add_frame("default", a)
		fl.sprite_frames = sf
		fl.centered = false
		fl.offset = Vector2(0, -8)
		fl.position = Vector2(_muzzle, -2.5)
		fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fl.visible = false
		add_child(fl)
		_flash_anim = fl
	else:
		sprite.texture = WeaponSprites.create_shotgun_texture()
		sprite.scale = Vector2(1.4, 1.4)
	visible = false  # hidden until firing


func _physics_process(delta: float) -> void:
	if _timer > 0:
		_timer -= delta

	# Aim toward mouse
	var mouse := get_global_mouse_position()
	var dir := (mouse - global_position).normalized()
	rotation = dir.angle()
	# keep the gun upright when aiming left
	$GunSprite.flip_v = absf(wrapf(rotation, -PI, PI)) > PI / 2
	$GunSprite.offset.y = 7 - 12 if $GunSprite.flip_v else -7
	if _flash_anim:
		_flash_anim.flip_v = $GunSprite.flip_v
		_flash_anim.position.y = 2.5 if $GunSprite.flip_v else -2.5

	# Fire with F key
	if Input.is_key_pressed(KEY_F) and _timer <= 0:
		_fire(dir)


func _fire(dir: Vector2) -> void:
	_timer = fire_cooldown
	# turn the prospector to face the shot
	var owner_body := get_parent()
	if absf(dir.x) > 0.1 and "_facing_right" in owner_body:
		owner_body._facing_right = dir.x > 0
		owner_body.get_node("AnimatedSprite2D").flip_h = dir.x < 0

	var base_angle := dir.angle()
	var spread_rad := deg_to_rad(spread_angle)

	for i in pellet_count:
		var offset := remap(i, 0, pellet_count - 1, -spread_rad / 2, spread_rad / 2)
		if pellet_count == 1:
			offset = 0.0
		var pellet_dir := Vector2.from_angle(base_angle + offset)

		var bullet := _bullet_scene.instantiate()
		bullet.global_position = global_position + dir * _muzzle
		bullet.velocity = pellet_dir * pellet_speed
		bullet.damage = pellet_damage
		bullet.lifetime = 0.8
		get_tree().current_scene.add_child(bullet)

	SFX.play(self, SFX.sfx_shotgun())

	# Show gun + muzzle flash
	visible = true
	if _flash_anim:
		_flash_anim.visible = true
		_flash_anim.frame = 0
		_flash_anim.play()
	else:
		$Flash.visible = true

	var tween := create_tween()
	# Recoil
	tween.tween_property(self, "position", _base_pos - dir.normalized() * 4, 0.05)
	tween.tween_property(self, "position", _base_pos, 0.12)
	# Hide flash quickly, hide gun after delay
	tween.parallel().tween_callback(func(): $Flash.visible = false).set_delay(0.06)
	if _flash_anim:
		tween.parallel().tween_callback(func(): _flash_anim.visible = false).set_delay(0.2)
	tween.tween_callback(func(): visible = false).set_delay(0.3)
