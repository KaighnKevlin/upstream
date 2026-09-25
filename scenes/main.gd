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
## Sandbox: no wave timer at all; waves only come when you press P.
@export var sandbox := true
## Sandbox starts with every element built and running (scripts/sandbox_showcase.gd).
@export var showcase := true

const HUD_BAR_TOP := 668.0
const HUD_BAR_BOTTOM := 680.0
const PixelFont = preload("res://scripts/pixel_font.gd")
const HUD_TEXT := Color(0.93, 0.86, 0.66)       # warm brass-cream
const HUD_TEXT_DIM := Color(0.72, 0.66, 0.52)
const HUD_SHADOW := Color(0.09, 0.07, 0.05, 0.9)

var dome_hp: int
var wave_number: int = 0
var _wave_timer: float = 0.0
var _game_over := false
var _waves_started := false

var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var _dome_sprite: Sprite2D
var _banner: NinePatchRect
var _banner_title: Label
var _banner_sub: Label
var _arrow: Sprite2D
var _arrow_count: Label
var _arrow_t := 0.0
var _game_over_panel: NinePatchRect

const ENEMY_NAMES := ["titan", "scuttler", "soldier", "caster", "ornithopter", "shieldbearer", "magpie"]

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
	if sandbox and showcase:
		preload("res://scripts/sandbox_showcase.gd").build.call_deferred(self)

	# Create boundary walls
	_create_boundaries()

	# Replace dome polygon with pixel sprite
	if has_node("DomeVisual"):
		$DomeVisual.visible = false
	_build_dome()

	# Large light on the dome so surface is always visible
	var LightTextures := preload("res://scripts/light_textures.gd")
	var dome_light := PointLight2D.new()
	dome_light.texture = LightTextures.create_radial_light(256)
	dome_light.texture_scale = 5.0
	dome_light.energy = 0.3  # stacks with the moonlight; see LIGHT BUDGET in tools/art/ROADMAP.md
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
	_ammo_label.text = "Ingots in dome: 0/%d" % _receiver.max_buffer
	_waves_started = not wait_for_first_ingot
	if _waves_started:
		_wave_label.text = "Next wave: %ds" % int(wave_interval)
	else:
		_wave_label.text = "Get an ingot into the dome to begin"
	if sandbox:
		_wave_label.text = "SANDBOX - god tools top right"
		_make_god_label()
	_build_mode_label.text = ""
	_style_hud()
	# the playtest harness passes user args (-- scenario out_dir): no title then
	if OS.get_cmdline_user_args().is_empty():
		_show_title()




