extends Node2D
## The Magma Wyrm: a mini-boss of the depths. A long segmented clockwork
## worm that sleeps in a hot chamber's magma pool. When the prospector
## comes within WAKE it bursts out and hunts them, burrowing through rock as
## easily as air (dust and sparks where it passes through stone), its body
## snaking after its head. Every segment burns on contact. Its head is the
## weak point: shots, turrets and blasts hurt it there. If the prospector
## gets far enough away it slides back into its pool. When it dies it comes
## apart ring by ring and leaves a relic: salvage and a free research level.
## Placed by scripts/depths.gd (one per world, in a chamber with a pool).
## Art: tools/art/gen_wyrm.py (head, body ring, tail; 28x28, facing +x).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

enum State { SLEEP, HUNT, RETURN, DEAD }

const SEGMENTS := 12
const GAP := 13.0
const SPEED := 120.0
const TURN := 2.6                # rad/s the head can turn
const WAKE := 230.0
const GIVE_UP := 720.0
const MAX_HP := 70
const BURN := 6

var hp := MAX_HP
var damage := BURN
var velocity := Vector2.ZERO     # turrets lead on this
var buried := true               # asleep in its pool
var bites := 0                   # tests
var _dying := false
var _state := State.SLEEP
var _home := Vector2.ZERO
var _dir := Vector2.UP
var _segs: Array[Vector2] = []
var _sprs: Array[Sprite2D] = []
var _bite_t := 0.0
var _dust := 0.0
var _bar: CanvasLayer
var _fill: ColorRect


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("wyrms")
	z_index = 3
	_home = global_position
	var tex := preload("res://assets/sprites/wyrm.png")
	for i in SEGMENTS:
		_segs.append(_home + Vector2(0, 4))
		var s := Sprite2D.new()
		var a := AtlasTexture.new()
		a.atlas = tex
		var frame := 0 if i == 0 else (2 if i == SEGMENTS - 1 else 1)
		a.region = Rect2(frame * 28, 0, 28, 28)
		s.texture = a
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.top_level = true
		s.z_index = 3 + (SEGMENTS - i) / 4
		s.visible = false
		add_child(s)
		_sprs.append(s)
	var glow := PointLight2D.new()
	glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(64)
	glow.color = Color(1.0, 0.5, 0.2)
	glow.energy = 0.9
	glow.texture_scale = 1.5
	add_child(glow)


func hit_center() -> Vector2:
	return global_position


func hit_radius() -> float:
	return 12.0


func knock(v: Vector2) -> void:
	if not _dying and _state == State.HUNT:
		_dir = (_dir + v.normalized() * 0.8).normalized()


func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") as Node2D


func _process(delta: float) -> void:
	if _dying:
		return
	var p := _player()
	match _state:
		State.SLEEP:
			if p and p.global_position.distance_to(_home) < WAKE:
				_wake()
			return
		State.HUNT:
			if p == null or p.global_position.distance_to(global_position) > GIVE_UP:
				_state = State.RETURN
			else:
				_steer(p.global_position + Vector2(0, -10), delta)
		State.RETURN:
			_steer(_home + Vector2(0, 10), delta)
			if global_position.distance_to(_home) < 14.0:
				_sleep()
				return
	global_position += _dir * SPEED * delta
	velocity = _dir * SPEED
	_follow()
	_bite(p, delta)
	_burrow_fx(delta)


func _wake() -> void:
	_state = State.HUNT
	buried = false
	_dir = Vector2.UP
	for s in _sprs:
		s.visible = true
	FX.burst(get_parent(), _home, Color(1.0, 0.55, 0.15), 30, 220.0, 0.5, 2.6)
	FX.shake(self, 8.0, 0.5)
	SFX.play(get_tree().current_scene, SFX.sfx_mine_break(), 2.0, 0.4)
	_make_bar()
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner"):
		scene._show_banner("A MAGMA WYRM STIRS", "its head is the weak spot")


func _sleep() -> void:
	_state = State.SLEEP
	buried = true
	global_position = _home
	for i in SEGMENTS:
		_segs[i] = _home + Vector2(0, 4)
		_sprs[i].visible = false
	FX.burst(get_parent(), _home, Color(1.0, 0.55, 0.15), 14, 120.0, 0.4, 2.0)
	if _bar:
		_bar.queue_free()
		_bar = null


## Turn toward a point, but only so fast: it swings wide and loops.
func _steer(to: Vector2, delta: float) -> void:
	var want := (to - global_position).normalized()
	var a := _dir.angle_to(want)
	_dir = _dir.rotated(clampf(a, -TURN * delta, TURN * delta))


