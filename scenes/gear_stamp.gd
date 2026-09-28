extends Node2D
## Gear stamp: a drop hammer over an anvil with a gear-shaped die. An iron
## ingot that lands on the anvil is stamped into a gear, one per stroke:
## the hammer winds up and drops, and the gear rolls off the `side` end.
## A cheaper gear than the assembler's (one iron ingot, no copper), but
## one at a time. It keeps a few ingots waiting; anything else that lands
## on the anvil (copper ingots, ore) is pushed on off the same end. Slow
## on its own, full speed with a gravity wheel or steam engine in reach.
## Put its feet on the floor or a ledge, under the end of a run; click the
## frame to turn it round.

const Power = preload("res://scripts/power.gd")
const Tech = preload("res://scripts/tech.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ORE := preload("res://scenes/ore.tscn")

const ORE_ONLY := 64
const STAMPS := {"iron": "gear"}     # ingot kind -> what it's stamped into
const STROKE := 1.0                  # s per stroke at full power
const HOLD := 3
const FACE := -16.0                  # anvil face, from the feet
const HALF := 12.0                   # anvil face half-width
const LIFT := 26.0                   # hammer rise above the face
const EJECT := Vector2(80, -60)

## Which end the gear leaves by: 1 right, -1 left.
@export var side := 1.0

var stamped := 0             # gears made (tests)
var taken := 0               # ingots taken in (tests)
var passed := 0              # other things pushed on (tests)
var _queue := []             # ingot kinds waiting
var _work := -1.0            # 0..STROKE while a stroke runs; < 0 idle
var _intake: Area2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _flash := 0.0
var _pushed := {}
var _hammer: Sprite2D
var _rod: Sprite2D


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw, which keeps the blank, the chevron, the queue and progress on top
	add_child(_spr(preload("res://assets/sprites/gear_stamp_frame.png"), Vector2(-20, -60)))
	_rod = _spr(preload("res://assets/sprites/gear_stamp_rod.png"), Vector2(-2, 0))
	_rod.region_enabled = true
	_rod.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rod.position = Vector2(0, FACE - LIFT - 12.0 + 2.0)
	add_child(_rod)
	_hammer = _spr(preload("res://assets/sprites/gear_stamp_hammer.png"), Vector2(-9, -10))
	add_child(_hammer)
	queue_redraw()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	# the anvil's face: what lands waits on it
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-HALF, FACE)
	seg.b = Vector2(HALF, FACE)
	cs.shape = seg
	body.add_child(cs)
	add_child(body)
	_intake = Area2D.new()
	_intake.collision_layer = 0
	_intake.collision_mask = 2
	var ic := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(HALF * 2 - 2, 12)
	ic.shape = r
	ic.position = Vector2(0, FACE - 6)
	_intake.add_child(ic)
	add_child(_intake)


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	return sp


func _physics_process(delta: float) -> void:
	if _intake == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_flash = maxf(0.0, _flash - delta * 4.0)
	for b in _intake.get_overlapping_bodies():
		if not (b is RigidBody2D) or b.is_queued_for_deletion() or b.freeze or b.has_meta("caught_by"):
			continue
		var k = b.get("kind")
		if b.is_in_group("ingots") and STAMPS.has(k) and _queue.size() < HOLD:
			_queue.append(k)
			taken += 1
			b.queue_free()
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -12.0, 0.8)
		else:
			# not for stamping (or no room): pushed on off the anvil
			var rb := b as RigidBody2D
			if rb.linear_velocity.x * side < 70.0:
				rb.linear_velocity.x = side * 80.0
			var id: int = b.get_instance_id()
			if not _pushed.has(id):
				_pushed[id] = true
				passed += 1
	if _work < 0 and not _queue.is_empty():
		_work = 0.0
	if _work >= 0:
		_work += delta * _rate * Tech.mult("assembly")
		if _work >= STROKE:
			_work = -1.0
			_strike(_queue.pop_front())
	queue_redraw()


func _strike(k: String) -> void:
	stamped += 1
	_flash = 1.0
	var at := global_position + Vector2(side * (HALF + 9), FACE - 8)   # clear of the anvil face
	var o: RigidBody2D = ORE.instantiate()
	o.kind = STAMPS[k]
	o.global_position = at
	get_tree().current_scene.add_child(o)
	o.linear_velocity = Vector2(EJECT.x * side, EJECT.y)
	o.angular_velocity = side * 8.0
	FX.burst(get_parent(), global_position + Vector2(0, FACE - 2), Color(1.0, 0.8, 0.45), 7, 90.0, 0.25, 1.4, 200.0)
	SFX.play_small(self, SFX.sfx_clink(), -6.0, 0.8)


## The hammer's height over the face: a slow wind-up, a quick drop.
func _hammer_y() -> float:
	if _work < 0:
		return FACE - 12.0
	var f := _work / STROKE
	var up := clampf(f / 0.8, 0.0, 1.0) if f < 0.8 else 1.0 - clampf((f - 0.8) / 0.2, 0.0, 1.0)
	return FACE - 3.0 - (LIFT - 3.0) * up


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := to_local(get_global_mouse_position())
	if absf(p.x) < HALF + 4 and p.y > FACE - LIFT - 14 and p.y < 0:
		side = -side
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35).lerp(Color(1, 0.95, 0.7), _flash)
	var top := FACE - LIFT - 12.0
	# the frame, anvil, rod and hammer are sprites (see _ready): the hammer
	# at its height, the rod down to it, flaring with the brass as it lands
	var hy := roundf(_hammer_y())
	_hammer.position = Vector2(0, hy)
	_rod.region_rect = Rect2(0, 0, 4, maxf(1.0, hy - 9.0 - _rod.position.y))
	_hammer.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.3, 1.1), _flash)
	# a blank on the anvil while a stroke runs
	if _work >= 0:
		draw_rect(Rect2(-5, FACE - 3, 10, 3), dark)
		draw_rect(Rect2(-4, FACE - 2.5, 8, 2), Color(0.62, 0.64, 0.7).lerp(Color(1.0, 0.6, 0.3), clampf(_work / STROKE, 0.0, 1.0) * 0.6))
	# the out end: a chevron
	var o := Vector2(side * (HALF - 2), FACE + 9)
	draw_line(o + Vector2(-side * 3, -3), o, brass, 1.0)
	draw_line(o + Vector2(-side * 3, 3), o, brass, 1.0)
	if _intake == null:
		return
	# waiting ingots as small bars on the beam, the stroke's progress under it
	for i in HOLD:
		var p := Vector2(-9 + i * 7, top - 9)
		draw_rect(Rect2(p, Vector2(5, 3)), dark)
		if i < _queue.size():
			draw_rect(Rect2(p + Vector2(0.5, 0.5), Vector2(4, 2)), Color(0.62, 0.64, 0.7))
	if _work >= 0:
		draw_rect(Rect2(-HALF, top + 3, HALF * 2, 2), dark)
		draw_rect(Rect2(-HALF, top + 3, HALF * 2 * clampf(_work / STROKE, 0.0, 1.0), 2), Color(0.95, 0.8, 0.45))
