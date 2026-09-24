extends Node2D
## Pressure plate: sits on the ground; when an enemy steps on it, it opens
## the trapdoor of the nearest drop hopper (linked by a cable).

const LINK_RANGE := 320.0

var _spr: Sprite2D
var _hopper: Node2D
var _cable: Line2D
var _cooldown := 0.0
var _area: Area2D


func _ready() -> void:
	add_to_group("pressure_plates")
	_snap_to_floor()
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/plate.png")
	_spr.hframes = 2
	_spr.centered = false
	_spr.offset = Vector2(-14, -7)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_cable = Line2D.new()
	_cable.width = 1.0
	_cable.default_color = Color(0.25, 0.2, 0.18, 0.9)
	_cable.z_index = -1
	add_child(_cable)
	if has_meta("ghost"):
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 8  # enemies
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 10)
	cs.shape = r
	cs.position = Vector2(0, -6)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_step)
	relink()


## Sit on the top face of the solid tile under the placement point.
func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 6:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	var c := tm.to_global(tm.map_to_local(cell))
	global_position = Vector2(c.x, c.y + 8)


func relink() -> void:
	var best: Node2D = null
	var best_d := LINK_RANGE
	for h in get_tree().get_nodes_in_group("hoppers"):
		if h.has_meta("ghost"):
			continue
		var d: float = h.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = h
	_hopper = best
	_draw_cable()


func _draw_cable() -> void:
	if _cable == null:
		return
	if _hopper == null or not is_instance_valid(_hopper):
		_cable.points = PackedVector2Array()
		return
	var a := Vector2(10, -3)
	var b := to_local(_hopper.global_position + Vector2(13, 2))
	var pts := PackedVector2Array()
	for k in 13:  # a slack cable that sags between the plate and the hopper
		var t := k / 12.0
		var p := a.lerp(b, t)
		p.y += sin(t * PI) * minf(30.0, a.distance_to(b) * 0.15)
		pts.append(p)
	_cable.points = pts


func _process(delta: float) -> void:
	_cooldown -= delta
	if _hopper != null and not is_instance_valid(_hopper):
		relink()


func _on_step(body: Node2D) -> void:
	if not body.is_in_group("enemies") or _cooldown > 0:
		return
	_cooldown = 1.6
	_spr.frame = 1
	if _hopper and is_instance_valid(_hopper):
		_hopper.dump()
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		_spr.frame = 0
