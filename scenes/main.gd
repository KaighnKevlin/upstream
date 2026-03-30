extends Node2D

@export var dome_max_hp: int = 100
@export var wave_interval: float = 30.0
@export var enemies_per_wave_base: int = 3

var dome_hp: int
var wave_number: int = 0
var _wave_timer: float = 0.0
var _game_over := false

var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

@onready var _receiver: Area2D = $Receiver
@onready var _turret: Node2D = $Turret
@onready var _hp_bar_fill: Polygon2D = $CanvasLayer/DomeHpFill
@onready var _ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var _wave_label: Label = $CanvasLayer/WaveLabel
@onready var _game_over_label: Label = $CanvasLayer/GameOverLabel
@onready var _dome_zone: Area2D = $DomeZone


func _ready() -> void:
	dome_hp = dome_max_hp
	_game_over_label.visible = false
	_turret.setup(_receiver)
	_receiver.ammo_changed.connect(_on_ammo_changed)
	_dome_zone.body_entered.connect(_on_enemy_reached_dome)
	_update_hp_bar()
	_ammo_label.text = "Ammo: 0/%d" % _receiver.max_buffer
	_wave_label.text = "Next wave: %ds" % int(wave_interval)


func _physics_process(delta: float) -> void:
	if _game_over:
		return

	_wave_timer += delta
	var time_left := wave_interval - _wave_timer
	_wave_label.text = "Next wave: %ds" % max(0, int(time_left))

	if _wave_timer >= wave_interval:
		_wave_timer = 0.0
		_spawn_wave()


func _spawn_wave() -> void:
	wave_number += 1
	var count := enemies_per_wave_base + wave_number
	_wave_label.text = "WAVE %d!" % wave_number

	for i in count:
		var enemy := _enemy_scene.instantiate()
		enemy.add_to_group("enemies")
		# Spawn off-screen right, staggered
		enemy.global_position = Vector2(820 + i * 40, 43)
		enemy.direction = -1.0
		add_child(enemy)


func _on_enemy_reached_dome(body: Node2D) -> void:
	if body.is_in_group("enemies") and not _game_over:
		var dmg: int = body.damage if "damage" in body else 10
		dome_hp = max(0, dome_hp - dmg)
		_update_hp_bar()
		body.queue_free()
		if dome_hp <= 0:
			_trigger_game_over()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_label.text = "Ammo: %d/%d" % [current, max_ammo]


func _update_hp_bar() -> void:
	var ratio := float(dome_hp) / float(dome_max_hp)
	var fill_w := 200.0 * ratio  # full bar = 200px (300 to 500)
	_hp_bar_fill.polygon = PackedVector2Array([
		Vector2(300, 976), Vector2(300 + fill_w, 976),
		Vector2(300 + fill_w, 990), Vector2(300, 990),
	])
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.8, 0.3, 1)
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.9, 0.7, 0.1, 1)
	else:
		_hp_bar_fill.color = Color(0.9, 0.2, 0.1, 1)


func _trigger_game_over() -> void:
	_game_over = true
	_game_over_label.visible = true
	_game_over_label.text = "DOME DESTROYED\nWaves survived: %d\nPress R to restart" % (wave_number - 1)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
