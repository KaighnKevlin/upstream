extends Node2D
## Balance: a brass beam on a post with a pan hung from each end. Pieces
## dropped into either pan are caught and held there, piling up, and the
## beam tips toward the heavier pan (iron weighs three coppers). Once one
## side is ahead by the setting (click the post: 1 / 2 / 3 copper-weights)
## and the beam has swung all the way down, that side fires ITS pull-wire
## (drag the ends; unwired, around itself), both pans tip out below and
## the beam rocks level again. Compares two lines: which delivered more
## weight first. Triggered, it just empties both pans. Ore-only: walkers
## pass through.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const THRESH := [1.0, 2.0, 3.0]
const PIVOT := Vector2(0, -52)
const ARM := 32.0                # pivot to each end hook, px
const HANG := 28.0               # end hook down to the pan's rim
const MAX_TILT := 0.26           # rad, at (or past) the setting
const SWING := 0.9               # rad/s the beam turns at
const SLOTS := [Vector2(-6.5, -6), Vector2(6.5, -6), Vector2(0, -17), Vector2(-6.5, -28), Vector2(6.5, -28), Vector2(0, -39)]

@export var mode := 1
@export var wire_l := Vector2(-70, 0)
@export var wire_r := Vector2(70, 0)

var fired_l := 0                 # tests
var fired_r := 0
var dumped := 0
var angle := 0.0                 # the beam's tilt; + is right side down
var _pans: Array = [[], []]      # held pieces, left and right
var _flash := [0.0, 0.0]
var _drag := -1                  # which wire end is being dragged
var _beam_art: Sprite2D          # art: the beam, tilted about the pivot
var _pan_art: Array = []         # the two pans, hung level from its ends


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the hangers, wires and setting)
	_spr(preload("res://assets/sprites/balance_post.png"), Vector2(-9, -55))
	_beam_art = _spr(preload("res://assets/sprites/balance_beam.png"), Vector2(-37, -5))
	_beam_art.position = PIVOT
	for i in 2:
		_pan_art.append(_spr(preload("res://assets/sprites/balance_pan.png"), Vector2(-17, -2)))
	_pose()
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = off
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.show_behind_parent = true
	add_child(s)
	return s


## Where the beam's end hook is on side i (0 left, 1 right).
func _hook(i: int) -> Vector2:
	return PIVOT + Vector2(-ARM if i == 0 else ARM, 0).rotated(angle)


## The centre of pan i's rim, hanging level under its hook.
func _rim(i: int) -> Vector2:
	return _hook(i) + Vector2(0, HANG)


func _weight(i: int) -> float:
	var w := 0.0
	for o in _pans[i]:
		if is_instance_valid(o):
			w += o.mass
	return w


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	# anything falling into a pan with room is caught
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o in _pans[0] or o in _pans[1] or o.get_meta("bal_until", 0.0) > now:
			continue
		for i in 2:
			var p: Vector2 = o.global_position - global_position - _rim(i)
			if absf(p.x) < 15 and p.y > -44 and p.y < 4 and _pans[i].size() < SLOTS.size():
				o.gravity_scale = 0.0
				_pans[i].append(o)
				SFX.play_small(self, SFX.sfx_ore_knock("metal"), -18.0, 1.1)
				break
	# the beam swings toward the heavier side, all the way at the setting
	var diff := _weight(1) - _weight(0)
	var target := clampf(diff / THRESH[mode], -1.0, 1.0) * MAX_TILT
	angle = move_toward(angle, target, SWING * delta)
	if absf(diff) >= THRESH[mode] - 0.01 and absf(angle) >= MAX_TILT - 0.001:
		_fire(1 if diff > 0 else 0)
		_dump()
	# hold what's in the pans, piled in them
	for i in 2:
		var c := global_position + _rim(i)
		for k in _pans[i].size():
			var o = _pans[i][k]
			if is_instance_valid(o):
				o.linear_velocity = (c + SLOTS[k] - o.global_position) / delta
				o.angular_velocity = 0.0
				if "_timer" in o:
					o._timer = 0.0
	for i in 2:
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
	_pose()
	queue_redraw()


func _fire(i: int) -> void:
	if i == 0:
		fired_l += 1
	else:
		fired_r += 1
	_flash[i] = 1.0
	SFX.play_small(self, SFX.sfx_ratchet(), -12.0, 1.5)
	var w: Vector2 = wire_l if i == 0 else wire_r
	var points := [global_position + w] if w != Vector2.ZERO else [global_position]
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			n.trigger()


## Both pans tip out below; the beam rocks back level on its own.
func _dump() -> void:
	var until := Time.get_ticks_msec() / 1000.0 + 1.5
	for i in 2:
		for o in _pans[i]:
			if is_instance_valid(o):
				o.gravity_scale = 1.0
				o.linear_velocity = Vector2(randf_range(-20.0, 20.0), 30.0)
				o.set_meta("bal_until", until)
				dumped += 1
		_pans[i].clear()
	SFX.play_small(self, SFX.sfx_latch(), -12.0, 0.9)


func trigger() -> void:
	_dump()


func _pose() -> void:
	if _beam_art == null:
		return
	_beam_art.rotation = angle
	for i in _pan_art.size():
		_pan_art[i].position = _rim(i)


func _wire_from(i: int) -> Vector2:
	return Vector2(-4 if i == 0 else 4, -8)


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position() - global_position
		if event.pressed:
			for i in 2:
				var w: Vector2 = wire_l if i == 0 else wire_r
				if w != Vector2.ZERO and m.distance_to(w) < 8:
					_drag = i
					get_viewport().set_input_as_handled()
					return
			if absf(m.x) < 6 and m.y > PIVOT.y and m.y < 2:
				mode = (mode + 1) % THRESH.size()
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif _drag >= 0:
			_drag = -1
	elif event is InputEventMouseMotion and _drag >= 0:
		var to := get_global_mouse_position() - global_position
		if _drag == 0:
			wire_l = to
		else:
			wire_r = to
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var chain := Color(0.55, 0.5, 0.42, 0.9)
	# the pull-wires, the firing one lit
	for i in 2:
		var w: Vector2 = wire_l if i == 0 else wire_r
		if w == Vector2.ZERO:
			continue
		var a := _wire_from(i)
		var mid := (a + w) * 0.5 + Vector2(0, 10)
		draw_polyline(PackedVector2Array([a, mid, w]), chain.lerp(Color(1, 0.85, 0.4), _flash[i]), 1.0)
		draw_circle(w, 3.0, dark)
		draw_circle(w, 2.0, Color(0.85, 0.65, 0.35))
	# (post, beam and pans are sprites) the hangers from each hook to its
	# pan's lugs
	for i in 2:
		var h := _hook(i)
		var r := _rim(i)
		draw_line(h, r + Vector2(-14, -1), chain, 1.0)
		draw_line(h, r + Vector2(14, -1), chain, 1.0)
		_pan_art[i].self_modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 1.05), _flash[i])
	var font := ThemeDB.fallback_font
	draw_string(font, PIVOT + Vector2(-5, -8), ">%d" % int(THRESH[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
