extends Node2D
## Water wheel: an undershot wheel on a frame, set over a flume so its
## lowest paddles dip in the running water. The current turns it, and it
## powers machines in reach like a gravity wheel: steadily, whether or not
## anything's floating by. Out of the water it stands still. Turns the way
## the flume runs. The flume carries on as before (pieces float under it).

const R := 20.0                  # paddle tips
const RATED := 3.0               # rad/s = full power
const SPIN_UP := 1.2

var omega := 0.0
var _angle := 0.0
var _check := 0.0
var _flow := 0.0                 # -1/0/+1: the water under it
var _wheel_art: Sprite2D         # art: the rim, spokes and paddles, turned to _angle


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the spray)
	_spr(preload("res://assets/sprites/water_wheel_frame.png"), Vector2(-17, -4))
	_wheel_art = _spr(preload("res://assets/sprites/water_wheel.png"), Vector2(-22, -22))
	_wheel_art.rotation = _angle
	_spr(preload("res://assets/sprites/water_wheel_axle.png"), Vector2(-4, -4))
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


func power() -> float:
	return clampf(absf(omega) / RATED, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_flow = 0.0
		var dip := global_position + Vector2(0, R - 4)
		for f in get_tree().get_nodes_in_group("flumes"):
			if is_instance_valid(f):
				var w: float = f.water_at(dip)
				if w != 0.0:
					_flow = w
					break
	omega = move_toward(omega, _flow * RATED, SPIN_UP * delta)
	_angle += omega * delta
	_wheel_art.rotation = _angle
	queue_redraw()


func _draw() -> void:
	# the frame, the wheel and the axle cap are sprites; spray where it
	# bites the water
	if absf(omega) > 0.5:
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var x := sin(t * 7.0 + i * 2.1) * 8.0
			draw_circle(Vector2(x, R - 2 - fposmod(t * 20.0 + i * 5.0, 8.0)), 1.0, Color(0.75, 0.88, 1.0, 0.6))
