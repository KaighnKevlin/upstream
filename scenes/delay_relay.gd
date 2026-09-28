extends Node2D
## Delay relay: a little brass clock on a bracket. When something fires it
## (a tally wheel, load cell, plate, bell, latch: it's triggerable) it
## winds its hand round for its setting (click: 1 / 3 / 5 s) and then
## fires whatever is at the end of its output wire (drag the wire's end).
## A signal that arrives while it's already winding starts the wait over
## (it doesn't queue a second firing): it fires once, a full setting after
## the LAST signal. So "a piece went by" becomes "the stream has gone
## quiet": wired from a tally wheel, it fires once a run has stopped for
## the set time; with a lone signal it's a plain delay, a sluice opening
## a second after the wheel turns rather than at once.
##
## Output goes only from the wire's end, never back into itself, and a
## signal arriving within COOL of its own output is dropped (so a relay
## hub fed from it and wired straight back can't retrigger it). Two relays
## wired in a ring make a slow clock, one beat per setting: bounded, never
## a runaway.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const DELAYS := [1.0, 3.0, 5.0]
const COOL := 0.1
const FACE := 10.0

@export var mode := 0
@export var wire_to := Vector2(70, 0)   # drag its end to what it should fire

var triggered := 0               # tests: signals taken
var restarts := 0                # tests: signals that started a wait over
var fired := 0                   # tests: outputs
var dropped := 0                 # tests: signals ignored in the cool-down
var waiting := false
var _left := 0.0
var _last_out := -10.0
var _flash := 0.0
var _dragging := false


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func trigger() -> void:
	if has_meta("ghost"):
		return
	if _now() < _last_out + COOL:
		dropped += 1
		return
	triggered += 1
	if waiting:
		restarts += 1
	waiting = true
	_left = DELAYS[mode]
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -20.0, 1.8)
	queue_redraw()


func fire() -> void:
	fired += 1
	_flash = 1.0
	_last_out = _now()
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.5)
	for n in Tripwire.linked_to(get_tree(), [global_position + wire_to]):
		if n != self and n.has_method("trigger"):
			n.trigger()


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	if waiting:
		_left -= delta
		if _left <= 0:
			waiting = false
			_left = 0.0
			fire()
		queue_redraw()
	if _flash > 0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position() - global_position
		if event.pressed and wire_to != Vector2.ZERO and m.distance_to(wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and m.length() < FACE + 2:
			mode = (mode + 1) % DELAYS.size()
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = get_global_mouse_position() - global_position
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var steel := Color(0.42, 0.44, 0.5)
	var hot := Color(1, 0.95, 0.7)
	var font := ThemeDB.fallback_font
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(FACE * 0.7, 0), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, brass.lerp(hot, _flash))
	# bracket and the winding key on top
	draw_line(Vector2(0, FACE), Vector2(0, FACE + 7), dark, 3.0)
	draw_line(Vector2(-6, FACE + 7), Vector2(6, FACE + 7), steel, 2.0)
	draw_line(Vector2(0, -FACE - 4), Vector2(0, -FACE), steel, 2.0)
	draw_circle(Vector2(0, -FACE - 4), 2.0, steel)
	# the case and face
	draw_circle(Vector2.ZERO, FACE + 1.5, dark)
	draw_circle(Vector2.ZERO, FACE, brass.lerp(hot, _flash))
	draw_circle(Vector2.ZERO, FACE - 2, Color(0.9, 0.86, 0.75))
	var total: float = DELAYS[mode]
	var f := 0.0
	if waiting:
		f = 1.0 - _left / total
		# the wound part of the dial, shaded
		draw_arc(Vector2.ZERO, (FACE - 2) * 0.5, -PI * 0.5, -PI * 0.5 + f * TAU, 24, Color(0.85, 0.65, 0.35, 0.6), FACE - 2)
	for k in int(total):
		var a := -PI * 0.5 + k * TAU / total
		var d := Vector2(cos(a), sin(a))
		draw_line(d * (FACE - 4), d * (FACE - 2), dark, 1.0)
	var ha := -PI * 0.5 + f * TAU
	draw_line(Vector2.ZERO, Vector2(cos(ha), sin(ha)) * (FACE - 3), Color(0.8, 0.2, 0.15), 1.5)
	draw_circle(Vector2.ZERO, 1.5, dark)
	var label := "%.1f" % _left if waiting else "%ds" % int(total)
	draw_string(font, Vector2(-8, -FACE - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
