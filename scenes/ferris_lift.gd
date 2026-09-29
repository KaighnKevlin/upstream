extends Node2D
## Ferris lift: a big spoked wheel hung with little cups, turning slowly.
## A cup sweeping through the bottom scoops up any marble resting there,
## carries it round and, just past the top, tips it out toward `side`.
## A bucket elevator: lifts a lot, one marble per cup, and turns faster
## when a gravity wheel or steam engine drives it. The node is the hub.

const Hold = preload("res://scripts/hold.gd")
const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const RADIUS := 56.0
const CUPS := 8
const SPIN := 0.7                # rad/s at full power
const SCOOP := 14.0              # px: how close a marble must be to a low cup

@export var side := 1.0          # which way it turns (and so which way it tips out at the top)

var lifted := 0                  # tests
var _angle := 0.0
var _load: Array = []            # per cup: the body it carries, or null
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _area: Area2D
var _wheel: Sprite2D             # pixel art: the stand, the turning wheel, level cups
var _cups: Array[Sprite2D] = []


func _ready() -> void:
	z_index = 2
	# sprites first (ghosts too)
	var stand := Sprite2D.new()
	stand.texture = preload("res://assets/sprites/ferris_stand.png")
	stand.centered = false
	stand.offset = Vector2(-32, -6)
	stand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stand)
	_wheel = Sprite2D.new()      # the spokes turn; the rim, being round, stays put (crisp)
	_wheel.texture = preload("res://assets/sprites/ferris_spokes.png")
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_wheel)
	var rim := Sprite2D.new()
	rim.texture = preload("res://assets/sprites/ferris_rim.png")
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(rim)
	for k in CUPS:
		var cup := Sprite2D.new()
		cup.texture = preload("res://assets/sprites/ferris_cup.png")
		cup.centered = false
		cup.offset = Vector2(-9, -10)
		cup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cup.position = _cup(k)
		add_child(cup)
		_cups.append(cup)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_load.resize(CUPS)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS + SCOOP
	cs.shape = c
	_area.add_child(cs)
	add_child(_area)


func _cup(k: int) -> Vector2:
	var a := _angle + TAU * k / CUPS
	return Vector2(cos(a), sin(a)) * RADIUS


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	# turning with `side` = 1 carries the rising cups up the left and over the top to the right
	_angle += delta * SPIN * _rate * side
	var near := _area.get_overlapping_bodies()
	for k in CUPS:
		var p := _cup(k)
		var b = _load[k]
		if b != null and not is_instance_valid(b):
			_load[k] = null
			b = null
		if b != null:
			var o := b as RigidBody2D
			# tip out once the cup is over the top and heading down the far side
			if p.y < -RADIUS * 0.6 and signf(p.x) == signf(side):
				Hold.release(o, self)
				o.remove_meta("in_lift")
				o.linear_velocity = Vector2(side * 90.0, -30.0)
				_load[k] = null
				lifted += 1
				SFX.play_small(self, SFX.sfx_ore_knock("wood"), -16.0, 1.1)
			else:
				Hold.claim(o, self)
				o.linear_velocity = (global_position + p + Vector2(0, -5) - o.global_position) / maxf(delta, 0.001) * 0.5
				o.angular_velocity = 0.0
				if "_timer" in o:
					o._timer = 0.0
			continue
		# an empty cup in the bottom third scoops the nearest free marble
		if p.y < RADIUS * 0.5:
			continue
		var best: RigidBody2D = null
		var bd := SCOOP
		for n in near:
			if not (n is RigidBody2D) or n.freeze or n.has_meta("in_lift") or n.has_meta("in_beam") or not Hold.free_to_take(n, self):
				continue
			var d: float = n.global_position.distance_to(global_position + p)
			if d < bd:
				bd = d
				best = n
		if best:
			best.set_meta("in_lift", true)
			Hold.claim(best, self)
			best.gravity_scale = 0.0
			best.sleeping = false
			_load[k] = best
	queue_redraw()


func _draw() -> void:
	# the wheel turns; its cups hang level from the rim
	_wheel.rotation = _angle
	for k in CUPS:
		_cups[k].position = _cup(k)
