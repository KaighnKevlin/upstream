extends StaticBody2D
## Vein tapper: bolts onto the top face of an ore vein, bores into it and
## lobs the ore out of an aimable mortar. It drains the whole connected vein
## (ORE_PER_CELL per block); tapped-out blocks turn back into plain rock,
## farthest first, and the tapper shuts down when the vein is gone.
##
## Aim: click it, then drag the handle; distance sets the force. While
## selected, a dotted arc previews where the ore will fly.

const LightTextures = preload("res://scripts/light_textures.gd")
const WorldGen = preload("res://scripts/world_gen.gd")
const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const Trajectory = preload("res://scripts/trajectory_preview.gd")

## Aim in degrees (0 = straight up, positive = right).
@export_range(-80, 80, 1) var eject_angle: float = -20.0
## Launch speed (px/s).
@export_range(150, 1400, 10) var eject_force: float = 520.0
## Seconds between shots.
@export_range(0.3, 5.0, 0.1) var eject_interval: float = 1.4

const ORE_PER_CELL := 6
const VEIN_MAX := 30
const PIVOT := Vector2(0, -21)      # mortar ring, relative to the node
const MUZZLE := 16.0
const HANDLE_MIN := 22.0
const HANDLE_MAX := 110.0
const FORCE_RANGE := Vector2(150, 1400)

## Ore left in each vein block, shared by every tapper on the map.
static var vein_left := {}

var _ore_scene: PackedScene = preload("res://scenes/ore.tscn")
var _timer := 0.0
var _anim_t := 0.0
var _spr: Sprite2D
var _mortar: Sprite2D
var _frames := 8
var _cells: Array[Vector2i] = []   # this tapper's vein, farthest first
var _depleted := false
var _meter_fill: ColorRect
var _selected := false
var _dragging := false
var _handle: Polygon2D
var _arc: Node2D
var _lamp: PointLight2D


func _ready() -> void:
	for n in ["Sprite", "Nozzle", "Light"]:
		if has_node(n):
			get_node(n).visible = false
	var tm := _get_tilemap()
	if tm:
		# bolt onto the top face of the ore cell under the placement point
		var cell := tm.local_to_map(tm.to_local(global_position))
		var c := tm.to_global(tm.map_to_local(cell))
		global_position = Vector2(c.x, c.y - 8)
		_map_vein(tm, cell)

	_spr = Sprite2D.new()
	var tex := load("res://assets/sprites/tapper.png") as Texture2D
	_spr.texture = tex
	_spr.hframes = 8
	_spr.offset = Vector2(0, -7)  # 40x46 frame, figure origin (20, 30) = this node
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)

	_mortar = Sprite2D.new()
	_mortar.texture = load("res://assets/sprites/tapper_mortar.png")
	_mortar.centered = false
	_mortar.offset = Vector2(-3, -5)
	_mortar.position = PIVOT
	_mortar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mortar)

	# vein gauge on the housing's right edge
	var back := ColorRect.new()
	back.color = Color(0.1, 0.08, 0.07)
	back.position = Vector2(9, -17)
	back.size = Vector2(2, 13)
	add_child(back)
	_meter_fill = ColorRect.new()
	_meter_fill.color = Color(0.45, 0.85, 0.9)
	add_child(_meter_fill)
	_update_meter()

	_lamp = PointLight2D.new()
	_lamp.texture = LightTextures.create_radial_light(128)
	_lamp.energy = 0.3
	_lamp.color = Color(0.5, 0.8, 0.95)
	_lamp.position = Vector2(0, -12)
	add_child(_lamp)

	_handle = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(Vector2.from_angle(k * TAU / 12) * 5)
	_handle.polygon = pts
	_handle.color = Color(1.0, 0.7, 0.2)
	_handle.visible = false
	_handle.z_index = 21
	add_child(_handle)
	_arc = Trajectory.new()
	_arc.tilemap = tm
	_arc.visible = false
	add_child(_arc)
	_aim_visuals()


# ── the vein ───────────────────────────────────────────────────────────

func _map_vein(tm: TileMapLayer, start: Vector2i) -> void:
	var kind := tm.get_cell_atlas_coords(start).x
	if not kind in [WorldGen.TILE_IRON, WorldGen.TILE_COPPER]:
		return
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and _cells.size() < VEIN_MAX:
		var c: Vector2i = queue.pop_front()
		_cells.append(c)
		if not vein_left.has(c):
			vein_left[c] = ORE_PER_CELL
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var nb := c + Vector2i(dx, dy)
				if not seen.has(nb) and tm.get_cell_source_id(nb) != -1 \
						and tm.get_cell_atlas_coords(nb).x == kind:
					seen[nb] = true
					queue.append(nb)
	# drain from the far end inward; the block under the tapper goes last
	_cells.sort_custom(func(a, b): return a.distance_squared_to(start) > b.distance_squared_to(start))


