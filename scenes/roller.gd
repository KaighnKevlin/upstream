extends RigidBody2D
## Roller: a clockwork juggernaut that is only a ball. It spins itself up
## toward the dome and rolls: a real rigid body, so it has momentum, it
## bounces off things, and blasts, bumpers and pendulums send it flying
## (knock()). It runs over the prospector if it's going fast, and slams
## into the dome hard. A ditch is what it's for: one that rolls into a
## ditch and sticks there braces against both walls, jacks itself up and
## unfolds into an iron plug level with the ground, and the pack walks
## over it. Destroy the plug and the ditch opens again.
## Art: tools/art/gen_roller.py (one 30x30 frame; the body turns it).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const RADIUS := 13.0
const MAX_SPIN := 9.0            # rad/s it drives itself to (~115 px/s)
const DRIVE := 6.0               # how fast it winds up to that
const MAX_HP := 18
const CRUSH_SPEED := 70.0        # rolling this fast into you hurts

var hp := MAX_HP
var damage := 12                 # into the dome
var direction := -1.0
var velocity := Vector2.ZERO     # turrets lead on this
var _dying := false
var _crush_t := 0.0
var _rumble := 0.0
var plugged := false             # locked into a ditch as a plug (tests)
var _stuck := 0.0
var _span := Vector2.ZERO        # plug: left, right x
var _spr: Sprite2D
const STUCK_TIME := 1.2
const GROUND_ROW := 6            # WorldGen.SURFACE_ROWS: the first row of ground


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1 | 64
	mass = 8.0
	gravity_scale = 1.0
	can_sleep = false
	var m := PhysicsMaterial.new()
	m.bounce = 0.25
	m.friction = 1.0
	physics_material_override = m
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/roller.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	z_index = 2
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return RADIUS


## Bumpers, blasts, pendulums: a shove it takes like the heavy thing it is.
func knock(v: Vector2) -> void:
	if not _dying:
		apply_central_impulse(v * mass * 0.6)


func _physics_process(delta: float) -> void:
	velocity = linear_velocity
	if _dying or plugged:
		return
	# sat in a ditch, not going anywhere: plug it
	if global_position.y - RADIUS > GROUND_ROW * 16 - 4 and linear_velocity.length() < 25.0:
		_stuck += delta
		if _stuck > STUCK_TIME:
			_plug()
			return
	else:
		_stuck = 0.0
	# spin itself up toward the dome (clockwise = rolling right)
	angular_velocity = move_toward(angular_velocity, MAX_SPIN * direction, DRIVE * delta)
	# rumble and grit off the ground while it rolls fast
	_rumble -= delta
	if _rumble <= 0 and absf(linear_velocity.x) > 60.0:
		_rumble = 0.12
		FX.burst(get_parent(), global_position + Vector2(0, RADIUS), Color(0.55, 0.45, 0.35, 0.7), 1, 30.0, 0.35, 1.4)
	# running over the prospector
	_crush_t -= delta
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and _crush_t <= 0 and linear_velocity.length() > CRUSH_SPEED and p.global_position.distance_to(global_position + Vector2(0, 6)) < RADIUS + 10.0:
		_crush_t = 0.8
		if p.has_method("take_damage"):
			p.take_damage(10)
		if p.has_method("launch"):
			p.launch(Vector2(signf(linear_velocity.x) * 300.0, -240.0))
		SFX.play(self, SFX.sfx_mine_break(), -4.0, 0.7)


## Brace and rise: find the ditch's edges at ground level and become a
## plate spanning them, flush with the ground.
func _plug() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	var row := GROUND_ROW
	var left := cell.x
	var right := cell.x
	for i in 6:
		if tm.get_cell_source_id(Vector2i(left - 1, row)) != -1:
			break
		left -= 1
	for i in 6:
		if tm.get_cell_source_id(Vector2i(right + 1, row)) != -1:
			break
		right += 1
	var x0 := tm.to_global(tm.map_to_local(Vector2i(left, row))).x - 8
	var x1 := tm.to_global(tm.map_to_local(Vector2i(right, row))).x + 8
	plugged = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	set_deferred("freeze", true)
	collision_layer = 1 | 8               # ground for walkers (and the prospector), still a target
	var top := float(row * 16)
	_span = Vector2(x0, x1)
	var cs: CollisionShape2D = get_child(0) as CollisionShape2D
	for c in get_children():
		if c is CollisionShape2D:
			cs = c
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, 12)
	cs.set_deferred("shape", rect)
	cs.set_deferred("position", Vector2.ZERO)
	var to := Vector2((x0 + x1) * 0.5, top + 6)
	rotation = 0.0
	_spr.visible = false
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): FX.burst(get_parent(), global_position, Color(0.6, 0.55, 0.5), 10, 80.0, 0.4, 1.8))
	SFX.play(self, SFX.sfx_clink(), 0.0, 0.5)
	SFX.play(self, SFX.sfx_ore_knock("metal"), -2.0, 0.6)
	queue_redraw()


func _draw() -> void:
	if not plugged:
		return
	var w := _span.y - _span.x
	var r := Rect2(-w * 0.5, -6, w, 12)
	draw_rect(r, Color(0.16, 0.15, 0.14))
	draw_rect(r.grow(-1), Color(0.36, 0.4, 0.42))
	draw_rect(Rect2(r.position.x + 1, -6 + 1, w - 2, 2), Color(0.5, 0.56, 0.56))
	draw_rect(Rect2(-w * 0.5 + 2, -2, w - 4, 4), Color(0.55, 0.42, 0.25))      # the drive band, now a brace
	var x := -w * 0.5 + 4
	while x < w * 0.5 - 3:
		draw_rect(Rect2(x, -4.5, 1, 1), Color(0.62, 0.48, 0.28))
		draw_rect(Rect2(x, 3.5, 1, 1), Color(0.62, 0.48, 0.28))
		x += 5
	draw_rect(Rect2(-3, -1, 6, 2), Color(0.9, 0.25, 0.18))                      # the eye, still watching


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	FX.burst(get_parent(), global_position, Color(0.9, 0.85, 0.7), 4, 80.0, 0.25, 1.4)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 0.6)
		return
	_dying = true
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), 0.0, 0.6)
	FX.burst(get_parent(), global_position, Color(1.0, 0.7, 0.3), 16, 170.0, 0.4, 2.2)
	FX.debris(get_parent(), global_position, 10, 200.0, false)
	FX.shake(self, 4.0, 0.25)
	preload("res://scenes/ore.gd").spill(get_parent(), global_position, 4)
	queue_free()
