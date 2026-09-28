extends Node2D
## Volcano: a brass steam cup that collects what drops into it until it
## holds N (click: 3 / 5), then rumbles and erupts them all straight up at
## once, fanned out a little so they come down either side of it rather
## than back in. Pieces in it don't despawn. A trigger (tally wheel, plate,
## bell) erupts whatever it holds early. Turns a trickle into a volley.
## The node is the middle of the cup's mouth.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const NEEDS := [3, 5]
const V_UP := 560.0              # about 160 px up
const FAN_MIN := 45.0            # px/s sideways, innermost; the outermost double
const RUMBLE := 0.35             # s of shaking before it goes
const SLOTS := [Vector2(-8, 15), Vector2(8, 15), Vector2(0, 15), Vector2(-4, 6), Vector2(4, 6)]

@export var mode := 1

var erupted := 0                 # tests: eruptions
var launched := 0                # tests: pieces thrown
var _held: Array = []
var _rumble := -1.0              # counting down to the eruption; < 0: quiet
var _flash := 0.0
var _cool := {}
var _body: Sprite2D


func _ready() -> void:
	z_index = 0                  # under the ore: the pile shows in the cup
	# the cone (ghosts too), behind our _draw: the crater's glow and the pips
	_body = Sprite2D.new()
	_body.texture = preload("res://assets/sprites/volcano.png")
	_body.centered = false
	_body.offset = Vector2(-31, -6)
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.show_behind_parent = true
	add_child(_body)
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func need() -> int:
	return NEEDS[mode % NEEDS.size()]


func trigger() -> void:
	if not _held.is_empty() and _rumble < 0:
		_rumble = 0.05


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or o in _held or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 15 and p.y > -12 and p.y < 20 and o.linear_velocity.y > -20:
			_held.append(o)
			o.gravity_scale = 0.0
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.2)
	_held = _held.filter(func(o): return is_instance_valid(o))
	if _rumble < 0 and _held.size() >= need():
		_rumble = RUMBLE
	if _rumble >= 0:
		_rumble -= delta
		if _rumble < 0:
			_erupt(now)
	for k in _held.size():
		var o: RigidBody2D = _held[k]
		var slot: Vector2 = SLOTS[k % SLOTS.size()] + Vector2(0, -3.0 * int(k / SLOTS.size()))
		if _rumble >= 0:
			slot += Vector2(randf_range(-1, 1), randf_range(-1, 1))
		# sink into its place in the pile (quick, not a jump)
		var v: Vector2 = (global_position + slot - o.global_position) / delta
		o.linear_velocity = v.limit_length(400.0)
		if "_timer" in o:
			o._timer = 0.0
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()


func _erupt(now: float) -> void:
	var n := _held.size()
	if n == 0:
		return
	var flip := 1.0 if randf() < 0.5 else -1.0
	for k in n:
		var o: RigidBody2D = _held[k]
		# a fan: from the middle out, alternating sides, never straight back in
		var u := 0.0 if n == 1 else float(k) / (n - 1) * 2.0 - 1.0
		var s := signf(u) if absf(u) > 0.01 else flip
		var vx := s * (FAN_MIN + FAN_MIN * absf(u)) + randf_range(-6, 6)
		o.gravity_scale = 1.0
		o.sleeping = false
		o.global_position = global_position + Vector2(clampf(vx * 0.05, -6, 6), -4)
		o.linear_velocity = Vector2(vx, -V_UP * randf_range(0.96, 1.04))
		_cool[o.get_instance_id()] = now + 3.0
	launched += n
	erupted += 1
	_held.clear()
	_flash = 1.0
	FX.burst(get_parent(), global_position + Vector2(0, -4), Color(0.92, 0.92, 0.9), 12, 110.0, 0.35, 1.5)
	SFX.play_small(self, SFX.sfx_bounce(), -4.0, 0.6)


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, 14)) < 16:
		mode = (mode + 1) % NEEDS.size()
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), 0) if _rumble >= 0 else Vector2.ZERO
	_body.position = shake
	# the crater glows as it erupts
	if _flash > 0.0:
		draw_colored_polygon(_quad(12, 0.5, 8.5, 20.5, shake), Color(1.0, 0.55, 0.25, _flash * 0.8))
	# gauge pips on the base: one per piece it needs, lit as they fill
	var nd := need()
	for k in nd:
		var c := Vector2((k - (nd - 1) * 0.5) * 5.0, 26) + shake
		draw_circle(c, 1.6, Color(1.0, 0.8, 0.4) if k < _held.size() else Color(0.25, 0.2, 0.15))


func _quad(top: float, y0: float, bottom: float, y1: float, off: Vector2) -> PackedVector2Array:
	# a trapezoid, `top` / `bottom` half-widths, shifted by `off`
	return PackedVector2Array([Vector2(-top, y0) + off, Vector2(top, y0) + off, Vector2(bottom, y1) + off, Vector2(-bottom, y1) + off])
