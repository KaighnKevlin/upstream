extends Node2D
## Magma pool: molten rock in a basin on the floor of the deepest caves,
## bubbling and glowing (it lights the cave around it). Standing in it
## burns: the prospector and any walker. Ore dropped in melts: copper and
## iron come back up as ingots (a smelter at the bottom of the world),
## anything else sizzles away, and shells and bombs go off.
## Placed by scripts/depths.gd; `width` is in px, origin at the pool's
## surface, left end.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")

const BURN := 4
const BURN_EVERY := 0.5

var width := 48.0
var melted := 0                  # tests: ingots made
var _area: Area2D
var _burn := {}                  # body -> time to its next burn
var _t := 0.0
var _bubble := 0.0
var _surface: Node2D


func _ready() -> void:
	add_to_group("magma")
	z_index = 1
	_surface = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_surface.material = mat
	_surface.draw.connect(_draw_surface)
	add_child(_surface)
	var l := PointLight2D.new()
	l.texture = preload("res://scripts/light_textures.gd").create_radial_light(128)
	l.color = Color(1.0, 0.45, 0.15)
	l.energy = 1.1
	l.texture_scale = maxf(1.6, width / 40.0)
	l.position = Vector2(width * 0.5, -4)
	add_child(l)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2 | 8 | 32
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 14)
	cs.shape = r
	cs.position = Vector2(width * 0.5, 5)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body, CONNECT_DEFERRED)


func _draw_surface() -> void:
	# a rolling crust over bright melt: dark skin, gold cracks, a hot rim
	_surface.draw_rect(Rect2(0, -1, width, 17), Color(0.75, 0.22, 0.05))
	var x := 0.0
	while x < width:
		var h := 1.5 + 1.2 * sin(x * 0.35 + _t * 2.2) + 0.8 * sin(x * 0.9 - _t * 3.1)
		_surface.draw_rect(Rect2(x, -1 - h * 0.5, 2, 2 + h), Color(1.0, 0.62, 0.15))
		if int(x / 2 + floor(_t * 3.0)) % 7 == 0:
			_surface.draw_rect(Rect2(x, 3, 2, 2), Color(1.0, 0.9, 0.5))
		if int(x / 2 + floor(_t * 1.3)) % 5 == 1:
			_surface.draw_rect(Rect2(x, 6, 2, 3), Color(0.35, 0.1, 0.05))   # drifting crust
		x += 2.0
	_surface.draw_rect(Rect2(0, -2, width, 1), Color(1.0, 0.85, 0.45, 0.7))


func _process(delta: float) -> void:
	_t += delta
	_surface.queue_redraw()
	_bubble -= delta
	if _bubble <= 0:
		_bubble = randf_range(0.3, 0.9)
		var at := global_position + Vector2(randf_range(4, width - 4), -1)
		FX.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 3, 40.0, 0.4, 1.5, -40.0)
		if randf() < 0.3:
			SFX.play_small(self, SFX.sfx_clink(), -18.0, 0.4)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	for b in _area.get_overlapping_bodies():
		if b is RigidBody2D:
			continue
		var t: float = _burn.get(b, 0.0) - delta
		if t <= 0:
			t = BURN_EVERY
			if b.has_method("take_damage") and not ("_dying" in b and b._dying):
				b.take_damage(BURN)
				FX.burst(get_parent(), b.global_position + Vector2(0, -6), Color(1.0, 0.5, 0.15), 5, 60.0, 0.3, 1.6, -60.0)
		_burn[b] = t


## Up and out over the nearer rim.
func _toss(x: float) -> Vector2:
	var mid := global_position.x + width * 0.5
	var side := -1.0 if x < mid else 1.0
	var dist := absf((mid + side * (width * 0.5 + 18.0)) - x)
	return Vector2(side * clampf(dist * 1.6, 70.0, 200.0), -300)


func _on_body(b) -> void:   # untyped: a deferred call can arrive after the body was freed
	if not is_instance_valid(b) or not b is RigidBody2D or b.freeze:
		return
	var kind = b.get("kind")
	if b.is_in_group("ingots"):
		b.linear_velocity = _toss(b.global_position.x)     # already smelted: the melt spits it back out
		return
	if kind in ["shell", "bomb"] and b.has_method("explode"):
		b.explode()
		return
	var at: Vector2 = b.global_position
	b.queue_free()
	SFX.play_small(self, SFX.sfx_laser(), -10.0, 0.5)     # the hiss
	FX.burst(get_parent(), at, Color(0.85, 0.85, 0.82, 0.6), 6, 40.0, 0.9, 3.0, -50.0)
	if kind in ["copper", "iron"] and b.is_in_group("ore"):
		var ing: RigidBody2D = preload("res://scenes/ingot.tscn").instantiate()
		ing.kind = kind
		ing.global_position = Vector2(at.x, global_position.y - 12)
		ing.linear_velocity = _toss(at.x)
		get_parent().add_child.call_deferred(ing)
		melted += 1
