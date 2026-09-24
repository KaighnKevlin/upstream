extends Area2D

var velocity := Vector2.ZERO
var damage := 8
var lifetime := 4.0
var _timer := 0.0

const HIT_RADIUS := 16.0


func _ready() -> void:
	# Tesla bolt: a cyan spark ball with a glow (from the clockwork caster)
	var spr := Sprite2D.new()
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 7:
			var d := Vector2(x, y).distance_to(Vector2(3, 3))
			if d < 1.5:
				img.set_pixel(x, y, Color(0.8, 0.89, 0.86))
			elif d < 3.2 and (x + y) % 2 == 0:
				img.set_pixel(x, y, Color(0.45, 0.73, 0.76))
	spr.texture = ImageTexture.create_from_image(img)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	var tween := spr.create_tween().set_loops()
	tween.tween_property(spr, "rotation", PI / 2, 0.06)
	var glow := PointLight2D.new()
	glow.texture = preload("res://scripts/light_textures.gd").create_radial_light(64)
	glow.color = Color(0.45, 0.8, 0.9)
	glow.energy = 0.5
	add_child(glow)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	# Check hit against player
	var scene := get_tree().current_scene
	if scene and scene.has_node("Player"):
		var player := scene.get_node("Player") as Node2D
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < HIT_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(damage)
			queue_free()
			return

	# Check hit against dome zone
	if scene and scene.has_node("DomeZone"):
		var dome := scene.get_node("DomeZone") as Node2D
		if global_position.distance_to(dome.global_position) < HIT_RADIUS * 2:
			if scene.has_method("damage_dome"):
				scene.damage_dome(damage)
			queue_free()
			return
