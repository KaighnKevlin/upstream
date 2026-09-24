extends Node2D
## Fused brass bomb dropped by the ornithopter (tools/art/gen_ornithopter.py).
## Falls under gravity; bursts on the dome (damaging it) or on the ground.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const GRAVITY := 520.0

var velocity := Vector2.ZERO
var damage := 6
var _spr: AnimatedSprite2D


func _ready() -> void:
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 14.0)
	var tex := preload("res://assets/sprites/bomb.png")
	for i in 2:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 10, 0, 10, 12)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.offset = Vector2(0, -1)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_spr.play()
	z_index = 3


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	_spr.rotation = lerpf(_spr.rotation, clampf(velocity.x * 0.004, -0.6, 0.6), 0.1)
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	# the dome's glass: roughly an ellipse over the zone (see main.gd _build_dome)
	if dome and absf(global_position.x - dome.global_position.x) < 70 \
			and global_position.y > dome.global_position.y - 45 + absf(global_position.x - dome.global_position.x) * 0.45:
		if scene.has_method("damage_dome"):
			scene.damage_dome(damage)
		_burst()
		return
	var tm := scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position + Vector2(0, 4)))) != -1:
		_burst()
	elif global_position.y > 1400:
		queue_free()


func _burst() -> void:
	FX.burst(get_parent(), global_position, Color(1.0, 0.75, 0.35), 14, 140.0, 0.4, 2.0)
	FX.burst(get_parent(), global_position, Color(0.8, 0.8, 0.78, 0.7), 6, 35.0, 0.9, 3.0, -50.0)
	FX.shake(self, 2.5, 0.15)
	SFX.play(get_tree().current_scene, SFX.sfx_enemy_die())
	queue_free()
