extends Node2D

const LightTextures = preload("res://scripts/light_textures.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

## How much velocity the ore retains after passing through (0.0–1.0).
@export_range(0.1, 0.9, 0.05) var velocity_retention: float = 0.6

var _ingot_scene: PackedScene = preload("res://scenes/ingot.tscn")

@onready var _area: Area2D = $Area2D


const HALF_SPAN := 84.0   # electrodes sit just past the 160px beam area
const TIP := 5.5          # electrode tip, px from its centre (tools/art/gen_machines.py)

var _bolt: Line2D
var _glow: Line2D
var _flicker := 0.0
var _light: PointLight2D
# While smelting, the arc bends from both electrodes onto the ore
var _strike_t := 0.0
var _strike_at := Vector2.ZERO  # local
const STRIKE_TIME := 0.16


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	for n in ["BeamLeft", "Beam", "BeamRight", "BeamGlow"]:
		if has_node(n):
			get_node(n).visible = false

	# two brass electrodes with an arc crackling between them
	for side in [-1.0, 1.0]:
		var e := Sprite2D.new()
		e.texture = preload("res://assets/sprites/electrode.png")
		e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.position = Vector2(side * HALF_SPAN, 0)
		e.flip_h = side > 0
		add_child(e)
	_glow = _make_line(6.0, Color(0.45, 0.8, 0.85, 0.25))
	_bolt = _make_line(1.5, Color(0.8, 0.95, 0.95, 0.95))
	_reroll_arc()

	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(128)
	light.texture_scale = 1.5
	light.energy = 0.45
	light.color = Color(0.45, 0.8, 0.9)
	add_child(light)
	_light = light


func _make_line(width: float, color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_SHARP
	add_child(l)
	return l


func _reroll_arc() -> void:
	var a := Vector2(-HALF_SPAN + TIP, 0)
	var b := Vector2(HALF_SPAN - TIP, 0)
	var pts := PackedVector2Array()
	if _strike_t > 0:
		# two jagged legs meeting at the ore
		_jag(pts, a, _strike_at, 7, 5.0)
		_jag(pts, _strike_at, b, 7, 5.0)
		pts.append(b)
	else:
		_jag(pts, a, b, 14, 3.5)
		pts.append(b)
	_bolt.points = pts
	_glow.points = pts


func _jag(pts: PackedVector2Array, from: Vector2, to: Vector2, n: int, amp: float) -> void:
	var normal := (to - from).orthogonal().normalized()
	pts.append(from)
	for i in range(1, n):
		pts.append(from.lerp(to, float(i) / n) + normal * randf_range(-amp, amp))


func _process(delta: float) -> void:
	_flicker -= delta
	var striking := _strike_t > 0
	_strike_t -= delta
	if _flicker <= 0 or (striking and _strike_t <= 0):
		_flicker = randf_range(0.02, 0.04) if _strike_t > 0 else randf_range(0.04, 0.09)
		_reroll_arc()
	# the strike runs hot: thicker, whiter bolt and a light flare
	var k := clampf(_strike_t / STRIKE_TIME, 0.0, 1.0)
	_bolt.width = 1.5 + 1.5 * k
	_glow.width = 6.0 + 6.0 * k
	_bolt.default_color = Color(0.8, 0.95, 0.95, 0.95).lerp(Color(1, 1, 0.95, 1), k)
	_light.energy = 0.45 + 0.9 * k


func _on_body_entered(body: Node2D) -> void:
	# Only smelt ore, not ingots
	if not body.is_in_group("ore"):
		return

	var vel: Vector2 = body.linear_velocity
	var pos: Vector2 = body.global_position

	SFX.play(self, SFX.sfx_laser())
	_strike_t = STRIKE_TIME
	_strike_at = to_local(pos)
	_reroll_arc()
	FX.burst(get_parent(), pos, Color(1.0, 0.97, 0.85), 6, 120.0, 0.18, 1.5, 0.0)   # white flash
	FX.burst(get_parent(), pos, Color(1.0, 0.6, 0.25), 10, 70.0, 0.5, 1.5, 420.0)  # molten drips

	# Remove the ore
	body.queue_free()

	# Spawn an ingot with reduced velocity
	# Deferred: adding a physics body inside a body_entered callback errors
	var ingot := _ingot_scene.instantiate() as RigidBody2D
	ingot.kind = "copper" if body.get("kind") in [null, "copper", "grit"] else "iron"   # iron ore, shot, gears melt to iron
	ingot.position = pos
	ingot.linear_velocity = vel * velocity_retention
	get_tree().current_scene.add_child.call_deferred(ingot)
