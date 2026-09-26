extends Node2D
## Vault sentinel: the guardian of a buried ruin (scripts/ruins.gd). A
## clockwork eye hanging from the vault's ceiling, shuttered and dormant
## (turrets ignore it) until the prospector comes within WAKE; then the
## iris opens and it fires bursts of bolts at them. It sleeps again if they
## leave. Destroy it and the vault's relic chest unseals.
## Art: tools/art/gen_sentinel.py (4 frames of 44x36: dormant, waking,
## awake x2; mount point at the top centre).

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const MAX_HP := 34
const WAKE := 230.0
const SLEEP := 420.0
const BURST := 3
const BURST_GAP := 0.16
const BURST_EVERY := 2.2
const BOLT_SPEED := 230.0
const LENS := Vector2(0, 17)
const MUZZLE := Vector2(0, 29)

var hp := MAX_HP
var damage := 0
var buried := true                # dormant: turrets leave it be
var awake := false
var vault: Node = null            # the relic chest it guards
var _dying := false
var _burst_t := 1.0
var _left := 0
var _gap := 0.0
var _spr: AnimatedSprite2D
var _eye: PointLight2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ruins")
	z_index = 2
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := preload("res://assets/sprites/sentinel.png")
	for spec in [["dormant", [0]], ["waking", [1]], ["awake", [2, 3]]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], 6.0)
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 44, 0, 44, 36)
			sf.add_frame(spec[0], a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-22, 0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("dormant")
	add_child(_spr)
	_eye = PointLight2D.new()
	_eye.texture = LightTextures.create_radial_light(64)
	_eye.color = Color(1.0, 0.3, 0.2)
	_eye.energy = 0.0
	_eye.position = LENS
	add_child(_eye)


func hit_center() -> Vector2:
	return global_position + LENS


func hit_radius() -> float:
	return 12.0


func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") as Node2D


func _physics_process(delta: float) -> void:
	if _dying:
		return
	var p := _player()
	var d := p.global_position.distance_to(hit_center()) if p else INF
	if not awake and d < WAKE:
		_wake()
	elif awake and d > SLEEP:
		_sleep()
	if not awake or p == null:
		return
	_eye.energy = 0.7 + 0.2 * sin(Time.get_ticks_msec() * 0.01)
	if _left > 0:
		_gap -= delta
		if _gap <= 0:
			_gap = BURST_GAP
			_left -= 1
			_fire(p)
		return
	_burst_t -= delta
	if _burst_t <= 0:
		_burst_t = BURST_EVERY
		_left = BURST


func _wake() -> void:
	awake = true
	buried = false
	_spr.play("waking")
	SFX.play(self, SFX.sfx_clink(), -2.0, 0.5)
	SFX.play_small(self, SFX.sfx_laser(), -8.0, 0.6)
	_burst_t = 0.9
	get_tree().create_timer(0.35).timeout.connect(func(): if awake and not _dying: _spr.play("awake"))
	var scene := get_tree().current_scene
	if scene.has_method("_show_banner"):
		scene._show_banner("THE SENTINEL WAKES", "destroy it to open the vault")


func _sleep() -> void:
	awake = false
	buried = true
	_left = 0
	_spr.play("dormant")
	_eye.energy = 0.0


func _fire(p: Node2D) -> void:
	var from := global_position + MUZZLE
	var aim := (p.global_position + Vector2(0, -12) - from).normalized()
	var b: Area2D = preload("res://scenes/enemy_bullet.tscn").instantiate()
	b.global_position = from
	b.velocity = aim.rotated(randf_range(-0.06, 0.06)) * BOLT_SPEED
	b.damage = 5
	get_parent().add_child(b)
	SFX.play_small(self, SFX.sfx_laser(), -10.0, 1.3)
	FX.burst(get_parent(), from, Color(1.0, 0.5, 0.35), 3, 50.0, 0.15, 1.1)


func take_damage(amount: int) -> void:
	if _dying:
		return
	if not awake:
		_wake()
	hp -= amount
	FX.damage_number(get_parent(), hit_center(), amount, self)
	_spr.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.12)
	if hp > 0:
		SFX.play(self, SFX.sfx_enemy_hit(), -4.0, 0.7)
		return
	_dying = true
	remove_from_group("enemies")
	_eye.energy = 0.0
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die(), 0.0, 0.5)
	FX.burst(get_parent(), hit_center(), Color(1.0, 0.7, 0.3), 24, 180.0, 0.5, 2.4)
	FX.debris(get_parent(), hit_center(), 12, 200.0, false)
	FX.shake(self, 5.0, 0.3)
	preload("res://scenes/ore.gd").spill(get_parent(), hit_center(), 4)
	if vault and is_instance_valid(vault) and vault.has_method("unseal"):
		vault.unseal()
	# the housing drops off its mount and smashes on the floor
	var tw := create_tween()
	tw.tween_property(_spr, "position:y", 60.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_spr, "rotation", 0.6, 0.45)
	tw.tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
