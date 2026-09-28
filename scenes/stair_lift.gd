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
var _art: Node2D                 # pixel art: blocks, stems and base rail, posed each frame
const BLOCK_TEX := preload("res://assets/sprites/stair_block.png")
const POST_TEX := preload("res://assets/sprites/stair_post.png")
const BASE_TEX := preload("res://assets/sprites/stair_base.png")


func _ready() -> void:
	z_index = 1
	# art first (ghosts too)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
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
	_art.queue_redraw()          # all sprite: see _draw_art


func _draw_art() -> void:
	var n := steps
	# base rail
	var x0 := minf(-RUN * 0.5 * side, side * (n - 0.5) * RUN)
	_art.draw_texture_rect(BASE_TEX, Rect2(x0, 7, n * RUN, 6), true)
	for k in n:
		var p: Vector2 = _blocks[k].position if k < _blocks.size() else _home(k)
		# the block's stem down to the base rail, then the block, tilted forward
		_art.draw_texture_rect(POST_TEX, Rect2(p.x - 2, p.y + 5, 4, 8 - (p.y + 5)), true)
		_art.draw_set_transform(p + Vector2(0, 3), TILT * side, Vector2.ONE)
		_art.draw_texture(BLOCK_TEX, Vector2(-9, -4))
		_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
