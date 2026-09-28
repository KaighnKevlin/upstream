extends Node2D

const WorldGen = preload("res://scripts/world_gen.gd")
const TileSetBuilder = preload("res://scripts/tileset_builder.gd")
const ObjectSprites = preload("res://scripts/object_sprites.gd")
const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

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

const ENEMY_NAMES := ["titan", "scuttler", "soldier", "caster", "ornithopter", "shieldbearer", "magpie", "sapper", "bridger", "mason", "foundry", "airship", "tinker", "dreadnought", "gremlin", "mortar", "grenadier", "colossus", "roller"]

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
	var fog := preload("res://scripts/fog.gd").new()   # fog of war underground
	fog.name = "Fog"
	add_child(fog)
	preload("res://scripts/ruins.gd").build(self, _tilemap)     # a buried vault with a sentinel
	preload("res://scenes/cache.gd").scatter(self, _tilemap)   # salvage caches in the caves
	preload("res://scenes/geyser.gd").scatter(self, _tilemap)  # ore geysers on cave floors
	preload("res://scenes/crawler.gd").scatter(self, _tilemap) # cave crawlers on cave ceilings
	preload("res://scenes/firedamp.gd").scatter(self, _tilemap) # mine gas in the deep caves
	preload("res://scripts/depths.gd").build(self, _tilemap)     # the hot bottom of the world: seams, magma pools
	var bars := preload("res://scripts/health_bars.gd").new()   # bars under wounded enemies
	bars.name = "HealthBars"
	add_child(bars)
	var amb := preload("res://scripts/ambience.gd").new()   # glowmoths and drips in the caves
	amb.name = "Ambience"
	add_child(amb)
	_start_music()
	_prebuild_sounds()
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
	_ammo_label.text = "Ingots in dome: 0/%d  (repair stock)" % _receiver.max_buffer
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
		"F1 manual   Tab/wheel pick   RMB remove   Q cancel   J mine   F shoot   Shift hook"
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


## Title card over the live, lightly dimmed world (attract mode): brass
## logo, subtitle, the two ways in.
## Any key or click fades it out and starts the game.
## Synthesise every sound effect now, one a frame (it happens under the
## title screen), instead of the first time each one plays mid-fight.
func _prebuild_sounds() -> void:
	for b in SFX.all_builders():
		b.call()
		await get_tree().process_frame


