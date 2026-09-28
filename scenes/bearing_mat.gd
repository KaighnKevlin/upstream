extends Node2D
## Ball-bearing mat: a shallow steel tray laid on the walkers' path. Empty,
## it's just floor. With loose ore rolling about in it, anything walking
## across skids and slips: it gets a fraction of its way (less the more
## ore there is) and now and then loses its footing entirely. Keep it
## stocked, a chute or a silo emptying into it, and the wave crawls
## across it under the turrets. Walkers kick the ore about as they go.

const ORE_ONLY := 64
const W := 90.0
const FULL := 6                  # pieces for the full effect
const HOLD := 0.7                # fraction of a walker's way it loses, fully stocked

var slowed := 0.0                # tests: walker-seconds spent slowed
var _area: Area2D
var _stock := 0


func _ready() -> void:
	z_index = 0
	if has_meta("ghost"):
		return
	var body := StaticBody2D.new()
	body.collision_layer = ORE_ONLY
	body.collision_mask = 0
	for seg in [[Vector2(-W * 0.5, -10), Vector2(-W * 0.5, 0)], [Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0)], [Vector2(W * 0.5, 0), Vector2(W * 0.5, -10)]]:
		var cs := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		cs.shape = s
		body.add_child(cs)
	add_child(body)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 8 | 2      # walkers and ore
	var ac := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W, 40)
	ac.shape = r
	ac.position = Vector2(0, -18)
	_area.add_child(ac)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	var ore := 0
	var walkers := []
	for b in _area.get_overlapping_bodies():
		if b is RigidBody2D and not b.freeze and b.global_position.y > global_position.y - 14:
			ore += 1
		elif b.is_in_group("enemies") and b.has_method("knock"):
			walkers.append(b)
	_stock = ore
	var f := clampf(float(ore) / FULL, 0.0, 1.0) * HOLD
	if f > 0.0:
		for e in walkers:
			if e.get("_dying"):
				continue
			# skidding: it only makes (1 - f) of its way
			e.global_position.x -= e.velocity.x * delta * f
			slowed += delta
			if randf() < delta * 0.6 * f:
				e.knock(Vector2(-signf(e.velocity.x) * 60.0, -40.0))   # feet out from under it
			# and kicks the bearings about
			for b in _area.get_overlapping_bodies():
				if b is RigidBody2D and absf(b.global_position.x - e.global_position.x) < 12:
					b.linear_velocity += Vector2(signf(e.velocity.x) * 30.0, -20.0)
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.09, 0.07, 0.1)
	var steel := Color(0.42, 0.44, 0.5)
	draw_line(Vector2(-W * 0.5, 0), Vector2(W * 0.5, 0), dark, 4.0)
	draw_line(Vector2(-W * 0.5, -1), Vector2(W * 0.5, -1), steel, 2.0)
	for x in [-W * 0.5, W * 0.5]:
		draw_line(Vector2(x, -10), Vector2(x, 0), dark, 3.0)
	# stocked: a dotted glint along the tray
	if _stock > 0:
		var n := 12
		for i in n:
			draw_circle(Vector2(-W * 0.5 + (i + 0.5) * W / n, -3), 1.0, Color(0.9, 0.85, 0.7, 0.3 + 0.5 * clampf(float(_stock) / FULL, 0.0, 1.0)))
