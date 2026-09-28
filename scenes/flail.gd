extends Node2D
## Flail: an iron post on the ground with a spiked ball on a chain, whirled
## round the post-top by a wheel in reach (gravity wheel, spinner, steam
## engine). Unpowered it only lolls round; powered it's a blur, battering
## any walker that comes within reach and knocking it back. It hits harder
## the faster it goes. The ball swats loose pieces too.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const HUB := Vector2(0, -30)
const CHAIN := 30.0
const BALL := 5.0
const W_MAX := 10.0              # rad/s at full power

var hits := 0                    # tests
var _a := 0.0
var _w := 0.0
var _level := 0.0
var _level_t := 0.0
var _seen := {}
var _chain_art: Sprite2D         # art: the chain and ball, turned to _a


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; over
	# our own _draw (the blur ring)
	_spr(preload("res://assets/sprites/flail_post.png"), Vector2.ZERO, Vector2(-9, -33))
	_chain_art = _spr(preload("res://assets/sprites/flail_chain.png"), HUB, Vector2(-2, -11))
	_chain_art.rotation = _a
	_spr(preload("res://assets/sprites/flail_cap.png"), HUB, Vector2(-5, -5))
	if has_meta("ghost"):
		return
	_snap_to_floor()
	add_to_group("power_users")


func _spr(tex: Texture2D, at: Vector2, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func ball() -> Vector2:
	return global_position + HUB + Vector2.RIGHT.rotated(_a) * CHAIN


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_level_t -= delta
	if _level_t <= 0:
		_level_t = 0.25
		_level = Power.level_at(get_tree(), global_position)
	var target := lerpf(0.8, W_MAX, _level)
	_w = move_toward(_w, target, 4.0 * delta)
	_a += _w * delta
	_chain_art.rotation = _a
	var b := ball()
	var now := Time.get_ticks_msec() / 1000.0
	var tangent := Vector2.RIGHT.rotated(_a + PI * 0.5) * _w * CHAIN
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		if _seen.get(e.get_instance_id(), 0.0) > now:
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 10.0
		if c.distance_to(b) < r + BALL:
			_seen[e.get_instance_id()] = now + 0.35
			var k := _w / W_MAX
			e.take_damage(1 + int(6.0 * k))
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock(Vector2(signf(c.x - global_position.x) * (80.0 + 260.0 * k), -120.0 * k))
			hits += 1
			FX.burst(get_parent(), b, Color(0.85, 0.95, 1.0), 5, 90.0, 0.15, 1.5, 0.0)
			SFX.play_small(self, SFX.sfx_enemy_hit(), -6.0, 0.8)
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(b) < BALL + 6.0 \
				and o.get_meta("flail_until", 0.0) < now:
			o.set_meta("flail_until", now + 0.3)
			o.sleeping = false
			o.linear_velocity = tangent.limit_length(420.0)
	queue_redraw()


func _draw() -> void:
	# (the post, chain, ball and swivel are sprites) a blur ring when it's fast
	var k := _w / W_MAX
	if k > 0.4:
		draw_arc(HUB, CHAIN, 0, TAU, 40, Color(0.7, 0.72, 0.8, 0.12 + 0.1 * k), BALL * 2.0)
