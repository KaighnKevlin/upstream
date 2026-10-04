extends Node2D
## Latch: a brass lever in a little iron box that remembers. It has two
## input posts, SET (left) and RESET (right), each its own triggerable
## stud, so a sensor's pull-wire can be dropped on either one. SET throws
## the lever up, RESET brings it down; a signal that finds it already that
## way does nothing. Every time the lever actually moves, it fires what's
## at the end of its own output wire (drag the wire's end). Click the body
## to flip it, or a post to set / reset it by hand.
##
## With a points switch on its output: a load cell under a bin SETs it when
## the bin is full (the stream swings away), something else RESETs it when
## the bin wants more (the stream swings back). It remembers in between.
##
## Which post: a sensor fires everything in reach (tripwire.gd LINK), which
## usually takes in both posts. The latch works out who fired and takes the
## post nearer that sensor's wire end (or the sensor itself); if it can't
## tell, or the wire sits dead between the two, the lever just flips.
## Output goes only from the wire's end, never its own posts; inputs that
## arrive within COOL of its own output are dropped, so two latches (or a
## latch and a relay hub) wired into each other can't ping-pong for ever.

const SFX = preload("res://scripts/sfx.gd")
const Tripwire = preload("res://scenes/tripwire.gd")
const SET_AT := Vector2(-22, 14)     # the posts, from the body
const RESET_AT := Vector2(22, 14)
const COOL := 0.1                    # s after its own output it won't listen
const SENDERS_EVERY := 1.0           # s between looks for nearby sensors
const SENDER_R := 700.0

@export var on := false
@export var wire_to := Vector2(0, -70)   # drag its end to what it should throw

var changes := 0                 # tests: lever moves
var fired := 0                   # tests: outputs
var sets := 0                    # tests: signals taken on each post
var resets := 0
var flips := 0                   # tests: ambiguous signals (flipped)
var dropped := 0                 # tests: inputs ignored in the cool-down
var _set_post: Node2D
var _reset_post: Node2D
var _hits := {}                  # post hit this frame: true = SET, false = RESET
var _pending := false
var _senders: Array = []
var _seen := {}                  # sender id -> its fire counter last frame
var _look := 0.0
var _cool := 0.0                 # > 0: just fired, not listening (game time)
var _lever := 0.0                # 0 down .. 1 up, drawn
var _flash := 0.0
var _flash_set := 0.0
var _flash_reset := 0.0
var _dragging := false
var _box: Sprite2D               # art: the iron box and its posts; brightens as it fires
var _lever_art: Sprite2D         # the brass lever, swung about its pivot


## A post: a stud the latch listens on.
class Post extends Node2D:
	var latch
	var is_set := true

	func trigger() -> void:
		latch._hit(is_set)


func _ready() -> void:
	z_index = 2
	_lever = 1.0 if on else 0.0
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the wire, the lamp, the labels, the posts' flashes)
	_box = _spr(preload("res://assets/sprites/latch_box.png"), Vector2(-28, -14))
	_lever_art = _spr(preload("res://assets/sprites/latch_lever.png"), Vector2(-4, -4))
	_lever_art.position = Vector2(-7, 0)
	_pose()
	if has_meta("ghost"):
		return
	_set_post = _post(SET_AT, true)
	_reset_post = _post(RESET_AT, false)


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.show_behind_parent = true
	add_child(sp)
	return sp


func _pose() -> void:
	_lever_art.rotation = lerpf(0.75, -0.75, _lever)
	_lever_art.self_modulate = Color.WHITE.lerp(Color(1.45, 1.35, 1.1), _flash)
	_box.self_modulate = Color.WHITE.lerp(Color(1.3, 1.22, 1.05), _flash * 0.5)


func _post(at: Vector2, is_set: bool) -> Node2D:
	var p := Post.new()
	p.latch = self
	p.is_set = is_set
	p.position = at
	p.add_to_group("triggerable")
	add_child(p)
	return p


func _hit(is_set: bool) -> void:
	if _set_post == null:
		return
	if _cool > 0:
		dropped += 1
		return
	_hits[is_set] = true
	if not _pending:
		_pending = true
		_resolve.call_deferred()


## Everything that reached us this frame, sorted into set / reset / flip.
func _resolve() -> void:
	_pending = false
	if _hits.is_empty():
		return
	var want: int                         # 1 set, 0 reset, -1 flip
	if _hits.size() == 1:
		want = 1 if _hits.has(true) else 0
	else:
		want = _nearer_post()
	_hits.clear()
	_snapshot()
	if want == 1:
		sets += 1
		_flash_set = 1.0
		set_on(true)
	elif want == 0:
		resets += 1
		_flash_reset = 1.0
		set_on(false)
	else:
		flips += 1
		_flash_set = 1.0
		_flash_reset = 1.0
		set_on(not on)


