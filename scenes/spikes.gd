extends Node2D
## Floor spikes: hurt enemies standing on them (2 every 0.5 s). Meant for the
## bottom of a pit; enemies climb out again, slowly.

const DAMAGE := 2
const TICK := 0.5
var _area: Area2D
var _t := 0.0


func _ready() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm:  # sit on the floor of the cell under the placement point
		var cell := tm.local_to_map(tm.to_local(global_position))
		for i in 6:
			if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
				break
			cell.y += 1
		var c := tm.to_global(tm.map_to_local(cell))
		global_position = Vector2(c.x, c.y + 8)
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/spikes.png")
	s.centered = false
	s.offset = Vector2(-8, -15)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	if has_meta("ghost"):
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 8
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 12)
	cs.shape = r
	cs.position = Vector2(0, -6)
	_area.add_child(cs)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	_t -= delta
	if _t > 0:
		return
	var hit := false
	for b in _area.get_overlapping_bodies():
		if b.is_in_group("enemies") and b.has_method("take_damage"):
			b.take_damage(DAMAGE)
			hit = true
	if hit:
		_t = TICK