func _ore_remaining() -> int:
	var total := 0
	for c in _cells:
		total += vein_left.get(c, 0)
	return total


func _take_ore() -> bool:
	if _infinite():
		return true  # sandbox: veins never run dry
	var tm := _get_tilemap()
	for c in _cells:
		var left: int = vein_left.get(c, 0)
		if left <= 0:
			continue
		vein_left[c] = left - 1
		if left - 1 == 0 and tm:
			# tapped out: back to the plain rock of that depth
			WorldGen.set_tile(tm, c, WorldGen._get_base_tile(c.y))
			var at := tm.to_global(tm.map_to_local(c))
			FX.burst(get_parent(), at, Color(0.55, 0.45, 0.35), 6, 40.0, 0.5, 2.0)
		return true
	return false


func _infinite() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get("sandbox") == true


func _update_meter() -> void:
	var cap := maxi(1, _cells.size() * ORE_PER_CELL)
	var h := 13.0 * float(_ore_remaining()) / cap
	_meter_fill.position = Vector2(9, -4 - h)
	_meter_fill.size = Vector2(2, h)


# ── running ────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _depleted:
		return
	_anim_t += delta
	_spr.frame = int(_anim_t * 10.0) % _frames
	_timer += delta
	if _timer >= eject_interval:
		_timer -= eject_interval
		if _take_ore():
			_fire()
		else:
			_shut_down()
		_update_meter()


func _aim_dir() -> Vector2:
	var a := deg_to_rad(eject_angle)
	return Vector2(sin(a), -cos(a))


func _fire() -> void:
	var dir := _aim_dir()
	var ore := _ore_scene.instantiate() as RigidBody2D
	ore.global_position = global_position + PIVOT + dir * MUZZLE
	get_tree().current_scene.add_child(ore)
	ore.linear_velocity = dir * eject_force
	var mouth := global_position + PIVOT + dir * (MUZZLE + 2)
	FX.burst(get_parent(), mouth, Color(0.85, 0.85, 0.8, 0.8), 5, 40.0, 0.6, 2.5, -40.0)
	SFX.play(self, SFX.sfx_turret_fire())
	var kick := create_tween()
	kick.tween_property(_mortar, "offset", Vector2(-6, -5), 0.04)
	kick.tween_property(_mortar, "offset", Vector2(-3, -5), 0.16)


func _shut_down() -> void:
	_depleted = true
	_spr.frame = 0
	_spr.modulate = Color(0.7, 0.68, 0.66)
	_lamp.energy = 0.0
	FX.burst(get_parent(), global_position + PIVOT, Color(0.6, 0.6, 0.58, 0.7), 8, 25.0, 1.2, 3.0, -30.0)


# ── aiming UI ──────────────────────────────────────────────────────────

func _handle_dist() -> float:
	return remap(eject_force, FORCE_RANGE.x, FORCE_RANGE.y, HANDLE_MIN, HANDLE_MAX)


func _aim_visuals() -> void:
	var dir := _aim_dir()
	_mortar.rotation = dir.angle()
	_handle.position = PIVOT + dir * _handle_dist()
	if _arc:
		_arc.origin = global_position + PIVOT + dir * MUZZLE
		_arc.velocity = dir * eject_force
		_arc.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _set_selected(on: bool) -> void:
	_selected = on
	_dragging = false
	_handle.visible = on
	_arc.visible = on
	if not _depleted:
		_spr.modulate = Color(1.25, 1.2, 1.1) if on else Color.WHITE
	_aim_visuals()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			_set_selected(false)
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			_set_selected(false)
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var over_body := absf(mouse.x - global_position.x) < 12 and mouse.y > global_position.y - 26 \
					and mouse.y < global_position.y + 4
			if _selected and mouse.distance_to(to_global(_handle.position)) < 10:
				_dragging = true
				get_viewport().set_input_as_handled()
			elif over_body:
				_set_selected(not _selected)
				get_viewport().set_input_as_handled()
			elif _selected:
				_set_selected(false)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var v := mouse - (global_position + PIVOT)
		if v.length() > 4:
			eject_angle = clampf(rad_to_deg(v.angle() + PI / 2), -80, 80)
			eject_force = clampf(remap(v.length(), HANDLE_MIN, HANDLE_MAX, FORCE_RANGE.x, FORCE_RANGE.y),
				FORCE_RANGE.x, FORCE_RANGE.y)
			_aim_visuals()
		get_viewport().set_input_as_handled()


func _get_tilemap() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene and scene.has_node("TileMapLayer"):
		return scene.get_node("TileMapLayer") as TileMapLayer
	return null