func _style_hud() -> void:
	# Brass panels + the pixel font (tools/art/gen_font.py). Font sizes are
	# multiples of 10 so the bitmap font scales by whole pixels.
	var hud := $CanvasLayer
	for spec in [[Vector2(8, 8), Vector2(372, 88)], [Vector2(8, 632), Vector2(508, 80)],
			[Vector2(530, 632), Vector2(742, 80)]]:
		var p := NinePatchRect.new()
		p.texture = preload("res://assets/ui/panel.png")
		p.patch_margin_left = 8
		p.patch_margin_top = 8
		p.patch_margin_right = 8
		p.patch_margin_bottom = 8
		p.position = spec[0]
		p.size = spec[1]
		hud.add_child(p)
		hud.move_child(p, 0)
	var layout := {
		"AmmoLabel": [Vector2(24, 18), 20, HUD_TEXT],
		"WaveLabel": [Vector2(24, 42), 20, HUD_TEXT],
		"BuildModeLabel": [Vector2(24, 66), 20, Color(0.55, 0.88, 0.9)],
		"PlayerHpLabel": [Vector2(20, 642), 20, HUD_TEXT],
		"DomeHpLabel": [Vector2(300, 642), 20, HUD_TEXT],
		"BuildLabel": [Vector2(552, 686), 16, HUD_TEXT_DIM],
		"Title": [Vector2(1060, 14), 20, HUD_TEXT_DIM],
		"GameOverLabel": [Vector2(390, 250), 30, Color(0.95, 0.45, 0.3)],
	}
	for n in layout:
		var l := hud.get_node(n) as Label
		var spec: Array = layout[n]
		l.position = spec[0]
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # no bleed between atlas cells
		l.add_theme_font_override("font", PixelFont.get_font())
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		l.add_theme_color_override("font_shadow_color", HUD_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	($CanvasLayer/DomeHpLabel as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	($CanvasLayer/BuildLabel as Label).text = \
		"RMB remove   Q cancel   J mine   F shoot   E carry/throw   S drop through"
	($CanvasLayer/Title as Label).text = "UPSTREAM"
	var toolbar := preload("res://scripts/build_bar.gd").new()
	toolbar.font = PixelFont.get_font()
	toolbar.position = Vector2(552, 620)   # tabs ride on the panel's top edge
	hud.add_child(toolbar)
	# HP bars: brass rim, dark well, fill on top
	for bar in [["PlayerHp", 20.0, 140.0], ["DomeHp", 300.0, 500.0]]:
		var bg := hud.get_node(bar[0] + "Bg") as Polygon2D
		bg.polygon = _rect_poly(bar[1] - 1, HUD_BAR_TOP - 1, bar[2] + 1, HUD_BAR_BOTTOM + 1)
		bg.color = Color(0.1, 0.09, 0.07)
		var rim := Polygon2D.new()
		rim.polygon = _rect_poly(bar[1] - 3, HUD_BAR_TOP - 3, bar[2] + 3, HUD_BAR_BOTTOM + 3)
		rim.color = Color(0.66, 0.56, 0.4)
		hud.add_child(rim)
		hud.move_child(rim, bg.get_index())
	_update_hp_bar()
	_update_player_hp_bar()
	_build_banner_and_markers()


## Title card over the paused, dimmed world: brass logo, subtitle, prompt.
## Any key or click fades it out and starts the game.
func _show_title() -> void:
	get_tree().paused = true
	$CanvasLayer.visible = false
	# frame the skyline with the dome at the bottom; restored on start, and
	# camera smoothing glides it back down to the prospector
	var cam := _player.get_node("Camera2D") as Camera2D
	_title_cam_zoom = cam.zoom
	cam.top_level = true
	cam.global_position = Vector2(1200, -40)
	cam.zoom = Vector2(2, 2)
	cam.reset_smoothing()
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/ui/logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	var sz := logo.texture.get_size() * 4.0
	logo.size = sz
	logo.position = Vector2((1280 - sz.x) / 2.0, 150)
	root.add_child(logo)
	var sub := _hud_label("A CLOCKWORK MINING DEFENCE", 20, Color(0.85, 0.75, 0.55))
	sub.size = Vector2(1280, 30)
	sub.position = Vector2(0, 150 + sz.y + 18)
	root.add_child(sub)
	var prompt := _hud_label("press any key", 30, Color(0.55, 0.88, 0.92))
	prompt.size = Vector2(1280, 40)
	prompt.position = Vector2(0, 405)
	root.add_child(prompt)
	var blink := prompt.create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", 0.25, 0.6)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.6)
	# logo drops in
	logo.position.y -= 40
	logo.modulate.a = 0.0
	var t := logo.create_tween().set_parallel()
	t.tween_property(logo, "position:y", logo.position.y + 40, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(logo, "modulate:a", 1.0, 0.35)
	_title = root
	# the world is paused, so input goes through the title's own control
	root.focus_mode = Control.FOCUS_ALL
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_title_input)
	root.grab_focus.call_deferred()


var _title: Control
var _title_cam_zoom := Vector2.ONE


func _on_title_input(event: InputEvent) -> void:
	if _title == null or not is_instance_valid(_title):
		return
	var go: bool = (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not go:
		return
	_title.accept_event()
	var title := _title
	_title = null
	var t := title.create_tween()
	t.tween_property(title, "modulate:a", 0.0, 0.35)
	t.tween_callback(func():
		title.get_parent().queue_free()
		$CanvasLayer.visible = true
		var cam := _player.get_node("Camera2D") as Camera2D
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.zoom = _title_cam_zoom
		get_tree().paused = false)


func _hud_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", HUD_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _brass_panel(pos: Vector2, size: Vector2) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = preload("res://assets/ui/panel.png")
	p.patch_margin_left = 8
	p.patch_margin_top = 8
	p.patch_margin_right = 8
	p.patch_margin_bottom = 8
	p.position = pos
	p.size = size
	return p


func _build_banner_and_markers() -> void:
	var hud := $CanvasLayer
	# wave banner: a brass plate that drops in from the top
	_banner = _brass_panel(Vector2(390, -120), Vector2(500, 96))
	hud.add_child(_banner)
	_banner_title = _hud_label("", 40, HUD_TEXT)
	_banner_title.position = Vector2(0, 12)
	_banner_title.size = Vector2(500, 44)
	_banner.add_child(_banner_title)
	_banner_sub = _hud_label("", 20, Color(0.55, 0.88, 0.9))
	_banner_sub.position = Vector2(0, 58)
	_banner_sub.size = Vector2(500, 24)
	_banner.add_child(_banner_sub)
	# off-screen enemy marker on the right edge
	_arrow = Sprite2D.new()
	_arrow.texture = preload("res://assets/ui/arrow.png")
	_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow.scale = Vector2(2, 2)
	_arrow.visible = false
	hud.add_child(_arrow)
	_arrow_count = _hud_label("", 20, HUD_TEXT)
	_arrow_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow_count.size = Vector2(60, 24)
	_arrow_count.visible = false
	hud.add_child(_arrow_count)
	# game-over plate, shown behind the game-over text
	_game_over_panel = _brass_panel(Vector2(370, 236), Vector2(540, 150))
	_game_over_panel.visible = false
	hud.add_child(_game_over_panel)
	hud.move_child(_game_over_panel, _game_over_label.get_index())
	_game_over_label.size = Vector2(540, 150)
	_game_over_label.position = Vector2(370, 236)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	var tween := create_tween()
	tween.tween_property(_banner, "position:y", 96.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8)
	tween.tween_property(_banner, "position:y", -120.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	if sandbox:
		_god_pour(delta)
	_update_offscreen_marker(delta)


func _update_offscreen_marker(delta: float) -> void:
	# Pulsing arrow on the right edge while enemies are out of view there
	var cam := get_viewport().get_camera_2d()
	if cam == null or _arrow == null:
		return
	var view := get_viewport().get_visible_rect().size
	var right := cam.get_screen_center_position().x + view.x / 2.0 / cam.zoom.x
	var count := 0
	var nearest: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.x > right - 8:
			count += 1
			if nearest == null or e.global_position.x < nearest.global_position.x:
				nearest = e
	_arrow.visible = count > 0 and not _game_over
	_arrow_count.visible = _arrow.visible
	if not _arrow.visible:
		return
	_arrow_t += delta
	var sy: float = (get_viewport().get_canvas_transform() * (nearest.global_position + Vector2(0, -20))).y
	sy = clampf(sy, 120.0, 610.0)
	_arrow.position = Vector2(view.x - 26 + sin(_arrow_t * 8.0) * 4.0, sy)
	_arrow_count.text = "x%d" % count
	_arrow_count.position = Vector2(view.x - 110, sy - 12)


func _rect_poly(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _build_dome() -> void:
	# Brass-and-glass observatory (tools/art/gen_dome.py): translucent glass,
	# brass ribs, riveted plinth with the intake grate over the shaft. The
	# cannon on the crown is the Turret, moved up there.
	var root := Node2D.new()
	root.name = "DomeArt"
	root.position = Vector2(1200, 96)  # centre of the dome on the ground
	add_child(root)
	for spec in [["dome_glass", Vector2(0, -34), 0.45], ["dome_ribs", Vector2(0, -34), 1.0],
			["dome_base", Vector2(0, -4), 1.0]]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % spec[0])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = spec[1]
		s.modulate.a = spec[2]
		root.add_child(s)
	_dome_sprite = root.get_child(1)  # the ribs flash when the dome is hit
	_turret.position = Vector2(1200, 36)
	_turret.z_index = 1
	# The dome no longer shoots: defence comes from placed funnel turrets.
	_turret.visible = false
	_turret.process_mode = Node.PROCESS_MODE_DISABLED


func _setup_terrain_visuals() -> void:
	# Back wall behind the terrain, so tunnels show rock rather than a void
	# pixel art: sample the terrain nearest-neighbour (the default is linear,
	# which blurred every tile and smeared the 1px edge outlines)
	_tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var wall := TileMapLayer.new()
	wall.name = "BackWall"
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.modulate = Color(0.36, 0.35, 0.42)   # darker and cooler: reads as "behind"
	wall.tile_set = TileSetBuilder.create_tileset(true)
	WorldGen.generate_back_wall(wall)
	add_child(wall)
	move_child(wall, _tilemap.get_index())

	# Edge shading + grass tufts on top of the terrain
	var shading := preload("res://scripts/tile_shading.gd").new()
	shading.name = "TileShading"
	shading.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shading)
	move_child(shading, _tilemap.get_index() + 1)
	shading.setup(_tilemap, WorldGen.WORLD_WIDTH, WorldGen.WORLD_HEIGHT)

	# Crystals, stalactites, roots etc. in the natural caves
	var decor := preload("res://scripts/cave_decor.gd").new()
	decor.name = "CaveDecor"
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(decor)
	move_child(decor, shading.get_index() + 1)
	decor.setup(_tilemap)

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
	moon.energy = 0.5
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
	if _game_over or not _waves_started or sandbox:
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
	var kinds := {}
	for i in count:
		var t := i if i < 4 else i % 4
		kinds[t] = kinds.get(t, 0) + 1
	# fliers join from wave 3: one, then one more every other wave
	var fliers := maxi(0, (wave_number - 1) / 2)
	if fliers > 0:
		kinds[4] = fliers
	var magpies := wave_number / 2   # ore thieves join from wave 2
	if magpies > 0:
		kinds[6] = magpies
	var bearers := (wave_number + 1) / 3   # shieldbearers from wave 2, one more every third wave
	if bearers > 0:
		kinds[5] = bearers
	var parts := []
	for t in kinds:
		parts.append("%d %s%s" % [kinds[t], ENEMY_NAMES[t], "s" if kinds[t] > 1 else ""])
	_show_banner("WAVE %d" % wave_number, "  ".join(parts))

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
			2: type = 2  # SOLDIER
			3: type = 3  # CASTER
			_: type = i % 4

		enemy.setup(type)
		enemy.global_position = Vector2(spawn_x - i * 20, surface_y)
		enemy.direction = -1.0
		add_child(enemy)

	for k in bearers:
		var sb := _enemy_scene.instantiate()
		sb.add_to_group("enemies")
		sb.setup(5)  # SHIELDBEARER
		sb.global_position = Vector2(spawn_x - (count + k) * 20, surface_y)
		sb.direction = -1.0
		add_child(sb)

	for k in magpies:
		var mp: Node2D = preload("res://scenes/magpie.tscn").instantiate()
		mp.global_position = Vector2(spawn_x + 20 + k * 60, -120 - k * 20)
		add_child(mp)

	for k in fliers:
		var flier := _enemy_scene.instantiate()
		flier.add_to_group("enemies")
		flier.setup(4)  # ORNITHOPTER
		flier.global_position = Vector2(spawn_x + 40 + k * 70, -40)
		flier.direction = -1.0
		add_child(flier)


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
	_ammo_label.text = "Ingots in dome: %d/%d" % [current, max_ammo]
	if not _waves_started and current > 0:
		_waves_started = true
		_wave_timer = 0.0


func _on_build_mode_changed(build_type: int) -> void:
	_build_mode_label.text = _build_names.get(build_type, "")


func _on_player_hp_changed(_current: int, _max: int) -> void:
	_update_player_hp_bar()


func _on_player_died() -> void:
	_trigger_game_over("PROSPECTOR DOWN")


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
	1: "Build: TRAMPOLINE",
	2: "Build: TAPPER (on dug-out ore)",
	3: "Build: LASER",
	4: "Build: UPSTREAM LIFT",
	5: "Build: HOPPER (click: move plate)",
	6: "Build: TURRET (fill its funnel)",
	7: "Build: SPIKES",
	8: "Build: CATAPULT (click to aim)",
	9: "Build: CHUTE (drag top to end)",
	10: "Build: SPLITTER (click: mode)",
	11: "Build: BUMPER",
	12: "Build: BELT (drag start to end)",
	13: "Build: BELLOWS (click to aim)",
	14: "Build: PENDULUM (pivot; ore swings it)",
	15: "Build: GRAVITY WHEEL (powers belts, fans)",
	16: "Build: ASSEMBLER (click: recipe)",
	17: "Build: LAB (flasks -> research)",
	18: "Build: TESLA COIL (feed it ingots)",
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


func _trigger_game_over(reason := "DOME DESTROYED") -> void:
	if _game_over:
		return
	_game_over = true
	_game_over_label.visible = true
	if _game_over_panel:
		_game_over_panel.visible = true
	_game_over_label.text = "%s\nWaves survived: %d\nPress R to restart" % [reason, maxi(0, wave_number - 1)]


# ── sandbox god tools ──────────────────────────────────────────────────
# G spawns the chosen enemy at the cursor (H picks which), O drops ore at
# the cursor (hold it to pour), K clears every enemy off the map.

const SandboxSave = preload("res://scripts/sandbox_save.gd")
var _god_type := 0
var _god_label: Label


func _make_god_label() -> void:
	_god_label = Label.new()
	_god_label.add_theme_font_override("font", PixelFont.get_font())
	_god_label.add_theme_font_size_override("font_size", 16)
	_god_label.add_theme_color_override("font_color", HUD_TEXT_DIM)
	_god_label.add_theme_color_override("font_shadow_color", HUD_SHADOW)
	_god_label.add_theme_constant_override("shadow_offset_x", 2)
	_god_label.add_theme_constant_override("shadow_offset_y", 2)
	_god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_god_label.position = Vector2(770, 40)
	_god_label.size = Vector2(490, 60)
	$CanvasLayer.add_child(_god_label)
	_update_god_label()


func _update_god_label() -> void:
	if _god_label:
		_god_label.text = "P wave   G spawn %s   H change\nO pour ore   K clear enemies\nF5 save layout   F9 load" % ENEMY_NAMES[_god_type].to_upper()


var _pour_t := 0.0
const POUR_EVERY := 0.07


func _drop_ore(at: Vector2) -> void:
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.global_position = at + Vector2(randf_range(-3, 3), 0)
	add_child(o)


func _god_pour(delta: float) -> void:
	if not Input.is_key_pressed(KEY_O) or _game_over:
		return
	_pour_t += delta
	if _pour_t >= POUR_EVERY:
		_pour_t = 0.0
		_drop_ore(get_global_mouse_position())


func _god_key(event: InputEventKey) -> void:
	var at := get_global_mouse_position()
	match event.keycode:
		KEY_O:
			if not event.echo:
				_drop_ore(at)
				_pour_t = -0.25  # holding: a short pause, then a steady pour (_process)
		KEY_G:
			if event.echo:
				return
			if ENEMY_NAMES[_god_type] == "magpie":
				var mp: Node2D = preload("res://scenes/magpie.tscn").instantiate()
				mp.global_position = at
				add_child(mp)
				return
			var e := _enemy_scene.instantiate()
			e.add_to_group("enemies")
			e.setup(_god_type)
			e.global_position = at
			e.direction = -1.0 if at.x > 1200 else 1.0  # toward the dome
			add_child(e)
		KEY_H:
			if not event.echo:
				_god_type = (_god_type + 1) % ENEMY_NAMES.size()
				_update_god_label()
		KEY_F5:
			if not event.echo:
				var n: int = SandboxSave.save(self)
				_show_banner("SAVED" if n >= 0 else "SAVE FAILED", "%d pieces and the terrain  -  F9 loads it" % n if n >= 0 else "")
		KEY_F9:
			if not event.echo:
				if not SandboxSave.has_save():
					_show_banner("NO SAVE YET", "F5 saves this layout")
				else:
					var n: int = await SandboxSave.load_into(self)
					_show_banner("LOADED", "%d pieces" % n)
		KEY_K:
			if not event.echo:
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.has_method("take_damage"):
						e.take_damage(999)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if _game_over and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		# Cheat: P to force spawn next wave
		if not _game_over and event.keycode == KEY_P:
			_waves_started = true
			_wave_timer = 0.0
			_spawn_wave()
		if sandbox and not _game_over:
			_god_key(event)
		# Cheat: L to toggle lighting (see underground)
		if event.keycode == KEY_L:
			if _canvas_mod.color.r < 0.5:
				_canvas_mod.color = Color(1, 1, 1, 1)  # full bright
			else:
				_canvas_mod.color = Color(0.08, 0.08, 0.12, 1)  # dark
