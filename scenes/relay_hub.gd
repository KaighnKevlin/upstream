extends Node2D
## Relay hub: a brass junction box with three pull-wires. When something
## fires it (a tally wheel, load cell, plate, bell, latch, delay relay:
## it's triggerable), it fires what's at the end of each of its wires at
## once, so one sensor drives several machines: the tally wheel that
## throws the points can open the sluice and set the latch in the same
## beat. Drag a wire's end to its target; drop it back on the box to park
## it (a parked wire fires nothing; pull it out again from its hook).
## Click the box to fire it by hand.
##
## Each machine is fired once however many wire ends are near it (two
## ends on one points switch don't throw it and throw it back). Output
## goes only from the wire ends, never into the hub itself, and a signal
## arriving within COOL of its own output is dropped: two hubs wired into
## each other fire once each, not for ever.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const COOL := 0.1
const PARK := 14.0                   # an end dropped this near the box is parked
const HOOKS := [Vector2(9, -6), Vector2(9, 0), Vector2(9, 6)]   # where parked wires hang
const BOX := Rect2(-9, -10, 18, 20)

@export var wire_1 := Vector2(70, -30)   # ZERO: parked
@export var wire_2 := Vector2(80, 0)
@export var wire_3 := Vector2(70, 30)

var triggered := 0               # tests: signals taken
var fired := 0                   # tests: outputs
var hit := 0                     # tests: machines fired, all told
var dropped := 0                 # tests: signals ignored in the cool-down
var _cool := 0.0                 # > 0: just fired, not listening (game time)
var _flash := 0.0
var _drag := -1                  # which wire's end is being dragged
var _art: Sprite2D               # the box, terminal, lamp bezels and hooks; brightens as it fires


func _ready() -> void:
	z_index = 2
	# the sprite first, so ghosts and build-bar icons get it too; behind our
	# own _draw (the wires, the lamps, a parked wire's coil)
	_art = Sprite2D.new()
	_art.texture = preload("res://assets/sprites/relay_hub.png")
	_art.centered = false
	_art.offset = Vector2(-17, -12)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.show_behind_parent = true
	add_child(_art)
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func wires() -> Array:
	return [wire_1, wire_2, wire_3]


func _set_wire(k: int, v: Vector2) -> void:
	if k == 0:
		wire_1 = v
	elif k == 1:
		wire_2 = v
	else:
		wire_3 = v


func trigger() -> void:
	if has_meta("ghost"):
		return
	if _cool > 0:
		dropped += 1
		return
	triggered += 1
	fire()


func fire() -> void:
	fired += 1
	_flash = 1.0
	_cool = COOL
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.7)
	var points := []
	for w in wires():
		if w != Vector2.ZERO:
			points.append(global_position + w)
	if points.is_empty():
		return
	# one call over all the ends: each machine comes back (and fires) once
	for n in Tripwire.linked_to(get_tree(), points):
		if n != self and n.has_method("trigger"):
			hit += 1
			n.trigger()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_cool -= delta
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _end(k: int) -> Vector2:
	var w: Vector2 = wires()[k]
	return HOOKS[k] if w == Vector2.ZERO else w


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position() - global_position
		if event.pressed:
			# nearest end (or parked hook) under the mouse
			var best := -1
			var bd := 7.0
			for k in 3:
				var d := m.distance_to(_end(k))
				if d < bd:
					bd = d
					best = k
			if best >= 0:
				_drag = best
				get_viewport().set_input_as_handled()
			elif BOX.grow(2).has_point(m):
				fire()
				get_viewport().set_input_as_handled()
		elif _drag >= 0:
			if m.length() < PARK:
				_set_wire(_drag, Vector2.ZERO)
			_drag = -1
			queue_redraw()
	elif event is InputEventMouseMotion and _drag >= 0:
		var m := get_global_mouse_position() - global_position
		# still over the box: it's parked until pulled clear
		_set_wire(_drag, Vector2.ZERO if m.length() < PARK else m)
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var hot := Color(1, 0.95, 0.7)
	var ws := wires()
	for k in 3:
		var w: Vector2 = ws[k]
		if w == Vector2.ZERO:
			continue
		var mid := w * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([HOOKS[k], mid, w]), Color(0.55, 0.5, 0.42, 0.8).lerp(hot, _flash * 0.6), 1.0)
		draw_circle(w, 3.0, dark)
		draw_circle(w, 2.0, brass.lerp(hot, _flash))
	# the box, its terminal and hooks are art; it glows as it fires
	_art.self_modulate = Color.WHITE.lerp(Color(1.3, 1.22, 1.05), _flash * 0.5)
	# three little lamps, one per wire: lit if it's run out, dark if parked
	# (then its wire hangs coiled on the hook)
	for k in 3:
		var at: Vector2 = HOOKS[k]
		var live: bool = ws[k] != Vector2.ZERO
		draw_circle(Vector2(-3, at.y), 1.8, (Color(1.0, 0.75, 0.3) if live else Color(0.25, 0.2, 0.16)).lerp(hot, _flash))
		if not live:
			draw_arc(at + Vector2(1, 0.5), 1.8, 0, TAU, 8, brass, 1.0)
