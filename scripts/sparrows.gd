extends Node2D
## Clockwork sparrows: a small flock of wind-up birds living on the surface.
## They glide down onto open grass, hop about and peck, and scatter in a
## flurry of wingbeats when the prospector or an enemy comes near (or
## anything explodes: FX.shake calls scare() through the "sparrows" group),
## then drift back in a while later. At night they roost out of sight.
## Pure ambience: no physics, no gameplay. Art: tools/art/gen_sparrow.py.

const WorldGen = preload("res://scripts/world_gen.gd")

const FLOCK := 7
const SCARE_PLAYER := 70.0
const SCARE_ENEMY := 110.0
const HOP := 9.0

enum { GROUND, FLEE, AWAY, LAND }

var _birds := []                 # [sprite, state, velocity, timer, target]
var _tex: Texture2D
var _dn: Node = null
var scattered := 0               # tests


func _ready() -> void:
	add_to_group("sparrows")
	z_index = 2
	_tex = preload("res://assets/sprites/sparrow.png")
	for k in FLOCK:
		var s := Sprite2D.new()
		var a := AtlasTexture.new()
		a.atlas = _tex
		a.region = Rect2(0, 0, 14, 12)
		s.texture = a
		s.centered = false
		s.offset = Vector2(-7, -11)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.visible = false
		add_child(s)
		_birds.append([s, AWAY, Vector2.ZERO, randf_range(0.5, 8.0), Vector2.ZERO])


func _frame(b: Array, f: int) -> void:
	(b[0].texture as AtlasTexture).region = Rect2(f * 14, 0, 14, 12)


func _night() -> bool:
	if _dn == null or not is_instance_valid(_dn):
		_dn = get_parent().get_node_or_null("DayNight")
	return _dn != null and _dn.has_method("daylight") and _dn.daylight() < 0.25


## A patch of open grass to land on, or ZERO if none found.
func _landing() -> Vector2:
	var tm := get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return Vector2.ZERO
	var row := WorldGen.SURFACE_ROWS
	for attempt in 20:
		var x := randi_range(10, WorldGen.WORLD_WIDTH - 10)
		if tm.get_cell_source_id(Vector2i(x, row)) != -1 and tm.get_cell_source_id(Vector2i(x, row - 1)) == -1:
			var p := tm.to_global(tm.map_to_local(Vector2i(x, row)))
			return Vector2(p.x + randf_range(-6, 6), p.y - 8)
	return Vector2.ZERO


## Everything nearby takes off (explosions call this).
func scare(at: Vector2, radius := 200.0) -> void:
	for b in _birds:
		if b[1] == GROUND and b[0].global_position.distance_to(at) < radius:
			_flee(b, at)


func _flee(b: Array, from: Vector2) -> void:
	b[1] = FLEE
	var away := signf(b[0].global_position.x - from.x)
	if away == 0:
		away = 1.0
	b[2] = Vector2(away * randf_range(90, 150), randf_range(-170, -120))
	b[3] = 0.0
	scattered += 1


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	var p := scene.get_node_or_null("Player") as Node2D if scene else null
	var night := _night()
	var t := Time.get_ticks_msec() * 0.001
	for b in _birds:
		var s: Sprite2D = b[0]
		match b[1]:
			GROUND:
				b[3] -= delta
				if b[3] <= 0:
					# hop a little, or peck
					if randf() < 0.5:
						s.position.x += randf_range(-HOP, HOP)
						s.flip_h = randf() < 0.5
						_frame(b, 0)
					else:
						_frame(b, 1)
					b[3] = randf_range(0.4, 1.4)
				if night:
					_flee(b, s.global_position + Vector2(randf_range(-1, 1), 0))
					continue
				if p and p.global_position.distance_to(s.global_position) < SCARE_PLAYER:
					_flee(b, p.global_position)
					continue
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.global_position.distance_to(s.global_position) < SCARE_ENEMY:
						_flee(b, e.global_position)
						break
			FLEE:
				b[2].y -= 30.0 * delta
				s.position += b[2] * delta
				s.flip_h = b[2].x < 0
				_frame(b, 2 + int(t * 18.0) % 3)
				if s.position.y < -400:
					b[1] = AWAY
					s.visible = false
					b[3] = randf_range(6.0, 16.0)
			AWAY:
				b[3] -= delta
				if b[3] <= 0 and not night:
					var land := _landing()
					if land == Vector2.ZERO:
						b[3] = 3.0
						continue
					b[4] = land
					b[1] = LAND
					s.position = land + Vector2(randf_range(-260, 260), -280)
					s.visible = true
			LAND:
				var to: Vector2 = b[4] - s.position
				if to.length() < 3.0:
					s.position = b[4]
					b[1] = GROUND
					b[3] = randf_range(0.3, 1.0)
					_frame(b, 0)
					continue
				var v := to.normalized() * minf(130.0, to.length() * 2.0 + 30.0)
				s.position += v * delta
				s.flip_h = v.x < 0
				_frame(b, 2 + int(t * 12.0) % 3 if to.length() > 20.0 else 3)


## Birds on the ground (tests).
func grounded() -> int:
	return _birds.filter(func(b): return b[1] == GROUND).size()
