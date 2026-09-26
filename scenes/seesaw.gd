extends Node2D
## Seesaw: a timber plank on a brass fulcrum, a real rigid body on a pin.
## Drop something heavy on one end and the other end comes up hard: whatever
## sits there (ore, you, an enemy) is flung into the air. Heavy iron
## catapults light copper; copper barely stirs a load of iron. A piece of
## the Rube Goldberg machine: a stream landing on one end, the flung ore
## flying on into a chute or a hopper. Rests on stops about 15 degrees each way.
## Art: tools/art/gen_seesaw.py.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const PIVOT := Vector2(0, -16)
const HALF := 34.0            # pivot to each end
const LIMIT := 0.26           # radians each way (shallow enough that ore rests on the low end)
const FLING := 1.35           # bodies on a rising end leave at its speed times this

var flings := 0               # tests
var _plank: RigidBody2D
var _cool := {}


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	var base := Sprite2D.new()
	base.texture = preload("res://assets/sprites/seesaw_base.png")
	base.centered = false
	base.offset = Vector2(-14, -19)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(base)
	if has_meta("ghost"):
		var s := Sprite2D.new()
		s.texture = preload("res://assets/sprites/seesaw_plank.png")
		s.position = PIVOT
		s.offset = Vector2(0, -3)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		return
	var anchor := StaticBody2D.new()
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	anchor.position = PIVOT
	add_child(anchor)
	_plank = RigidBody2D.new()
	_plank.position = PIVOT
	_plank.collision_layer = 1        # you and enemies stand on it
	_plank.collision_mask = 2 | 128   # loose items push it about; it rests on its stops (128)
	_plank.mass = 2.0
	_plank.angular_damp = 0.8
	_plank.gravity_scale = 0.0        # balanced on the pin; loads tip it
	_plank.can_sleep = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2 + 4, 6)
	cs.shape = r
	_plank.add_child(cs)
	for side in [-1.0, 1.0]:   # raised brass caps: loads rest against them instead of rolling off
		var lip := CollisionShape2D.new()
		var lr := RectangleShape2D.new()
		lr.size = Vector2(4, 12)
		lip.shape = lr
		lip.position = Vector2(side * (HALF + 1.0), -4.0)
		_plank.add_child(lip)
	var grip := PhysicsMaterial.new()
	grip.friction = 1.0
	grip.bounce = 0.0
	_plank.physics_material_override = grip
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/seesaw_plank.png")
	spr.offset = Vector2(0, -3)   # the art's pivot is 3px below its centre
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plank.add_child(spr)
	add_child(_plank)
	# stops under each end, on a layer only the plank sees
	var stops := StaticBody2D.new()
	stops.collision_layer = 128
	stops.collision_mask = 0
	for side in [-1.0, 1.0]:
		var sc := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 2.0
		sc.shape = c
		sc.position = PIVOT + Vector2(side * HALF * cos(LIMIT), HALF * sin(LIMIT) + 5.0)
		stops.add_child(sc)
	add_child(stops)
	var pin := PinJoint2D.new()
	pin.position = PIVOT
	add_child(pin)
	pin.node_a = pin.get_path_to(anchor)    # paths resolve once it's in the tree
	pin.node_b = pin.get_path_to(_plank)


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


func _physics_process(delta: float) -> void:
	if _plank == null:
		return
	for k in _cool.keys():
		_cool[k] -= delta
		if _cool[k] <= 0:
			_cool.erase(k)
	var w := _plank.angular_velocity
	if absf(w) < 2.0:
		return
	# the end that's rising flings whatever stands on it
	for side in [-1.0, 1.0]:
		var end_v := Vector2(0, side * HALF * w)          # y speed of that end (up is negative)
		if end_v.y > -150.0:
			continue
		var end := _plank.to_global(Vector2(side * HALF * 0.75, -4))
		# loose items riding the rising end leave with it, catapulted
		for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
			if not is_instance_valid(o) or o.freeze or _cool.has(o):
				continue
			var p: Vector2 = o.global_position
			if absf(p.x - end.x) < 18.0 and p.y < end.y + 6.0 and p.y > end.y - 20.0:
				o.linear_velocity = Vector2(o.linear_velocity.x + side * 40.0, minf(o.linear_velocity.y, end_v.y * FLING))
				_cool[o] = 0.5
				flings += 1
		var bodies := get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("player")
		for b in bodies:
			if not (b is CharacterBody2D) or _cool.has(b) or ("_dying" in b and b._dying):
				continue
			var feet: Vector2 = b.global_position
			if absf(feet.x - end.x) < 16.0 and feet.y < end.y + 6.0 and feet.y > end.y - 30.0:
				var v := Vector2(side * 60.0, end_v.y * FLING)
				if b.has_method("launch"):
					b.launch(v)
				elif b.has_method("knock"):
					b.knock(v)
					b._knock_t = 0.5
				_cool[b] = 0.5
				flings += 1
				FX.burst(get_parent(), end, Color(0.66, 0.5, 0.32), 5, 60.0, 0.3, 1.4)
				SFX.play_small(self, SFX.sfx_bounce(), -6.0, 0.8)
