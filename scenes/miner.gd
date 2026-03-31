extends StaticBody2D

const LightTextures = preload("res://scripts/light_textures.gd")
const ObjectSprites = preload("res://scripts/object_sprites.gd")

## Angle of ore ejection in degrees (0 = straight up, positive = rightward).
@export_range(-60, 60, 1) var eject_angle: float = 0.0

## Force applied to ejected ore (pixels/s).
@export_range(100, 2000, 10) var eject_force: float = 800.0

## Seconds between ore ejections.
@export_range(0.3, 5.0, 0.1) var eject_interval: float = 1.5

var _ore_scene: PackedScene = preload("res://scenes/ore.tscn")
var _timer: float = 0.0


func _ready() -> void:
	# Replace polygon with pixel sprite
	if has_node("Sprite"):
		$Sprite.visible = false
	if has_node("Nozzle"):
		$Nozzle.visible = false
	if has_node("Light"):
		$Light.visible = false
	var spr := Sprite2D.new()
	spr.texture = ObjectSprites.create_miner_texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(128)
	light.texture_scale = 1.0
	light.energy = 0.6
	light.color = Color(0.4, 0.6, 1.0)
	add_child(light)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= eject_interval:
		_timer -= eject_interval
		_eject_ore()


func _eject_ore() -> void:
	# Find empty space above the miner to spawn ore
	var spawn_pos := _find_spawn_pos()
	if spawn_pos == Vector2.ZERO:
		return  # no empty space found, skip

	var ore := _ore_scene.instantiate() as RigidBody2D
	ore.global_position = spawn_pos

	var angle_rad := deg_to_rad(eject_angle - 90)
	var direction := Vector2(cos(angle_rad), sin(angle_rad))

	get_tree().current_scene.add_child(ore)
	ore.apply_central_impulse(direction * eject_force)


func _find_spawn_pos() -> Vector2:
	# Look upward from miner position for empty tile
	var tilemap := _get_tilemap()
	if tilemap == null:
		# No tilemap — just spawn above
		return global_position + Vector2(0, -20)

	var tile_pos := tilemap.local_to_map(tilemap.to_local(global_position))
	# Check up to 10 tiles above
	for i in range(1, 10):
		var check := Vector2i(tile_pos.x, tile_pos.y - i)
		if tilemap.get_cell_source_id(check) == -1:
			return tilemap.to_global(tilemap.map_to_local(check))

	return Vector2.ZERO  # no empty space found


func _get_tilemap() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene and scene.has_node("TileMapLayer"):
		return scene.get_node("TileMapLayer") as TileMapLayer
	return null
