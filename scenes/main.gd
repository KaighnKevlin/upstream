extends Node2D

const WorldGen = preload("res://scripts/world_gen.gd")
const TileSetBuilder = preload("res://scripts/tileset_builder.gd")

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
@onready var _build_mode_label: Label = $CanvasLayer/BuildModeLabel
@onready var _dome_zone: Area2D = $DomeZone
@onready var _tilemap: TileMapLayer = $TileMapLayer
@onready var _player: CharacterBody2D = $Player
@onready var _player_hp_fill: Polygon2D = $CanvasLayer/PlayerHpFill


func _ready() -> void:
	# Generate the tilemap world
	_tilemap.tile_set = TileSetBuilder.create_tileset()
	WorldGen.generate(_tilemap)

	# Create boundary walls
	_create_boundaries()

	# Setup game state
	dome_hp = dome_max_hp
	_game_over_label.visible = false
	_turret.setup(_receiver)
	_receiver.ammo_changed.connect(_on_ammo_changed)
	_dome_zone.body_entered.connect(_on_enemy_reached_dome)
	BuildSystem.build_mode_changed.connect(_on_build_mode_changed)
	_player.hp_changed.connect(_on_player_hp_changed)
	_player.player_died.connect(_on_player_died)
	_update_hp_bar()
	_update_player_hp_bar()
	_ammo_label.text = "Ammo: 0/%d" % _receiver.max_buffer
	_wave_label.text = "Next wave: %ds" % int(wave_interval)
	_build_mode_label.text = ""




func _create_boundaries() -> void:
	var w := WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE   # 800
	var h := WorldGen.WORLD_HEIGHT * WorldGen.TILE_SIZE  # 1280
	var thickness := 20.0

	# Left wall
	_add_wall(Vector2(-thickness / 2, h / 2), Vector2(thickness, h + 200))
	# Right wall
	_add_wall(Vector2(w + thickness / 2, h / 2), Vector2(thickness, h + 200))
	# Floor
	_add_wall(Vector2(w / 2, h + thickness / 2), Vector2(w + 40, thickness))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1  # walls layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


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
		# Spawn off-screen right, on the surface
		var surface_y := (WorldGen.SURFACE_ROWS - 1) * WorldGen.TILE_SIZE - 12
		enemy.global_position = Vector2(WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE + 40 + i * 40, surface_y)
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


func _on_build_mode_changed(build_type: int) -> void:
	_build_mode_label.text = _build_names.get(build_type, "")


func _on_player_hp_changed(_current: int, _max: int) -> void:
	_update_player_hp_bar()


func _on_player_died() -> void:
	_trigger_game_over()


func _update_player_hp_bar() -> void:
	var ratio := float(_player.hp) / float(_player.max_hp)
	var fill_w := 120.0 * ratio
	_player_hp_fill.polygon = PackedVector2Array([
		Vector2(20, 976), Vector2(20 + fill_w, 976),
		Vector2(20 + fill_w, 990), Vector2(20, 990),
	])
	if ratio > 0.5:
		_player_hp_fill.color = Color(0.2, 0.6, 0.9, 1)
	elif ratio > 0.25:
		_player_hp_fill.color = Color(0.9, 0.7, 0.1, 1)
	else:
		_player_hp_fill.color = Color(0.9, 0.2, 0.1, 1)


var _build_names := {
	0: "",
	1: "Building: TRAMPOLINE",
	2: "Building: MINER",
	3: "Building: LASER",
}


func _update_hp_bar() -> void:
	var ratio := float(dome_hp) / float(dome_max_hp)
	var fill_w := 200.0 * ratio
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
