extends CharacterBody2D
## Clockwork gremlin: a saboteur. It doesn't care about the dome: it runs
## for your nearest machine, gets up close and unscrews it (WRENCH seconds,
## sparks and clanks, a bar over the machine showing how far it's got).
## When it's done the machine falls to pieces (a little scrap) and the
## gremlin goes for the next one. With nothing left to wreck it heads for
## the dome like everyone else. Fast and fragile: 5 HP, but a hopper that
## clears walls and small ditches. Kill it before it finishes.
## Art: tools/art/gen_gremlin.py (8 frames of 30x28: 6 run, 2 wrench).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const SPEED := 88.0
const GRAVITY := 980.0
const MAX_HP := 5
const WRENCH := 3.5            # seconds to take a machine apart
const REACH := Vector2(34, 70) # close enough to work on it (x, y)
const HOP := -330.0
const GIVE_UP := 6.0           # stuck this long: pick another target

var hp := MAX_HP
var damage := 4
var direction := -1.0
var wrecked := 0               # tests
var _dying := false
var _knock_t := 0.0
var _target: Node2D = null
var _work := 0.0
var _clank := 0.0
var _stuck := 0.0
var _retarget := 0.0
var _skip := {}                # targets it gave up on
var _spr: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 20)
	cs.shape = r
	cs.position = Vector2(0, -10)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/gremlin.png")
	for spec in [["run", [0, 1, 2, 3, 4, 5], 14.0], ["wrench", [6, 7], 7.0]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 30, 0, 30, 28)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-13, -27)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("run")
	add_child(_spr)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -13)


func hit_radius() -> float:
	return 9.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v
		_knock_t = 0.4
		_work = 0.0


func _machines() -> Array:
	var bs := get_node_or_null("/root/BuildSystem")
	if bs == null:
		return []
	return bs._placed_buildings.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion() and not _skip.has(b))


func _pick() -> void:
	_target = null
	var best := INF
	for b in _machines():
		var d: float = absf(b.global_position.x - global_position.x) + absf(b.global_position.y - global_position.y) * 2.0
		if d < best:
			best = d
			_target = b
	_stuck = 0.0


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
		move_and_slide()
		return
	_retarget -= delta
	if _target == null or not is_instance_valid(_target) or _retarget <= 0:
		_retarget = 1.5
		if _work <= 0:
			_pick()
	var goal: Vector2
	if _target and is_instance_valid(_target):
		goal = _target.global_position
	else:
		var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
		goal = dome.global_position if dome else Vector2(1200, 0)
	var d := goal - global_position
	if _target and is_instance_valid(_target) and absf(d.x) < REACH.x and absf(d.y) < REACH.y and is_on_floor():
		_wrench(delta)
		move_and_slide()
		queue_redraw()
		return
	_work = maxf(0.0, _work - delta)       # dragged off it: the half-undone screws go back
	_spr.play("run")
	direction = signf(d.x) if absf(d.x) > 3 else direction
	velocity.x = SPEED * direction
	if is_on_floor():
		# hop walls, and hop up to a target on a ledge above
		if is_on_wall() or (d.y < -30 and absf(d.x) < 40):
			velocity.y = HOP
	# stuck (a wall too high, a pit it can't leave): try another machine
	if absf(get_real_velocity().x) < 10:
		_stuck += delta
		if _stuck > GIVE_UP and _target:
			_skip[_target] = true
			_pick()
	else:
		_stuck = maxf(0.0, _stuck - delta)
	_spr.flip_h = direction < 0
	move_and_slide()
	queue_redraw()


func _wrench(delta: float) -> void:
	velocity.x = 0
	_spr.play("wrench")
	direction = signf(_target.global_position.x - global_position.x) if absf(_target.global_position.x - global_position.x) > 2 else direction
	_spr.flip_h = direction < 0
	_work += delta
	_clank -= delta
	if _clank <= 0:
		_clank = 0.29
		var at := global_position + Vector2(10 * direction, -8)
		FX.burst(get_parent(), at, Color(1.0, 0.85, 0.45), 3, 90.0, 0.2, 1.1, -40.0)
		SFX.play_small(self, SFX.sfx_clink(), -9.0, randf_range(1.1, 1.5))
	if _work >= WRENCH:
		_dismantle(_target)
		_work = 0.0
		_target = null
		_retarget = 0.0


func _dismantle(b: Node2D) -> void:
	var at := b.global_position + Vector2(0, -12)
	FX.burst(get_parent(), at, Color(0.7, 0.62, 0.5), 16, 150.0, 0.5, 2.2)
	FX.debris(get_parent(), at, 8, 180.0, false)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), -2.0, 0.9)
	preload("res://scenes/ore.gd").spill(get_parent(), at, 2)
	var bs := get_node_or_null("/root/BuildSystem")
	if bs:
		bs._placed_buildings.erase(b)
	b.queue_free()
	wrecked += 1
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner") and wrecked == 1:
		scene._show_banner("A GREMLIN WRECKED A MACHINE", "kill them before they finish")


## Progress over the machine it's working on.
func _draw() -> void:
	if _work <= 0 or _target == null or not is_instance_valid(_target):
		return
	var top := to_local(_target.global_position + Vector2(-14, -46))
	draw_rect(Rect2(top, Vector2(28, 4)), Color(0.08, 0.07, 0.06, 0.85))
	draw_rect(Rect2(top + Vector2(1, 1), Vector2(26 * clampf(_work / WRENCH, 0, 1), 2)), Color(0.55, 0.95, 0.45))


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 1.5)
		return
	_dying = true
	_work = 0.0
	queue_redraw()
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 1)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), -2.0, 1.5)
	FX.burst(get_parent(), hit_center(), Color(0.55, 0.95, 0.45), 10, 130.0, 0.35, 1.6)
	FX.debris(get_parent(), hit_center(), 5, 160.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 1.6, 0.3)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_callback(queue_free)
