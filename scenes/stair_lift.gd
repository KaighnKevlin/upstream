extends Node2D
## Stair lift: the reciprocating-step lift of real marble machines. A
## staircase of brass blocks rising toward `side`; alternate blocks bob
## up and down a step's height, out of phase, so at the top of each stroke
## a block stands level with the next one up and, tilted forward, rolls
## its marble across. Marbles climb it one hop at a time. Driven faster by
## a gravity wheel or steam engine. The node is the bottom step.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const ORE_ONLY := 64
const RUN := 16.0
const RISE := 14.0
const TILT := 0.12               # rad, forward-down, so marbles roll on
const PERIOD := 1.1              # s per stroke at full power

@export var steps := 6
@export var side := 1.0

var _blocks: Array[AnimatableBody2D] = []
var _phase := 0.0
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var strokes := 0                 # tests


func _ready() -> void:
	z_index = 1
	if has_meta("ghost"):
		queue_redraw()
		return
	add_to_group("power_users")
	for k in steps:
		var b := AnimatableBody2D.new()
		b.collision_layer = ORE_ONLY
		b.collision_mask = 0
		b.sync_to_physics = true
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(RUN, 6)
		cs.shape = r
		cs.position = Vector2(0, 3)
		cs.rotation = TILT * side
		b.add_child(cs)
		b.position = _home(k)
		add_child(b)
		_blocks.append(b)


func _home(k: int) -> Vector2:
	return Vector2(side * k * RUN, -k * RISE)


func _physics_process(delta: float) -> void:
	if _blocks.is_empty():
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var before := int(_phase / PI)
	_phase += delta * PI / PERIOD * _rate
	if int(_phase / PI) != before:
		strokes += 1
		SFX.play_small(self, SFX.sfx_ore_knock("wood"), -18.0, 0.9)
	for k in _blocks.size():
		# alternate blocks out of phase: 0 at the bottom of the stroke, -RISE at the top
		var lift := -RISE * 0.5 * (1.0 - cos(_phase + k * PI))
		_blocks[k].position = _home(k) + Vector2(0, lift)
	queue_redraw()


func _draw() -> void:
	var n := steps
	for k in n:
		var p: Vector2 = _blocks[k].position if k < _blocks.size() else _home(k)
		# the block and its post down to the base line
		var top := p + Vector2(0, 0)
		draw_line(top + Vector2(0, 6), Vector2(top.x, 8), Color(0.16, 0.13, 0.1), 2.0)
		draw_set_transform(top + Vector2(0, 3), TILT * side, Vector2.ONE)
		draw_rect(Rect2(-RUN * 0.5, -3, RUN, 6), Color(0.1, 0.08, 0.07))
		draw_rect(Rect2(-RUN * 0.5 + 1, -2, RUN - 2, 4), Color(0.72, 0.55, 0.3))
		draw_rect(Rect2(-RUN * 0.5 + 1, -2, RUN - 2, 1), Color(0.9, 0.75, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# base rail
	draw_line(Vector2(-RUN * 0.5 * side, 9), Vector2(side * (n - 0.5) * RUN, 9), Color(0.16, 0.13, 0.1), 3.0)
