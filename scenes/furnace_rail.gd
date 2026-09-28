extends "res://scenes/chute.gd"
## Furnace rail: a chute with a glowing grate over a firebox. Ore that
## spends long enough on it (DWELL seconds in all) comes off as an ingot;
## ore that runs across quickly comes off raw. So the yield is a matter of
## speed: lay it shallow, or put a brake rail before it, and it all
## smelts. Copper and grit make copper ingots; iron, shot, gears iron ones.
## Hotter (quicker) when a gravity wheel or steam engine is in reach.

const Power = preload("res://scripts/power.gd")
const FX = preload("res://scripts/fx.gd")
const INGOT := preload("res://scenes/ingot.tscn")
const DWELL := 1.2
const SMELTS := ["copper", "iron", "grit", "shot", "gear", "scrap"]

var smelted := 0                 # tests
var _heat: Area2D
var _dwell := {}                 # id -> seconds on the grate
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _t := 0.0


func _ready() -> void:
	has_lip = false
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
		if not (o is RigidBody2D) or o.is_queued_for_deletion() or o.is_in_group("ingots"):
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


func _draw_surface(a: Vector2, b: Vector2, t: Vector2, n: Vector2, l: float) -> void:
	# the firebox under the rail, and a glowing grate on it
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	var hot := Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.8, 0.3), glow * 0.5)
	draw_line(a - n * 6, b - n * 6, Color(0.18, 0.1, 0.08), 7.0)
	draw_line(a - n * 6, b - n * 6, Color(hot, 0.5 * glow), 3.0)
	var k := 4.0
	while k < l - 2:
		var p := a + t * k
		draw_line(p - n * 1, p + n * 1.5, hot, 1.5)
		k += 6.0
