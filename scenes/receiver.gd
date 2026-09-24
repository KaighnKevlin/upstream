extends Area2D

const ObjectSprites = preload("res://scripts/object_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

var _spr: Sprite2D

signal ammo_changed(current: int, max_ammo: int)

@export var max_buffer: int = 20
var buffer: int = 0


@onready var _buffer_fill: Polygon2D = $BufferFill

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	_update_bar()

	# Replace polygon with pixel sprite
	if has_node("Sprite"):
		$Sprite.visible = false
	if has_node("Funnel"):
		$Funnel.visible = false
	var spr := Sprite2D.new()
	spr.texture = ObjectSprites.create_receiver_texture()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	spr.visible = false  # the dome plinth's intake grate is the receiver now
	add_child(spr)
	_spr = spr
	if has_node("Label"):
		$Label.visible = false
	# the gauge is a thin strip along the plinth's top rail (world y ~86)
	for n in ["BufferBg", "BufferFill"]:
		get_node(n).position = Vector2(0, 16)
	$BufferBg.polygon = PackedVector2Array([Vector2(-51, -2), Vector2(51, -2), Vector2(51, 2), Vector2(-51, 2)])
	$BufferBg.color = Color(0.16, 0.15, 0.12, 1)
	_update_bar()


func _on_body_entered(body: Node2D) -> void:
	# Only accept ingots (RigidBody2D not in "ore" group)
	if not body is RigidBody2D:
		return
	if body.is_in_group("ore"):
		body.queue_free()  # raw ore is destroyed, not accepted
		return

	# It's an ingot — accept it
	SFX.play(self, SFX.sfx_ammo_received())
	if buffer < max_buffer:
		buffer += 1
		ammo_changed.emit(buffer, max_buffer)
		_update_bar()
		FX.pop(_spr, Vector2(1.2, 0.85), 0.16)
		FX.burst(get_parent(), body.global_position, Color(1.0, 0.85, 0.35), 6, 60.0, 0.35, 1.5)
	body.queue_free()


func consume_ammo() -> bool:
	if buffer > 0:
		buffer -= 1
		ammo_changed.emit(buffer, max_buffer)
		_update_bar()
		return true
	return false


func _update_bar() -> void:
	var fill_ratio := float(buffer) / float(max_buffer)
	var w := 50.0 * fill_ratio  # half-width of fill
	_buffer_fill.polygon = PackedVector2Array([
		Vector2(-50, -1), Vector2(-50 + w * 2, -1),
		Vector2(-50 + w * 2, 1), Vector2(-50, 1),
	])
	# Color shifts from green to red as buffer empties
	# ammo gauge set into the plinth: core-cyan when full, amber, then red
	if fill_ratio > 0.5:
		_buffer_fill.color = Color(0.45, 0.8, 0.85, 1)
	elif fill_ratio > 0.2:
		_buffer_fill.color = Color(0.85, 0.66, 0.3, 1)
	else:
		_buffer_fill.color = Color(0.85, 0.3, 0.2, 1)
