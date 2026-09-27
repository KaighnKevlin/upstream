extends Node2D
## Fireworks over the dome when a wave is cleared: brass rockets hiss up
## from the dome in a ragged volley, trailing sparks, and burst at the top
## of their climb into a shower of gold, cyan, copper or green, each with a
## flash of light and a pop. Frees itself when the last spark is done.

const FX = preload("res://scripts/fx.gd")
const SFX = preload("res://scripts/sfx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")

const COLOURS := [Color(1.0, 0.82, 0.35), Color(0.45, 0.9, 1.0), Color(1.0, 0.5, 0.25), Color(0.55, 1.0, 0.5), Color(1.0, 0.95, 0.85)]
const GRAVITY := 260.0

var launched := 0                # tests
var burst := 0
var _rockets := []               # [position, velocity, colour]


## A volley of `count` rockets from `from`, over `spread` seconds.
static func volley(parent: Node, from: Vector2, count := 7, spread := 2.2) -> Node2D:
	var f: Node2D = load("res://scripts/fireworks.gd").new()
	f.z_index = 4
	parent.add_child(f)
	for k in count:
		parent.get_tree().create_timer(randf() * spread).timeout.connect(f._launch.bind(from + Vector2(randf_range(-40, 40), -30)))
	parent.get_tree().create_timer(spread + 4.0).timeout.connect(f.queue_free)
	return f


func _launch(at: Vector2) -> void:
	if not is_inside_tree():
		return
	_rockets.append([at, Vector2(randf_range(-90, 90), randf_range(-360, -300)), COLOURS.pick_random()])
	launched += 1
	SFX.play_small(self, SFX.sfx_laser(), -14.0, 1.8)


func _process(delta: float) -> void:
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Array = _rockets[i]
		r[1].y += GRAVITY * delta
		r[0] += r[1] * delta
		if randf() < 0.7:
			FX.burst(get_parent(), r[0], Color(1.0, 0.8, 0.5, 0.8), 1, 12.0, 0.35, 1.0, 40.0)
		if r[1].y > -40.0:
			_pop(r[0], r[2])
			_rockets.remove_at(i)


func _pop(at: Vector2, col: Color) -> void:
	burst += 1
	FX.burst(get_parent(), at, col, 70, 210.0, 1.2, 2.8, 50.0)
	FX.burst(get_parent(), at, col.lerp(Color.WHITE, 0.5), 30, 110.0, 0.9, 2.2, 40.0)
	FX.burst(get_parent(), at, Color(1, 1, 1, 0.95), 14, 50.0, 0.35, 2.2)
	var l := PointLight2D.new()
	l.texture = LightTextures.create_radial_light(128)
	l.color = col
	l.energy = 1.8
	l.texture_scale = 3.0
	l.global_position = at
	get_parent().add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "energy", 0.0, 0.7)
	t.tween_callback(l.queue_free)
	SFX.play_small(self, SFX.sfx_turret_fire(), -10.0, randf_range(1.5, 2.0))