func _show_title() -> void:
	# attract mode: the world keeps running behind the title (the sandbox's
	# showcase busy at work) while the camera drifts slowly across it
	$CanvasLayer.visible = false
	# frame the skyline with the dome at the bottom; restored on start, and
	# camera smoothing glides it back down to the prospector
	var cam := _player.get_node("Camera2D") as Camera2D
	_title_cam_zoom = cam.zoom
	cam.top_level = true
	cam.global_position = Vector2(1200, -40)
	cam.zoom = Vector2(2, 2)
	cam.reset_smoothing()
	_title_drift = cam.create_tween().set_loops()
	_title_drift.tween_property(cam, "global_position:x", 1750.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_drift.tween_property(cam, "global_position:x", 950.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.38)
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
	# two ways in: the sandbox (showcase + god tools) or survival (waves)
	for i in 11:
		var spec: Array = [["1  SANDBOX", "a working showcase, god tools, no waves until you ask"],
			["2  SURVIVAL", "a bare world: get an ingot into the dome and the waves begin"],
			["3  MARBLE WORKS", "the Beam and a marble machine, under the dome"],
			["4  COUNTER", "marbles counting in binary on six flip-flops"],
			["5  GALTON", "a bell curve out of pegs and chance"],
			["6  COASTER", "a drop, a loop-the-loop, a jump and a bell"],
			["7  PUZZLE", "build a way for five marbles into the cup"],
			["8  DEFENCE", "marbles feed the turrets: hold the vault"],
			["9  CLATTER", "the busier the machine, the more it draws in"],
			["0  MUSIC BOX", "every marble plays the tune on the way down"],
			["-  PACHINKO", "hold and release the plunger: aim for the 200"]][i]
		# rows of five
		var x := 20.0 + (i % 5) * 250.0
		var y := 378.0 + (i / 5) * 58.0
		var opt := _hud_label(spec[0], 18, Color(0.55, 0.88, 0.92))
		opt.size = Vector2(240, 40)
		opt.position = Vector2(x, y + 5)
		root.add_child(opt)
		var d := _hud_label(spec[1], 10, Color(0.85, 0.75, 0.55))
		d.size = Vector2(240, 20)
		d.position = Vector2(x, y + 36)
		root.add_child(d)
		_title_opts.append(Rect2(Vector2(x, y), Vector2(240, 60)))
		var blink := opt.create_tween().set_loops()
		blink.tween_interval(i * 0.6)
		blink.tween_property(opt, "modulate:a", 0.45, 0.6)
		blink.tween_property(opt, "modulate:a", 1.0, 0.6)
	# logo drops in
	logo.position.y -= 40
	logo.modulate.a = 0.0
	var t := logo.create_tween().set_parallel()
	t.tween_property(logo, "position:y", logo.position.y + 40, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(logo, "modulate:a", 1.0, 0.35)
	_title = root
	# input goes through the title's own control (it swallows every key and click)
	root.focus_mode = Control.FOCUS_ALL
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_title_input)
	root.grab_focus.call_deferred()


var _title: Control
var _title_cam_zoom := Vector2.ONE
var _title_drift: Tween
var _title_opts: Array[Rect2] = []


func _on_title_input(event: InputEvent) -> void:
	if _title == null or not is_instance_valid(_title):
		return
	var go: bool = (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not go:
		return
	# 2 or a click on SURVIVAL: the wave game; anything else: the sandbox
	var survival: bool = (event is InputEventKey and event.keycode == KEY_2) \
		or (event is InputEventMouseButton and _title_opts.size() > 1 and _title_opts[1].has_point(event.position))
	var marble: bool = (event is InputEventKey and event.keycode == KEY_3) \
		or (event is InputEventMouseButton and _title_opts.size() > 2 and _title_opts[2].has_point(event.position))
	var counter: bool = (event is InputEventKey and event.keycode == KEY_4) \
		or (event is InputEventMouseButton and _title_opts.size() > 3 and _title_opts[3].has_point(event.position))
	var galton: bool = (event is InputEventKey and event.keycode == KEY_5) \
		or (event is InputEventMouseButton and _title_opts.size() > 4 and _title_opts[4].has_point(event.position))
	var coaster: bool = (event is InputEventKey and event.keycode == KEY_6) \
		or (event is InputEventMouseButton and _title_opts.size() > 5 and _title_opts[5].has_point(event.position))
	var puzzle: bool = (event is InputEventKey and event.keycode == KEY_7) \
		or (event is InputEventMouseButton and _title_opts.size() > 6 and _title_opts[6].has_point(event.position))
	var defence: bool = (event is InputEventKey and event.keycode == KEY_8) \
		or (event is InputEventMouseButton and _title_opts.size() > 7 and _title_opts[7].has_point(event.position))
	var clatter: bool = (event is InputEventKey and event.keycode == KEY_9) \
		or (event is InputEventMouseButton and _title_opts.size() > 8 and _title_opts[8].has_point(event.position))
	var music: bool = (event is InputEventKey and event.keycode == KEY_0) \
		or (event is InputEventMouseButton and _title_opts.size() > 9 and _title_opts[9].has_point(event.position))
	var pachinko: bool = (event is InputEventKey and event.keycode == KEY_MINUS) \
		or (event is InputEventMouseButton and _title_opts.size() > 10 and _title_opts[10].has_point(event.position))
	if survival:
		start_survival()
	elif marble:
		start_marble_works()
	elif counter:
		start_counter_works()
	elif galton:
		start_galton_works()
	elif coaster:
		start_coaster_works()
	elif puzzle:
		start_puzzle_works()
	elif defence:
		start_defence_works()
	elif clatter:
		start_clatter_works()
	elif music:
		start_music_works()
	elif pachinko:
		start_pachinko_works()
	_title.accept_event()
	var title := _title
	_title = null
	if _title_drift:
		_title_drift.kill()
		_title_drift = null
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


# --- Music ------------------------------------------------------------------
# "Clockwork Nocturne" (tools/audio/gen_music.py), looping; F8 mutes it.
var _music: AudioStreamPlayer


func _start_music() -> void:
	var st := load("res://assets/audio/nocturne.wav") as AudioStream   # loops (set in its .import)
	if st == null:
		return
	_music = AudioStreamPlayer.new()
	_music.stream = st
	_music.volume_db = -14.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS   # plays under the title too
	add_child(_music)
	if OS.get_cmdline_user_args().is_empty():   # not in the test harness
		_music.play()


func open_manual() -> void:
	var m := get_node_or_null("Manual")
	if m == null:
		m = preload("res://scripts/manual.gd").new()
		m.name = "Manual"
		add_child(m)
	m.toggle()


func toggle_music() -> void:
	if _music == null:
		return
	_music.stream_paused = not _music.stream_paused
	_show_banner("MUSIC OFF" if _music.stream_paused else "MUSIC ON", "F8 toggles it")


## Survival: the bare world and the wave game (no showcase, no god tools);
## the first ingot into the dome starts the waves.
## The marble-machine demo: the surface showcase cleared, a cavern carved
## under the dome with the Beam and one big machine around it
## (scripts/marble_works.gd); the prospector is dropped into it. Sandbox
## tools stay on.
func start_marble_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/marble_works.gd").build(self)
	_player.global_position = Vector2(1300, 540)
	_show_banner("MARBLE WORKS", "the Beam lifts, the machine spends the drop")


## A marble computer: six flip-flops counting in binary, the marbles lifted
## round and round by a screw (scripts/counter_works.gd). Sandbox tools stay on.
func start_counter_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/counter_works.gd").build(self)
	_player.global_position = Vector2(1520, 540)
	_show_banner("BINARY COUNTER", "each marble adds one")


## Chance: a Galton board, pegs and bins, filling into a bell curve
## (scripts/galton_works.gd). Sandbox tools stay on.
func start_galton_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/galton_works.gd").build(self)
	_player.global_position = Vector2(1520, 540)
	_show_banner("GALTON BOARD", "every peg a coin toss")


## A fun run: screw, curved drop, loop-the-loop, jump, bell
## (scripts/coaster_works.gd). Sandbox tools stay on.
func start_coaster_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/coaster_works.gd").build(self)
	_player.global_position = Vector2(1600, 540)
	_show_banner("COASTER", "down, round, over and ding")


## A marble puzzle: route a dispenser's marbles past a wall into a goal cup
## with chutes (scripts/puzzle_works.gd). Sandbox tools stay on.
func start_puzzle_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	var cup: Node2D = await preload("res://scripts/puzzle_works.gd").build(self)
	cup.filled.connect(func(): _show_banner("SOLVED", "five in the cup" if cup.accept == "" else "five iron, no copper"))
	_player.global_position = Vector2(1400, 540)
	_show_banner("MARBLE PUZZLE", "get five marbles into the cup: build chutes (9)")


## The marble machine as defence: a dispenser and a flip-flop feed two
## turrets against a wave walking for the vault (scripts/defence_works.gd).
func start_defence_works(sorted := false) -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	var d: Node2D = await preload("res://scripts/defence_works.gd").build(self, sorted)
	d.finished.connect(func(won: bool): _show_banner("VAULT HELD" if won else "VAULT BROKEN", "the machine kept the turrets fed" if won else "too many got through"))
	_player.global_position = Vector2(1050, 540)
	_show_banner("MARBLE DEFENCE", "the machine feeds the turrets: hold the vault")


## Noise draws enemies: the machine's clatter sends walkers for the vault
## (scripts/clatter_works.gd).
func start_clatter_works(felt := false) -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	var parts: Array = await preload("res://scripts/clatter_works.gd").build(self, felt)
	parts[1].finished.connect(func(_won: bool): _show_banner("VAULT BROKEN", "the racket drew too many"))
	parts[0].attract.connect(func(n: int): _show_banner("HEARD", "the clatter carries: %d coming" % (n + 1)))
	_player.global_position = Vector2(1050, 540)
	_show_banner("CLATTER", "every knock is heard: the busier, the more come")


## A music box: a switchback of chime bars plays a tune for every marble
## (scripts/music_works.gd).
func start_music_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/music_works.gd").build(self)
	_player.global_position = Vector2(1450, 540)
	_show_banner("MUSIC BOX", "every marble plays the tune on the way down")


## A marble game you play: a plunger, a peg field, scoring pockets
## (scripts/pachinko_works.gd).
func start_pachinko_works() -> void:
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	await preload("res://scripts/pachinko_works.gd").build(self)
	_player.global_position = Vector2(960, 540)
	_show_banner("PACHINKO", "click and hold the plunger (bottom right), let go to fire")


func start_survival() -> void:
	sandbox = false
	preload("res://scripts/sandbox_showcase.gd").clear(self)
	if _god_label:
		_god_label.queue_free()
		_god_label = null
	wave_number = 0
	_wave_timer = 0.0
	_waves_started = false
	_wave_label.text = "Get an ingot into the dome to begin"
	var goals := preload("res://scripts/goals.gd").new()   # the first steps, in the HUD
	goals.name = "Goals"
	add_child(goals)


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
	_repair_dome(delta)
	_check_cleared(delta)


## A wave is cleared when its whole column has marched in and none of its
## walkers or fliers are left (the cave dwellers - crawlers, bats, the
## wyrm, a vault's sentinel - don't count, nor do rollers that have
## plugged a ditch): a banner and fireworks over the dome.
var _wave_live := false
var _marching := 0
var _clear_t := 0.0
var waves_cleared := 0          # tests
const CAVE_GROUPS := ["crawlers", "cinderbats", "wyrms", "ruins"]

func _check_cleared(delta: float) -> void:
	if not _wave_live or _game_over or _marching > 0:
		return
	_clear_t -= delta
	if _clear_t > 0:
		return
	_clear_t = 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("plugged"):
			continue
		var cave := false
		for g in CAVE_GROUPS:
			cave = cave or e.is_in_group(g)
		if not cave:
			return
	_wave_live = false
	waves_cleared += 1
	_show_banner("WAVE %d CLEARED" % wave_number, "")
	var dome := get_node_or_null("DomeZone") as Node2D
	preload("res://scripts/fireworks.gd").volley(self, dome.global_position if dome else Vector2(1200, 90))


# --- Dome repair ------------------------------------------------------------
# Ingots delivered to the dome are its repair stock: while it's damaged it
# welds one in every REPAIR_EVERY seconds for REPAIR_HP. So the supply chain
# keeps the base alive under pressure.
const REPAIR_EVERY := 3.0
const REPAIR_HP := 4
var repaired := 0   # tests
var _repair_t := 0.0


func _repair_dome(delta: float) -> void:
	if _game_over or dome_hp >= dome_max_hp:
		_repair_t = 0.0
		return
	_repair_t += delta
	if _repair_t < REPAIR_EVERY:
		return
	_repair_t = 0.0
	if not _receiver.consume_ammo():
		return
	dome_hp = mini(dome_max_hp, dome_hp + REPAIR_HP)
	repaired += REPAIR_HP
	_update_hp_bar()
	for k in 3:
		FX.burst(self, Vector2(1200 + randf_range(-60, 60), 96 - randf_range(10, 60)), Color(1.0, 0.85, 0.45), 6, 60.0, 0.3, 1.2)
	SFX.play(self, SFX.sfx_clink(), -8.0, 1.2)


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
	var dn := preload("res://scripts/daynight.gd").new()   # day and night
	dn.name = "DayNight"
	add_child(dn)
	var birds := preload("res://scripts/sparrows.gd").new()    # clockwork sparrows on the grass
	birds.name = "Sparrows"
	add_child(birds)
	var eyes := preload("res://scripts/night_eyes.gd").new()   # enemy eye lamps glow after dark
	eyes.name = "NightEyes"
	add_child(eyes)


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
	_tick_meteors(delta)
	if _game_over or not _waves_started or sandbox:
		return

	_wave_timer += delta
	var time_left := wave_interval - _wave_timer
	_wave_label.text = "Next wave: %ds" % max(0, int(time_left))

	if _wave_timer >= wave_interval:
		_wave_timer = 0.0
		_spawn_wave()


# --- Meteor showers --------------------------------------------------------
# Now and then, some way into the gap after a wave, burning chunks of ore
# rain down across the map for a few seconds (scenes/meteor.gd): craters,
# loose copper and iron everywhere, and bad luck for anything underneath.
const SHOWER_CHANCE := 0.35
const SHOWER_TIME := 9.0
var _shower_in := -1.0
var _shower_left := 0.0
var _meteor_t := 0.0
var meteors := 0   # tests


func start_meteor_shower() -> void:
	_shower_left = SHOWER_TIME
	_meteor_t = 0.6
	_show_banner("METEOR SHOWER", "ore from the sky: mind your head")


func _tick_meteors(delta: float) -> void:
	if _quake_in > 0:
		_quake_in -= delta
		if _quake_in <= 0:
			start_quake()
	if _storm_in > 0:
		_storm_in -= delta
		if _storm_in <= 0:
			start_storm()
	if _gale_in > 0:
		_gale_in -= delta
		if _gale_in <= 0:
			start_gale()
	if _shower_in > 0:
		_shower_in -= delta
		if _shower_in <= 0:
			start_meteor_shower()
	if _shower_left <= 0:
		return
	_shower_left -= delta
	_meteor_t -= delta
	if _meteor_t > 0:
		return
	_meteor_t = randf_range(0.25, 0.7)
	var m: Node2D = preload("res://scenes/meteor.gd").new()
	var w := WorldGen.WORLD_WIDTH * WorldGen.TILE_SIZE
	m.global_position = Vector2(randf_range(120.0, w - 120.0), -420.0)
	m.velocity = Vector2(randf_range(-150, 150), randf_range(380, 460))
	m.iron = randf() < 0.3
	m.size = randf_range(0.8, 1.6)
	add_child(m)
	meteors += 1


const STORM_CHANCE := 0.25
var _storm_in := -1.0
var _quake_in := -1.0
var storm: Node2D = null   # the current thunderstorm (scripts/storm.gd)


const GALE_CHANCE := 0.2
var _gale_in := -1.0
var gale: Node2D = null    # the current gale (scripts/gale.gd)


func start_gale() -> void:
	if is_instance_valid(gale):
		return
	gale = preload("res://scripts/gale.gd").new()
	add_child(gale)
	_show_banner("GALE", "a wind from the %s: anything in the air drifts" % ("west" if gale.direction > 0 else "east"))


const QUAKE_CHANCE := 0.15
var quake: Node2D = null   # the current earthquake (scripts/quake.gd)


func start_quake() -> void:
	if is_instance_valid(quake):
		return
	quake = preload("res://scripts/quake.gd").new()
	add_child(quake)
	_show_banner("EARTHQUAKE", "the ground heaves: mind the cave roofs")


func start_storm() -> void:
	if is_instance_valid(storm):
		return
	storm = preload("res://scripts/storm.gd").new()
	add_child(storm)
	_show_banner("THUNDERSTORM", "lightning finds tall metal: tesla coils drink it")


func _spawn_wave() -> void:
	_wave_live = true
	_clear_t = 2.0
	if wave_number >= 1 and randf() < SHOWER_CHANCE:
		_shower_in = 12.0
	elif wave_number >= 2 and randf() < STORM_CHANCE:
		_storm_in = 8.0
	elif wave_number >= 3 and randf() < QUAKE_CHANCE:
		_quake_in = 10.0
	elif wave_number >= 2 and randf() < GALE_CHANCE:
		_gale_in = 6.0
	wave_number += 1
	var count := enemies_per_wave_base + wave_number
	_wave_label.text = "WAVE %d!" % wave_number
	# from wave 4 a wave may roll a trait (not the boss waves)
	wave_trait = force_trait
	if wave_trait == "" and wave_number >= 4 and wave_number % 5 != 0 and randf() < TRAIT_CHANCE:
		wave_trait = TRAITS.keys().pick_random()
	if wave_trait == "BLACKOUT":
		var dn := get_node_or_null("DayNight")
		if dn:
			dn.clock = 0.0          # the sky goes dark as they come
			dn.apply()
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
	var sappers := wave_number / 3   # burrowers from wave 3
	if sappers > 0:
		kinds[7] = sappers
	var bridgers := (wave_number + 2) / 4   # bridge engines from wave 2
	if bridgers > 0:
		kinds[8] = bridgers
	var masons := (wave_number + 1) / 4   # bricklayers from wave 3
	if masons > 0:
		kinds[9] = masons
	var airships := 1 if wave_number >= 4 and wave_number % 2 == 0 else 0   # troop drops from wave 4
	if airships > 0:
		kinds[11] = airships
	var tinkers := wave_number / 3 if wave_number >= 4 else 0   # repair crews from wave 4
	if tinkers > 0:
		kinds[12] = tinkers
	var gremlins := (wave_number - 3) / 2 if wave_number >= 5 else 0   # saboteurs from wave 5
	if gremlins > 0:
		kinds[14] = gremlins
	var mortars := (wave_number - 2) / 4 if wave_number >= 6 else 0   # artillery from wave 6
	if mortars > 0:
		kinds[15] = mortars
	var grenadiers := (wave_number - 1) / 3 if wave_number >= 4 else 0   # bombers from wave 4
	if grenadiers > 0:
		kinds[16] = grenadiers
	var rollers := wave_number / 4 if wave_number >= 5 else 0   # rolling juggernauts from wave 5
	if rollers > 0:
		kinds[18] = rollers
	if wave_trait == "SIEGE":
		mortars += 1
		grenadiers += 1
	var swarm := (4 + wave_number / 2) if wave_trait == "SWARM" else 0
	var sky_boss := wave_number % 10 == 0   # the Dreadnought every tenth wave
	var colossus := wave_number >= 15 and wave_number % 10 == 5   # the Colossus on 15, 25, ...
	var boss := wave_number % 5 == 0 and not sky_boss and not colossus   # the Foundry Engine on the other fifths
	if boss:
		kinds[10] = 1
	if colossus:
		kinds[17] = 1
	if sky_boss:
		kinds[13] = 1
	var gild_chance := 0.0 if wave_number < 6 else minf(0.6, 0.15 + 0.05 * (wave_number - 6))
	var gilded := 0
	var parts := []
	for t in kinds:
		parts.append("%d %s%s" % [kinds[t], ENEMY_NAMES[t], "s" if kinds[t] > 1 else ""])
	if swarm > 0:
		parts.append("+%d scuttlers" % swarm)
	if wave_trait != "":
		_show_banner("WAVE %d  -  %s" % [wave_number, wave_trait], TRAITS[wave_trait] + "     " + "  ".join(parts))
	else:
		_show_banner("WAVE %d" % wave_number, "  ".join(parts) + ("   (some gilded)" if gild_chance > 0 else ""))

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
		enemy.gilded = randf() < gild_chance
		gilded += 1 if enemy.gilded else 0
		enemy.direction = -1.0
		_march_in(enemy, Vector2(spawn_x, surface_y), i)

	for k in bearers:
		var sb := _enemy_scene.instantiate()
		sb.add_to_group("enemies")
		sb.setup(5)  # SHIELDBEARER
		sb.gilded = randf() < gild_chance
		gilded += 1 if sb.gilded else 0
		sb.direction = -1.0
		_march_in(sb, Vector2(spawn_x, surface_y), count + k)

	for k in magpies:
		var mp: Node2D = preload("res://scenes/magpie.tscn").instantiate()
		mp.global_position = Vector2(spawn_x + 20 + k * 60, -120 - k * 20)
		add_child(mp)

	for k in tinkers:
		var tk: Node2D = preload("res://scenes/tinker.tscn").instantiate()
		_march_in(tk, Vector2(spawn_x, 40), 3 + k * 3)   # a little behind the front of the pack

	for k in gremlins:
		var gr: Node2D = preload("res://scenes/gremlin.tscn").instantiate()
		_march_in(gr, Vector2(spawn_x, 40), 1 + k * 2)

	for k in swarm:
		var sc := _enemy_scene.instantiate()
		sc.add_to_group("enemies")
		sc.setup(1)   # SCUTTLER
		sc.direction = -1.0
		_march_in(sc, Vector2(spawn_x, surface_y), 2 + k)

	for k in grenadiers:
		var gn: Node2D = preload("res://scenes/grenadier.tscn").instantiate()
		_march_in(gn, Vector2(spawn_x, 40), 4 + k * 3)

	for k in rollers:
		var ro: Node2D = preload("res://scenes/roller.tscn").instantiate()
		_march_in(ro, Vector2(spawn_x, 60), 2 + k * 5)

	for k in mortars:
		var mo: Node2D = preload("res://scenes/mortar.tscn").instantiate()
		_march_in(mo, Vector2(spawn_x, 40), count + bearers + 2 + k * 2)   # at the back

	for k in airships:
		var ab: Node2D = preload("res://scenes/airship.tscn").instantiate()
		ab.global_position = Vector2(spawn_x + 60, -150)
		add_child(ab)

	if sky_boss:
		var dn: Node2D = preload("res://scenes/dreadnought.tscn").instantiate()
		dn.global_position = Vector2(spawn_x + 100, -120)
		add_child(dn)

	if colossus:
		var co := _enemy_scene.instantiate()
		co.add_to_group("enemies")
		co.setup(0)
		co.colossus = true
		co.direction = -1.0
		_march_in(co, Vector2(spawn_x, surface_y - 40), count + 2)
		_show_banner("THE COLOSSUS", "it steps over your ditches")

	if boss:
		var fe: Node2D = preload("res://scenes/foundry.tscn").instantiate()
		fe.global_position = Vector2(spawn_x - 20, 20)
		add_child(fe)

	for k in masons:
		var ms: Node2D = preload("res://scenes/mason.tscn").instantiate()
		ms.global_position = Vector2(spawn_x - 30 - k * 60, 40)
		add_child(ms)

	for k in bridgers:
		var br: Node2D = preload("res://scenes/bridger.tscn").instantiate()
		br.global_position = Vector2(spawn_x - 60 - k * 70, 40)
		add_child(br)

	for k in sappers:
		var sp: Node2D = preload("res://scenes/sapper.tscn").instantiate()
		sp.global_position = Vector2(spawn_x - 10 - k * 90, 80)
		add_child(sp)

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


## Walkers enter at the world's edge one after another (a column marching
## in) rather than appearing strung out over the far east, on top of
## whatever the player built there.
const MARCH_GAP := 0.35

## Wave traits: a random twist on some waves from wave 4 (TRAIT_CHANCE),
## named on the wave's banner. SWIFT and IRONCLAD are applied to each
## walker as it arrives (after its own _ready has set its stats); SWARM
## and SIEGE change what's in the wave; BLACKOUT turns the clock to night.
const TRAITS := {
	"SWIFT": "they come fast",
	"IRONCLAD": "half again the armour",
	"SWARM": "a flood of scuttlers",
	"SIEGE": "artillery at the back",
	"BLACKOUT": "they come in the dark",
}
const TRAIT_CHANCE := 0.45
var wave_trait := ""
var force_trait := ""           # tests: this trait every wave

func _apply_trait(n: Node) -> void:
	if not is_instance_valid(n):
		return
	match wave_trait:
		"SWIFT":
			if "speed" in n:
				n.speed *= 1.4
		"IRONCLAD":
			if "hp" in n:
				n.hp = int(ceil(n.hp * 1.5))
				if "max_hp" in n:
					n.max_hp = n.hp


func _march_in(n: Node2D, at: Vector2, place: int) -> void:
	n.global_position = at
	if wave_trait in ["SWIFT", "IRONCLAD"]:
		n.ready.connect(_apply_trait.bind(n), CONNECT_ONE_SHOT)
	if place <= 0:
		add_child(n)
		return
	# a Timer of our own: it goes with this scene if we leave mid-column
	_marching += 1
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = place * MARCH_GAP
	add_child(t)
	t.timeout.connect(func():
		t.queue_free()
		_marching -= 1
		if _game_over:
			n.free()
		else:
			add_child(n))
	t.tree_exiting.connect(func():
		if is_instance_valid(n) and not n.is_inside_tree():
			n.free())
	t.start()


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
	_ammo_label.text = "Ingots in dome: %d/%d  (repair stock)" % [current, max_ammo]
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
	19: "Build: FLAMER (feed it ore)",
	20: "Build: TRAPDOOR (over a pit)",
	21: "Build: CRUSHER (ore -> grit; chews walkers)",
	22: "Build: ELECTROMAGNET (lifts iron and walkers, drops them)",
	23: "Build: HARPOON BALLISTA (feed it scrap; downs fliers)",
	24: "Build: SEESAW (drop heavy on one end)",
	25: "Build: PNEUMATIC TUBE (drag intake to outlet)",
	38: "Build: BEAM TAP (on the Beam; click it: filter)",
	39: "Build: FLIP-FLOP (sends every other marble each way)",
	40: "Build: ESCAPEMENT (one marble per beat; at a track end)",
	41: "Build: TIPPING BUCKET (collects, then pours a batch)",
	42: "Build: SIEVE RAIL (drag; grit drops through)",
	43: "Build: ARCHIMEDES SCREW (drag bottom to top)",
	45: "Build: STAIR LIFT (bobbing steps climb marbles up)",
	46: "Build: FERRIS LIFT (cups scoop marbles at the bottom, tip them at the top)",
	47: "Build: JUMP (drag to set the landing: fast pieces fly the gap)",
	48: "Build: BELL (a marble strikes it: rings, and fires traps in reach)",
	49: "Build: LOOP-THE-LOOP (feed it off a steep drop: slow marbles fall off)",
	50: "Build: DISPENSER (drops a marble every 1/2/4 s: click to change)",
	51: "Build: GOAL CUP (counts marbles in; fires traps in reach when full)",
	52: "Build: WEIGH SCALE (heavy ore rolls off one side, light the other: click for 1.5/2.5)",
	53: "Build: MARBLE CANNON (feed its hopper: fires flat at walkers in front; iron punches shields)",
	54: "Build: FELT CHUTE (drag: marbles on it make no clatter, but it slows them)",
	55: "Build: CHIME BAR (drag a sloped bar; a marble landing on it rings its note: click to retune)",
	56: "Build: PLUNGER (click and hold it, let go: fires a marble straight up; reloads what falls back in)",
	57: "Build: VORTEX FUNNEL (roll marbles in over the rim: they spiral down and drop out one at a time)",
	58: "Build: FLAP SORTER (drag; spring flaps drop pieces heavier than their spring: click a flap to change it)",
	59: "Build: OVERFLOW GATE (feeds its first side until the spot it watches is full: drag the ring there)",
	60: "Build: DEFLECTOR PLATE (flying ore ricochets off it: bank trampoline shots; click to turn 15 degrees)",
	61: "Build: BOOSTER RAIL (drag the way it drives: rollers push marbles along it, uphill too; faster when powered)",
	62: "Build: CATCH NET (flying ore lands soft, rolls to the ring and drops straight down: aim trampolines at it)",
	63: "Build: MAGNET DRUM (put it where a chute ends: iron things cling and drop behind it, copper and stone fly on)",
	64: "Build: SLUICE GATE (across a chute: holds the stream back until a tripwire, plate, bell or click opens it)",
	65: "Build: TALLY WHEEL (over a chute: every 3/5/10 pieces it fires traps at its wire's end; click to change, drag the wire)",
	66: "Build: POINTS SWITCH (a rocker that stays put: thrown by a trigger, like a tally wheel or a plate, or a click)",
	67: "Build: BRAKE RAIL (drag; brushes hold what runs on it to 80/150/250 px/s: click its number)",
	68: "Build: TEETER LAUNCHER (drop a piece in its high cup: it flings the one waiting in the low cup up)",
	69: "Build: CROSSOVER (feed its top corners: each stream crosses to the far bottom corner without catching the other)",
	70: "Build: FLYWHEEL (next to a gravity wheel: spins up on its surplus, keeps machines running when the feed stops)",
	71: "Build: ROTARY DISTRIBUTOR (drop a stream in: out left, down, right in turn; click to skip one)",
	72: "Build: FLIPPER (pieces rest on it; a trigger, like a tally wheel or plate, or a click bats them high)",
	44: "Build: ROBOTIC ARM (picks from one spot, drops at another)",
	37: "Build: DOMINO ROW (drag start to end; click an end to reset)",
	36: "Build: STEAM ENGINE (feed it ore: powers machines in reach)",
	35: "Build: POP-UP BARRICADE (a wall that springs up when a trigger near it fires)",
	34: "Build: DRONE DOCK (porter drones carry loose ore to turrets, ingots to the dome)",
	33: "Build: CLOCKWORK TIMER (trips machines nearby every few s; click it)",
	32: "Build: BRASS SENTRY (patrols, hammers walkers)",
	31: "Build: LANTERN (hangs from a ceiling, or on a pole)",
	30: "Build: STEAM BORER (tunnels by itself; click it to turn)",
	29: "Build: PRESSURE PLATE (any weight trips machines nearby)",
	28: "Build: TRIPWIRE (drag; trips kegs, trapdoors, pendulums near its stakes)",
	27: "Build: SNARE (holds a walker; flips ore)",
	26: "Build: POWDER KEG (shoot it, hit it, or let them walk in)",
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
		_god_label.text = "P wave   G spawn %s   H change\nO pour ore   K clear enemies\nF3 gale  F4 quake  F5 save  F6 meteors  F7 storm  F9 load" % ENEMY_NAMES[_god_type].to_upper()


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
			if ENEMY_NAMES[_god_type] in ["magpie", "sapper", "bridger", "mason", "foundry", "airship", "tinker", "dreadnought", "gremlin", "mortar", "grenadier", "roller"]:
				var mp: Node2D = load("res://scenes/%s.tscn" % ENEMY_NAMES[_god_type]).instantiate()
				mp.global_position = at
				add_child(mp)
				return
			var e := _enemy_scene.instantiate()
			e.add_to_group("enemies")
			if ENEMY_NAMES[_god_type] == "colossus":
				e.setup(0)
				e.colossus = true
			else:
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
		KEY_F6:
			if not event.echo:
				start_meteor_shower()
		KEY_F7:
			if not event.echo:
				start_storm()
		KEY_F3:
			if not event.echo:
				start_gale()
		KEY_F4:
			if not event.echo:
				start_quake()
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
		if event.keycode == KEY_F8 and not event.echo:
			toggle_music()
		if event.keycode == KEY_F1 and not event.echo:
			open_manual()
		# Cheat: L to toggle lighting (see underground)
		if event.keycode == KEY_L:
			if has_node("Fog"):
				$Fog.visible = _canvas_mod.color.r >= 0.5   # full bright also lifts the fog
			if _canvas_mod.color.r < 0.5:
				_canvas_mod.color = Color(1, 1, 1, 1)  # full bright
			else:
				_canvas_mod.color = Color(0.08, 0.08, 0.12, 1)  # dark
