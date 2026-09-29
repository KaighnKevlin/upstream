extends "res://scenes/chute.gd"
## Furnace rail: a chute with a glowing grate over a firebox. Ore that
## spends long enough on it (DWELL seconds in all) comes off as an ingot;
## ore that runs across quickly comes off raw. So the yield is a matter of
## speed: lay it shallow, or put a brake rail before it, and it all
## smelts. Copper and grit make copper ingots; iron, shot, gears iron ones.
## An ingot rolled back over it heats up again (for a crucible, which
## wants its bars hot): the same dwell brings a cold one back to white-hot.
## Hotter (quicker) when a gravity wheel or steam engine is in reach.

const Power = preload("res://scripts/power.gd")
const FX = preload("res://scripts/fx.gd")
const INGOT := preload("res://scenes/ingot.tscn")
const DWELL := 1.2
const SMELTS := ["copper", "iron", "grit", "shot", "gear", "scrap"]
const RAIL_TEX := preload("res://assets/sprites/furnace_rail.png")
const CAP_TEX := preload("res://assets/sprites/furnace_cap.png")

var smelted := 0                 # tests
var _heat: Area2D
var _dwell := {}                 # id -> seconds on the grate
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _t := 0.0
var _art: Node2D                 # the grate and firebox, pixel art tiled along the rail


func _ready() -> void:
	has_lip = false
	# art first, so ghosts and build-bar icons have it; behind our _draw (the glow)
	_art = Node2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_art.show_behind_parent = true
	_art.draw.connect(_draw_art)
	add_child(_art)
	super._ready()
	if not has_meta("ghost"):
		add_to_group("power_users")


func _rebuilt() -> void:
	if _heat:
		_heat.queue_free()
	_heat = Area2D.new()
	_heat.collision_layer = 0
	_heat.collision_mask = 2
	var b := end_offset
	var t := b.normalized()
	var up := Vector2(t.y, -t.x)
	if up.y > 0:
		up = -up
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(b.length(), 14)
	cs.shape = r
	cs.position = b * 0.5 + up * 6.0
	cs.rotation = b.angle()
	_heat.add_child(cs)
	add_child(_heat)


func _physics_process(delta: float) -> void:
	if _heat == null:
		return
	_t += delta
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	var heat := lerpf(0.6, 1.0, (_rate - Power.UNPOWERED) / (1.0 - Power.UNPOWERED))
	for o in _heat.get_overlapping_bodies():
		if not (o is RigidBody2D) or o.is_queued_for_deletion():
			continue
		if o.is_in_group("ingots"):
			# an ingot back over the grate heats up again: as long on it as
			# ore takes to smelt brings a cold bar back to white-hot
			if o.has_method("reheat"):
				o.reheat(delta * heat / DWELL)
			continue
		if not str(o.get("kind")) in SMELTS:
			continue
		var id: int = o.get_instance_id()
		_dwell[id] = _dwell.get(id, 0.0) + delta * heat
		if _dwell[id] >= DWELL:
			_dwell.erase(id)
			var ingot := INGOT.instantiate() as RigidBody2D
			ingot.kind = "copper" if o.get("kind") in ["copper", "grit"] else "iron"
			ingot.position = o.global_position
			ingot.linear_velocity = o.linear_velocity
			o.queue_free()
			get_tree().current_scene.add_child.call_deferred(ingot)
			smelted += 1
			FX.burst(get_parent(), o.global_position, Color(1.0, 0.6, 0.25), 6, 50.0, 0.4, 1.2, 300.0)
	queue_redraw()


## The chute's own look is replaced by the art; the fire's glow and the
## selection handle are drawn over it.
func _draw() -> void:
	if _art:
		_art.queue_redraw()
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	var t := (b - a) / l
	_draw_surface(a, b, t, Vector2(t.y, -t.x), l)
	_draw_selected()


## The grate (a tiled strip, row 3 on the rail line) and a cap at each end.
func _draw_art() -> void:
	var e := _ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var l := (b - a).length()
	if l < 1:
		return
	_art.draw_set_transform(a, (b - a).angle())
	_art.draw_texture_rect(RAIL_TEX, Rect2(0, -3, l, 14), true)
	_art.draw_texture(CAP_TEX, Vector2(-3, -4))
	_art.draw_texture(CAP_TEX, Vector2(l - 3, -4))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_surface(a: Vector2, b: Vector2, _dir: Vector2, _n: Vector2, l: float) -> void:
	# the fire's glow in the firebox vents and between the grate's bars
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	var hot := Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.8, 0.3), glow * 0.5)
	draw_set_transform(a, (b - a).angle())
	var k := 2.0
	while k + 4.0 < l - 2:
		draw_rect(Rect2(k, 4, 4, 3), Color(hot, 0.35 + 0.4 * glow))
		k += 8.0
	k = 2.0
	while k < l - 3:
		draw_rect(Rect2(k - 0.5, -0.5, 1, 2), hot)
		k += 4.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
