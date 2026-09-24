extends Node2D

const WorldGen = preload("res://scripts/world_gen.gd")
const TileSetBuilder = preload("res://scripts/tileset_builder.gd")
const ObjectSprites = preload("res://scripts/object_sprites.gd")
const FX = preload("res://scripts/fx.gd")

@export var dome_max_hp: int = 100
@export var wave_interval: float = 30.0
@export var enemies_per_wave_base: int = 3
## Hold the first wave until the first ingot lands in the receiver, so a new
## player has time to learn miner -> laser -> trampoline before anything attacks.
@export var wait_for_first_ingot: bool = true

const HUD_BAR_TOP := 696.0
const HUD_BAR_BOTTOM := 710.0

var dome_hp: int
var wave_number: int = 0
var _wave_timer: float = 0.0
var _game_over := false
var _waves_started := false

var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var _dome_sprite: Sprite2D

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
@onready var _canvas_mod: CanvasModulate = $CanvasModulate


func _ready() -> void:
	# Generate the tilemap world
	_tilemap.tile_set = TileSetBuilder.create_tileset()
	WorldGen.generate(_tilemap)
	_setup_terrain_visuals()

	# Create boundary walls
	_create_boundaries()

	# Replace dome polygon with pixel sprite
	if has_node("DomeVisual"):
		$DomeVisual.visible = false
	var dome_spr := Sprite2D.new()
	dome_spr.texture = ObjectSprites.create_dome_texture()
	dome_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dome_spr.scale = Vector2(2.5, 1.5)
	dome_spr.global_position = Vector2(1200, 72)
	add_child(dome_spr)
	_dome_sprite = dome_spr

	# Large light on the dome so surface is always visible
	var LightTextures := preload("res://scripts/light_textures.gd")
	var dome_light := PointLight2D.new()
	dome_light.texture = LightTextures.create_radial_light(256)
	dome_light.texture_scale = 5.0
	dome_light.energy = 0.55  # stacks with the moonlight; higher washes sprites out
	dome_light.color = Color(0.9, 0.9, 1.0)
	dome_light.global_position = Vector2(1200, 20)
	dome_light.shadow_enabled = true
	add_child(dome_light)

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
	_waves_started = not wait_for_first_ingot
	if _waves_started:
		_wave_label.text = "Next wave: %ds" % int(wave_interval)
	else:
		_wave_label.text = "Get an ingot into the dome to begin"
	_build_mode_label.text = ""




func _setup_terrain_visuals() -> void:
	# Back wall behind the terrain, so tunnels show rock rather than a void
	var wall := TileMapLayer.new()
	wall.name = "BackWall"
	wall.tile_set = TileSetBuilder.create_tileset(true)
	WorldGen.generate_back_wall(wall)
	add_child(wall)
	move_child(wall, _tilemap.get_index())

	# Edge shading + grass tufts on top of the terrain
	var shading := preload("res://scripts/tile_shading.gd").new()
	shading.name = "TileShading"
	add_child(shading)
	move_child(shading, _tilemap.get_index() + 1)
	shading.setup(_tilemap, WorldGen.WORLD_WIDTH, WorldGen.WORLD_HEIGHT)

	_add_moonlight()


func _add_moonlight() -> void:
	# A world-wide band of cool light: full strength above ground, fading out a
	# few tiles below the grass. Without it, enemies walking in outside the dome
	# light are black silhouettes on a black surface.
	const SCALE := 5.0
	const TOP := -250.0
	const BOTTOM := 250.0
	var surface_y := float(WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE)
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.BLACK)
	grad.set_offset(0, (surface_y - TOP) / (BOTTOM - TOP))
	grad.set_offset(1, (surface_y + 6 * WorldGen.TILE_SIZE - TOP) / (BOTTOM - TOP))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = int((WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE + 400) / SCALE)
	tex.height = int((BOTTOM - TOP) / SCALE)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)

	var moon := PointLight2D.new()
	moon.name = "Moonlight"
	moon.texture = tex
	moon.texture_scale = SCALE
	moon.energy = 0.6
	moon.color = Color(0.7, 0.78, 1.0)
	moon.global_position = Vector2(WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE / 2.0, (TOP + BOTTOM) / 2.0)
	add_child(moon)


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
	if _game_over or not _waves_started:
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

	var surface_y := 40  # spawn above ground, gravity drops them
	var spawn_x := WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE - 30  # just inside right boundary

	for i in count:
		var enemy := _enemy_scene.instantiate()
		enemy.add_to_group("enemies")

		# One of each type, then cycle through them
		var type: int
		match i:
			0: type = 0  # TITAN
			1: type = 1  # SCUTTLER
			2: type = 2  # SKELETON
			3: type = 3  # WIZARD
			_: type = i % 4

		enemy.setup(type)
		enemy.global_position = Vector2(spawn_x - i * 20, surface_y)
		enemy.direction = -1.0
		add_child(enemy)


func _on_enemy_reached_dome(body: Node2D) -> void:
	if body.is_in_group("enemies") and not _game_over:
		var dmg: int = body.damage if "damage" in body else 10
		body.queue_free()
		damage_dome(dmg)


func damage_dome(amount: int) -> void:
	if _game_over:
		return
	dome_hp = max(0, dome_hp - amount)
	_update_hp_bar()
	FX.shake(self, 2.0 + amount * 0.2, 0.3)
	if _dome_sprite:
		FX.flash(_dome_sprite, Color(2.2, 0.6, 0.6), 0.25)
	if dome_hp <= 0:
		_trigger_game_over()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_label.text = "Ammo: %d/%d" % [current, max_ammo]
	if not _waves_started and current > 0:
		_waves_started = true
		_wave_timer = 0.0


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
		Vector2(20, HUD_BAR_TOP), Vector2(20 + fill_w, HUD_BAR_TOP),
		Vector2(20 + fill_w, HUD_BAR_BOTTOM), Vector2(20, HUD_BAR_BOTTOM),
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
	4: "Building: UPSTREAM",
}


func _update_hp_bar() -> void:
	var ratio := float(dome_hp) / float(dome_max_hp)
	var fill_w := 200.0 * ratio
	_hp_bar_fill.polygon = PackedVector2Array([
		Vector2(300, HUD_BAR_TOP), Vector2(300 + fill_w, HUD_BAR_TOP),
		Vector2(300 + fill_w, HUD_BAR_BOTTOM), Vector2(300, HUD_BAR_BOTTOM),
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
	if event is InputEventKey and event.pressed:
		if _game_over and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		# Cheat: P to force spawn next wave
		if not _game_over and event.keycode == KEY_P:
			_waves_started = true
			_wave_timer = 0.0
			_spawn_wave()
		# Cheat: L to toggle lighting (see underground)
		if event.keycode == KEY_L:
			if _canvas_mod.color.r < 0.5:
				_canvas_mod.color = Color(1, 1, 1, 1)  # full bright
			else:
				_canvas_mod.color = Color(0.08, 0.08, 0.12, 1)  # dark
