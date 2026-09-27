extends Node2D
## Drone dock: a landing pad that launches two porter drones (scenes/
## drone.gd). They tidy up loose pieces within RANGE of it: ingots to the
## dome's intake, ore and shot to the nearest funnel turret. Remove the
## dock and its drones go with it.
## Art: tools/art/gen_drone.py (dock.png, 40x26, feet at the bottom).

const RANGE := 320.0
const DRONES := 2

var _drones: Array[Node2D] = []


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/dock.png")
	spr.centered = false
	spr.offset = Vector2(-20, -25)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	if has_meta("ghost"):
		return
	add_to_group("docks")
	# the pad is a floor: pieces can land on it
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(38, 10)
	cs.shape = r
	cs.position = Vector2(0, -5)
	body.add_child(cs)
	add_child(body)
	for k in DRONES:
		call_deferred("_launch", k)


func _launch(k: int) -> void:
	var d: Node2D = preload("res://scenes/drone.gd").new()
	d.dock = self
	d.global_position = global_position + Vector2(-8 + k * 16, -30)
	get_parent().add_child(d)
	_drones.append(d)


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func delivered() -> int:
	var n := 0
	for d in _drones:
		if is_instance_valid(d):
			n += d.delivered
	return n


func _exit_tree() -> void:
	for d in _drones:
		if is_instance_valid(d):
			d.queue_free()
