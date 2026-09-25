extends Node2D

## Direction ore is launched after bouncing, in degrees (0 = straight up).
@export_range(-80, 80, 1) var bounce_angle: float = 0.0

## Force multiplier applied on bounce.
@export_range(100, 2000, 10) var bounce_force: float = 700.0

const ObjectSprites = preload("res://scripts/object_sprites.gd")
const SFX = preload("res://scripts/sfx.gd")
const Tech = preload("res://scripts/tech.gd")
const FX = preload("res://scripts/fx.gd")

@onready var _area: Area2D = $Area2D
@onready var _arrow: Polygon2D = $Arrow
@onready var _sprite: Polygon2D = $Sprite
@onready var _angle_handle: Polygon2D = $AngleHandle
@onready var _force_handle: Polygon2D = $ForceHandle
@onready var _force_line: Polygon2D = $ForceLine

var _pixel_sprite: Sprite2D
var _rig: Node2D            # base + animated spring/plate, tilted to the launch angle
var _arc: Node2D
var _top: AnimatedSprite2D

enum DragMode { NONE, BODY, ANGLE, FORCE }
var _selected := false
var _drag_mode: DragMode = DragMode.NONE
var _drag_offset := Vector2.ZERO

const COLOR_NORMAL := Color(0.2, 0.85, 0.3, 1)
const COLOR_SELECTED := Color(0.4, 1.0, 0.5, 1)
const ANGLE_HANDLE_DIST := 45.0
const FORCE_MIN_DIST := 30.0   # the single handle: distance = force
const FORCE_MAX_DIST := 120.0
const PREVIEW_DROP := 420.0     # the arc previews ore dropping onto the plate at this speed
const Trajectory = preload("res://scripts/trajectory_preview.gd")
const HANDLE_GRAB_RADIUS := 14.0


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_hide_handles()

	# Add pixel art sprite
	_build_rig()
	_sprite.visible = false  # hide polygon
	_arrow.color = Color(0.45, 0.8, 0.85, 0.6)  # aim hint, in the cores' cyan

	_update_visuals()


# Physical bounce: only things landing on the plate's top face bounce; they
# reflect off it (keeping their slide along the plate) and the spring adds a
# kick along the normal. Things coming up from underneath pass straight
# through, so a vertical stack of trampolines no longer lifts anything:
# ore has to be *landed* on each one. The player can hold S to drop through.
const RESTITUTION := 0.8      # how much of the incoming normal speed comes back
const KICK := 0.45            # spring kick = bounce_force * KICK, along the normal
const SLIDE_KEEP := 0.95      # tangential speed kept
const MAX_SPEED_K := 1.4      # cap: bounce_force * this (no runaway ping-pong)


## heft: the body's mass. Heavy (iron) ore squashes the spring and gets
## less of its kick back: kick / sqrt(mass).
func bounce_velocity(v: Vector2, heft := 1.0) -> Vector2:
	var n := _launch_dir()
	var vn := v.dot(n)
	var tangent := v - n * vn
	var out := tangent * SLIDE_KEEP + n * (-vn * RESTITUTION + bounce_force * KICK * Tech.mult("springs") / sqrt(maxf(heft, 0.1)))
	return out.limit_length(bounce_force * MAX_SPEED_K)


func _on_body_entered(body: Node2D) -> void:
	var n := _launch_dir()
	var v: Vector2
	if body is RigidBody2D:
		v = body.linear_velocity
	elif body is CharacterBody2D and body.has_method("launch"):
		v = body.velocity
		if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
			return  # dropping through on purpose
	else:
		return
	if v.dot(n) > -15.0:
		return  # coming from underneath or skimming past: no bounce

	SFX.play(self, SFX.sfx_bounce())
	if _top:
		_top.play("bounce")
	else:
		FX.pop(_pixel_sprite, Vector2(1.25, 0.55), 0.18)
	var out := bounce_velocity(v, body.mass if body is RigidBody2D else 1.0)
	if body is RigidBody2D:
		body.linear_velocity = out
	else:
		body.launch(out)


## Brass plate on a coil spring (tools/art/gen_items.py): a fixed base and
## an animated top that crushes and rebounds on each bounce. The node origin
## is the plate's top; the spring's foot is 14px below it.
func _build_rig() -> void:
	var top_tex := load("res://assets/sprites/trampoline_top.png") as Texture2D
	if top_tex == null:
		_pixel_sprite = Sprite2D.new()
		_pixel_sprite.texture = preload("res://assets/sprites/trampoline.png")
		_pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_pixel_sprite.offset = Vector2(0, 8)
		add_child(_pixel_sprite)
		return
	_rig = Node2D.new()
	add_child(_rig)
	var base := Sprite2D.new()
	base.texture = load("res://assets/sprites/trampoline_base.png")
	base.centered = false
	base.offset = Vector2(-14, -2)
	base.position = Vector2(0, 14)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rig.add_child(base)
	_top = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for spec in [["idle", [0]], ["bounce", [1, 2, 3, 4, 5, 6, 7]]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], 20.0)
		sf.set_animation_loop(spec[0], false)
		for i in spec[1]:
			var a := AtlasTexture.new()
			a.atlas = top_tex
			a.region = Rect2(i * 48, 0, 48, 28)
			sf.add_frame(spec[0], a)
	_top.sprite_frames = sf
	_top.centered = false
	_top.offset = Vector2(-24, -26)
	_top.position = Vector2(0, 14)
	_top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_top.play("idle")
	_rig.add_child(_top)


