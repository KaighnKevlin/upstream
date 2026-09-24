extends Line2D
## A short fading streak behind a fast-moving body (ore, ingots). Add as a
## child of the body; it draws in world space and only grows while the body
## is moving faster than min_speed, so resting ore leaves nothing behind.

@export var length := 7              # points kept
@export var min_speed := 140.0
@export var head_color := Color(0.8, 0.6, 0.4, 0.55)

var _body: Node2D


func _ready() -> void:
	_body = get_parent() as Node2D
	top_level = true
	global_position = Vector2.ZERO
	width = 5.0
	var curve := Curve.new()          # thin at the tail, full at the body
	curve.add_point(Vector2(0, 0.1))
	curve.add_point(Vector2(1, 1))
	width_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(head_color, 0.0))
	g.set_color(1, head_color)
	gradient = g
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	z_as_relative = true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_body):
		return
	var v: Vector2 = _body.linear_velocity if "linear_velocity" in _body else Vector2.ZERO
	if v.length() > min_speed:
		add_point(_body.global_position)
		while get_point_count() > length:
			remove_point(0)
	elif get_point_count() > 0:
		remove_point(0)  # let the streak shrink away once it slows
