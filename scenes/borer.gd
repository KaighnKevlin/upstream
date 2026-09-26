extends Node2D
## Steam borer: a tracked boiler with a drill cone that tunnels on its own.
## Facing left or right it cuts a two-tile-high tunnel, crawling forward a
## tile at a time (and dropping down if the floor gives out); facing down it
## sinks a shaft. Ore it cuts through comes out behind it as loose chunks,
## stone now and then as grit. It even grinds through ironstone, slowly.
## It stops after MAX_TILES, at the world's edge, or short of the dome.
## Click it to turn it (right, left, down) and set it going again. Faster
## when a gravity wheel drives it.
## Art: tools/art/gen_borer.py (4 frames of 40x28, facing right).

const Power = preload("res://scripts/power.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

enum Mode { RIGHT, LEFT, DOWN }

const BORE := 0.35             # seconds per soft tile at full power (~1 s unpowered)
const BORE_HARD := 1.6         # ironstone
const DRIVE := 0.25            # through open air
const MAX_TILES := 48
const GRIT_CHANCE := 0.25
const DOME_CLEAR := 150.0

@export var mode: Mode = Mode.RIGHT

var bored := 0                 # tiles cut (tests)
var travelled := 0
var stopped := false
var _cell := Vector2i.ZERO     # the (lower) cell it stands in
var _t := 0.0
var _moving := false
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _spr: AnimatedSprite2D
var _tm: TileMapLayer


func _ready() -> void:
	z_index = 2
	_spr = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 12.0)
	var tex := preload("res://assets/sprites/borer.png")
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 40, 0, 40, 28)
		sf.add_frame("default", a)
	_spr.sprite_frames = sf
	_spr.centered = false
	_spr.offset = Vector2(-18, -12)        # tracks on the tunnel floor
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_face()
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_tm = get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if _tm == null:
		return
	_cell = _tm.local_to_map(_tm.to_local(global_position))
	for i in 8:
		if _tm.get_cell_source_id(_cell + Vector2i.DOWN) != -1:
			break
		_cell.y += 1
	global_position = _home(_cell)
	_spr.play()


## Where the machine sits for a cell: sideways, the middle of the 2-high
## tunnel above the cell's floor; down, the cell's centre.
func _home(c: Vector2i) -> Vector2:
	var p := _tm.to_global(_tm.map_to_local(c))
	return p + (Vector2(0, -8) if mode != Mode.DOWN else Vector2.ZERO)


func _face() -> void:
	_spr.rotation = PI / 2 if mode == Mode.DOWN else 0.0
	_spr.flip_h = mode == Mode.LEFT


func _dir() -> Vector2i:
	return [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN][mode]


func _front() -> Array:
	var f := _cell + _dir()
	return [f] if mode == Mode.DOWN else [f, f + Vector2i.UP]


func _solid(c: Vector2i) -> bool:
	return _tm.get_cell_source_id(c) != -1


func _blocked(c: Vector2i) -> bool:
	if c.x < 1 or c.x >= WorldGen.WORLD_WIDTH - 1 or c.y >= WorldGen.WORLD_HEIGHT - 1:
		return true
	var dome := get_tree().current_scene.get_node_or_null("DomeZone") as Node2D
	if dome and c.y < WorldGen.SURFACE_ROWS + 4 and absf(_tm.to_global(_tm.map_to_local(c)).x - dome.global_position.x) < DOME_CLEAR:
		return true
	return false


func _physics_process(delta: float) -> void:
	if _tm == null or stopped or _moving:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	# sideways over a hole: drop into it first
	if mode != Mode.DOWN and not _solid(_cell + Vector2i.DOWN) and _cell.y < WorldGen.WORLD_HEIGHT - 2:
		_step(_cell + Vector2i.DOWN, 0.12)
		return
	var front := _front()
	if _blocked(front[0]) or travelled >= MAX_TILES:
		_stop()
		return
	var need := DRIVE
	for c in front:
		if _solid(c):
			need = maxf(need, BORE_HARD if _tm.get_cell_atlas_coords(c).x == WorldGen.TILE_HARD else BORE)
	_t += delta * _rate
	if randf() < delta * 8.0 and need > DRIVE:
		var tip := global_position + Vector2(_dir()) * 20.0
		FX.burst(get_parent(), tip, Color(0.6, 0.52, 0.42), 1, 70.0, 0.3, 1.4)
	if _t < need:
		return
	_t = 0.0
	for c in front:
		if _solid(c):
			_cut(c)
	travelled += 1
	_step(_cell + _dir(), 0.18)


func _step(to: Vector2i, time: float) -> void:
	_cell = to
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", _home(_cell), time)
	tw.tween_callback(func(): _moving = false)


func _cut(c: Vector2i) -> void:
	var t := _tm.get_cell_atlas_coords(c).x
	var src := _tm.get_cell_source_id(c)
	_tm.set_cell(c, -1)
	WorldGen.reframe_around(_tm, c)
	get_tree().call_group("tile_shading", "mark_dirty", c)
	get_tree().call_group("cave_decor", "tile_cleared", c)
	FX.tile_break(get_parent(), _tm, c, src, Vector2i(t, 0), Vector2(_dir()))
	SFX.play_small(self, SFX.sfx_mine_break(t), -8.0, 0.8)
	bored += 1
	var kind := ""
	if t == WorldGen.TILE_IRON:
		kind = "iron"
	elif t == WorldGen.TILE_COPPER:
		kind = "copper"
	elif t in [WorldGen.TILE_STONE, WorldGen.TILE_DEEP_STONE, WorldGen.TILE_HARD] and randf() < GRIT_CHANCE:
		kind = "grit"
	if kind == "":
		return
	# out behind the machine
	var o: RigidBody2D = preload("res://scenes/ore.tscn").instantiate()
	o.kind = kind
	var back := -Vector2(_dir())
	o.global_position = global_position + back * 22.0 + (Vector2(0, -4) if mode != Mode.DOWN else Vector2(0, -26))
	o.linear_velocity = back * 60.0 + Vector2(randf_range(-30, 30), -120)
	get_parent().add_child.call_deferred(o)


func _stop() -> void:
	stopped = true
	_spr.stop()
	SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.6)
	FX.burst(get_parent(), global_position + Vector2(-8, -14), Color(0.8, 0.8, 0.78, 0.6), 6, 25.0, 1.2, 3.0, -40.0)


func _input(event: InputEvent) -> void:
	if _tm == null:
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position) < 20 and not _moving:
			turn(((mode + 1) % 3) as Mode)
			get_viewport().set_input_as_handled()


## Face a new way and set off again.
func turn(to: Mode) -> void:
	mode = to
	_face()
	global_position = _home(_cell)
	stopped = false
	travelled = 0
	_t = 0.0
	_spr.play()
	SFX.play(self, SFX.sfx_clink())
