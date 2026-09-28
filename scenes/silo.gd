extends Node2D
## Silo: a tall brass bin with a funnel on top and a gate at the bottom,
## the marble machine's storage chest. Whatever drops into the funnel is
## taken in and kept (up to CAP, and it doesn't despawn while stored); it
## lets them out of the bottom one at a time, on a clock (0.5 / 1 / 2 s)
## or one per trigger (a tally wheel, plate, bell), click to switch. Turns
## a bursty supply into a steady feed, or banks ore until it's called for.

const SFX = preload("res://scripts/sfx.gd")
const ORE := preload("res://scenes/ore.tscn")
const INGOT := preload("res://scenes/ingot.tscn")
const CAP := 40
const MODES := [0.5, 1.0, 2.0, 0.0]      # 0: on trigger only
const H := 60.0

@export var mode := 1

var stored: Array[String] = []   # kinds, first in first out ("ingot:iron" for ingots)
var let_out := 0                 # tests
var _t := 0.0
var _mouth: Area2D


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	add_to_group("triggerable")
	_mouth = Area2D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 12)
	cs.shape = r
	cs.position = Vector2(0, -H - 4)
	_mouth.add_child(cs)
	add_child(_mouth)
	_mouth.body_entered.connect(_take, CONNECT_DEFERRED)


func _take(b) -> void:
	if not is_instance_valid(b) or not (b is RigidBody2D) or b.is_queued_for_deletion() or stored.size() >= CAP:
		return
	if b.get("kind") == null:
		return
	stored.append(("ingot:" if b.is_in_group("ingots") else "") + str(b.kind))
	b.queue_free()
	SFX.play_small(self, SFX.sfx_ore_knock("ore"), -18.0, 0.9)
	queue_redraw()


func trigger() -> void:
	_release()


func _release() -> void:
	if stored.is_empty():
		return
	var k: String = stored.pop_front()
	var o: RigidBody2D = (INGOT if k.begins_with("ingot:") else ORE).instantiate()
	o.kind = k.trim_prefix("ingot:")
	if "lifetime" in o:
		o.lifetime = 1.0e9
	o.global_position = global_position + Vector2(0, 10)
	get_parent().add_child(o)
	o.linear_velocity = Vector2(0, 60)
	let_out += 1
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _mouth == null or MODES[mode] <= 0.0:
		return
	_t -= delta
	if _t <= 0 and not stored.is_empty():
		_t = MODES[mode]
		_release()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := to_local(get_global_mouse_position())
	if absf(p.x) < 12 and p.y > -H and p.y < 6:
		mode = (mode + 1) % MODES.size()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# funnel
	draw_line(Vector2(-18, -H - 14), Vector2(-9, -H), dark, 3.0)
	draw_line(Vector2(18, -H - 14), Vector2(9, -H), dark, 3.0)
	# the bin, filled to its level
	draw_rect(Rect2(-10, -H, 20, H + 6), dark)
	draw_rect(Rect2(-8, -H + 2, 16, H + 2), Color(0.22, 0.18, 0.14))
	var fill := float(stored.size()) / CAP
	if fill > 0:
		var fh := (H + 2) * fill
		draw_rect(Rect2(-8, 4 - fh, 16, fh), Color(0.62, 0.42, 0.24))
	for y in [-H * 0.66, -H * 0.33]:
		draw_line(Vector2(-10, y), Vector2(10, y), brass, 1.0)
	# gate
	draw_rect(Rect2(-5, 6, 10, 4), brass)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-9, -H - 18), str(stored.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.8, 0.55))
	draw_string(font, Vector2(12, -4), ("%.1fs" % MODES[mode]) if MODES[mode] > 0 else "trig", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
