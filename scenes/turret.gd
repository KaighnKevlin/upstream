extends Node2D

const ObjectSprites = preload("res://scripts/object_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")

@export var fire_rate: float = 1.5  # shots per second
@export var fire_range: float = 500.0
@export var bullet_speed: float = 300.0
@export var damage_per_shot: int = 2

var _ammo_port: Node = null
var _timer: float = 0.0
var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var _turret_sprite: Sprite2D

@onready var _barrel: Polygon2D = $Barrel


func setup(ammo_port: Node) -> void:
	_ammo_port = ammo_port

	# Replace polygon art
	$Base.visible = false
	_barrel.visible = false
	_turret_sprite = Sprite2D.new()
	_turret_sprite.texture = ObjectSprites.create_turret_texture()
	_turret_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_turret_sprite.scale = Vector2(1.5, 1.5)
	add_child(_turret_sprite)


func _physics_process(delta: float) -> void:
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
		tween.tween_property(_barrel, "modulate", Color(1, 0.3, 0.3), 0.1)
		tween.tween_property(_barrel, "modulate", Color.WHITE, 0.2)
		return

	# Aim barrel toward target
	var dir := (nearest.global_position - global_position).normalized()
	_barrel.rotation = dir.angle() + PI / 2  # +90° because barrel points up by default

	SFX.play(self, SFX.sfx_turret_fire())

	# Spawn bullet
	var bullet := _bullet_scene.instantiate()
	bullet.global_position = global_position + dir * 22  # tip of barrel
	bullet.velocity = dir * bullet_speed
	bullet.damage = damage_per_shot
	get_tree().current_scene.add_child(bullet)

	# Muzzle flash
	var tween := create_tween()
	tween.tween_property(_barrel, "modulate", Color(1, 1, 0.5), 0.03)
	tween.tween_property(_barrel, "modulate", Color.WHITE, 0.08)
