extends Node2D
## Drop hopper: a brass funnel on stilts over a cage bin. Ore bounced into
## the funnel piles up inside physically (and doesn't despawn while stored).
## Its own pressure plate sits on the ground nearby, on a cable: when an
## enemy steps on it the trapdoor opens and the pile drops on whatever is
## underneath (falling ore hurts enemies, see ore.gd). Click the hopper and
## drag the plate's handle to move the plate along the ground.
## Geometry matches tools/art/gen_traps.py (origin = centre of the bin).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const FUNNEL_L := [Vector2(-26, -34), Vector2(-11, -18)]
const FUNNEL_R := [Vector2(26, -34), Vector2(11, -18)]
const BIN_TOP := -18.0
const BIN_BOTTOM := 26.0
const BIN_HALF := 11.0
const OPEN_TIME := 1.1
const LEG_MAX := 140.0
const PLATE_RANGE := 200.0

## Where the plate sits, in px along the ground from the hopper (+ = right,
## the side enemies come from). Under the hopper suits walkers; move it
## ahead (+) for fast ones so the pile is already falling when they arrive.
@export var plate_offset_x := 0.0

var _door: StaticBody2D
var _leaf_l: Sprite2D
var _leaf_r: Sprite2D
var _store: Area2D
var _open := false
var _lamp: Sprite2D
var _plate: Node2D
var _walls: StaticBody2D
var _plate_spr: Sprite2D
var _plate_area: Area2D
var _cable: Line2D
var _handle: Polygon2D
var _selected := false
var _dragging := false
var _plate_cooldown := 0.0


func _ready() -> void:
	add_to_group("hoppers")
	var back := _sprite("res://assets/sprites/hopper_back.png", -1)
	back.offset = Vector2(0, -38 + 36)  # 64x72, origin (32, 38)
	var front := _sprite("res://assets/sprites/hopper_front.png", 1)
	front.offset = back.offset
	_leaf_l = _leaf(Vector2(-BIN_HALF, BIN_BOTTOM + 1), false)
	_leaf_r = _leaf(Vector2(BIN_HALF, BIN_BOTTOM + 1), true)
	if has_meta("ghost"):
		return
	_build_legs()

	# walls: terrain layer, so ore (and the player) collide with them
	var walls := StaticBody2D.new()
	_walls = walls
	walls.collision_layer = 1
	walls.collision_mask = 0
	for seg in [FUNNEL_L, FUNNEL_R, [Vector2(-BIN_HALF, BIN_TOP), Vector2(-BIN_HALF, BIN_BOTTOM)],
			[Vector2(BIN_HALF, BIN_TOP), Vector2(BIN_HALF, BIN_BOTTOM)]]:
		_segment(walls, seg[0], seg[1])
	add_child(walls)
	_door = StaticBody2D.new()
	_door.collision_layer = 1
	_door.collision_mask = 0
	_segment(_door, Vector2(-BIN_HALF, BIN_BOTTOM), Vector2(BIN_HALF, BIN_BOTTOM))
	add_child(_door)

	# the stored-ore zone (keeps ore from despawning)
	_store = Area2D.new()
	_store.collision_layer = 0
	_store.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BIN_HALF * 2, BIN_BOTTOM - BIN_TOP + 16)
	shape.shape = rect
	shape.position = Vector2(0, (BIN_TOP + BIN_BOTTOM) / 2.0 - 8)
	_store.add_child(shape)
	add_child(_store)
	_build_plate()


