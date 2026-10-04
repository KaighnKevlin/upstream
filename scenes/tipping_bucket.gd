extends Node2D
## Tipping bucket: the batcher. A brass cup on a pivot that fills up one
## marble at a time; when the next one lands on a full cup (HOLD, click to
## cycle 3 / 5 / 8) it tips over and pours the whole batch out of its low
## side at once, then rights itself. Turns a trickle into bursts: a
## turret volley, a hopper drop, a wheel's big shove.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const HOLDS := [3, 5, 8]
const W := 30.0
const D := 24.0

@export var mode := 1
@export var side := 1.0           # which way it pours

var tipped := 0                   # tests
var poured := 0
var _body: StaticBody2D
var _floor: CollisionShape2D
var _wall: CollisionShape2D
var _inside: Area2D
var _angle := 0.0
var _busy := false
var _cup: Sprite2D


func _ready() -> void:
	z_index = 1
	# post and cup sprites (ghosts too), mirrored to pour the other way;
	# the cup turns about its back corner in _draw
	var post := Sprite2D.new()
	post.texture = preload("res://assets/sprites/tipping_bucket_post.png")
	post.centered = false
	post.offset = Vector2(-7, -2)
	post.position = Vector2(-side * W * 0.5, 0)
	post.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post.show_behind_parent = true
	add_child(post)
	_cup = Sprite2D.new()
	_cup.texture = preload("res://assets/sprites/tipping_bucket.png")
	_cup.centered = false
	_cup.offset = Vector2(-4, -28)
	_cup.position = Vector2(-side * W * 0.5, 0)
	_cup.scale = Vector2(side, 1)
	_cup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cup.show_behind_parent = true
	add_child(_cup)
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()      # landings (and fast iron off a chute) stick, not bounce out
	m.absorbent = true
	m.bounce = 1.0
	_body.physics_material_override = m
	_floor = _seg(Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0))
	_seg(Vector2(-side * W * 0.5, 0), Vector2(-side * W * 0.5, -D))          # the back wall stays
	_wall = _seg(Vector2(side * W * 0.5, 0), Vector2(side * W * 0.5, -D))    # the pouring lip
	add_child(_body)
	_inside = Area2D.new()
	_inside.collision_layer = 0
	_inside.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W - 4, D)
	cs.shape = r
	cs.position = Vector2(0, -D * 0.5)
	_inside.add_child(cs)
	add_child(_inside)
	_inside.body_entered.connect(_on_enter, CONNECT_DEFERRED)


func _seg(a: Vector2, b: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var s := SegmentShape2D.new()
	s.a = a
	s.b = b
	cs.shape = s
	_body.add_child(cs)
	return cs


func count() -> int:
	return _inside.get_overlapping_bodies().filter(func(b): return b is RigidBody2D).size() if _inside else 0


func _on_enter(_b) -> void:
	if _busy:
		return
	if count() > HOLDS[mode]:
		_tip()


func _tip() -> void:
	_busy = true
	tipped += 1
	var batch := _inside.get_overlapping_bodies().filter(func(b): return b is RigidBody2D)
	poured += batch.size()
	_floor.set_deferred("disabled", true)
	_wall.set_deferred("disabled", true)
	for b in batch:
		b.sleeping = false
		b.linear_velocity = Vector2(side * randf_range(90, 140), randf_range(-60, 0))
	SFX.play(self, SFX.sfx_ore_knock("metal"), -4.0, 0.7)
	var t := create_tween()
	t.tween_property(self, "_angle", side * 1.9, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(0.5)
	t.tween_callback(func():
		_floor.set_deferred("disabled", false)
		_wall.set_deferred("disabled", false))
	t.tween_property(self, "_angle", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _busy = false)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# the post and cup are sprites (see _ready): tip the cup, then mark its
	# capacity along the floor
	if _cup:
		_cup.rotation = _angle
	draw_set_transform(Vector2(-side * W * 0.5, 0), _angle, Vector2.ONE)
	var o := Vector2(side * W * 0.5, 0)
	for k in HOLDS[mode]:
		var x: float = o.x - W * 0.5 + 3 + k * (W - 6) / maxf(1, HOLDS[mode] - 1)
		draw_rect(Rect2(Vector2(x - 0.5, -3), Vector2(1, 1)), Color(0.2, 0.16, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or _inside == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Pointer.world(self).distance_to(global_position + Vector2(0, -12)) < 18:
			mode = (mode + 1) % HOLDS.size()
			SFX.play(self, SFX.sfx_clink())
			var scene := get_tree().current_scene
			if scene.has_method("_show_banner"):
				scene._show_banner("TIPPING BUCKET", "tips when the %dth lands" % (HOLDS[mode] + 1))
			get_viewport().set_input_as_handled()
