extends Node2D
## Dice box: a brass box with a hopper on top and a die tumbling in a
## window. Each piece that drops in is sent out of one of its outlets at
## random, the die showing which: left or right, or (click it) left, down
## or right. Over a long run every outlet gets its fair share, but never
## in a pattern, so it mixes two streams into one, or shares a stream
## between machines without the steady beat of the distributor.

const SFX = preload("res://scripts/sfx.gd")
## Launch velocities and spout positions: [left, down, right].
const OUTS := [Vector2(-150, -60), Vector2(0, 80), Vector2(150, -60)]
const SPOUT := [Vector2(-14, 4), Vector2(0, 12), Vector2(14, 4)]
const DIE := Vector2(0, -3)      # the die's window
const FACES := [preload("res://assets/sprites/dice_face_1.png"), preload("res://assets/sprites/dice_face_2.png"), preload("res://assets/sprites/dice_face_3.png")]

## How many ways it sends: 2 (left, right) or 3 (left, down, right).
@export var outlets := 2

var sent := [0, 0, 0]            # tests: pieces out of each outlet (left, down, right)
var last := -1                   # the outlet the last piece went to
var _cool := {}
var _roll := 0.0                 # tumbling time left
var _spin := 0.0
var _face := 1                   # pips showing
var _rng := RandomNumberGenerator.new()   # its own die, apart from the world's dice
var _down_art: Sprite2D          # art: the down spout, shown in 3-way mode
var _die: Sprite2D               # the die, tumbling in its window


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the outlet lamps)
	_down_art = _spr(preload("res://assets/sprites/dice_box_down.png"), Vector2(-5, 7))
	_spr(preload("res://assets/sprites/dice_box.png"), Vector2(-18, -24))
	_die = _spr(FACES[0], Vector2(-4.5, -4.5))
	_die.position = DIE
	_pose()
	if has_meta("ghost"):
		return
	_rng.randomize()
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 14)
	cs.shape = r
	cs.position = Vector2(0, -14)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_take)


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


## The die's face and turn, and the down spout (3-way only).
func _pose() -> void:
	var face := _face
	if _roll > 0.0:
		face = 1 + int(_spin * 0.5) % maxi(outlets, 2)
	_die.texture = FACES[clampi(face, 1, 3) - 1]
	_die.rotation = _spin
	_down_art.visible = outlets == 3


## The outlet indexes in use, into OUTS.
func ways() -> Array:
	return [0, 2] if outlets == 2 else [0, 1, 2]


func _take(b) -> void:
	if not (b is RigidBody2D):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _cool.get(b.get_instance_id(), 0.0) > now:
		return
	_cool[b.get_instance_id()] = now + 1.0
	var w := ways()
	var i := _rng.randi_range(0, w.size() - 1)
	var k: int = w[i]
	b.global_position = global_position + SPOUT[k]
	b.linear_velocity = OUTS[k]
	sent[k] += 1
	last = k
	_face = i + 1
	_roll = 0.25
	SFX.play_small(self, SFX.sfx_ratchet(), -20.0, 1.3 + 0.1 * i)
	_redraw()


func _process(delta: float) -> void:
	if _roll > 0.0:
		_roll = maxf(0.0, _roll - delta)
		_spin += delta * 30.0
		_redraw()
	elif _spin != 0.0:
		_spin = 0.0
		_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 16:
		outlets = 3 if outlets == 2 else 2
		get_viewport().set_input_as_handled()
		_redraw()


## Pip layouts for faces 1..3 (the die only ever needs as many as outlets).
func _pips(face: int) -> Array:
	match face:
		1:
			return [Vector2.ZERO]
		2:
			return [Vector2(-2, -2), Vector2(2, 2)]
		_:
			return [Vector2(-2, -2), Vector2.ZERO, Vector2(2, 2)]


func _draw() -> void:
	# the outlets' lamps, in the spouts: the one just used lit
	for k in ways():
		draw_circle(SPOUT[k], 1.8, Color(1.0, 0.8, 0.4) if k == last else Color(0.35, 0.3, 0.25))


## The die and spouts posed, and the lamps redrawn.
func _redraw() -> void:
	_pose()
	queue_redraw()