## Each ring follows the one before it at GAP.
func _follow() -> void:
	_segs[0] = global_position
	for i in range(1, SEGMENTS):
		var d := _segs[i] - _segs[i - 1]
		if d.length() > GAP:
			_segs[i] = _segs[i - 1] + d.normalized() * GAP
	for i in SEGMENTS:
		var s := _sprs[i]
		s.global_position = _segs[i]
		var ahead: Vector2 = _dir if i == 0 else (_segs[i - 1] - _segs[i])
		if ahead.length() > 0.01:
			s.rotation = ahead.angle()


func _bite(p: Node2D, delta: float) -> void:
	_bite_t -= delta
	if p == null or _bite_t > 0:
		return
	for i in SEGMENTS:
		if _segs[i].distance_to(p.global_position + Vector2(0, -10)) < (14.0 if i == 0 else 11.0):
			_bite_t = 1.3
			bites += 1
			if p.has_method("take_damage"):
				p.take_damage(BURN)
			if p.has_method("launch"):
				p.launch((p.global_position - _segs[i]).normalized() * 280.0 + Vector2(0, -180))
			FX.burst(get_parent(), p.global_position, Color(1.0, 0.5, 0.15), 8, 90.0, 0.3, 1.6)
			return


## Dust and sparks wherever it bores through stone.
func _burrow_fx(delta: float) -> void:
	_dust -= delta
	if _dust > 0:
		return
	_dust = 0.08
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position))) != -1:
		FX.burst(get_parent(), global_position, Color(0.55, 0.45, 0.38), 3, 60.0, 0.35, 1.6)
		if randf() < 0.3:
			FX.burst(get_parent(), global_position, Color(1.0, 0.6, 0.2), 2, 80.0, 0.2, 1.0)
			SFX.play_small(self, SFX.sfx_mine_hit(), -16.0, 0.6)


func _make_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	var root := Control.new()
	root.position = Vector2(440, 100)
	_bar.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.85)
	bg.size = Vector2(400, 26)
	root.add_child(bg)
	_fill = ColorRect.new()
	_fill.color = Color(1.0, 0.45, 0.15)
	_fill.position = Vector2(5, 17)
	_fill.size = Vector2(390.0 * float(hp) / MAX_HP, 5)
	root.add_child(_fill)
	var l := Label.new()
	l.text = "THE MAGMA WYRM"
	l.add_theme_font_override("font", preload("res://scripts/pixel_font.gd").get_font())
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	l.position = Vector2(0, 1)
	l.size = Vector2(400, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	add_child(_bar)


func take_damage(amount: int) -> void:
	if _dying:
		return
	if _state == State.SLEEP:
		_wake()
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_sprs[0].modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprs[0], "modulate", Color.WHITE, 0.12)
	if _fill:
		_fill.size.x = 390.0 * maxf(0.0, float(hp) / MAX_HP)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -2.0, 0.6)
		return
	_die()


func _die() -> void:
	_dying = true
	_state = State.DEAD
	remove_from_group("enemies")
	if _bar:
		_bar.queue_free()
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner"):
		scene._show_banner("THE MAGMA WYRM FALLS", "it leaves a relic")
	# ring by ring, head to tail, it bursts apart
	var tw := create_tween()
	for i in SEGMENTS:
		var k := i
		tw.tween_callback(func():
			var at := _segs[k]
			FX.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 12, 150.0, 0.4, 2.0)
			FX.debris(get_parent(), at, 3, 160.0, false)
			SFX.play_small(self, SFX.sfx_mine_break(), -6.0, 0.6 + k * 0.03)
			_sprs[k].visible = false)
		tw.tween_interval(0.07)
	tw.tween_callback(_relic)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)


## Its relic: a hot pile of salvage and a blueprint (a free research level).
func _relic() -> void:
	var at := global_position
	preload("res://scenes/ore.gd").spill(get_parent(), at, 8)
	for kind in ["flask", "flask", "gear", "spring"]:
		var o: RigidBody2D = load("res://scenes/ore.tscn").instantiate()
		o.kind = kind
		o.lifetime = 90.0
		o.global_position = at + Vector2(randf_range(-6, 6), -6)
		o.linear_velocity = Vector2(randf_range(-140, 140), randf_range(-280, -140))
		get_parent().add_child(o)
	var Tech := preload("res://scripts/tech.gd")
	var open_ones := []
	for t in Tech.TECHS:
		if not Tech.maxed(t.id):
			open_ones.append(t.id)
	if not open_ones.is_empty():
		var id: String = open_ones.pick_random()
		Tech.levels[id] = Tech.level(id) + 1
		var scene := get_tree().current_scene
		if scene.has_method("_show_banner"):
			scene._show_banner("WYRM RELIC", "blueprint: %s (%s)" % [Tech.info(id).name, Tech.info(id).desc])
