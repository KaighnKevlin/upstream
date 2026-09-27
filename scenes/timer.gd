extends Node2D
## Clockwork timer: a brass clock on a post. Every INTERVALS[mode] seconds
## its hand comes round to the top, its bell rings, and it trips every
## linked machine within reach (the same set a tripwire or pressure plate
## would, tripwire.gd linked_to): kegs blow, trapdoors drop, pendulums get
## kicked, hoppers dump, tesla coils overload, fans gust, and latched
## catapults let fly. Click it to change the interval (2 / 4 / 8 s).
## Art: tools/art/gen_timer.py (20x34; the hand is drawn here).

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")

const INTERVALS := [2.0, 4.0, 8.0]
const FACE := Vector2(0, -21)

@export var mode := 1

var tripped := 0                 # tests
var _t := 0.0
var _ring := 0.0


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/timer.png")
	spr.centered = false
	spr.offset = Vector2(-10, -33)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	if has_meta("ghost"):
		return
	add_to_group("timers")


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


func _process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t += delta
	_ring = maxf(0.0, _ring - delta)
	if _t >= float(INTERVALS[mode]):
		_t = 0.0
		trip()
	queue_redraw()


func trip() -> void:
	tripped += 1
	_ring = 0.35
	SFX.play_small(self, SFX.sfx_clink(), -4.0, 2.4)
	FX.burst(get_parent(), global_position + Vector2(0, -30), Color(1.0, 0.9, 0.6), 4, 40.0, 0.25, 1.1)
	for n in Tripwire.linked_to(get_tree(), [global_position]):
		n.trigger()


func _draw() -> void:
	if has_meta("ghost"):
		return
	# the hand sweeps once round per interval, straight up when it trips
	var a: float = _t / INTERVALS[mode] * TAU
	var tip := FACE + Vector2(sin(a), -cos(a)) * 4.6
	draw_line(FACE, tip, Color(0.16, 0.14, 0.12), 1.0)
	# the bell shakes when it rings
	if _ring > 0:
		var j := sin(_ring * 80.0) * 1.2
		draw_line(Vector2(-4 + j, -33), Vector2(-6 + j, -35), Color(1.0, 0.9, 0.6, 0.8), 1.0)
		draw_line(Vector2(4 + j, -33), Vector2(6 + j, -35), Color(1.0, 0.9, 0.6, 0.8), 1.0)
	# links while building (like the other triggers)
	var bs := get_node_or_null("/root/BuildSystem")
	if bs and bs.current_build != 0:
		for n in Tripwire.linked_to(get_tree(), [global_position]):
			var d: Vector2 = to_local(n.global_position) - FACE
			var steps := int(d.length() / 6.0)
			for k in steps:
				if k % 2 == 0:
					draw_line(FACE + d * (float(k) / steps), FACE + d * (float(k + 1) / steps), Color(1.0, 0.8, 0.4, 0.45), 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position + FACE) < 10:
			mode = (mode + 1) % INTERVALS.size()
			_t = 0.0
			SFX.play(self, SFX.sfx_clink())
			var scene := get_tree().current_scene
			if scene.has_method("_show_banner"):
				scene._show_banner("TIMER", "every %d s" % int(INTERVALS[mode]))
			get_viewport().set_input_as_handled()
