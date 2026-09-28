extends Node2D
## Jump: the marble-run gap jump. A little upturned kicker at the node flicks
## pieces into the air; a landing ramp with a backboard waits across the gap
## (drag to set where). Fast pieces fly the gap and land; slow ones drop
## short, through the gap, so it sorts a stream by speed. Put whatever
## should catch the slow ones underneath.
## Ore-only layer: walkers pass through.

const ORE_ONLY := 64
const KICK := 14.0               # kicker length
const KICK_ANGLE := -0.2         # rad: tipped up toward the gap (steeper and the kick eats the speed)
const LAND := 44.0               # landing ramp length
const LAND_SLOPE := 0.3          # it runs on down, away from the kicker
const LEN_MIN := 30.0
const LEN_MAX := 160.0

@export var end_offset := Vector2(60, 10)   # the landing ramp's near end

var landed := 0                  # tests: pieces that made the jump
var fell := 0                    # and that dropped short
var _body: StaticBody2D
var _land_area: Area2D
var _gap_area: Area2D
var _counted := {}
var _kick_sp: Sprite2D           # pixel art: the kicker, and the landing ramp across the gap
var _land_sp: Sprite2D


func _dir() -> float:
	return 1.0 if end_offset.x >= 0 else -1.0


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	if _body:
		_rebuild()
	queue_redraw()


func _ready() -> void:
	z_index = 1
	# sprites first (ghosts too), drawn for a jump to the right and mirrored
	_kick_sp = Sprite2D.new()
	_kick_sp.texture = preload("res://assets/sprites/jump_kick.png")
	_kick_sp.centered = false
	_kick_sp.offset = Vector2(-4, -8)
	_kick_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_kick_sp.show_behind_parent = true
	add_child(_kick_sp)
	_land_sp = Sprite2D.new()
	_land_sp.texture = preload("res://assets/sprites/jump_land.png")
	_land_sp.centered = false
	_land_sp.offset = Vector2(-4, -30)
	_land_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_land_sp.show_behind_parent = true
	add_child(_land_sp)
	if has_meta("ghost"):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = ORE_ONLY
	_body.collision_mask = 0
	var m := PhysicsMaterial.new()      # like a chute: landings stick, then roll
	m.absorbent = true
	m.bounce = 0.5
	m.friction = 1.0
	_body.physics_material_override = m
	add_child(_body)
	_land_area = _sensor()
	_gap_area = _sensor()
	_land_area.body_entered.connect(func(b): _count(b, true))
	_gap_area.body_entered.connect(func(b): _count(b, false))
	_rebuild()


func _sensor() -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	add_child(a)
	return a


func _count(b, made_it: bool) -> void:
	if not (b is RigidBody2D) or _counted.get(b.get_instance_id(), 0.0) > Time.get_ticks_msec() / 1000.0:
		return
	_counted[b.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + 1.0
	if made_it:
		landed += 1
	else:
		fell += 1


func _kick_end() -> Vector2:
	var s := _dir()
	return Vector2(cos(KICK_ANGLE) * s, sin(KICK_ANGLE)) * KICK


func _land_end() -> Vector2:
	var s := _dir()
	return end_offset + Vector2(s, LAND_SLOPE).normalized() * LAND


func _rebuild() -> void:
	for n in [_body, _land_area, _gap_area]:
		for c in n.get_children():
			c.queue_free()
	var s := _dir()
	_seg(_body, Vector2.ZERO, _kick_end())
	_seg(_body, end_offset, _land_end())
	# the backboard over the landing's far end stops overshoots
	var back := _land_end()
	_seg(_body, back + Vector2(0, -14), back + Vector2(s * 4, -40))   # raised: rolling pieces pass under, fliers hit it
	# landing sensor sits just above the ramp; the gap sensor below the kicker's lip
	var lr := RectangleShape2D.new()
	lr.size = Vector2(LAND, 14)
	var lc := CollisionShape2D.new()
	lc.shape = lr
	lc.position = (end_offset + _land_end()) * 0.5 + Vector2(0, -8)
	lc.rotation = atan2(LAND_SLOPE, 1.0) * s
	_land_area.add_child(lc)
	var gap_w := absf(end_offset.x - _kick_end().x)
	var gr := RectangleShape2D.new()
	gr.size = Vector2(maxf(gap_w - 6, 8), 10)
	var gc := CollisionShape2D.new()
	gc.shape = gr
	gc.position = Vector2((_kick_end().x + end_offset.x) * 0.5, maxf(end_offset.y, 0) + 30)
	_gap_area.add_child(gc)
	queue_redraw()


func _seg(on: CollisionObject2D, a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var sh := SegmentShape2D.new()
	sh.a = a
	sh.b = b
	cs.shape = sh
	on.add_child(cs)


func _draw() -> void:
	var k := _kick_end()
	var s := _dir()
	# the kicker and the landing ramp (posts, backboard) are sprites
	_kick_sp.scale = Vector2(s, 1)
	_land_sp.scale = Vector2(s, 1)
	_land_sp.position = end_offset
	# a dotted arc showing the flight
	var n := 8
	for i in n:
		var t := (i + 0.5) / n
		var p := k.lerp(end_offset, t) + Vector2(0, -sin(t * PI) * 14.0)
		draw_circle(p, 1.0, Color(0.9, 0.8, 0.55, 0.5))
