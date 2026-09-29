extends Node2D
## Robotic arm: a clockwork inserter on a brass turret. It watches a pick-up
## spot (PICK, on one side) for a resting piece that matches its filter,
## swings over, closes its claw on it, swings it round to the drop spot on
## the other side and lets go. Slower than a tap or a splitter, but it
## picks exactly what you ask for off a track or a pile. Click the base to
## cycle the filter; the arm's reach sets both spots.

const Hold = preload("res://scripts/hold.gd")
const SFX = preload("res://scripts/sfx.gd")
const FILTERS := ["any", "copper", "iron", "scrap", "ingot", "grit"]
const COLORS := {"copper": Color(0.95, 0.55, 0.3), "iron": Color(0.6, 0.65, 0.75), "scrap": Color(0.7, 0.6, 0.45),
	"grit": Color(0.8, 0.75, 0.65), "ingot": Color(1.0, 0.85, 0.4), "any": Color(0.6, 0.9, 1.0)}
const SHOULDER := Vector2(0, -16)
const UPPER := 20.0
const LOWER := 18.0
const PICK_R := 14.0
const SWING := 0.55              # s per move

@export var mode := 0
@export var pick := Vector2(-30, -8)
@export var drop := Vector2(30, -24)

var moved := 0                   # tests
var _state := 0                  # 0 wait, 1 to pick, 2 to drop, 3 back
var _hand := Vector2.ZERO        # local
var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _held: RigidBody2D = null
var _art: Node2D                 # pixel art under our _draw (filter lamp, pick/drop marks)
var _upper: Sprite2D
var _lower: Sprite2D
var _claw: Sprite2D


func _ready() -> void:
	z_index = 3
	# sprites first (ghosts too): the turret, two links turned to the reach, the claw
	_art = Node2D.new()
	_art.show_behind_parent = true
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_art)
	_part(preload("res://assets/sprites/arm_base.png"), Vector2(-12, -22))
	_upper = _part(preload("res://assets/sprites/arm_upper.png"), Vector2(-4, -4))
	_lower = _part(preload("res://assets/sprites/arm_lower.png"), Vector2(-4, -4))
	_claw = _part(preload("res://assets/sprites/arm_claw.png"), Vector2(-7, -2))
	_claw.hframes = 2
	_art.move_child(_lower, 1)   # the forearm under the upper link's elbow knuckle
	_hand = pick + Vector2(0, -14)
	if has_meta("ghost"):
		return
	add_to_group("arms")


func _matches(o: RigidBody2D) -> bool:
	var f: String = FILTERS[mode]
	if f == "any":
		return true
	if f == "ingot":
		return o.is_in_group("ingots")
	return o.is_in_group("ore") and o.get("kind") == f


func _find() -> RigidBody2D:
	var at := to_global(pick)
	for g in ["ore", "ingots"]:
		for o in get_tree().get_nodes_in_group(g):
			if is_instance_valid(o) and not o.freeze and Hold.free_to_take(o, self) and o.global_position.distance_to(at) < PICK_R \
					and o.linear_velocity.length() < 60.0 and _matches(o):
				return o
	return null


func _move(to: Vector2) -> void:
	_from = _hand
	_to = to
	_t = 0.0


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	if _state == 0:
		var o := _find()
		if o:
			_held = o
			o.set_meta("caught_by", self)
			_state = 1
			_move(to_local(o.global_position))
		queue_redraw()
		return
	_t = minf(1.0, _t + delta / SWING)
	var k := _t * _t * (3.0 - 2.0 * _t)
	# swing on an arc (up and over), not straight through
	_hand = _from.lerp(_to, k) + Vector2(0, -sin(k * PI) * 18.0 if _state == 2 else 0.0)
	if _held and is_instance_valid(_held) and _state == 2:
		_held.global_position = to_global(_hand + Vector2(0, 5))
		_held.linear_velocity = Vector2.ZERO
		if "_timer" in _held:
			_held._timer = 0.0
	if _t >= 1.0:
		match _state:
			1:   # grab
				if _held and is_instance_valid(_held):
					_held.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
					_held.set_deferred("freeze", true)
					SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.5)
					_state = 2
					_move(drop)
				else:
					_state = 3
					_move(pick + Vector2(0, -14))
			2:   # let go
				if _held and is_instance_valid(_held):
					_held.freeze = false
					_held.remove_meta("caught_by")
					_held.linear_velocity = Vector2(0, 30)
					_held.sleeping = false
					moved += 1
				_held = null
				_state = 3
				_move(pick + Vector2(0, -14))
			3:
				_state = 0
	queue_redraw()


## Two-bone reach from the shoulder to the hand.
func _elbow(hand: Vector2) -> Vector2:
	var d := hand - SHOULDER
	var l := clampf(d.length(), 1.0, UPPER + LOWER - 0.5)
	var a := acos(clampf((UPPER * UPPER + l * l - LOWER * LOWER) / (2.0 * UPPER * l), -1.0, 1.0))
	return SHOULDER + d.normalized().rotated(-a * signf(d.x if d.x != 0 else 1.0)) * UPPER


func _part(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	_art.add_child(sp)
	return sp


func _draw() -> void:
	var col: Color = COLORS[FILTERS[mode]]
	# pose the sprites: shoulder -> elbow -> hand
	var e := _elbow(_hand)
	_upper.position = SHOULDER
	_upper.rotation = (e - SHOULDER).angle()
	_lower.position = e
	_lower.rotation = (_hand - e).angle()
	_claw.position = _hand
	_claw.frame = 0 if _held == null or _state == 1 else 1
	# the filter lamp on the turret
	draw_circle(Vector2(0, -3), 1.5, col)
	# where it picks from and drops to (faint)
	draw_arc(pick, PICK_R, 0, TAU, 16, Color(col.r, col.g, col.b, 0.25), 1.0)
	draw_line(drop + Vector2(-3, 0), drop + Vector2(3, 0), Color(col.r, col.g, col.b, 0.35), 1.0)


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position + Vector2(0, -4)) < 10:
			mode = (mode + 1) % FILTERS.size()
			SFX.play(self, SFX.sfx_clink())
			var scene := get_tree().current_scene
			if scene.has_method("_show_banner"):
				scene._show_banner("ROBOTIC ARM", "picks up: %s" % FILTERS[mode])
			get_viewport().set_input_as_handled()
