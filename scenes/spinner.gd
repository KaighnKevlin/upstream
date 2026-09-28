extends Node2D
## Spinner: a four-bladed vane hung low over a track, the pinball kind.
## Every piece rolling under it flicks a blade and spins it up, and gives a
## little of its speed for it. While it turns it powers machines in reach
## like a gravity wheel: a steady line (about one a second at a good roll)
## runs it flat out, and it winds down a few seconds after the line stops.
## Put it in a marble run and the run drives its own sling or lift.

const R := 12.0                  # blade length, px
const RATED := 14.0              # rad/s = full power
const KICK := 0.022              # rad/s per (px/s of the piece) per pass
const TAKE := 0.88               # of its speed the piece keeps

var omega := 0.0
var passes := 0                  # tests
var _angle := 0.0
var _seen := {}
var _vane_art: Sprite2D          # art: the four blades, turned to _angle


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the blur disc and the gauge fill)
	_spr(preload("res://assets/sprites/spinner_bracket.png"), Vector2(-11, -27))
	_vane_art = _spr(preload("res://assets/sprites/spinner_vane.png"), Vector2(-14, -14))
	_spr(preload("res://assets/sprites/spinner_hub.png"), Vector2(-4, -4))
	if has_meta("ghost"):
		return
	add_to_group("power_wheels")


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


func power() -> float:
	return clampf(omega / RATED, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze:
			continue
		var p: Vector2 = o.global_position - global_position
		if absf(p.x) < 6 and p.y > -4 and p.y < R + 8 and absf(o.linear_velocity.x) > 30 and _seen.get(o.get_instance_id(), 0.0) < now:
			_seen[o.get_instance_id()] = now + 0.4
			omega += absf(o.linear_velocity.x) * KICK
			o.linear_velocity *= TAKE
			passes += 1
	omega = maxf(0.0, omega - (0.6 + omega * 0.3) * delta)
	_angle += omega * delta
	# the blades turn, and brighten as they blur
	_vane_art.rotation = _angle
	_vane_art.modulate = Color.WHITE.lerp(Color(1.25, 1.2, 1.05), clampf(omega / RATED, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	# the bracket, the blades and the hub are sprites; a faint disc over the
	# blades when it's fast
	var blur := clampf(omega / RATED, 0.0, 1.0)
	if blur > 0.3:
		draw_circle(Vector2.ZERO, R, Color(0.85, 0.65, 0.35, 0.15 * blur))
	# the power gauge's fill, in the slot on the bracket's head
	draw_rect(Rect2(-5, -23, 10 * blur, 1), Color(1.0, 0.85, 0.5))
