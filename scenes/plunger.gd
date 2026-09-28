extends Node2D
## Plunger: a spring launcher, pinball style. Click and hold it to draw the
## spring back (the longer, the harder), let go to fire a marble straight
## up out of its barrel. Loaded from its own magazine (`ammo`), or from
## marbles dropped into its mouth. A player's hand on the marble machine.

const SFX = preload("res://scripts/sfx.gd")
const MIN_SPEED := 820.0       # every shot clears the lane; power sets how far out it flies
const MAX_SPEED := 1150.0
const CHARGE_TIME := 1.2         # s to full

@export var ammo := 20

var fired := 0                   # tests
var power := 0.0                 # 0..1 while charging
var _charging := false
var _mouth: Area2D


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	# a marble that drops back into the barrel is reloaded
	_mouth = Area2D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60, 24)
	cs.shape = r
	cs.position = Vector2(0, -2)
	_mouth.add_child(cs)
	add_child(_mouth)


## Fire at `p` (0..1 of the speed range). The tests call this directly.
func fire(p: float) -> void:
	if ammo <= 0:
		return
	ammo -= 1
	fired += 1
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.lifetime = 1.0e9
	o.global_position = global_position + Vector2(0, -24)
	o.add_to_group("showcase")
	get_parent().add_child(o)
	o.collision_mask |= 2        # marbles in play knock each other about
	o.linear_velocity = Vector2(0, -lerpf(MIN_SPEED, MAX_SPEED, clampf(p, 0.0, 1.0)))
	SFX.play_small(self, SFX.sfx_bounce(), -6.0, 0.8 + p * 0.5)
	power = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and get_global_mouse_position().distance_to(global_position + Vector2(0, -10)) < 22:
		_charging = true
		power = 0.0
		get_viewport().set_input_as_handled()
	elif not event.pressed and _charging:
		_charging = false
		fire(power)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _mouth == null:
		return
	for b in _mouth.get_overlapping_bodies():
		if b is RigidBody2D and b.linear_velocity.y >= -20.0 and not b.is_queued_for_deletion():
			ammo += 1
			b.queue_free()
			queue_redraw()


func _process(delta: float) -> void:
	if _charging:
		power = minf(1.0, power + delta / CHARGE_TIME)
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	# the barrel
	draw_rect(Rect2(-9, -30, 18, 34), dark)
	draw_rect(Rect2(-7, -28, 14, 30), Color(0.3, 0.24, 0.18))
	# the spring, squashed as it's drawn back
	var top := -22.0 + power * 14.0
	var k := 0
	var y := top
	while y < 0:
		draw_line(Vector2(-5, y), Vector2(5, y + 2), Color(0.7, 0.72, 0.76), 1.0)
		y += 3.0 - power * 1.6
		k += 1
	draw_rect(Rect2(-6, top - 4, 12, 4), brass)
	# the knob underneath, pulled down with the spring
	draw_line(Vector2(0, 4), Vector2(0, 10 + power * 12), dark, 3.0)
	draw_circle(Vector2(0, 12 + power * 12), 6.0, dark)
	draw_circle(Vector2(0, 12 + power * 12), 4.5, Color(0.8, 0.25, 0.2))
	# power gauge
	if power > 0:
		draw_rect(Rect2(12, -30, 4, 30), dark)
		draw_rect(Rect2(12, -30 * power, 4, 30 * power), Color(1.0, 0.7 - power * 0.5, 0.2))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-12, 34), "x%d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.75, 0.55))
