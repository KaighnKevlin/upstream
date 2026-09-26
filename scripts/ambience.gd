extends Node2D
## Cave life, near the camera: glowmoths drifting in open cave air (they
## bob, wander and scatter from the prospector's lamp) and water dripping
## from cave ceilings (a drop falls, splashes, plinks). Only underground,
## only in open air, only where the fog has been lifted. One node draws it
## all; nothing here is physics.

const WorldGen = preload("res://scripts/world_gen.gd")
const SFX = preload("res://scripts/sfx.gd")

const MOTHS := 28
const DRIPS := 10
const DEEP := (WorldGen.SURFACE_ROWS + 4) * WorldGen.TILE_SIZE   # below this is "cave"

var _moths := []      # [pos, vel, phase]
var _drips := []      # [pos, vy, state (0 hanging, 1 falling, 2 splash), t]
var _tm: TileMapLayer
var _fog: Node


func _ready() -> void:
	z_index = 4


func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size / (cam.zoom if cam else Vector2.ONE)
	var c := cam.get_screen_center_position() if cam else Vector2(1200, 300)
	return Rect2(c - size * 0.5, size)


func _air(p: Vector2) -> bool:
	return _tm.get_cell_source_id(_tm.local_to_map(_tm.to_local(p))) == -1


func _seen(p: Vector2) -> bool:
	return _fog == null or not _fog.visible or _fog.is_revealed(p)


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if _tm == null:
		_tm = scene.get_node_or_null("TileMapLayer") as TileMapLayer
		_fog = scene.get_node_or_null("Fog")
		if _tm == null:
			return
	var view := _view()
	var player := scene.get_node_or_null("Player") as Node2D
	# moths: drop the ones far outside the view, spawn in open cave air
	_moths = _moths.filter(func(m): return view.grow(160).has_point(m[0]) and _air(m[0]))
	for k in 3:
		if _moths.size() >= MOTHS:
			break
		var p := Vector2(randf_range(view.position.x, view.end.x), randf_range(maxf(view.position.y, DEEP), view.end.y))
		if p.y > DEEP and _air(p) and _seen(p) and _air(p + Vector2(0, 16)):
			_moths.append([p, Vector2.from_angle(randf() * TAU) * 12.0, randf() * TAU])
	for m in _moths:
		m[2] += delta
		var want: Vector2 = Vector2(sin(m[2] * 0.7), cos(m[2] * 0.9)) * 14.0
		if player and player.global_position.distance_to(m[0]) < 60.0:
			want += (m[0] - player.global_position).normalized() * 70.0   # scatter from the lamp
		m[1] = m[1].lerp(want, minf(1.0, delta * 1.5))
		var np: Vector2 = m[0] + m[1] * delta
		if _air(np):
			m[0] = np
		else:
			m[1] = -m[1]
	# drips: find a ceiling (rock above, air below), hang, fall, splash
	_drips = _drips.filter(func(d): return view.grow(80).has_point(d[0]) and d[2] < 3)
	if _drips.size() < DRIPS and randf() < delta * 3.0:
		for attempt in 25:   # caves can be a small part of the view: look around a bit
			var p := Vector2(randf_range(view.position.x, view.end.x), randf_range(maxf(view.position.y, DEEP), view.end.y))
			var c := _tm.local_to_map(_tm.to_local(p))
			if _tm.get_cell_source_id(c) != -1 or not _seen(p):
				continue
			for k in 12:   # up through the air to the ceiling
				if _tm.get_cell_source_id(c + Vector2i.UP) != -1:
					var at := _tm.to_global(_tm.map_to_local(c)) + Vector2(randf_range(-6, 6), -8)
					if at.y > DEEP:
						_drips.append([at, 0.0, 0, randf_range(0.6, 2.0)])
					break
				c += Vector2i.UP
			break
	for d in _drips:
		match d[2]:
			0:
				d[3] -= delta
				if d[3] <= 0:
					d[2] = 1
			1:
				d[1] += 600.0 * delta
				var np: Vector2 = d[0] + Vector2(0, d[1] * delta)
				if not _air(np) or np.y > view.end.y + 40:
					d[2] = 2
					d[3] = 0.25
					if view.has_point(d[0]) and player and player.global_position.distance_to(d[0]) < 260.0:
						SFX.play_small(self, SFX.sfx_clink(), -30.0, randf_range(2.2, 2.8))
				else:
					d[0] = np
			2:
				d[3] -= delta
				if d[3] <= 0:
					d[2] = 3
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for m in _moths:
		var p: Vector2 = m[0]
		var pulse := 0.55 + 0.45 * sin(t * 3.0 + m[2] * 5.0)
		draw_circle(p, 3.0, Color(0.45, 0.9, 0.95, 0.12 * pulse))
		draw_circle(p, 1.4, Color(0.6, 0.95, 1.0, 0.45 * pulse))
		draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.9, 1.0, 1.0, pulse))
		var flap := absf(sin(t * 14.0 + m[2] * 7.0)) * 1.5
		draw_line(p + Vector2(-0.5, 0), p + Vector2(-2.0, -flap), Color(0.7, 0.85, 0.9, 0.5), 1.0)
		draw_line(p + Vector2(0.5, 0), p + Vector2(2.0, -flap), Color(0.7, 0.85, 0.9, 0.5), 1.0)
	for d in _drips:
		var p: Vector2 = d[0]
		match d[2]:
			0:
				var grow: float = 1.0 - clampf(d[3], 0.0, 1.0)
				draw_circle(p + Vector2(0, 1), 0.6 + grow * 0.8, Color(0.6, 0.75, 0.9, 0.7))
			1:
				draw_line(p, p + Vector2(0, -3), Color(0.65, 0.8, 0.95, 0.75), 1.0)
			2:
				var k: float = 1.0 - d[3] / 0.25
				for s in [-1.0, 1.0]:
					draw_line(p + Vector2(s * 1.0, -1), p + Vector2(s * (2.0 + k * 3.0), -2.0 - k * 2.0), Color(0.65, 0.8, 0.95, 0.6 * (1.0 - k)), 1.0)
