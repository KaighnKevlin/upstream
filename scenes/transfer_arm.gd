extends Node2D
## Transfer arm: a swinging scoop on a pivot, the hand-off between levels.
## A piece rolling into its cup at the bottom of the swing is caught, and
## the arm swings it up the near side, over the top of its pivot and down
## the far side (toward `side`), where it tips it out onto a chute or into
## a cup about one level higher than it came in. Then it swings back empty
## for the next; any arriving while it's away wait in the cradle. Slow by
## itself; a gravity wheel or engine in reach drives it at full speed.
## The node is the pivot; feed the cradle (below it, a little back from
## `side`) with the low end of a chute, and put the next piece of track
## under the drop point (up and over toward `side`).

const SFX = preload("res://scripts/sfx.gd")
const Power = preload("res://scripts/power.gd")
const ARM := 36.0
const REST := 0.5                # rad from straight down, back toward the feed
const DROP := PI + 0.9           # over the top and down the far side
const T_UP := 0.8                # s to swing up and over, at full power
const T_BACK := 0.6              # s to swing back empty, at full power
const V_OUT := Vector2(45, 20)   # tipped out, toward `side`

@export var side := 1.0          # the way it hands pieces on

var lifted := 0                  # tests
var last_lift := 0.0             # tests: px the last one went up
var _phi := REST
var _state := 0                  # 0 waiting, 1 swinging up, 2 swinging back
var _f := 0.0
var _rider: RigidBody2D = null
var _rider_y := 0.0
var _waiting: Array = []
var _cool := {}
var _rate := 1.0
var _rate_t := 0.0
var _art: Node2D                 # pixel art, drawn for side +1 and mirrored
var _arm_sp: Sprite2D
const STAND_TEX := preload("res://assets/sprites/transfer_stand.png")
const ARM_TEX := preload("res://assets/sprites/transfer_arm.png")


func _ready() -> void:
	z_index = 0                  # under the ore: the rider shows in the cup
	# sprites first (ghosts too), under our _draw (the governor pip)
	_art = Node2D.new()
	_art.show_behind_parent = true
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_art)
	var st := Sprite2D.new()
	st.texture = STAND_TEX
	st.centered = false
	st.offset = Vector2(-38, -7)
	_art.add_child(st)
	_arm_sp = Sprite2D.new()
	_arm_sp.texture = ARM_TEX
	_arm_sp.centered = false
	_arm_sp.offset = Vector2(-11, -20)
	_art.add_child(_arm_sp)
	if has_meta("ghost"):
		return
	add_to_group("power_users")


func _cup(phi: float) -> Vector2:
	# phi 0: straight down; up the back (-side), over the top, down toward side
	return Vector2(-side * sin(phi), cos(phi)) * ARM


## Where it catches (for layouts and tests).
func catch_point() -> Vector2:
	return _cup(REST)


## Where it tips pieces out (for layouts and tests).
func drop_point() -> Vector2:
	return _cup(DROP)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var catch := global_position + catch_point()
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or o == _rider or o in _waiting or _cool.get(o.get_instance_id(), 0.0) > now:
			continue
		if o.global_position.distance_to(catch) < 12 and o.linear_velocity.y > -60:
			o.gravity_scale = 0.0
			_waiting.append(o)
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -20.0, 1.3)
	_waiting = _waiting.filter(func(o): return is_instance_valid(o))
	match _state:
		0:
			_phi = REST
			if not _waiting.is_empty():
				_rider = _waiting.pop_front()
				_rider_y = _rider.global_position.y
				_state = 1
				_f = 0.0
		1:
			_f = minf(1.0, _f + delta * _rate / T_UP)
			_phi = lerpf(REST, DROP, _ease(_f))
			if not is_instance_valid(_rider):
				_state = 2
				_f = 0.0
			elif _f >= 1.0:
				_tip(now)
				_state = 2
				_f = 0.0
		2:
			_f = minf(1.0, _f + delta * _rate / T_BACK)
			_phi = lerpf(DROP, REST, _ease(_f))
			if _f >= 1.0:
				_state = 0
				SFX.play_small(self, SFX.sfx_clink(), -20.0, 1.4)
	if is_instance_valid(_rider) and _state == 1:
		_hold(_rider, global_position + _cup(_phi), delta)
	for k in _waiting.size():
		_hold(_waiting[k], catch + Vector2(-side * 7.0 * k, -1.0 * k), delta)
	queue_redraw()


func _ease(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)


func _hold(o: RigidBody2D, at: Vector2, delta: float) -> void:
	o.linear_velocity = (at - o.global_position) / delta
	if "_timer" in o:
		o._timer = 0.0


func _tip(now: float) -> void:
	_rider.gravity_scale = 1.0
	_rider.sleeping = false
	_rider.global_position = global_position + drop_point()
	_rider.linear_velocity = Vector2(side * V_OUT.x, V_OUT.y)
	last_lift = _rider_y - _rider.global_position.y
	_cool[_rider.get_instance_id()] = now + 1.5
	_rider = null
	lifted += 1
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 1.0)


func _draw() -> void:
	# the arm sprite hangs straight down at phi 0 and turns with it (art
	# space is side +1: the _art node mirrors)
	_art.scale = Vector2(side, 1)
	_arm_sp.rotation = _phi
	# the governor pip on the pivot glows when it's powered
	draw_circle(Vector2.ZERO, 1.6, Color(0.1, 0.08, 0.07))
	draw_circle(Vector2.ZERO, 1.2, Color(1.0, 0.8, 0.4).lerp(Color(0.35, 0.25, 0.15), 1.0 - (_rate - Power.UNPOWERED) / (1.0 - Power.UNPOWERED)))
