extends Node2D
## A thunderstorm (a random event; F7 in sandbox). Rain sweeps across the
## view, and every couple of seconds lightning strikes. It goes for tall
## metal first: a tesla coil it hits is charged full, a magnet or turret is
## just a lightning rod. Otherwise it hits something out in the open: an
## enemy (fried), loose ore (smelted to an ingot where it lies), you, or
## the bare ground. The screen flashes and the camera shakes.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const STRIKE_DAMAGE := 7
const SPLASH := 38.0

var duration := 18.0
var strikes := 0         # tests
var charged := 0
var smelted := 0
var _t := 0.0
var _next := 1.5
var _rain: CPUParticles2D
var _flash: ColorRect
var _bolts := []         # [points, life]


func _ready() -> void:
	z_index = 6
	_rain = CPUParticles2D.new()
	_rain.amount = 650
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(900, 10)
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2(0, 400)
	_rain.initial_velocity_min = 620.0
	_rain.initial_velocity_max = 760.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 1.0
	_rain.color = Color(0.66, 0.74, 0.9, 0.6)
	var streak := Image.create(1, 10, false, Image.FORMAT_RGBA8)
	streak.fill(Color.WHITE)
	_rain.texture = ImageTexture.create_from_image(streak)
	_rain.local_coords = false
	add_child(_rain)
	var layer := CanvasLayer.new()
	layer.layer = 4
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.size = Vector2(4000, 4000)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	add_child(layer)


func _physics_process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		_rain.global_position = cam.get_screen_center_position() + Vector2(120, -420)
	if _t > duration:
		_rain.emitting = false
		if _t > duration + 1.2:
			queue_free()
		return
	_next -= delta
	if _next <= 0:
		_next = randf_range(1.2, 2.6)
		_strike()
	for b in _bolts:
		b[1] -= delta
	_bolts = _bolts.filter(func(b): return b[1] > 0)
	queue_redraw()


func _visible_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size / (cam.zoom if cam else Vector2.ONE)
	var c := cam.get_screen_center_position() if cam else Vector2(1200, 0)
	return Rect2(c - size * 0.5, size)


## Picks where the bolt lands: tall metal first, then things in the open.
func _pick_target() -> Vector2:
	var view := _visible_rect().grow(200)
	var rods := []
	for n in get_tree().get_nodes_in_group("power_users"):
		var f: String = n.get_script().resource_path.get_file() if n.get_script() else ""
		if f in ["tesla.gd", "magnet.gd"] and view.has_point(n.global_position):
			rods.append(n)
	if not rods.is_empty() and randf() < 0.6:
		var r = rods.pick_random()
		return r.to_global(r.ELECTRODE) if "ELECTRODE" in r else r.to_global(r.FACE)
	var opts := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not ("_dying" in e and e._dying) and view.has_point(e.global_position) and e.global_position.y < 120:
			opts.append(e.hit_center() if e.has_method("hit_center") else e.global_position)
	if not opts.is_empty() and randf() < 0.6:
		return opts.pick_random()
	# open ground somewhere in view: the first solid cell down a random column
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	var x := randf_range(view.position.x + 150, view.end.x - 150)
	if tm:
		var col := tm.local_to_map(tm.to_local(Vector2(x, 0))).x
		for row in 40:
			if tm.get_cell_source_id(Vector2i(col, row)) != -1:
				return tm.to_global(tm.map_to_local(Vector2i(col, row))) + Vector2(0, -8)
	return Vector2(x, 90)


func _strike() -> void:
	var at := _pick_target()
	strikes += 1
	var top := Vector2(at.x + randf_range(-120, 120), at.y - 520)
	var pts := PackedVector2Array([top])
	var n := 14
	for k in range(1, n):
		var p := top.lerp(at, float(k) / n)
		pts.append(p + Vector2(randf_range(-14, 14), 0))
	pts.append(at)
	_bolts.append([pts, 0.28])
	# a fork
	var mid: Vector2 = pts[n / 2]
	_bolts.append([PackedVector2Array([mid, mid + Vector2(randf_range(-60, 60), 70), mid + Vector2(randf_range(-90, 90), 130)]), 0.2])
	_flash.color.a = 0.55
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	FX.shake(self, 5.0, 0.3)
	FX.burst(get_parent(), at, Color(0.8, 0.92, 1.0), 16, 170.0, 0.3, 1.8)
	FX.burst(get_parent(), at, Color(0.4, 0.38, 0.4, 0.6), 6, 40.0, 1.0, 3.0, -40.0)
	var light := PointLight2D.new()
	light.texture = LightTextures.create_radial_light(256)
	light.color = Color(0.7, 0.85, 1.0)
	light.energy = 3.0
	light.texture_scale = 3.0
	light.global_position = at
	get_parent().add_child(light)
	var lt := light.create_tween()
	lt.tween_property(light, "energy", 0.0, 0.4)
	lt.tween_callback(light.queue_free)
	var scene := get_tree().current_scene
	SFX.play(scene, SFX.sfx_mine_break(), 2.0, 0.35)
	SFX.play(scene, SFX.sfx_laser(), -2.0, 0.4)
	# what it hit
	for n2 in get_tree().get_nodes_in_group("power_users"):
		if n2.get_script() and n2.get_script().resource_path.get_file() == "tesla.gd" \
				and n2.to_global(n2.ELECTRODE).distance_to(at) < 20.0:
			n2.charge = n2.MAX_CHARGE
			charged += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		if c.distance_to(at) < SPLASH:
			e.take_damage(STRIKE_DAMAGE)
	for o in get_tree().get_nodes_in_group("ore"):
		if is_instance_valid(o) and not o.freeze and o.global_position.distance_to(at) < SPLASH \
				and o.get("kind") in ["copper", "iron", "scrap", "grit"]:
			var ingot: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
			ingot.kind = "copper" if o.get("kind") in ["copper", "grit"] else "iron"
			ingot.global_position = o.global_position
			ingot.linear_velocity = Vector2(randf_range(-60, 60), -160)
			o.queue_free()
			get_parent().add_child.call_deferred(ingot)
			smelted += 1
	var p := scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(at) < SPLASH and p.has_method("take_damage"):
		p.take_damage(10)


func _draw() -> void:
	for b in _bolts:
		var pts: PackedVector2Array = b[0]
		var a: float = clampf(b[1] / 0.28, 0.0, 1.0)
		var local := PackedVector2Array()
		for q in pts:
			local.append(to_local(q))
		draw_polyline(local, Color(0.55, 0.75, 1.0, 0.35 * a), 7.0)
		draw_polyline(local, Color(0.95, 0.98, 1.0, a), 2.0)
