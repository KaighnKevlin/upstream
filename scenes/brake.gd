extends "res://scenes/chute.gd"
## Brake rail: a chute with stiff brushes along it. Anything going faster
## than its limit (80 / 150 / 250 px/s) is held to it while it's on
## the rail, so a stream arrives at a known speed: into a cup or a net
## without overshooting, onto a flap sorter slowly enough to drop. Click
## its number to change the limit.

const LIMITS := [80.0, 150.0, 250.0]
const BRISTLE := Color(0.55, 0.4, 0.22)

@export var mode := 1

var braked := 0                  # tests
var _brush: Area2D


func _rebuilt() -> void:
	if _brush:
		_brush.queue_free()
	_brush = Area2D.new()
	_brush.collision_layer = 0
	_brush.collision_mask = 2
	var a := Vector2.ZERO
	var b := end_offset
	var t := (b - a).normalized()
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2((b - a).length(), 14)
	cs.shape = r
	cs.position = (a + b) * 0.5 + up * 6.0
	cs.rotation = (b - a).angle()
	_brush.add_child(cs)
	add_child(_brush)


func _physics_process(_delta: float) -> void:
	if _brush == null:
		return
	var cap: float = LIMITS[mode]
	for o in _brush.get_overlapping_bodies():
		if o is RigidBody2D and o.linear_velocity.length() > cap:
			o.linear_velocity = o.linear_velocity.limit_length(cap)
			if not o.has_meta("braked_by"):
				o.set_meta("braked_by", get_instance_id())
				braked += 1


func _label_at() -> Vector2:
	var e := _ends()
	var t: Vector2 = (e[1] - e[0]).normalized()
	return (e[0] + e[1]) * 0.5 + Vector2(t.y, -t.x) * 16.0


## Clicking its number changes the limit; anywhere else on it, the chute's
## own click-to-select-and-drag.
func _input(event: InputEvent) -> void:
	if _brush != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and to_local(get_global_mouse_position()).distance_to(_label_at()) < 10:
		mode = (mode + 1) % LIMITS.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _draw_surface(a: Vector2, b: Vector2, t: Vector2, n: Vector2, l: float) -> void:
	# bristles standing up off the rail, denser for a lower limit
	var gap := 3.0 + mode * 2.0
	var k := 3.0
	while k < l - 2:
		var p := a + t * k
		draw_line(p, p + n * 6.0 + t * 1.0, BRISTLE, 1.0)
		k += gap
	var font := ThemeDB.fallback_font
	draw_string(font, (a + b) * 0.5 + n * 16.0 - Vector2(8, 0), "%d" % int(LIMITS[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
