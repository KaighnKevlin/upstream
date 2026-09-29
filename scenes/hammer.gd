extends Node2D
## Hammer: a bell-crank on a pivot, a paddle sticking out one way and a
## brass hammer head hanging below. A piece dropping onto the paddle knocks
## it down, which swings the head out toward `side`, where it strikes
## whatever rests on the little ledge beside it and sends it flying
## sideways. The dropped piece rolls off the tipped paddle and carries on
## down; the struck one flies, harder the heavier and faster the drop and
## the lighter the one struck (iron dropped on copper sends it far). A
## trigger (tally wheel, plate, bell) swings it too. Load the ledge by
## dropping a piece onto it; it holds one. The node is the pivot.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const PADDLE := 24.0             # pivot to the paddle's plate, away from `side`
const HEAD := 26.0               # pivot to the hammer head, hanging down
const STRIKE := 0.46             # rad of swing where the head meets the ledge piece
const V_MIN := 220.0
const V_MAX := 700.0
const V_TRIG := 380.0            # a triggered swing's launch speed

@export var side := 1.0          # the way the struck piece flies

var struck := 0                  # tests: pieces launched off the ledge
var swings := 0                  # tests
var last_speed := 0.0
var _swing := 0.0                # rad, + : paddle down, head out toward side
var _state := 0                  # 0 at rest, 1 swinging out, 2 swinging back
var _power := 0.0
var _loaded: RigidBody2D = null
var _cool := {}
var _frame: Sprite2D
var _crank: Sprite2D


func _ready() -> void:
	z_index = 2
	# sprites (ghosts too): the bracket and ledge, the crank swinging over them
	_frame = _sprite(preload("res://assets/sprites/hammer_frame.png"), Vector2(-9, -20))
	_crank = _sprite(preload("res://assets/sprites/hammer_crank.png"), Vector2(-34, -8))
	_place_art()
	if has_meta("ghost"):
		return
	add_to_group("triggerable")


func _sprite(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


## Drawn for side +1 (flying right); mirrored for -1. The crank turns with
## the swing, the same way _rot() turns its points.
func _place_art() -> void:
	var s := 1.0 if side >= 0 else -1.0
	_frame.scale = Vector2(s, 1)
	_crank.scale = Vector2(s, 1)
	_crank.rotation = -_swing * side


## Where a piece rests on the ledge (for layouts and tests).
func ledge_point() -> Vector2:
	return Vector2(side * 23.0, HEAD - 2.0)


## Where a piece lands on the paddle (for layouts and tests).
func paddle_point() -> Vector2:
	return Vector2(-side * PADDLE, -7)


func _rot(v: Vector2) -> Vector2:
	return v.rotated(-_swing * side)


func trigger() -> void:
	_start(V_TRIG)


func _start(power: float) -> void:
	if _state != 0:
		return
	_state = 1
	_power = power
	swings += 1
	SFX.play_small(self, SFX.sfx_clink(), -14.0, 0.8)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore") + get_tree().get_nodes_in_group("ingots"):
		if not is_instance_valid(o) or o.freeze or o == _loaded or _cool.get(o.get_instance_id(), 0.0) > now or not Hold.free_to_take(o, self):
			continue
		var p: Vector2 = o.global_position - global_position
		# onto the paddle: the swing, and the piece rolls off it and on down
		var q := p - paddle_point()
		if _state == 0 and absf(q.x) < 11 and q.y > -12 and q.y < 6 and o.linear_velocity.y > 40:
			var target_m: float = _loaded.mass if is_instance_valid(_loaded) else 1.0
			_start(clampf(V_MIN + o.linear_velocity.y * 0.7 * o.mass / maxf(target_m, 0.3), V_MIN, V_MAX))
			o.linear_velocity = Vector2(-side * 60.0, o.linear_velocity.y * 0.4)
			_cool[o.get_instance_id()] = now + 0.6
			continue
		# onto the ledge: it's held there, waiting to be struck
		if not is_instance_valid(_loaded) and p.distance_to(ledge_point()) < 11:
			_loaded = o
			Hold.claim(o, self)
			o.gravity_scale = 0.0
	match _state:
		1:
			_swing = move_toward(_swing, STRIKE, delta * 7.0)
			if _swing >= STRIKE:
				_hit(now)
				_state = 2
		2:
			_swing = move_toward(_swing, 0.0, delta * 1.2)
			if _swing <= 0.0:
				_state = 0
	if is_instance_valid(_loaded):
		Hold.claim(_loaded, self)
		_loaded.linear_velocity = (global_position + ledge_point() - _loaded.global_position) / delta
		if "_timer" in _loaded:
			_loaded._timer = 0.0
	else:
		_loaded = null
	queue_redraw()


func _hit(now: float) -> void:
	SFX.play_small(self, SFX.sfx_ore_knock("metal"), -6.0, 0.9)
	if not is_instance_valid(_loaded):
		return
	Hold.release(_loaded, self)
	_loaded.sleeping = false
	_loaded.linear_velocity = Vector2(side * _power, -50.0)
	_cool[_loaded.get_instance_id()] = now + 1.0
	FX.burst(get_parent(), _loaded.global_position, Color(1.0, 0.85, 0.5), 5, 70.0, 0.2, 1.0)
	last_speed = _power
	struck += 1
	_loaded = null


func _draw() -> void:
	_place_art()
