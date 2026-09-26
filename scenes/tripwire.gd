extends Node2D
## Tripwire: a steel wire strung between two brass stakes (drag from one to
## the other). When a walker (or a flier, low enough) breaks it, the wire
## snaps and trips every linked machine: anything triggerable within LINK
## of either stake. Powder kegs go up, trapdoors drop, wrecking pendulums
## get a hard shove. Then it restrings itself (RESET). It's the wiring for
## Rube Goldberg traps: a wire across the path, a keg under the bridge.
## Linked machines show a dotted line to the nearer stake while you build.
## Anything with a trigger() method in group "triggerable" can be linked.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const LEN_MIN := 24.0
const LEN_MAX := 300.0
const LINK := 150.0
const RESET := 3.0
const STAKE := 12.0              # shortest stake; they reach down to the ground
const STAKE_MAX := 64.0

@export var end_offset := Vector2(96, 0)

var tripped := 0                 # tests
var _cut := 0.0                  # > 0: snapped, restringing
var _sag := 0.0                  # the wire's twang after a restring
var _stakes := [STAKE, STAKE]


func set_end(offset: Vector2) -> void:
	var l := clampf(offset.length(), LEN_MIN, LEN_MAX)
	end_offset = offset.normalized() * l if offset.length() > 0.1 else Vector2(LEN_MIN, 0)
	_fit_stakes()
	queue_redraw()


## Each stake runs from its end of the wire down to the ground below.
func _fit_stakes() -> void:
	if not is_inside_tree() or has_meta("icon"):
		return
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	for i in 2:
		var p := global_position + (end_offset if i == 1 else Vector2.ZERO)
		var d := STAKE
		while d < STAKE_MAX and tm.get_cell_source_id(tm.local_to_map(tm.to_local(p + Vector2(0, d)))) == -1:
			d += 4.0
		_stakes[i] = d


func _ready() -> void:
	z_index = 2
	_fit_stakes()
	if has_meta("ghost"):
		return
	add_to_group("tripwires")


func _linked() -> Array:
	return linked_to(get_tree(), [global_position, global_position + end_offset])


## Every triggerable machine within LINK of any of these points (tripwire
## stakes, a pressure plate).
static func linked_to(tree: SceneTree, points: Array) -> Array:
	var out := []
	for n in tree.get_nodes_in_group("triggerable"):
		if not is_instance_valid(n):
			continue
		for p in points:
			if n.global_position.distance_to(p) < LINK:
				out.append(n)
				break
	return out


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		queue_redraw()
		return
	_sag = maxf(0.0, _sag - delta * 2.0)
	if _cut > 0:
		_cut -= delta
		if _cut <= 0:
			_sag = 1.0
			SFX.play_small(self, SFX.sfx_clink(), -12.0, 1.9)
		queue_redraw()
		return
	var a := global_position
	var b := a + end_offset
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 10.0
		if Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) < r:
			trip()
			return
	if _sag > 0 or _build_mode():
		queue_redraw()


## The wire snaps: everything linked goes.
func trip() -> void:
	if _cut > 0:
		return
	_cut = RESET
	tripped += 1
	SFX.play(self, SFX.sfx_clink(), -2.0, 2.2)
	FX.burst(get_parent(), global_position + end_offset * 0.5, Color(0.85, 0.9, 0.9), 6, 80.0, 0.25, 1.1)
	for n in _linked():
		n.trigger()
	queue_redraw()


func _build_mode() -> bool:
	var bs := get_node_or_null("/root/BuildSystem")
	return bs != null and bs.current_build != 0


func _draw() -> void:
	var b := end_offset
	if has_meta("ghost"):
		_fit_stakes()
	for i in 2:
		var p: Vector2 = b if i == 1 else Vector2.ZERO
		# a brass-capped stake driven into the ground
		draw_line(p, p + Vector2(0, _stakes[i]), Color(0.16, 0.14, 0.12), 3.0)
		draw_line(p + Vector2(0, 1), p + Vector2(0, _stakes[i]), Color(0.45, 0.36, 0.26), 1.0)
		draw_rect(Rect2(p + Vector2(-2, -2), Vector2(4, 3)), Color(0.85, 0.68, 0.38))
	if _cut > 0:
		# snapped: the two ends hang down from their stakes
		var hang := minf(b.length() * 0.4, 18.0)
		draw_line(Vector2.ZERO, Vector2(b.normalized().x * 4, hang), Color(0.7, 0.75, 0.75, 0.9), 1.0)
		draw_line(b, b + Vector2(-b.normalized().x * 4, hang), Color(0.7, 0.75, 0.75, 0.9), 1.0)
	else:
		var mid := b * 0.5 + Vector2(0, sin(Time.get_ticks_msec() * 0.05) * 3.0 * _sag)
		var col := Color(0.78, 0.84, 0.84, 0.9)
		draw_line(Vector2.ZERO, mid, col, 1.0)
		draw_line(mid, b, col, 1.0)
	if not has_meta("ghost") and _build_mode():
		for n in _linked():
			var to: Vector2 = to_local(n.global_position)
			var from := Vector2.ZERO if to.length() < (to - b).length() else b
			var d := to - from
			var steps := int(d.length() / 6.0)
			for k in steps:
				if k % 2 == 0:
					draw_line(from + d * (float(k) / steps), from + d * (float(k + 1) / steps), Color(1.0, 0.8, 0.4, 0.45), 1.0)
