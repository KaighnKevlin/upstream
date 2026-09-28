extends Node2D
## Noise meter: how much racket the machine is making. Every marble that
## hits something hard (a sharp drop in its speed) adds to it in proportion,
## a bell adds a lot (NoiseMeter.add), and it slowly dies away. Each time it
## climbs past another STEP, `attract` fires: something down in the dark has
## heard. The Factorio pollution idea, for marbles: the busier the machine,
## the more it draws in. Draws a gauge at its position.

const STEP := 100.0
const DECAY := 0.05              # fraction lost per second
const IMPACT := 0.012            # noise per px/s of speed lost in a knock

signal attract(level: int)

var level := 0.0
var peak_steps := 0              # how many thresholds have been crossed (tests)
var _prev := {}                  # ore id -> last speed


static func add(tree: SceneTree, amount: float) -> void:
	for m in tree.get_nodes_in_group("noise_meters"):
		m.level += amount


func _ready() -> void:
	z_index = 5
	add_to_group("noise_meters")


func _physics_process(delta: float) -> void:
	var seen := {}
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o):
			continue
		var id: int = o.get_instance_id()
		var v: float = o.linear_velocity.length()
		var was: float = _prev.get(id, v)
		if was - v > 60.0:
			level += (was - v) * IMPACT * o.mass
		_prev[id] = v
		seen[id] = true
	for id in _prev.keys():
		if not seen.has(id):
			_prev.erase(id)
	level = maxf(0.0, level - level * DECAY * delta)
	var steps := int(level / STEP)
	if steps > peak_steps:
		peak_steps = steps
		attract.emit(steps)
	elif steps < peak_steps - 1:
		peak_steps = steps + 1      # it has to get noisy again to draw more
	queue_redraw()


func _draw() -> void:
	var w := 220.0
	var f := clampf(fmod(level, STEP) / STEP, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-4, -4, w + 8, 22), Color(0.08, 0.06, 0.05, 0.85))
	draw_rect(Rect2(-4, -4, w + 8, 22), Color(0.72, 0.55, 0.3), false, 1.5)
	var hot := Color(0.95, 0.55, 0.25).lerp(Color(1.0, 0.25, 0.15), clampf(level / (STEP * 4.0), 0.0, 1.0))
	draw_rect(Rect2(0, 0, w * f, 14), hot)
	draw_string(font, Vector2(4, 11), "CLATTER %d" % int(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.95, 0.85))
	draw_string(font, Vector2(w - 70, 11), "heard x%d" % peak_steps, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.95, 0.85))