## Both posts were hit at once: which one did the sender mean? The one
## nearer a link point (body or wire end) of a sensor that just fired.
func _nearer_post() -> int:
	var sp := _set_post.global_position
	var rp := _reset_post.global_position
	var ds := INF
	var dr := INF
	for n in _senders:
		if not is_instance_valid(n) or not _seen.has(n.get_instance_id()):
			continue
		if _count(n) == _seen[n.get_instance_id()]:
			continue
		for p in _link_points(n):
			if minf(p.distance_to(sp), p.distance_to(rp)) >= Tripwire.LINK:
				continue
			ds = minf(ds, p.distance_to(sp))
			dr = minf(dr, p.distance_to(rp))
	if ds < dr - 2.0:
		return 1
	if dr < ds - 2.0:
		return 0
	return -1


static func _count(n: Object) -> int:
	var c := -1
	for k in ["fired", "rings", "tripped"]:
		if k in n and typeof(n.get(k)) == TYPE_INT:
			c = maxi(c, 0) + n.get(k)
	return c


static func _link_points(n: Node2D) -> Array:
	var out := [n.global_position]
	for k in ["wire_to", "end_offset", "wire_1", "wire_2", "wire_3"]:
		if k in n and n.get(k) is Vector2 and n.get(k) != Vector2.ZERO:
			out.append(n.global_position + n.get(k))
	return out


func _snapshot() -> void:
	for n in _senders:
		if is_instance_valid(n):
			_seen[n.get_instance_id()] = _count(n)


func _find_senders() -> void:
	_senders.clear()
	var par := get_parent()
	if par == null:
		return
	for c in par.get_children():
		if c != self and c is Node2D and c.global_position.distance_to(global_position) < SENDER_R and _count(c) >= 0:
			_senders.append(c)


func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	changes += 1
	SFX.play_small(self, SFX.sfx_latch(), -12.0, 1.15 if on else 0.9)
	fire()


func fire() -> void:
	fired += 1
	_flash = 1.0
	_cool = COOL
	for n in Tripwire.linked_to(get_tree(), [global_position + wire_to]):
		if n != self and n != _set_post and n != _reset_post and n.has_method("trigger"):
			n.trigger()


func _physics_process(delta: float) -> void:
	if _set_post == null:
		return
	_cool -= delta
	_look -= delta
	if _look <= 0:
		_look = SENDERS_EVERY
		_find_senders()
	if not _pending:
		_snapshot()
	var target := 1.0 if on else 0.0
	var was := [_lever, _flash, _flash_set, _flash_reset]
	_lever = move_toward(_lever, target, delta * 8.0)
	_flash = maxf(0.0, _flash - delta * 3.0)
	_flash_set = maxf(0.0, _flash_set - delta * 3.0)
	_flash_reset = maxf(0.0, _flash_reset - delta * 3.0)
	if was != [_lever, _flash, _flash_set, _flash_reset]:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := Pointer.world(self) - global_position
		if event.pressed and m.distance_to(wire_to) < 8:
			_dragging = true
			get_viewport().set_input_as_handled()
		elif event.pressed and m.distance_to(SET_AT) < 7:
			_flash_set = 1.0
			set_on(true)
			get_viewport().set_input_as_handled()
		elif event.pressed and m.distance_to(RESET_AT) < 7:
			_flash_reset = 1.0
			set_on(false)
			get_viewport().set_input_as_handled()
		elif event.pressed and absf(m.x) < 15 and m.y > -14 and m.y < 12:
			set_on(not on)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		wire_to = Pointer.world(self) - global_position
		queue_redraw()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	var brass := Color(0.85, 0.65, 0.35)
	var hot := Color(1, 0.95, 0.7)
	var font := ThemeDB.fallback_font
	# output wire, from the top of the box
	if wire_to != Vector2.ZERO:
		var mid := wire_to * 0.5 + Vector2(0, 14)
		draw_polyline(PackedVector2Array([Vector2(0, -12), mid, wire_to]), Color(0.55, 0.5, 0.42, 0.8), 1.0)
		draw_circle(wire_to, 3.0, dark)
		draw_circle(wire_to, 2.0, brass.lerp(hot, _flash))
	# the posts (art), flashing as a signal lands on them, and their labels
	for s in [[SET_AT, _flash_set, "S"], [RESET_AT, _flash_reset, "R"]]:
		var at: Vector2 = s[0]
		if s[1] > 0.0:
			draw_circle(at, 3.5, Color(hot, s[1] * 0.8))
		draw_string(font, at + Vector2(-2.5, 11), s[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.9, 0.8, 0.55))
	_pose()
	# the lamp (in the art's bezel): lit while set
	var lamp := Vector2(8, -6)
	draw_circle(lamp, 2.2, Color(1.0, 0.75, 0.3) if on else Color(0.25, 0.2, 0.16))
	draw_string(font, Vector2(-9, -15), "ON" if on else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.9, 0.8, 0.55))
