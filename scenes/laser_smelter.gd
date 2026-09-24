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


func _make_line(width: float, color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_SHARP
	add_child(l)
	return l


func _reroll_arc() -> void:
	var a := -HALF_SPAN + TIP
	var b := HALF_SPAN - TIP
	var pts := PackedVector2Array([Vector2(a, 0)])
	var n := 14
	for i in range(1, n):
		pts.append(Vector2(lerpf(a, b, float(i) / n), randf_range(-3.5, 3.5)))
	pts.append(Vector2(b, 0))
	_bolt.points = pts
	_glow.points = pts


func _process(delta: float) -> void:
	_flicker -= delta
	if _flicker <= 0:
		_flicker = randf_range(0.04, 0.09)
		_reroll_arc()


func _on_body_entered(body: Node2D) -> void:
	# Only smelt ore, not ingots
	if not body.is_in_group("ore"):
		return

	var vel: Vector2 = body.linear_velocity
	var pos: Vector2 = body.global_position

	SFX.play(self, SFX.sfx_laser())
	FX.burst(get_parent(), pos, Color(1.0, 0.6, 0.25), 8, 80.0, 0.3, 1.5, 200.0)

	# Remove the ore
	body.queue_free()

	# Spawn an ingot with reduced velocity
	# Deferred: adding a physics body inside a body_entered callback errors
	var ingot := _ingot_scene.instantiate() as RigidBody2D
	ingot.position = pos
	ingot.linear_velocity = vel * velocity_retention
	get_tree().current_scene.add_child.call_deferred(ingot)
