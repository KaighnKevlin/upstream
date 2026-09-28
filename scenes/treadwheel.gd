extends Node2D
## Treadwheel: a big wooden wheel the prospector walks inside, like a
## medieval crane. Stand in it and walk (either way) and it turns, driving
## the machines in reach over belts like a gravity wheel: power by hand for
## before there's ore to spare, or when the feed runs dry. Stop walking and
## it coasts down. Jump to get out.

const R := 34.0
const SPIN_UP := 0.9             # power gained per second of walking
const COAST := 0.35              # lost per second when not

var level := 0.0                 # 0..1
var _angle := 0.0
var walked := 0.0                # tests: seconds walked in it
var _wheel: Sprite2D


func _ready() -> void:
	z_index = 0                      # (behind the cave backdrop at -1)
	process_physics_priority = 10    # after the player moves, so it can hold them in place
	# sprites first, so ghosts and build-bar icons get them too
	var frame := Sprite2D.new()
	frame.texture = preload("res://assets/sprites/treadwheel_frame.png")
	frame.centered = false
	frame.offset = Vector2(-25, -4)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.show_behind_parent = true
	add_child(frame)
	_wheel = Sprite2D.new()
	_wheel.texture = preload("res://assets/sprites/treadwheel.png")
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wheel.show_behind_parent = true
	add_child(_wheel)
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func power() -> float:
	return level


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var walking := false
	var pl := get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if pl and pl.global_position.distance_to(global_position + Vector2(0, R * 0.4)) < R and absf(pl.velocity.x) > 20.0 and pl.is_on_floor():   # jump to get out
		walking = true
		# the floor turns under your feet: you walk in place
		pl.global_position.x = global_position.x + clampf(pl.global_position.x - global_position.x, -3.0, 3.0)
		_angle += signf(pl.velocity.x) * delta * 2.2
		walked += delta
	if walking:
		level = minf(1.0, level + SPIN_UP * delta)
	else:
		level = maxf(0.0, level - COAST * delta)
		_angle += level * delta * 2.0
	queue_redraw()


func _draw() -> void:
	_wheel.rotation = _angle   # the frame and wheel are sprites (see _ready)
	if level > 0.01:
		draw_arc(Vector2.ZERO, R + 7, -PI * 0.5, -PI * 0.5 + TAU * level, 32, Color(1.0, 0.8, 0.35, 0.8), 2.0)
