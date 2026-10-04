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
var _flame_art: Sprite2D         # art: the flame, 3 frames stepped by _flick


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the fuse label). The flame hangs behind the basket.
	_flame_art = _spr(preload("res://assets/sprites/igniter_flame.png"), Vector2(-5, -4))
	_flame_art.hframes = 3
	_spr(preload("res://assets/sprites/igniter.png"), Vector2(-9, -26))
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


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


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
	_flame_art.frame = int(_flick * 12) % 3
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
	if Pointer.world(self).distance_to(global_position + Vector2(0, -6)) < 10:
		mode = (mode + 1) % FUSES.size()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	# the brazier and its flame are sprites; only the fuse label is drawn
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, -12), "%ds" % int(FUSES[mode]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.8, 0.55))