func _launch_dir() -> Vector2:
	var angle_rad := deg_to_rad(bounce_angle - 90)
	return Vector2(cos(angle_rad), sin(angle_rad))


func _angle_handle_global() -> Vector2:
	return _force_handle_global()  # one handle does both now


func _force_handle_global() -> Vector2:
	var dist := remap(bounce_force, 100, 2000, FORCE_MIN_DIST, FORCE_MAX_DIST)
	return global_position + _launch_dir() * dist


func _mouse_near(point: Vector2) -> bool:
	return get_global_mouse_position().distance_to(point) < HANDLE_GRAB_RADIUS


func _mouse_over_body() -> bool:
	var mouse := get_global_mouse_position()
	return absf(mouse.x - global_position.x) < 22 and absf(mouse.y - global_position.y) < 8


func select() -> void:
	_selected = true
	_sprite.color = COLOR_SELECTED
	_show_handles()
	_update_visuals()


func deselect() -> void:
	_selected = false
	_drag_mode = DragMode.NONE
	_sprite.color = COLOR_NORMAL
	_hide_handles()


func _input(event: InputEvent) -> void:
	# Escape always deselects
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_Q):
		if _selected:
			deselect()
			return

	# Skip if in build mode (guard for editor preview where autoloads don't exist)
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		if _selected:
			deselect()
		return

	# Mouse button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# If selected, check handle clicks first
			if _selected:
				if _mouse_near(_force_handle_global()):
					_drag_mode = DragMode.ANGLE  # direction = angle, distance = force
					get_viewport().set_input_as_handled()
					return
				# Clicking the body while selected = start dragging body
				if _mouse_over_body():
					_drag_mode = DragMode.BODY
					_drag_offset = global_position - get_global_mouse_position()
					get_viewport().set_input_as_handled()
					return
				# Clicked elsewhere — deselect
				deselect()
			else:
				# Not selected — click to select
				if _mouse_over_body():
					select()
					get_viewport().set_input_as_handled()
		else:
			# Mouse released — stop dragging
			_drag_mode = DragMode.NONE

	# Mouse motion — handle dragging
	if event is InputEventMouseMotion and _drag_mode != DragMode.NONE:
		var mouse := get_global_mouse_position()
		match _drag_mode:
			DragMode.BODY:
				global_position = mouse + _drag_offset
			DragMode.ANGLE:
				var dir := (mouse - global_position)
				if dir.length() > 5:
					var raw_angle := rad_to_deg(dir.angle() + PI / 2)
					bounce_angle = clampf(raw_angle, -80, 80)
					bounce_force = clampf(remap(dir.length(), FORCE_MIN_DIST, FORCE_MAX_DIST, 100.0, 2000.0), 100, 2000)
			DragMode.FORCE:
				var dist := mouse.distance_to(global_position)
				bounce_force = clampf(
					remap(dist, FORCE_MIN_DIST, FORCE_MAX_DIST, 100.0, 2000.0),
					100, 2000)
		_update_visuals()
		get_viewport().set_input_as_handled()


func _show_handles() -> void:
	if _force_handle.polygon.size() != 12:  # round handle, like the tapper's and catapult's
		var pts := PackedVector2Array()
		for k in 12:
			pts.append(Vector2.from_angle(k * TAU / 12) * 5)
		_force_handle.polygon = pts
	_force_handle.visible = true
	_angle_handle.visible = false
	_force_line.visible = false
	if _arc == null:
		_arc = Trajectory.new()
		_arc.tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer")
		add_child(_arc)
	_arc.visible = true
	_update_arc()


func _hide_handles() -> void:
	_angle_handle.visible = false
	_force_handle.visible = false
	_force_line.visible = false
	if _arc:
		_arc.visible = false


## Preview: where ore dropped straight onto the plate would bounce to.
func _update_arc() -> void:
	if _arc == null:
		return
	_arc.origin = global_position + _launch_dir() * 10.0
	_arc.velocity = bounce_velocity(Vector2(0, PREVIEW_DROP))
	_arc.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _update_visuals() -> void:
	# Tilt the platform perpendicular to launch direction
	_sprite.rotation = deg_to_rad(bounce_angle)
	if _pixel_sprite:
		_pixel_sprite.rotation = deg_to_rad(bounce_angle)
	if _rig:
		_rig.rotation = deg_to_rad(bounce_angle)
	_area.rotation = deg_to_rad(bounce_angle)  # the catch zone lies along the plate

	var dir := _launch_dir()
	var perp := dir.rotated(PI / 2)

	# Arrow
	var tip := dir * 30.0
	_arrow.polygon = PackedVector2Array([
		tip,
		tip - dir * 12 + perp * 6,
		tip - dir * 12 - perp * 6,
	])

	# Angle handle position
	_angle_handle.position = dir * ANGLE_HANDLE_DIST

	# The handle: direction = angle, distance = force
	var force_dist := remap(bounce_force, 100, 2000, FORCE_MIN_DIST, FORCE_MAX_DIST)
	_force_handle.position = dir * force_dist
	_force_handle.color = Color(1.0, 0.7, 0.2)
	_update_arc()

	# Line connecting them
	var line_start := dir * (ANGLE_HANDLE_DIST + 10)
	var line_end := dir * (force_dist - 10)
	if line_start.distance_to(line_end) > 5:
		_force_line.polygon = PackedVector2Array([
			line_start - perp * 1, line_end - perp * 1,
			line_end + perp * 1, line_start + perp * 1,
		])
	else:
		_force_line.polygon = PackedVector2Array()
