extends Node2D
## Runs the Marble Defence example: a wave of walkers comes in from the
## right wall one every few seconds and walks for the vault at the left.
## Anything that reaches the vault is a leak. Held with three leaks or
## fewer, the wave is beaten. Draws the vault and a tally.

const Enemy = preload("res://scenes/enemy.gd")

@export var wave := 12
@export var every := 2.6
@export var spawn_at := Vector2(1620, 560)
@export var vault_x := 975.0
@export var max_leaks := 3
## the wave, in order, repeating: enemy type names
@export var types: Array = ["SCUTTLER", "SCUTTLER", "SOLDIER"]

var sent := 0
var leaks := 0
var killed := 0
var over := false
var _t := 2.0
var _live: Array = []

signal finished(won: bool)


func _physics_process(delta: float) -> void:
	if over:
		return
	_t -= delta
	if sent < wave and _t <= 0:
		_t = every
		sent += 1
		var e: Node = preload("res://scenes/enemy.tscn").instantiate()
		e.add_to_group("enemies")
		e.setup(Enemy.EnemyType[types[(sent - 1) % types.size()]])
		e.global_position = spawn_at
		e.direction = -1.0
		get_parent().add_child(e)
		_live.append(e)
	for e in _live.duplicate():
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			_live.erase(e)
			killed += 1
			continue
		if e.global_position.x < vault_x:
			_live.erase(e)
			leaks += 1
			e.queue_free()
	if leaks > max_leaks:
		over = true
		finished.emit(false)
	elif sent >= wave and _live.is_empty():
		over = true
		finished.emit(true)
	queue_redraw()


func _draw() -> void:
	# the vault door, at the left
	var v := Vector2(vault_x - global_position.x, spawn_at.y - global_position.y)
	draw_rect(Rect2(v + Vector2(-26, -44), Vector2(22, 60)), Color(0.1, 0.08, 0.07))
	draw_rect(Rect2(v + Vector2(-24, -42), Vector2(18, 56)), Color(0.55, 0.42, 0.25))
	draw_circle(v + Vector2(-15, -14), 5.0, Color(0.85, 0.65, 0.35))
	var font := ThemeDB.fallback_font
	draw_string(font, v + Vector2(-40, -54), "VAULT  leaks %d / %d" % [leaks, max_leaks], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1.0, 0.4, 0.3) if leaks > 0 else Color(0.85, 0.75, 0.55))
	draw_string(font, v + Vector2(-40, -68), "wave %d / %d   down %d" % [sent, wave, killed], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.75, 0.55))
