extends Node2D
## Dispenser: a brass magazine that drops a fresh marble every few seconds
## (click: 1 / 2 / 4 s) out of its spout. A marble source for puzzles and
## test rigs; the marbles it makes keep going until they're used.

const SFX = preload("res://scripts/sfx.gd")
const PERIODS := [1.0, 2.0, 4.0]

@export var mode := 1
@export var limit := 0           # 0: for ever; otherwise stops after this many
@export var kinds: Array = ["copper"]   # dropped in turn

var dropped := 0                 # tests
var _t := 0.5
var _flash := 0.0


func _ready() -> void:
	z_index = 2
	# the magazine: a sprite, behind our _draw (flash, pips); ghosts too
	var art := Sprite2D.new()
	art.texture = preload("res://assets/sprites/dispenser.png")
	art.centered = false
	art.offset = Vector2(-11, -38)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.show_behind_parent = true
	add_child(art)
	if not has_meta("ghost"):
		add_to_group("dispensers")


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_flash = maxf(0.0, _flash - delta * 3.0)
	if limit > 0 and dropped >= limit:
		return
	_t -= delta
	if _t <= 0:
		_t = PERIODS[mode]
		dropped += 1
		_flash = 1.0
		var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
		o.kind = kinds[(dropped - 1) % kinds.size()]
		o.lifetime = 1.0e9
		o.global_position = global_position + Vector2(0, 14)
		o.add_to_group("showcase")
		get_parent().add_child(o)
		o.linear_velocity = Vector2(0, 40)
		SFX.play_small(self, SFX.sfx_ore_knock("metal"), -20.0, 1.4)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position) < 16:
		mode = (mode + 1) % PERIODS.size()
		queue_redraw()


func _draw() -> void:
	# the magazine and spout are a sprite (see _ready); the spout flashes as one drops
	if _flash > 0.0:
		draw_rect(Rect2(-4, 4, 8, 6), Color(1, 0.95, 0.7, 0.8 * _flash))
	# the period, in pips
	for k in mode + 1:
		draw_circle(Vector2(12, -28 + k * 6), 1.5, Color(1.0, 0.85, 0.5))
