extends Area2D

const ObjectSprites = preload("res://scripts/object_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

var velocity := Vector2.ZERO
var damage := 1
var lifetime := 3.0
var _timer := 0.0
var _bounces := 0
var _spr: Sprite2D

const HIT_RADIUS := 14.0
const MAX_BOUNCES := 3


func _ready() -> void:
	if has_node("Sprite"):
		$Sprite.queue_free()
	var spr := Sprite2D.new()
	var shot := load("res://assets/sprites/shot.png") as Texture2D
	if shot:  # brass slug with a hot trail, pointed along its flight
		spr.texture = shot
		spr.offset = Vector2(-2, 0)
		spr.rotation = velocity.angle()
	else:
		spr.texture = ObjectSprites.create_bullet_texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	_spr = spr


func _physics_process(delta: float) -> void:
	var next_pos := global_position + velocity * delta

	# Check tile collision
	var tilemap := _get_tilemap()
	if tilemap:
		var tile_pos := tilemap.local_to_map(tilemap.to_local(next_pos))
		if tilemap.get_cell_source_id(tile_pos) != -1:
			# Hit a tile — destroy bullet
			FX.burst(get_parent(), global_position, Color(1, 0.85, 0.4), 4, 60.0, 0.2, 1.5)
			queue_free()
			return

	position += velocity * delta
	if _spr:
		_spr.rotation = velocity.angle()
	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	# Check enemy hits
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < HIT_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			queue_free()
			return

	# Check trampoline bounces
	if _bounces < MAX_BOUNCES:
		var scene := get_tree().current_scene
		for child in scene.get_children():
			if child.has_method("_launch_dir") and global_position.distance_to(child.global_position) < 22:
				# Reflect bullet off the trampoline surface
				var normal: Vector2 = child._launch_dir()  # surface normal = launch direction
				velocity = velocity.bounce(normal) * 0.9  # slight speed loss on bounce
				_bounces += 1
				SFX.play(self, SFX.sfx_bounce())
				break


func _get_tilemap() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene and scene.has_node("TileMapLayer"):
		return scene.get_node("TileMapLayer") as TileMapLayer
	return null
