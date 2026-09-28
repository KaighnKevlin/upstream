extends Node2D
## Igniter: a brazier hung over a track. Every piece that rolls under its
## flame is lit: it trails sparks and, after its fuse (click: 1 / 2 / 3 s),
## or at once if it touches a walker, bursts, hurting and throwing walkers
## close by. The piece is spent. Turns a marble line into a bomb line: time
## the fuse to the run, or send them at the walkers. Copper and iron alike;
## the blast is small (no crater), so a track survives its own bombs.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const FUSES := [1.0, 2.0, 3.0]
const RADIUS := 44.0
const DAMAGE := 8
const TOUCH := 14.0              # a lit piece this close to a walker goes off

@export var mode := 1

var lit := 0                     # tests
var burst := 0
var _fuse := {}                  # ore -> seconds left
var _flick := 0.0


func _ready() -> void:
	z_index = 2
	if has_meta("ghost"):
		return
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 22)
	cs.shape = r
	cs.position = Vector2(0, 10)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_light)


func _light(b) -> void:
	if not (b is RigidBody2D) or not b.is_in_group("ore") or _fuse.has(b) or b.has_meta("lit"):
		return
	b.set_meta("lit", true)
	_fuse[b] = FUSES[mode]
	b.modulate = Color(1.5, 1.1, 0.8)
	lit += 1
	SFX.play_small(self, SFX.sfx_clink(), -12.0, 2.2)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_flick += delta
	if int(_flick * 12) % 2 == 0:
		queue_redraw()
	if _fuse.is_empty():
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	for o in _fuse.keys():
		if not is_instance_valid(o):
			_fuse.erase(o)
			continue
		_fuse[o] -= delta
		if randf() < 0.5:
			FX.burst(o.get_parent(), o.global_position, Color(1.0, 0.8, 0.35), 1, 40.0, 0.2, 1.0, -40.0)
		var boom: bool = _fuse[o] <= 0.0
		if not boom:
			for e in enemies:
				if is_instance_valid(e) and not ("_dying" in e and e._dying):
					var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
					var reach: float = TOUCH + (e.hit_radius() if e.has_method("hit_radius") else 10.0)
					if c.distance_to(o.global_position) < reach:
						boom = true
						break
		if boom:
			_fuse.erase(o)
			_blast(o)


func _blast(o: RigidBody2D) -> void:
	burst += 1
	var at := o.global_position
	var parent := o.get_parent()
	FX.burst(parent, at, Color(1.0, 0.9, 0.5), 16, 220.0, 0.3, 2.0)
	FX.burst(parent, at, Color(1.0, 0.5, 0.15), 10, 150.0, 0.45, 2.4)
	FX.burst(parent, at, Color(0.3, 0.28, 0.3, 0.6), 6, 40.0, 1.2, 4.0, -40.0)
	FX.shake(self, 3.0, 0.2)
	SFX.play(get_tree().current_scene, SFX.sfx_turret_fire(), -4.0, 0.8)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or not e.has_method("take_damage"):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var d := c.distance_to(at)
		var reach: float = RADIUS + (e.hit_radius() if e.has_method("hit_radius") else 10.0) * 0.5
		if d < reach:
			e.take_damage(maxi(2, int(DAMAGE * (1.0 - d / (reach * 1.4)))))
			if is_instance_valid(e) and e.has_method("knock"):
				e.knock((c - at).normalized() * 220.0 + Vector2(0, -200))
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and p.global_position.distance_to(at) < RADIUS * 0.7 and p.has_method("launch"):
		p.launch((p.global_position - at).normalized() * 260.0 + Vector2(0, -160))
	o.queue_free()


func _input(event: InputEvent) -> void:
	if has_meta("ghost") or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -6)) < 10:
		mode = (mode + 1) % FUSES.size()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var iron := Color(0.42, 0.44, 0.5)
	# the hanger bracket, the basket, the flame licking down at the track
	draw_line(Vector2(0, -22), Vector2(0, -12), dark, 3.0)
	draw_line(Vector2(0, -22), Vector2(0, -12), iron, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -12), Vector2(8, -12), Vector2(5, -3), Vector2(-5, -3)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -11), Vector2(7, -11), Vector2(4, -4), Vector2(-4, -4)]), iron)
	for x in [-4.0, 0.0, 4.0]:
		draw_line(Vector2(x, -11), Vector2(x * 0.6, -4), dark, 1.0)
	var fl := 1.0 + (0.25 if int(_flick * 12) % 2 == 0 else -0.1)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(0, 8 * fl)]), Color(1.0, 0.55, 0.15, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -3), Vector2(2, -3), Vector2(0, 4 * fl)]), Color(1.0, 0.95, 0.6))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, -12), "%ds" % int(FUSES[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
