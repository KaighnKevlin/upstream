extends Node

enum BuildType { NONE, TRAMPOLINE, MINER, LASER, UPSTREAM, HOPPER, TURRET, SPIKES, CATAPULT, CHUTE, SPLITTER, BUMPER, BELT, BELLOWS, PENDULUM, WHEEL, ASSEMBLER, LAB, TESLA, FLAMER, TRAPDOOR, CRUSHER, MAGNET, HARPOON, SEESAW, TUBE, KEG, SNARE }

var current_build: BuildType = BuildType.NONE
var _ghost: Node2D = null
var _placed_buildings: Array[Node2D] = []
var ui_rects: Array[Callable] = []   # screen rects (HUD) that clicks don't build/remove through

var _scenes := {
	BuildType.TRAMPOLINE: preload("res://scenes/trampoline.tscn"),
	BuildType.MINER: preload("res://scenes/miner.tscn"),
	BuildType.LASER: preload("res://scenes/laser_smelter.tscn"),
	BuildType.UPSTREAM: preload("res://scenes/upstream_shaft.tscn"),
	BuildType.HOPPER: preload("res://scenes/hopper.tscn"),
	BuildType.TURRET: preload("res://scenes/funnel_turret.tscn"),
	BuildType.SPIKES: preload("res://scenes/spikes.tscn"),
	BuildType.CATAPULT: preload("res://scenes/catapult.tscn"),
	BuildType.CHUTE: preload("res://scenes/chute.tscn"),
	BuildType.SPLITTER: preload("res://scenes/splitter.tscn"),
	BuildType.BUMPER: preload("res://scenes/bumper.tscn"),
	BuildType.BELT: preload("res://scenes/belt.tscn"),
	BuildType.BELLOWS: preload("res://scenes/bellows.tscn"),
	BuildType.PENDULUM: preload("res://scenes/pendulum.tscn"),
	BuildType.WHEEL: preload("res://scenes/gravity_wheel.tscn"),
	BuildType.ASSEMBLER: preload("res://scenes/assembler.tscn"),
	BuildType.LAB: preload("res://scenes/lab.tscn"),
	BuildType.TESLA: preload("res://scenes/tesla.tscn"),
	BuildType.FLAMER: preload("res://scenes/flamer.tscn"),
	BuildType.TRAPDOOR: preload("res://scenes/trapdoor.tscn"),
	BuildType.CRUSHER: preload("res://scenes/crusher.tscn"),
	BuildType.MAGNET: preload("res://scenes/magnet.tscn"),
	BuildType.HARPOON: preload("res://scenes/harpoon.tscn"),
	BuildType.SEESAW: preload("res://scenes/seesaw.tscn"),
	BuildType.TUBE: preload("res://scenes/tube.tscn"),
	BuildType.KEG: preload("res://scenes/keg.tscn"),
	BuildType.SNARE: preload("res://scenes/snare.tscn"),
}

