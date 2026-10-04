extends "res://scenes/rocker.gd"
## Weigh scale: a rocker that sorts by weight, not turn. A counterweight
## holds it tipped toward the light side; a marble heavier than the weight
## (click: 1.5 / 2.5, so copper vs iron, or shot and ingots vs copper) tips
## it over as it lands and rolls off the heavy side instead. Iron one way,
## copper the other: the marble machine's ore filter.
##
## Rate: up to 10 a second, sorted exactly.
##
## On a track (a chute ending at its funnel: see scenes/rocker.gd) each
## rider goes the heavy or the light way by its kind's weight; if that way
## is backed up it waits (a sorter doesn't send it the wrong way), and the
## queue behind it waits too.

const THRESH := [1.5, 2.5]
const ORE_KINDS: Dictionary = preload("res://scenes/ore.gd").KINDS

@export var mode := 0
@export var heavy_side := 1.0    # which way heavy pieces go

var heavy := 0                   # tests
var light := 0
var _right_t := 0.0              # s until the counterweight rights it after a rider tipped it


func _ready() -> void:
	super._ready()
	if has_meta("ghost"):
		return
	tilt = -heavy_side
	_apply()
	# the weighing pan: a sensor in the funnel's throat
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 10)
	cs.shape = r
	cs.position = Vector2(0, -12)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_weigh)


func _weigh(b) -> void:
	if not (b is RigidBody2D):
		return
	var is_heavy: bool = b.mass > THRESH[mode]
	tilt = heavy_side if is_heavy else -heavy_side
	_apply()
	if is_heavy:
		heavy += 1
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.7)
	else:
		light += 1


func _want(kind: String) -> int:
	var spec: Dictionary = ORE_KINDS.get(kind, {})
	var is_heavy: bool = float(spec.get("mass", 1.0)) > THRESH[mode]
	var s := heavy_side if is_heavy else -heavy_side
	return 1 if s > 0 else 0


func _dodges() -> bool:
	return false


func _went(i: int, _kind: String) -> void:
	_next = _fork.net.tick + 6   # at most 10/s
	var is_heavy: bool = (i == 1) == (heavy_side > 0)
	if is_heavy:
		heavy += 1
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.7)
	else:
		light += 1
	tilt = 1.0 if i == 1 else -1.0
	_right_t = 0.3
	_apply()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _right_t > 0:
		_right_t -= delta
		if _right_t <= 0 and tilt != -heavy_side:
			tilt = -heavy_side
			_apply()


func _on_leave(b) -> void:
	# counted, but no flip-flop: the counterweight rights it for the next one
	if not is_instance_valid(b) or not b is RigidBody2D:
		return
	if b.get_meta("rocked_by", 0) == get_instance_id() or absf(b.global_position.x - global_position.x) < ARM - 3:
		return
	b.set_meta("rocked_by", get_instance_id())
	sent[1 if b.global_position.x > global_position.x else 0] += 1
	tilt = -heavy_side
	_apply()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if Pointer.world(self).distance_to(global_position) < 18:
		mode = (mode + 1) % THRESH.size()
		queue_redraw()


func _draw() -> void:
	super._draw()
	# the counterweight on the light side, and the setting
	var s := -heavy_side
	draw_line(Vector2(s * 4, 2), Vector2(s * 12, 12), Color(0.16, 0.13, 0.1), 2.0)
	draw_rect(Rect2(Vector2(s * 12 - 4, 12), Vector2(8, 7 + mode * 3)), Color(0.1, 0.08, 0.07))
	draw_rect(Rect2(Vector2(s * 12 - 3, 13), Vector2(6, 5 + mode * 3)), Color(0.5, 0.52, 0.56))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-heavy_side * 30 - 6, -14), "%.1f" % THRESH[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.75, 0.55))
