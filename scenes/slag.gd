extends Node2D
## A gob of molten slag flung by the Foundry Engine. Flies on a ballistic
## arc; splashes where it lands (the ground, the dome, you), burning what's
## close and knocking loose ore about. Glows as it flies.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const GRAVITY := 700.0
const SPLASH := 34.0

var velocity := Vector2.ZERO
var dome_damage := 5
var player_damage := 12
var _trail := 0.0
var _age := 0.0


func _ready() -> void:
	z_index = 4
	var l := PointLight2D.new()
	l.texture = LightTextures.create_radial_light(64)
	l.color = Color(1.0, 0.55, 0.2)
	l.energy = 0.9
	add_child(l)


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation = velocity.angle()
	_trail -= delta
	if _trail <= 0:
		_trail = 0.03
		FX.burst(get_parent(), global_position, Color(1.0, 0.55, 0.15, 0.8), 1, 20.0, 0.35, 1.6, -30.0)
	queue_redraw()
	var scene := get_tree().current_scene
	var dome := scene.get_node_or_null("DomeZone") as Node2D
	if dome and global_position.distance_to(dome.global_position + Vector2(0, -20)) < 60.0 and _age > 0.2:
		_splash(true)
		return
	var p := scene.get_node_or_null("Player") as Node2D
	if p and global_position.distance_to(p.global_position) < 14.0:
		_splash(false)
		return
	var tm := scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if (tm and tm.get_cell_source_id(tm.local_to_map(tm.to_local(global_position))) != -1) or global_position.y > 1400:
		_splash(false)


func _splash(on_dome: bool) -> void:
	var scene := get_tree().current_scene
	var at := global_position
	FX.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 16, 150.0, 0.5, 2.0, 200.0)
	FX.burst(get_parent(), at, Color(0.35, 0.3, 0.3, 0.8), 6, 40.0, 0.9, 3.0, -40.0)
	SFX.play_small(scene, SFX.sfx_ore_knock("ground"), -2.0, 0.5)
	if on_dome and scene.has_method("damage_dome"):
		scene.damage_dome(dome_damage)
	var p := scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(at) < SPLASH and p.has_method("take_damage"):
		p.take_damage(player_damage)
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and o.global_position.distance_to(at) < SPLASH * 1.5 and not o.freeze:
			o.sleeping = false
			o.linear_velocity += (o.global_position - at).normalized() * 180.0 + Vector2(0, -120)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.12, 0.05))
	draw_circle(Vector2(0.5, 0), 3.8, Color(0.9, 0.35, 0.08))
	draw_circle(Vector2(1.2, -0.5), 2.2, Color(1.0, 0.75, 0.3))
	draw_circle(Vector2(1.6, -1.0), 0.9, Color(1.0, 0.95, 0.8))
