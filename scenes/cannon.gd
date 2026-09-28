extends Node2D
## Marble cannon: a squat brass gun on the floor with a hopper on its back.
## Marbles dropped into the hopper are loaded (up to MAG) and fired flat
## and fast out of the muzzle toward `side` at anything walking in front
## of it. Flat shots meet shields head on: copper glances off a tower
## shield, iron punches through, so what you feed it matters.
## Ore-only hopper: walkers pass through it.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ORE_ONLY := 64
const MAG := 6
const SPEED := 640.0
const RANGE := 420.0
const EVERY := 0.6

@export var side := 1.0

var loaded: Array[String] = []   # kinds, first in first out
var fired := 0                   # tests
var _t := 0.0
var _kick := 0.0
var _art: Node2D                 # carriage and barrel sprites, mirrored for side -1
var _barrel: Sprite2D


func _ready() -> void:
	z_index = 2
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw (the load pips in the magazine tray)
	_art = Node2D.new()
	_art.show_behind_parent = true
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_art)
	var car := Sprite2D.new()
	car.texture = preload("res://assets/sprites/marble_cannon_carriage.png")
	car.centered = false
	car.offset = Vector2(-24, -44)
	_art.add_child(car)
	_barrel = Sprite2D.new()
	_barrel.texture = preload("res://assets/sprites/marble_cannon_barrel.png")
	_barrel.centered = false
	_barrel.offset = Vector2(-16, -20)
	_art.add_child(_barrel)
	_art.scale.x = 1.0 if side >= 0 else -1.0
	if has_meta("ghost"):
		return
	add_to_group("cannons")
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	m.bounce = 1.0
	body.physics_material_override = m
	for seg in [[Vector2(-20, -40), Vector2(-7, -18)], [Vector2(8, -40), Vector2(7, -18)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		var f := 1.0 if side >= 0 else -1.0   # the hopper's tall side is behind the gun
		s.a = Vector2(seg[0].x * f, seg[0].y)
		s.b = Vector2(seg[1].x * f, seg[1].y)
		cs.shape = s
		body.add_child(cs)
	add_child(body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 10)
	ac.shape = r
	ac.position = Vector2(0, -20)
	a.add_child(ac)
	add_child(a)
	a.body_entered.connect(_load, CONNECT_DEFERRED)


func _load(b) -> void:
	if not is_instance_valid(b) or not (b is RigidBody2D) or loaded.size() >= MAG or b.is_queued_for_deletion():
		return
	var k = b.get("kind")
	if k == null:
		return
	loaded.append(str(k))
	b.queue_free()
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 1.2)
	queue_redraw()


func _target() -> Node2D:
	var best: Node2D = null
	var bd := RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var d: Vector2 = e.global_position - global_position
		if d.x * side > 10 and absf(d.y) < 60 and absf(d.x) < bd:
			bd = absf(d.x)
			best = e
	return best


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t -= delta
	_kick = maxf(0.0, _kick - delta * 6.0)
	_barrel.position.x = -_kick * 4.0     # recoil (mirrored with the art)
	if _t > 0 or loaded.is_empty() or _target() == null:
		return
	_t = EVERY
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = loaded.pop_front()
	o.global_position = global_position + Vector2(side * 26, -8)
	get_parent().add_child(o)
	o.linear_velocity = Vector2(side * SPEED, -40)
	fired += 1
	_kick = 1.0
	FX.burst(get_parent(), o.global_position, Color(1.0, 0.85, 0.5), 5, 80.0, 0.2, 1.0)
	SFX.play_small(self, SFX.sfx_turret_fire(), -8.0, 1.1)
	queue_redraw()


func _draw() -> void:
	# carriage, wheels, barrel and hopper are sprites (see _ready)
	_art.scale.x = 1.0 if side >= 0 else -1.0
	_barrel.position.x = -_kick * 4.0
	# the load, as pips in the magazine tray: iron dark, copper orange
	for i in loaded.size():
		draw_circle(Vector2(-14 + i * 5.5, -18), 2.2, Color(0.45, 0.47, 0.52) if loaded[i] == "iron" else Color(0.85, 0.55, 0.3))
