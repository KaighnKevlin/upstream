extends Node2D
## Dispenser: a brass magazine that drops a fresh marble every few seconds
## (click: 1 / 2 / 4 s) out of its spout. A marble source for puzzles and
## test rigs; the marbles it makes keep going until they're used.

const SFX = preload("res://scripts/sfx.gd")
const PERIODS := [1.0, 2.0, 4.0]

@export var mode := 1
@export var limit := 0           # 0: for ever; otherwise stops after this many

var dropped := 0                 # tests
var _t := 0.5
var _flash := 0.0


func _ready() -> void:
	z_index = 2
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
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	# the magazine: a tube of marbles
	draw_rect(Rect2(-8, -34, 16, 38), dark)
	draw_rect(Rect2(-6, -32, 12, 34), Color(0.3, 0.24, 0.18))
	for k in 3:
		draw_circle(Vector2(0, -26 + k * 10), 4.0, Color(0.7, 0.5, 0.3))
	# spout
	draw_rect(Rect2(-5, 4, 10, 6), dark)
	draw_rect(Rect2(-4, 4, 8, 5), brass)
	# the period, in pips
	for k in mode + 1:
		draw_circle(Vector2(12, -28 + k * 6), 1.5, Color(1.0, 0.85, 0.5))
