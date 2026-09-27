extends Node2D
## Goal cup: a brass cup with a counter. Every marble that drops in is
## counted (and stays); when it holds `target` it lights up, chimes and
## fires everything triggerable in reach, and tells the scene if the scene
## is listening (puzzles). The node is the cup's floor centre.
## Ore-only layer: walkers pass through.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const ORE_ONLY := 64
const W := 34.0
const D := 30.0

signal filled

@export var target := 5

var count := 0
var done := false
var _seen := {}
var _glow := 0.0


func _ready() -> void:
	z_index = 1
	add_to_group("goal_cups")
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var m := PhysicsMaterial.new()
	m.absorbent = true
	m.bounce = 1.0
	body.physics_material_override = m
	for seg in [[Vector2(-W * 0.5, -D), Vector2(-W * 0.5, 0)], [Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0)], [Vector2(W * 0.5, 0), Vector2(W * 0.5, -D)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		cs.shape = s
		body.add_child(cs)
	add_child(body)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W - 4, D - 6)
	ac.shape = r
	ac.position = Vector2(0, -D * 0.5 + 3)
	a.add_child(ac)
	add_child(a)
	a.body_entered.connect(_on_enter)


func _on_enter(b) -> void:
	if not (b is RigidBody2D) or _seen.has(b.get_instance_id()):
		return
	_seen[b.get_instance_id()] = true
	b.collision_mask |= 2        # the marbles in it pile up rather than overlap
	count += 1
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 0.9 + count * 0.05)
	if not done and count >= target:
		done = true
		_glow = 1.0
		SFX.play(self, SFX.sfx_bell(), -4.0, 1.2)
		for n in Tripwire.linked_to(get_tree(), [global_position]):
			if n != self and n.has_method("trigger"):
				n.trigger()
		filled.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if done:
		_glow = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	if done:
		draw_rect(Rect2(-W * 0.5 - 6, -D - 6, W + 12, D + 10), Color(1.0, 0.85, 0.4, 0.15 + 0.2 * _glow))
	for seg in [[Vector2(-W * 0.5, -D), Vector2(-W * 0.5, 0)], [Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0)], [Vector2(W * 0.5, 0), Vector2(W * 0.5, -D)]]:
		draw_line(seg[0], seg[1], dark, 5.0)
		draw_line(seg[0], seg[1], brass if not done else Color(1.0, 0.9, 0.5), 3.0)
	# the tally
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-W * 0.5, -D - 10), "%d / %d" % [count, target], HORIZONTAL_ALIGNMENT_CENTER, W, 12,
		Color(1.0, 0.85, 0.4) if done else Color(0.85, 0.75, 0.55))
