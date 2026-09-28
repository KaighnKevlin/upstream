extends Node2D
## Flip-flop: the marble-machine splitter. A brass rocker on a pivot under
## a little funnel, tipped one way; a marble drops onto it, rolls off the
## low side, and its weight rocks the rocker over the other way as it
## leaves, so the next goes the other way. Every other, by gravity alone.
## Ore-only layer (like chutes): walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const TILT := 0.55               # rad each way
const ARM := 15.0                # half-length of the rocker

var tilt := 1.0                  # +1: low side right
var sent := [0, 0]               # tests: left, right
var _body: StaticBody2D
var _shape: CollisionShape2D
var _sense: Area2D
var _angle := TILT
var _cool := 0.0
var _bar: Sprite2D


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind the
	# parent so the weigh scale / gate / points extras draw over them
	var base := Sprite2D.new()
	base.texture = preload("res://assets/sprites/rocker_base.png")
	base.centered = false
	base.offset = Vector2(-22, -28)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.show_behind_parent = true
	add_child(base)
	_bar = Sprite2D.new()
	_bar.texture = preload("res://assets/sprites/rocker_bar.png")
	_bar.centered = false
	_bar.offset = Vector2(-18, -4)
	_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bar.show_behind_parent = true
	_bar.rotation = _angle
	add_child(_bar)
	if has_meta("ghost"):
		return
	add_to_group("rockers")
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()      # like a chute: landings don't bounce off it
	m.absorbent = true
	m.bounce = 1.0
	m.friction = 0.4
	_body.physics_material_override = m
	_shape = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-ARM, 0)
	seg.b = Vector2(ARM, 0)
	_shape.shape = seg
	_body.add_child(_shape)
	add_child(_body)
	# funnel lips above, so drops land on the pivot
	for s in [-1.0, 1.0]:
		var cs := CollisionShape2D.new()
		var sg := SegmentShape2D.new()
		sg.a = Vector2(s * 18, -24)
		sg.b = Vector2(s * 10, -12)
		cs.shape = sg
		_body.add_child(cs)
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 2
	var sc := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(ARM * 2 + 10, 14)
	sc.shape = r
	sc.position = Vector2(0, -2)
	_sense.add_child(sc)
	add_child(_sense)
	_sense.body_exited.connect(_on_leave)
	_apply()


func _apply() -> void:
	_angle = TILT * tilt
	_shape.rotation = _angle
	_bar.rotation = _angle
	queue_redraw()


func _on_leave(b) -> void:
	if not is_instance_valid(b) or not b is RigidBody2D or _cool > 0:
		return
	# once per marble, and only as it rolls off the end (not a bounce out the top)
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	var went := 1 if b.global_position.x > global_position.x else 0
	sent[went] += 1
	# its weight leaving the low end rocks it over
	tilt = -tilt
	_cool = 0.25
	_apply()
	SFX.play_small(self, SFX.sfx_ore_knock("wood"), -14.0, 1.4)


func _physics_process(delta: float) -> void:
	_cool -= delta


func _draw() -> void:
	pass   # stand, pivot, bar and funnel lips are sprites (see _ready)
