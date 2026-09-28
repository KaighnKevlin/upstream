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


func _ready() -> void:
	z_index = 2
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
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var k := -_kick * 4.0 * side
	# wheels and carriage
	for x in [-10.0, 10.0]:
		draw_circle(Vector2(x, -4), 6.0, dark)
		draw_circle(Vector2(x, -4), 4.0, Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(-16, -14, 32, 8), dark)
	draw_rect(Rect2(-15, -13, 30, 6), Color(0.4, 0.3, 0.2))
	# barrel
	var b0 := Vector2(k - side * 10, -12)
	var b1 := Vector2(k + side * 28, -10)
	draw_line(b0, b1, dark, 10.0)
	draw_line(b0, b1, brass, 7.0)
	draw_line(b0 + Vector2(0, -2), b1 + Vector2(0, -2), Color(1.0, 0.9, 0.6, 0.5), 1.0)
	draw_circle(b1, 4.0, dark)
	# hopper
	var s := 1.0 if side >= 0 else -1.0
	draw_line(Vector2(-20 * s, -40), Vector2(-7 * s, -18), dark, 3.0)
	draw_line(Vector2(8 * s, -40), Vector2(7 * s, -18), dark, 3.0)
	draw_line(Vector2(-20 * s, -40), Vector2(-7 * s, -18), Color(0.6, 0.62, 0.66), 1.0)
	draw_line(Vector2(8 * s, -40), Vector2(7 * s, -18), Color(0.6, 0.62, 0.66), 1.0)
	# the load, as pips: iron dark, copper orange
	for i in loaded.size():
		draw_circle(Vector2(-14 + i * 5.5, -18), 2.2, Color(0.45, 0.47, 0.52) if loaded[i] == "iron" else Color(0.85, 0.55, 0.3))
