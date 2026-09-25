extends Node2D
## Chute: a sloped steel rail that only ore rides. Ore landing on it loses
## its bounce and rolls downhill, leaving the low end at whatever speed the
## drop gave it, so gravity carries ore sideways: gather a tapper's spray,
## steer ore round an obstacle, or feed a funnel from the side.
## One-way like the trampoline: ore coming up from underneath passes
## through. The player and enemies don't collide with it at all.
##
## Placed by its top end; click it, then drag the end handle to set the
## slope and length.

const ORE_ONLY := 64          # physics layer 7: ore and ingots collide with it
const LEN_MIN := 32.0
const LEN_MAX := 220.0
const POST_MAX := 220.0
const LIP := 7.0              # little stop at the high end so landings don't roll off backwards

## The other end of the rail, relative to where it was placed.
@export var end_offset := Vector2(84, 36)

var has_lip := true          # belts carry ore up past their high end: no stop
var _body: StaticBody2D
var _posts: Array[Line2D] = []
var _selected := false
var _dragging := false
static var _steel := _make_steel()


static func _make_steel() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.5
	m.absorbent = true   # cancels the ore's own bounce: landings stick, then roll
	m.friction = 1.0     # combined friction is the ore's (0.3): it rolls rather than skids
	return m


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	_body.physics_material_override = _steel
	add_child(_body)
	_rebuild()


## Endpoints left to right (the one-way side is always the top).
func _ends() -> Array:
	var a := Vector2.ZERO
	var b := end_offset
	return [a, b] if a.x <= b.x else [b, a]


func _rebuild() -> void:
	queue_redraw()
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var rail := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2.ZERO
	seg.b = Vector2((b - a).length(), 0)
	rail.shape = seg
	rail.position = a
	rail.rotation = (b - a).angle()
	rail.one_way_collision = true
	rail.one_way_collision_margin = 4.0
	_body.add_child(rail)
	if has_lip:
		var high := a if a.y < b.y else b
		var lip := CollisionShape2D.new()
		var ls := SegmentShape2D.new()
		ls.a = high
		ls.b = high + Vector2(0, -LIP)
		lip.shape = ls
		_body.add_child(lip)
	_rebuilt()
	_build_posts()


## For subclasses (the belt adds its grip area).
func _rebuilt() -> void:
	pass


func _build_posts() -> void:
	for p in _posts:
		p.queue_free()
	_posts.clear()
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	for end in _ends():
		var top := to_global(end) + Vector2(0, 2)
		var q := PhysicsRayQueryParameters2D.create(top, top + Vector2(0, POST_MAX), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var leg := Line2D.new()
		leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
		leg.texture = preload("res://assets/sprites/strut.png")
		leg.texture_mode = Line2D.LINE_TEXTURE_TILE
		leg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		leg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		leg.width = 5.0
		leg.z_index = -2
		add_child(leg)
		_posts.append(leg)


# ── look: a riveted steel trough, lighter lip on top, ties underneath ──

const DARK := Color(0.09, 0.07, 0.1)
const STEEL := Color(0.42, 0.44, 0.5)
const SHINE := Color(0.78, 0.82, 0.86)
const BRASS := Color(0.85, 0.62, 0.28)


func _draw() -> void:
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var d := (b - a)
	var l := d.length()
	if l < 1:
		return
	var t := d / l
	var n := Vector2(t.y, -t.x)   # up, off the running surface
	# ties / brackets under the rail
	var k := 6.0
	while k < l - 3:
		var p := a + t * k
		draw_line(p - n * 1, p - n * 6, DARK, 3.0)
		draw_line(p - n * 2, p - n * 5, STEEL.darkened(0.3), 1.0)
		k += 12.0
	# the trough: dark outline, steel body, bright running surface
	draw_line(a - n * 2, b - n * 2, DARK, 6.0)
	draw_line(a - n * 2, b - n * 2, STEEL, 3.0)
	draw_line(a - n * 0.5, b - n * 0.5, SHINE, 1.0)
	# rivets
	k = 10.0
	while k < l - 5:
		var r := a + t * k - n * 3
		draw_rect(Rect2(r.round() - Vector2(0.5, 0.5), Vector2(1, 1)), BRASS)
		k += 20.0
	_draw_surface(a, b, t, n, l)
	# stop at the high end, brass caps on both ends
	var high := a if a.y < b.y else b
	if has_lip:
		draw_line(high + Vector2(0, 1), high + Vector2(0, -LIP), DARK, 4.0)
		draw_line(high + Vector2(0, 0), high + Vector2(0, -LIP + 1), STEEL, 2.0)
	for p in [a, b]:
		draw_rect(Rect2((p - n * 2).round() - Vector2(2, 2), Vector2(4, 4)), DARK)
		draw_rect(Rect2((p - n * 2).round() - Vector2(1, 1), Vector2(2, 2)), BRASS)
	_draw_selected()


func _draw_surface(_a: Vector2, _b: Vector2, _t: Vector2, _n: Vector2, _l: float) -> void:
	pass


func _draw_selected() -> void:
	if _selected:
		draw_line(Vector2.ZERO, end_offset, Color(1.0, 0.7, 0.2, 0.35), 1.0)
		var h := end_offset
		draw_circle(h, 6.0, DARK)
		draw_circle(h, 4.5, Color(1.0, 0.7, 0.2))


# ── aiming UI: click to select, drag the end handle ────────────────────

func _dist_to_rail(p: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(to_local(p), Vector2.ZERO, end_offset).distance_to(to_local(p))


func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	modulate = Color(1.2, 1.15, 1.05) if on else Color.WHITE
	queue_redraw()


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	_rebuild()


func _input(event: InputEvent) -> void:
	if _body == null:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			_set_selected(false)
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			_set_selected(false)
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _selected and mouse.distance_to(to_global(end_offset)) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif _dist_to_rail(mouse) < 8:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		set_end(to_local(mouse).snapped(Vector2(2, 2)))
		get_viewport().set_input_as_handled()
