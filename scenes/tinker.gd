extends CharacterBody2D
## Clockwork tinker: the wave's repair crew. A squat round automaton with a
## toolbox on its back and a welding torch. It walks with the pack, and
## every couple of seconds it stops to weld the most damaged enemy nearby
## back together (a crackling blue arc, a few HP at a time, never past
## full). Fragile: kill it first, or everything else keeps coming back.
## Art: tools/art/gen_tinker.py (8 frames of 36x34: 6 walk, 2 weld).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const SPEED := 30.0
const GRAVITY := 980.0
const MAX_HP := 6
const REACH := 95.0
const WELD_EVERY := 2.0
const WELD_HP := 3
const TORCH := Vector2(13, -17)

var hp := MAX_HP
var damage := 5
var direction := -1.0
var healed := 0                  # tests: HP given back
var _dying := false
var _knock_t := 0.0
var _weld_t := 1.0
var _arc_t := 0.0
var _arc_to := Vector2.ZERO
var _spr: AnimatedSprite2D
var _max_hp := {}                # enemy -> the most HP it has been seen with


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 22)
	cs.shape = r
	cs.position = Vector2(0, -11)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/tinker.png")
	for spec in [["walk", [0, 1, 2, 3, 4, 5], 10.0, true], ["weld", [6, 7], 12.0, true]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[2])
		sf.set_animation_loop(spec[0], spec[3])
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 36, 0, 36, 34)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-16, -33)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	add_child(_spr)
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	if dome and absf(dome.global_position.x - global_position.x) > 1:
		direction = signf(dome.global_position.x - global_position.x)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -16)


func hit_radius() -> float:
	return 10.0


func knock(v: Vector2) -> void:
	if not _dying:
		velocity = v
		_knock_t = 0.4


## Who needs it most: the enemy nearby furthest below the best HP it's had.
func _patient() -> Node:
	var best: Node = null
	var worst := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or ("_dying" in e and e._dying) or not ("hp" in e):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if c.distance_to(hit_center()) > REACH:
			continue
		var full = e.get("max_hp") if e.get("max_hp") != null else e.get("MAX_HP")
		_max_hp[e] = int(full) if full != null else maxi(_max_hp.get(e, e.hp), e.hp)
		var missing: int = _max_hp[e] - e.hp
		if missing > worst:
			worst = missing
			best = e
	return best


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif _knock_t <= 0:
		velocity.y = 0
	if _knock_t > 0:
		_knock_t -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
		move_and_slide()
		return
	_weld_t -= delta
	_arc_t -= delta
	var welding := _arc_t > 0
	if _weld_t <= 0:
		_weld_t = 0.5
		var p := _patient()
		if p:
			_weld_t = WELD_EVERY
			var give := mini(WELD_HP, _max_hp[p] - p.hp)
			p.hp += give
			healed += give
			_arc_to = p.hit_center() if p.has_method("hit_center") else p.global_position
			_arc_t = 0.45
			welding = true
			FX.burst(get_parent(), _arc_to, Color(0.6, 0.85, 1.0), 8, 70.0, 0.3, 1.2)
			SFX.play_small(self, SFX.sfx_laser(), -12.0, 1.6)
	if welding:
		velocity.x = 0
		_spr.play("weld")
	else:
		velocity.x = SPEED * direction
		_spr.play("walk")
		if is_on_wall():
			velocity.y = -26.0
	_spr.flip_h = direction < 0
	_spr.offset.x = -16 if direction > 0 else -20
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	if _arc_t <= 0:
		return
	var a := Vector2(TORCH.x * direction, TORCH.y)
	var b := to_local(_arc_to)
	var pts := PackedVector2Array([a])
	var n := (b - a).orthogonal().normalized()
	for k in range(1, 6):
		pts.append(a.lerp(b, k / 6.0) + n * randf_range(-3, 3))
	pts.append(b)
	var al := clampf(_arc_t / 0.45, 0.0, 1.0)
	draw_polyline(pts, Color(0.4, 0.7, 1.0, 0.4 * al), 4.0)
	draw_polyline(pts, Color(0.85, 0.95, 1.0, al), 1.2)


func take_damage(amount: int) -> void:
	if _dying:
		return
	hp -= amount
	preload("res://scripts/fx.gd").damage_number(get_parent(), hit_center() if has_method("hit_center") else global_position, amount, self)
	FX.burst(get_parent(), hit_center(), Color(0.85, 0.72, 0.45), 5, 80.0, 0.3, 1.5)
	_spr.modulate = Color(3, 3, 3)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit())
		return
	_dying = true
	remove_from_group("enemies")
	collision_layer = 0
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 2)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	FX.burst(get_parent(), hit_center(), Color(0.6, 0.85, 1.0), 12, 140.0, 0.4, 2.0)
	FX.debris(get_parent(), hit_center(), 6, 170.0, false)
	var tw := create_tween()
	tw.tween_property(_spr, "rotation", -direction * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(queue_free)