var _ghost_colors := {
	BuildType.TRAMPOLINE: Color(0.2, 0.85, 0.3, 0.4),
	BuildType.MINER: Color(0.3, 0.3, 0.8, 0.4),
	BuildType.LASER: Color(1.0, 0.2, 0.1, 0.4),
	BuildType.UPSTREAM: Color(0.3, 0.5, 1.0, 0.4),
	BuildType.HOPPER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TURRET: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SPIKES: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.CATAPULT: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.CHUTE: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SPLITTER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BUMPER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BELT: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BELLOWS: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.PENDULUM: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.WHEEL: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.ASSEMBLER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.LAB: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TESLA: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.FLAMER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TRAPDOOR: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.CRUSHER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.MAGNET: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.HARPOON: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SEESAW: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TUBE: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.KEG: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SNARE: Color(1.0, 0.85, 0.5, 0.5),
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
			KEY_4:
				_set_build(BuildType.UPSTREAM)
			KEY_5:
				_set_build(BuildType.HOPPER)
			KEY_6:
				_set_build(BuildType.TURRET)
			KEY_7:
				_set_build(BuildType.SPIKES)
			KEY_8:
				_set_build(BuildType.CATAPULT)
			KEY_9:
				_set_build(BuildType.CHUTE)
			KEY_0:
				_set_build(BuildType.SPLITTER)
			KEY_B:
				_set_build(BuildType.BUMPER)
			KEY_C:
				_set_build(BuildType.BELT)
			KEY_V:
				_set_build(BuildType.BELLOWS)
			KEY_M:
				_set_build(BuildType.PENDULUM)
			KEY_N:
				_set_build(BuildType.WHEEL)
			KEY_T:
				_set_build(BuildType.ASSEMBLER)
			KEY_Y:
				_set_build(BuildType.LAB)
			KEY_U:
				_set_build(BuildType.TESLA)
			KEY_I:
				_set_build(BuildType.FLAMER)
			KEY_X:
				_set_build(BuildType.TRAPDOOR)
			KEY_R:
				_set_build(BuildType.CRUSHER)
			KEY_Z:
				_set_build(BuildType.MAGNET)
			KEY_ESCAPE, KEY_Q:
				_set_build(BuildType.NONE)

	# Chutes and belts are drawn: press at the top end, drag, release at the other end
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _drag_from != null:
		_place_chute(_drag_from, _get_world_mouse_pos() - _drag_from)
		_drag_from = null
		get_viewport().set_input_as_handled()
		return

	# Place building on click
	if event is InputEventMouseButton and event.pressed:
		for r in ui_rects:
			if (r.call() as Rect2).has_point(event.position):
				return  # the HUD handles it
		if event.button_index == MOUSE_BUTTON_LEFT and current_build in [BuildType.CHUTE, BuildType.BELT, BuildType.TUBE]:
			var at := _get_world_mouse_pos()
			if _can_place(at):
				_drag_from = at
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and current_build != BuildType.NONE:
			_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_building_at_mouse()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _ghost != null and _drag_from != null:
		# drawing a chute: the ghost's top stays put, its end follows the mouse
		_ghost.global_position = _drag_from
		var off: Vector2 = _get_world_mouse_pos() - _drag_from
		if off.length() >= DRAG_MIN:
			_ghost.set_end(off)
		return
	if _ghost != null:
		var pos := _get_world_mouse_pos()
		_ghost.global_position = _ghost.snap_pos(pos) if _ghost.has_method("snap_pos") else pos

		# Show red ghost if placement is invalid
		var valid := _can_place(pos)
		_ghost.modulate = _ghost_colors[current_build] if valid else Color(1.0, 0.2, 0.2, 0.4)


var _drag_from = null   # Vector2 while a chute is being drawn
const DRAG_MIN := 12.0


func _place_chute(from: Vector2, off: Vector2) -> void:
	var building: Node2D = _scenes[current_build].instantiate()
	building.global_position = from
	if off.length() >= DRAG_MIN:  # a plain click keeps the default slope
		building.end_offset = off.normalized() * clampf(off.length(), building.LEN_MIN, building.LEN_MAX)
	get_tree().current_scene.add_child(building)
	_placed_buildings.append(building)
	if _ghost:
		_ghost.set_end(building.end_offset)  # next one starts from the same shape


func _set_build(build_type: BuildType) -> void:
	_drag_from = null
	current_build = build_type
	build_mode_changed.emit(build_type)

	# Remove old ghost
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null

	# Create ghost preview
	if build_type != BuildType.NONE:
		_ghost = _scenes[build_type].instantiate()
		_ghost.set_meta("ghost", true)  # buildings skip physics setup for ghosts
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
		# Tappers: on an ore block whose top face is dug out (the rig sits above it)
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) == -1:
				return false
			var atlas_coords := tilemap.get_cell_atlas_coords(tile_pos)
			if atlas_coords.x != 2 and atlas_coords.x != 3:
				return false
			if tilemap.get_cell_source_id(tile_pos + Vector2i(0, -1)) != -1:
				return false
	elif current_build == BuildType.TRAPDOOR:
		# over a pit: the cell and the one below it open
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) != -1 or tilemap.get_cell_source_id(tile_pos + Vector2i(0, 1)) != -1:
				return false
	elif current_build in [BuildType.SPIKES, BuildType.CATAPULT, BuildType.BUMPER, BuildType.ASSEMBLER, BuildType.LAB, BuildType.TESLA, BuildType.FLAMER, BuildType.CRUSHER, BuildType.HARPOON, BuildType.SEESAW, BuildType.KEG, BuildType.SNARE]:
		# on a floor: empty cell with solid ground just below
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) != -1:
				return false
			if tilemap.get_cell_source_id(tile_pos + Vector2i(0, 1)) == -1:
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
	if current_build == BuildType.UPSTREAM:
		# on top of a lift: it grows instead
		var lift := _lift_below(pos)
		if lift:
			lift.extend()
			return
	if not _can_place(pos):
		return

	var building: Node2D = _scenes[current_build].instantiate()
	building.global_position = pos
	get_tree().current_scene.add_child(building)
	_placed_buildings.append(building)


## A lift whose top is just under `pos` (building there extends it).
func _lift_below(pos: Vector2) -> Node2D:
	for b in _placed_buildings:
		if is_instance_valid(b) and b.has_method("extend") and absf(b.global_position.x - pos.x) < 28.0 \
				and pos.y < b.top_y() + 30.0 and pos.y > b.top_y() - 100.0:
			return b
	return null


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
