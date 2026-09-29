extends "res://scenes/rocker.gd"
## Points switch: a rocker that stays put. Everything goes the way it
## leans until it's thrown: by a trigger (a tally wheel, a tripwire, a
## plate, a bell: it's triggerable) or a click. Routing by signal: with a
## tally wheel, three one way then three the other; with a plate, the
## stream swings to the turret when a walker steps on it.
##
## Rate: up to 10 a second.
##
## On a track (a chute ending at its funnel: see scenes/rocker.gd) every
## rider goes the way it's thrown; if that way is backed up it doesn't
## switch itself: the rider waits and the queue backs up behind it, until
## the way clears or something throws it.


func _ready() -> void:
	super._ready()
	if not has_meta("ghost"):
		add_to_group("triggerable")


func _dodges() -> bool:
	return false


func _went(_i: int, _kind: String) -> void:
	_next = _fork.net.tick + 6   # it doesn't rock: at most 10/s


func trigger() -> void:
	tilt = -tilt
	_apply()
	SFX.play_small(self, SFX.sfx_latch(), -12.0, 0.9)


func _on_leave(b) -> void:
	# counted, but it never throws itself
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	sent[1 if b.global_position.x > global_position.x else 0] += 1


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 16:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	super._draw()
	# a lever on the pivot, showing which way it's thrown
	var d := Vector2(tilt * 7, -10)
	draw_line(Vector2.ZERO, d, Color(0.1, 0.08, 0.07), 3.0)
	draw_line(Vector2.ZERO, d, Color(0.8, 0.25, 0.2), 1.5)
	draw_circle(d, 2.5, Color(0.8, 0.25, 0.2))
