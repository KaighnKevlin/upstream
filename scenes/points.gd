extends "res://scenes/rocker.gd"
## Points switch: a railway-style weighted ground throw. A steel switch
## tongue on a pivot under the funnel sends everything down one side; below
## it a throw lever with an iron ball on its end lies over to that side, and
## the ball's weight holds the tongue there through a rod. It stays put
## until it's thrown: by a trigger (a tally wheel, a tripwire, a plate, a
## bell: it's triggerable: the pull swings the lever) or a click on the
## lever. Thrown, the ball swings up over the top and drops to the other
## side, dragging the tongue across. Routing by signal: with a tally wheel,
## three one way then three the other; with a plate, the stream swings to
## the turret when a walker steps on it.
##
## Rate: up to 10 a second.
##
## On a track (a chute ending at its funnel: see scenes/rocker.gd) every
## rider goes the way the tongue lies; if that way is backed up it doesn't
## switch itself: the rider waits and the queue backs up behind it, until
## the way clears or something throws it. While the tongue is crossing over
## (THROW s) nothing goes by: a marble can't pass a half-thrown switch.

const THROW := 0.2               # s the lever takes to swing over
const LEVER_REST := 1.25         # rad the lever lies over from upright
const LEVER_AT := Vector2(0, 14) # its bearing

var _lever: Sprite2D
var _throw_t := 0                # net tick until which it's mid-throw


func _ready() -> void:
	super._ready()
	if not has_meta("ghost"):
		add_to_group("triggerable")


func _build_art() -> void:
	_sprite(preload("res://assets/sprites/points_frame.png"), Vector2(-22, -28))
	_lever = _sprite(preload("res://assets/sprites/points_lever.png"), Vector2(-8, -16))
	_lever.position = LEVER_AT
	_lever.show_behind_parent = false
	_lever.z_index = 1           # over the chutes laid from the tongue's ends
	_bar = _sprite(preload("res://assets/sprites/points_tongue.png"), Vector2(-18, -4))


## The lever lies over the way the tongue sends; the rod keeps the tongue at
## the lever's angle, scaled.
func _pose(a: float) -> void:
	super._pose(a)
	if _lever:
		_lever.rotation = LEVER_REST * a / TILT
	queue_redraw()


func _swing_time() -> float:
	return THROW


func _dodges() -> bool:
	return false


func pick(kind: String, free: Array) -> int:
	if _fork.net.tick < _throw_t:
		return -1
	return super.pick(kind, free)


func _went(_i: int, _kind: String) -> void:
	_next = _fork.net.tick + 6   # it doesn't rock: at most 10/s


func trigger() -> void:
	tilt = -tilt
	if _fork and _fork.net != null and is_instance_valid(_fork.net):
		_throw_t = _fork.net.tick + int(THROW * 60.0)
	_apply()
	SFX.play_small(self, SFX.sfx_latch(), -12.0, 0.9)
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -16.0, 0.6)


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
	var p := Pointer.world(self)
	if p.distance_to(global_position) < 16 or p.distance_to(global_position + LEVER_AT + Vector2(0, -5)) < 12:
		trigger()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# the rod from the lever (4 px up it) to the tongue's underside (6 px out)
	var la := LEVER_REST * _vis / TILT
	var from := LEVER_AT + Vector2(sin(la), -cos(la)) * 4.0
	var s := 1.0 if _vis > 0 else -1.0
	var to := Vector2(cos(_vis), sin(_vis)) * 6.0 * s + Vector2(-sin(_vis), cos(_vis)) * 2.0
	draw_line(from, to, Color(0.16, 0.15, 0.14), 1.6)
	draw_line(from, to, Color(0.42, 0.47, 0.5), 0.8)
