extends Node

enum BuildType { NONE, TRAMPOLINE, MINER, LASER }

var current_build: BuildType = BuildType.NONE
var _ghost: Node2D = null
var _placed_buildings: Array[Node2D] = []

var _scenes := {
	BuildType.TRAMPOLINE: preload("res://scenes/trampoline.tscn"),
	BuildType.MINER: preload("res://scenes/miner.tscn"),
	BuildType.LASER: preload("res://scenes/laser_smelter.tscn"),
}

var _ghost_colors := {
	BuildType.TRAMPOLINE: Color(0.2, 0.85, 0.3, 0.4),
	BuildType.MINER: Color(0.3, 0.3, 0.8, 0.4),
	BuildType.LASER: Color(1.0, 0.2, 0.1, 0.4),
}

signal build_mode_changed(build_type: BuildType)


func _input(event: InputEvent) -> void:
	# Number keys to select build type
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_set_build(BuildType.TRAMPOLINE)
			KEY_2:
				_set_build(BuildType.MINER)
			KEY_3:
				_set_build(BuildType.LASER)
			KEY_ESCAPE:
				_set_build(BuildType.NONE)

	# Place building on click
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and current_build != BuildType.NONE:
			_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_building_at_mouse()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _ghost != null:
		var pos := _get_world_mouse_pos()
		_ghost.global_position = pos

		# Show red ghost if placement is invalid
		var valid := _can_place(pos)
		_ghost.modulate = _ghost_colors[current_build] if valid else Color(1.0, 0.2, 0.2, 0.4)


func _set_build(build_type: BuildType) -> void:
	current_build = build_type
	build_mode_changed.emit(build_type)

	# Remove old ghost
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null

	# Create ghost preview
	if build_type != BuildType.NONE:
		_ghost = _scenes[build_type].instantiate()
		_ghost.modulate = _ghost_colors[build_type]
		# Disable all processing on ghost
		_ghost.set_physics_process(false)
		_ghost.set_process(false)
		# Disable collisions on ghost children
		_disable_collisions(_ghost)
		get_tree().current_scene.add_child(_ghost)


func _can_place(pos: Vector2) -> bool:
	var tilemap := _get_tilemap()

	if current_build == BuildType.MINER:
		# Miners: must be on ore
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			var atlas_coords := tilemap.get_cell_atlas_coords(tile_pos)
			if atlas_coords.x != 2 and atlas_coords.x != 3:
				return false
	else:
		# Trampolines and lasers: must be in empty space (no solid tile)
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			var source_id := tilemap.get_cell_source_id(tile_pos)
			if source_id != -1:
				return false

	# Check overlap with existing buildings
	for building in _placed_buildings:
		if not is_instance_valid(building):
			continue
		if building.global_position.distance_to(pos) < 30:
			return false

	return true


func _place_building() -> void:
	var pos := _get_world_mouse_pos()
	if not _can_place(pos):
		return

	var building: Node2D = _scenes[current_build].instantiate()
	building.global_position = pos
	get_tree().current_scene.add_child(building)
	_placed_buildings.append(building)


func _get_tilemap() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene and scene.has_node("TileMapLayer"):
		return scene.get_node("TileMapLayer") as TileMapLayer
	return null


func _remove_building_at_mouse() -> void:
	var mouse_pos := _get_world_mouse_pos()
	var closest: Node2D = null
	var closest_dist := 50.0  # max removal distance

	for building in _placed_buildings:
		if not is_instance_valid(building):
			continue
		var dist: float = building.global_position.distance_to(mouse_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = building

	if closest != null:
		_placed_buildings.erase(closest)
		closest.queue_free()


func _get_world_mouse_pos() -> Vector2:
	var viewport := get_viewport()
	var canvas := viewport.get_canvas_transform()
	return canvas.affine_inverse() * viewport.get_mouse_position()


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape2D:
		node.disabled = true
	if node is Area2D:
		node.monitoring = false
	for child in node.get_children():
		_disable_collisions(child)