func _sprite(path: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	add_child(s)
	return s


func _leaf(hinge: Vector2, mirrored: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/trapdoor.png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.offset = Vector2(0, -2)
	s.position = hinge
	s.scale.x = -1.0 if mirrored else 1.0
	s.z_index = 1
	add_child(s)
	return s


func _segment(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	body.add_child(cs)


## Brass stilts from the bin's corners down to the ground.
func _build_legs() -> void:
	var space := get_world_2d().direct_space_state
	for side in [-1.0, 1.0]:
		var top := global_position + Vector2(side * (BIN_HALF + 1), BIN_BOTTOM - 4)
		var q := PhysicsRayQueryParameters2D.create(top, top + Vector2(side * 10, LEG_MAX), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var leg := Line2D.new()
		leg.points = PackedVector2Array([to_local(top), to_local(hit.position)])
		leg.width = 2.0
		leg.default_color = Color(0.66, 0.52, 0.32)
		leg.z_index = -2
		add_child(leg)
		var foot := Line2D.new()
		foot.points = PackedVector2Array([to_local(hit.position) + Vector2(-3, 0), to_local(hit.position) + Vector2(3, 0)])
		foot.width = 2.0
		foot.default_color = Color(0.35, 0.28, 0.2)
		foot.z_index = -2
		add_child(foot)


# ── the plate ──────────────────────────────────────────────────────────

func _build_plate() -> void:
	_cable = Line2D.new()
	_cable.width = 1.0
	_cable.default_color = Color(0.25, 0.2, 0.18, 0.9)
	_cable.z_index = -1
	add_child(_cable)
	_plate = Node2D.new()
	add_child(_plate)
	_plate_spr = Sprite2D.new()
	_plate_spr.texture = load("res://assets/sprites/plate.png")
	_plate_spr.hframes = 2
	_plate_spr.centered = false
	_plate_spr.offset = Vector2(-14, -7)
	_plate_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.add_child(_plate_spr)
	_plate_area = Area2D.new()
	_plate_area.collision_layer = 0
	_plate_area.collision_mask = 8  # enemies
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 10)
	cs.shape = r
	cs.position = Vector2(0, -6)
	_plate_area.add_child(cs)
	_plate.add_child(_plate_area)
	_plate_area.body_entered.connect(_on_plate_step)
	_handle = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(Vector2.from_angle(k * TAU / 12) * 5)
	_handle.polygon = pts
	_handle.color = Color(1.0, 0.7, 0.2)
	_handle.position = Vector2(0, -16)
	_handle.visible = false
	_handle.z_index = 21
	_plate.add_child(_handle)
	_place_plate()


## Put the plate on the ground under hopper.x + plate_offset_x.
func _place_plate() -> void:
	var space := get_world_2d().direct_space_state
	var x := global_position.x + plate_offset_x
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y), Vector2(x, global_position.y + 260), 1)
	q.exclude = [_walls.get_rid(), _door.get_rid()]  # not our own bin / trapdoor
	var hit := space.intersect_ray(q)
	var ground_y: float = hit.position.y if not hit.is_empty() else global_position.y + BIN_BOTTOM + 60
	_plate.global_position = Vector2(x, ground_y)
	# slack cable from the plate up to the bin's side
	var side := signf(plate_offset_x) if absf(plate_offset_x) > 1.0 else 1.0
	var a := _plate.position + Vector2(-10 * side, -3)
	var b := Vector2(BIN_HALF * side, 4)
	var cable := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		var p := a.lerp(b, t)
		p.y += sin(t * PI) * minf(24.0, a.distance_to(b) * 0.12)
		cable.append(p)
	_cable.points = cable


func _on_plate_step(body: Node2D) -> void:
	if not body.is_in_group("enemies") or _plate_cooldown > 0:
		return
	_plate_cooldown = 1.6
	_plate_spr.frame = 1
	dump()
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		_plate_spr.frame = 0


func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	if _handle:
		_handle.visible = on
	modulate = Color(1.2, 1.15, 1.05) if on else Color.WHITE


func _input(event: InputEvent) -> void:
	if _plate == null:
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
	var local := to_local(mouse)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var over_hopper := absf(local.x) < 26 and local.y > -36 and local.y < BIN_BOTTOM + 4
			if _selected and mouse.distance_to(_handle.global_position) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif over_hopper:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		plate_offset_x = clampf(local.x, -PLATE_RANGE, PLATE_RANGE)
		_place_plate()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_plate_cooldown -= delta
	if _store == null:
		return
	for body in _store.get_overlapping_bodies():
		if "_timer" in body:
			body._timer = 0.0  # stored ore keeps


func stored_count() -> int:
	return _store.get_overlapping_bodies().size() if _store else 0


## Pressure plate calls this: open the trapdoor, let the pile fall, close.
func dump() -> void:
	if _open or _door == null:
		return
	_open = true
	for cs in _door.get_children():
		cs.set_deferred("disabled", true)
	var t := create_tween().set_parallel()
	t.tween_property(_leaf_l, "rotation", PI / 2, 0.12)
	t.tween_property(_leaf_r, "rotation", -PI / 2, 0.12)
	SFX.play(self, SFX.sfx_turret_fire())
	FX.burst(get_parent(), global_position + Vector2(0, BIN_BOTTOM), Color(0.55, 0.45, 0.35), 8, 40.0, 0.4, 2.0)
	# resting ore is asleep and wouldn't notice the floor going: wake it once
	# the door's collision is actually off, and give it a shove downward
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in _store.get_overlapping_bodies():
		if body is RigidBody2D:
			body.sleeping = false
			body.linear_velocity += Vector2(randf_range(-10, 10), 60)
	await get_tree().create_timer(OPEN_TIME).timeout
	if not is_inside_tree():
		return
	for cs in _door.get_children():
		cs.set_deferred("disabled", false)
	var c := create_tween().set_parallel()
	c.tween_property(_leaf_l, "rotation", 0.0, 0.2)
	c.tween_property(_leaf_r, "rotation", 0.0, 0.2)
	_open = false
