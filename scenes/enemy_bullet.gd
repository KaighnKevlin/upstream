extends Area2D

var velocity := Vector2.ZERO
var damage := 8
var lifetime := 4.0
var _timer := 0.0

const HIT_RADIUS := 16.0


func _ready() -> void:
	# Purple projectile sprite
	var spr := Sprite2D.new()
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var purple := Color(0.7, 0.2, 0.9)
	var purple_hi := Color(0.9, 0.4, 1.0)
	for y in 6:
		for x in 6:
			if Vector2(x, y).distance_to(Vector2(2.5, 2.5)) < 3:
				img.set_pixel(x, y, purple if (x + y) % 2 == 0 else purple_hi)
	spr.texture = ImageTexture.create_from_image(img)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)


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
			# Damage the dome via main script
			if scene.has_method("_on_enemy_reached_dome"):
				scene.dome_hp = max(0, scene.dome_hp - damage)
				scene._update_hp_bar()
				if scene.dome_hp <= 0:
					scene._trigger_game_over()
			queue_free()
			return
