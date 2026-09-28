extends Node2D
## Flywheel: a heavy iron disc on a frame, belted to the machines around it
## like a gravity wheel. It stores power: while a gravity wheel in reach is
## running at full power it spins up on the surplus, and when the feed dries
## up it keeps the machines it reaches running, slowing as they draw on it
## (the more machines, the faster it runs down). The accumulator of the
## marble machine: smooths a bursty feed into steady power.

const Power = preload("res://scripts/power.gd")
const CHARGE := 0.12             # spin gained per second off a full-power wheel
const IDLE := 0.008              # lost per second, bearing drag
const PER_USER := 0.012          # lost per second per machine drawing on it

var spin := 0.0                  # 0..1: stored energy
var _angle := 0.0
var _scan := 0.0
var _users := 0
var _feeding := false
var _disc: Sprite2D              # turns by _angle


func _ready() -> void:
	z_index = 1
	# sprites first, so ghosts and build-bar icons get them too; behind our
	# own _draw (the charge arc)
	var fr := Sprite2D.new()
	fr.texture = preload("res://assets/sprites/flywheel_frame.png")
	fr.centered = false
	fr.offset = Vector2(-20, -6)
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fr.show_behind_parent = true
	add_child(fr)
	_disc = Sprite2D.new()
	_disc.texture = preload("res://assets/sprites/flywheel_disc.png")   # centred on the axle
	_disc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_disc.show_behind_parent = true
	add_child(_disc)
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


## As a power source: full until it's run down to a third, then fading.
func power() -> float:
	return clampf(spin * 1.5, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_scan -= delta
	if _scan <= 0:
		_scan = 0.25
		_feeding = false
		for w in get_tree().get_nodes_in_group("power_wheels"):
			if w != self and is_instance_valid(w) and not w.has_method("_is_flywheel") \
					and w.global_position.distance_to(global_position) <= Power.REACH and w.power() >= 0.95:
				_feeding = true
		_users = 0
		for u in get_tree().get_nodes_in_group("power_users"):
			if is_instance_valid(u) and u.global_position.distance_to(global_position) <= Power.REACH:
				_users += 1
	if _feeding:
		spin = minf(1.0, spin + CHARGE * delta)
	else:
		spin = maxf(0.0, spin - (IDLE + PER_USER * _users) * delta)
	_angle += spin * 9.0 * delta
	queue_redraw()


func _is_flywheel() -> bool:
	return true


func _draw() -> void:
	_disc.rotation = _angle      # frame and disc are sprites (see _ready)
	# the charge, as a brass arc round the rim
	if spin > 0.01:
		draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * spin, 32, Color(1.0, 0.8, 0.35, 0.85), 2.0)
