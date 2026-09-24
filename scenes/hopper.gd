extends Node2D
## Drop hopper: a brass funnel on stilts over a cage bin. Ore bounced into
## the funnel piles up inside physically (and doesn't despawn while stored).
## A linked pressure plate opens the trapdoor: the pile drops on whatever is
## underneath, and falling ore hurts enemies (see ore.gd).
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

var _door: StaticBody2D
var _leaf_l: Sprite2D
var _leaf_r: Sprite2D
var _store: Area2D
var _open := false
var _lamp: Sprite2D


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
	get_tree().call_group("pressure_plates", "relink")


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


func _physics_process(_delta: float) -> void:
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
