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
	_barrel_sprite.offset = Vector2(-3, -4)  # pivot at the breech
	_barrel_sprite.position = Vector2(0, -4)
	_barrel_sprite.rotation = -PI / 2
	add_child(_barrel_sprite)


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
		var tween := create_tween()
		tween.tween_property(_barrel_sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
		tween.tween_property(_barrel_sprite, "modulate", Color.WHITE, 0.2)
		return

	# Aim the barrel at the target
	var dir := (nearest.global_position + Vector2(0, -12) - global_position).normalized()
	_aim = dir.angle()

	SFX.play(self, SFX.sfx_turret_fire())

	# Spawn bullet
	var bullet := _bullet_scene.instantiate()
	bullet.global_position = global_position + Vector2(0, -4) + dir * 20  # muzzle
	bullet.velocity = dir * bullet_speed
	bullet.damage = damage_per_shot
	get_tree().current_scene.add_child(bullet)

	# Muzzle flash (on the visible pixel sprite; the polygon barrel is hidden)
	FX.flash(_barrel_sprite, Color(2.0, 1.8, 1.0), 0.1)
	FX.pop(_barrel_sprite, Vector2(0.8, 1.0), 0.12)  # recoil
	FX.burst(get_parent(), global_position + dir * 12, Color(1, 0.9, 0.5), 5, 90.0, 0.15, 1.5, 0.0)
