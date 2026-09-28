extends Node2D
## Trebuchet: a throwing arm on an A-frame, powered by weight. Ore dropped
## into the counterweight box (its back end) is the power: the heavier the
## load, the farther it throws. Ore dropped into the sling (its front, on
## the ground) is the shot. A trigger (a tally wheel, a plate, a load cell)
## or a click looses it: the box drops, the arm swings and the sling flings
## its load high and far toward `side`; the counterweight ore spills out
## and the box must be refilled. Iron in the box outthrows copper.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const BOX := Vector2(-26, -40)   # the counterweight box, cocked up (x flips with side)
const SLING := Vector2(34, -6)   # the sling, on the ground in front
const V_PER := 190.0             # launch speed per sqrt(mass) of counterweight
const V_MAX := 900.0

@export var side := 1.0

var thrown := 0                  # tests
var last_speed := 0.0
var _box: Array = []
var _sling: Array = []
var _swing := 0.0                # 0 cocked .. 1 thrown
var _cool := {}


func _p(v: Vector2) -> Vector2:
	return Vector2(v.x * side, v.y)


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func _mass(arr: Array) -> float:
	var m := 0.0
	for b in arr:
		if is_instance_valid(b):
			m += b.mass
	return m


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _swing <= 0.0:
		for o in get_tree().get_nodes_in_group("ore"):
			if not is_instance_valid(o) or o.freeze or o in _box or o in _sling or _cool.get(o.get_instance_id(), 0.0) > now:
				continue
			for pair in [[_box, BOX], [_sling, SLING]]:
				var c: Vector2 = global_position + _p(pair[1])
				if absf(o.global_position.x - c.x) < 12 and o.global_position.y > c.y - 18 and o.global_position.y < c.y + 4:
					pair[0].append(o)
					o.gravity_scale = 0.0
					break
	else:
		_swing = maxf(0.0, _swing - delta * 0.8)   # winds back to cocked
	for pair in [[_box, BOX], [_sling, SLING]]:
		var arr: Array = pair[0]
		var i := 0
		for b in arr.duplicate():
			if not is_instance_valid(b):
				arr.erase(b)
				continue
			var at: Vector2 = global_position + _p(pair[1]) + Vector2((i % 3) * 5 - 5, -6 - (i / 3) * 6)
			b.linear_velocity = (at - b.global_position) / delta
			if "_timer" in b:
				b._timer = 0.0
			i += 1
	queue_redraw()


func trigger() -> void:
	if _swing > 0.0 or _sling.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var m := _mass(_box)
	var v := clampf(V_PER * sqrt(m), 120.0, V_MAX)
	for b in _sling:
		if is_instance_valid(b):
			b.gravity_scale = 1.0
			b.global_position = global_position + _p(Vector2(-10, -70))
			b.linear_velocity = Vector2(side * 0.72, -0.7).normalized() * v * randf_range(0.95, 1.05)
			_cool[b.get_instance_id()] = now + 2.0
	for b in _box:
		if is_instance_valid(b):
			b.gravity_scale = 1.0
			b.linear_velocity = Vector2(-side * 60.0, 40.0)
			_cool[b.get_instance_id()] = now + 2.0
	_box.clear()
	_sling.clear()
	_swing = 1.0
	thrown += 1
	last_speed = v
	SFX.play_small(self, SFX.sfx_bounce(), -4.0, 0.6)
	FX.burst(get_parent(), global_position + _p(Vector2(-10, -70)), Color(0.9, 0.8, 0.6), 6, 60.0, 0.3, 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -30)) < 16:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.16, 0.12, 0.08)
	var wood := Color(0.55, 0.4, 0.22)
	# A-frame
	draw_line(Vector2(-18, 8), Vector2(0, -34), dark, 4.0)
	draw_line(Vector2(18, 8), Vector2(0, -34), dark, 4.0)
	draw_line(Vector2(-22, 8), Vector2(22, 8), dark, 4.0)
	# the arm: cocked with the box up behind and the sling end down in front;
	# thrown, swung over the other way
	var a := lerpf(-0.9, 1.9, _swing) * side
	var pivot := Vector2(0, -34)
	var long_end := pivot + Vector2(side * 44, 0).rotated(-a * -1.0 if side > 0 else a)
	var short_end := pivot - (long_end - pivot) * 0.45
	draw_line(short_end, long_end, dark, 5.0)
	draw_line(short_end, long_end, wood, 3.0)
	draw_circle(pivot, 3.0, Color(0.85, 0.65, 0.35))
	# the box and the sling at their resting places
	var bx := _p(BOX)
	draw_rect(Rect2(bx + Vector2(-11, -16), Vector2(22, 18)), dark, false, 2.0)
	var sl := _p(SLING)
	draw_arc(sl + Vector2(0, -6), 10.0, 0.2, PI - 0.2, 10, Color(0.7, 0.62, 0.45), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, bx + Vector2(-10, -20), "%.1f" % _mass(_box), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
