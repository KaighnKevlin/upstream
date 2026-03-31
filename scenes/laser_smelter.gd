extends Node2D

const LightTextures = preload("res://scripts/light_textures.gd")
const SFX = preload("res://scripts/sfx.gd")

## How much velocity the ore retains after passing through (0.0–1.0).
@export_range(0.1, 0.9, 0.05) var velocity_retention: float = 0.6

var _ingot_scene: PackedScene = preload("res://scenes/ingot.tscn")

@onready var _area: Area2D = $Area2D


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)

	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(128)
	light.texture_scale = 1.5
	light.energy = 0.8
	light.color = Color(1.0, 0.3, 0.2)
	add_child(light)


func _on_body_entered(body: Node2D) -> void:
	# Only smelt ore, not ingots
	if not body.is_in_group("ore"):
		return

	var vel: Vector2 = body.linear_velocity
	var pos: Vector2 = body.global_position

	SFX.play(self, SFX.sfx_laser())

	# Remove the ore
	body.queue_free()

	# Spawn an ingot with reduced velocity
	var ingot := _ingot_scene.instantiate() as RigidBody2D
	ingot.global_position = pos
	get_tree().current_scene.add_child(ingot)
	ingot.linear_velocity = vel * velocity_retention
